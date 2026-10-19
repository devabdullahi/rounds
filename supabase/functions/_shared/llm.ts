// One JSON-returning LLM call behind a provider switch (same variables as tools/kb-generate):
//   LLM_PROVIDER      = openai (default) | anthropic
//   LLM_MODEL         = optional override for every task (a one-line rollback)
//   LLM_MODEL_<TASK>  = optional override for one task, e.g. LLM_MODEL_GRADE=gpt-6-luna; the
//                       model name picks its provider (gpt-… OpenAI, claude-… Anthropic)
//   OPENAI_API_KEY / ANTHROPIC_API_KEY / DEEPSEEK_API_KEY (flashcards)
// Keys come from supabase/functions/.env locally and `supabase secrets set` when deployed.
//
// Each call names its task, and the task picks the model and reasoning effort. Thinking is slow:
// the case writer took 41 s without it and 168 s at high effort, and a profile stage 77 s at low and
// 172 s at high, so only work where accuracy matters thinks, at an effort that fits the time limit.

import { costUSD, recordUsage, takeBudget, type Usage } from "./usage.ts";

/** `thinking` says how the provider takes a reasoning effort: OpenAI's reasoning models
 *  (max_completion_tokens, reasoning_effort, no temperature), or not at all. */
export type Provider = {
  url: string; keyEnv: string; model: string; style: "openai" | "anthropic"; thinking?: "openai" | "deepseek";
  tasks?: Record<Task, Setting>;
};

/** What a call is for. Every call names one, so cost and model choice are tracked per feature. */
export type Task = "patient" | "check" | "case" | "grade" | "cards" | "profile";

/** How hard the model reasons before answering. Only providers with per-task settings use it. */
export type Effort = "off" | "low" | "medium" | "high" | "max";

/** A task's model and effort, and the provider to call when it isn't the configured one. */
type Setting = { provider?: string; model: string; effort: Effort };

/** Reasoning tokens count against max_tokens, so thinking calls get this much extra room or the
 *  answer is cut off after the reasoning (finish_reason "length", empty content). */
const REASONING_BUDGET: Record<Exclude<Effort, "off">, number> = { low: 2000, medium: 4000, high: 8000, max: 16000 };

/** Per task on OpenAI: GPT-6 Luna with reasoning off where speed matters and the facts are already
 *  decided (patient chat, the reply check; ~1.6 s a turn), GPT-6.1 Sol where judgment or medical
 *  recall matters (writing the case, grading, condition profiles). Sol has no "none" effort, so its
 *  tasks always name one. Flashcards go to DeepSeek V4.1 Flash, the user's pick for cards
 *  (2026-10-18). */
const OPENAI_TASKS: Record<Task, Setting> = {
  patient: { model: "gpt-6-luna", effort: "off" },
  check: { model: "gpt-6-luna", effort: "off" },
  cards: { provider: "deepseek", model: "deepseek-flash", effort: "off" },
  case: { model: "gpt-6.1-sol", effort: "low" },
  grade: { model: "gpt-6.1-sol", effort: "medium" },
  profile: { model: "gpt-6.1-sol", effort: "medium" },
};

export type CallOptions = { task: Task; temperature?: number; timeoutMs?: number };

export const PROVIDERS: Record<string, Provider> = {
  openai: { url: "https://api.openai.com/v1/chat/completions", keyEnv: "OPENAI_API_KEY", model: "gpt-6.1-sol", style: "openai", thinking: "openai", tasks: OPENAI_TASKS },
  deepseek: { url: "https://api.deepseek.com/chat/completions", keyEnv: "DEEPSEEK_API_KEY", model: "deepseek-flash", style: "openai", thinking: "deepseek" },
  anthropic: { url: "https://api.anthropic.com/v1/messages", keyEnv: "ANTHROPIC_API_KEY", model: "claude-sonnet-5-5", style: "anthropic" },
};

function providerName(): string {
  return Deno.env.get("LLM_PROVIDER") ?? "openai";
}

/** The provider a model name belongs to, or undefined for a name that doesn't say. */
function providerOf(model: string): string | undefined {
  if (model.startsWith("gpt-")) return "openai";
  if (model.startsWith("claude-")) return "anthropic";
  if (model.startsWith("deepseek-")) return "deepseek";
  return undefined;
}

/** The model and effort a task runs with, after env overrides. An overridden model is sent to the
 *  provider its name belongs to, and keeps the task's effort only on a provider that thinks. */
export function settingFor(provider: Provider, task: Task, env: (key: string) => string | undefined = (k) => Deno.env.get(k)): Setting {
  const base = provider.tasks?.[task] ?? { model: provider.model, effort: "off" as Effort };
  const override = env(`LLM_MODEL_${task.toUpperCase()}`) ?? env("LLM_MODEL");
  if (!override) return provider.tasks ? base : { model: base.model, effort: "off" };
  const target = providerOf(override);
  const thinks = target ? PROVIDERS[target]?.thinking !== undefined : provider.thinking !== undefined;
  return { ...(target ? { provider: target } : {}), model: override, effort: provider.tasks && thinks ? base.effort : "off" };
}

/** The provider name and setting a task resolves to. */
function resolve(task: Task): { name: string; provider: Provider | undefined; setting: Setting } {
  const configured = providerName();
  const home = PROVIDERS[configured];
  const setting = home ? settingFor(home, task) : { model: "unknown", effort: "off" as Effort };
  const name = setting.provider ?? configured;
  return { name, provider: PROVIDERS[name], setting };
}

export function currentModel(task: Task): string {
  const { name, setting } = resolve(task);
  return `${name}/${setting.model}`;
}

/** How long one model call may take. A hung provider must fail the call (so withQuota refunds and
 *  the student can retry) well before the edge runtime kills the whole request. */
export const LLM_TIMEOUT_MS = 90_000;

export async function completeJSON<T>(
  system: string, user: string, maxTokens: number, { task, temperature, timeoutMs = LLM_TIMEOUT_MS }: CallOptions,
): Promise<T> {
  const { name, provider, setting: { model, effort } } = resolve(task);
  if (!provider) throw new Error(`unknown LLM provider ${name}`);
  const key = Deno.env.get(provider.keyEnv);
  if (!key) throw new Error(`${provider.keyEnv} is not set`);
  await takeBudget();

  const res = provider.style === "openai"
    ? await fetch(provider.url, {
      method: "POST",
      headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
      signal: AbortSignal.timeout(timeoutMs),
      body: JSON.stringify({
        model,
        messages: [{ role: "system", content: system }, { role: "user", content: user }],
        response_format: { type: "json_object" },
        ...thinkingFields(provider.thinking, maxTokens, effort),
        // OpenAI's reasoning models take only the default temperature.
        ...(provider.thinking === "openai" ? {} : { temperature: temperature ?? 0.7 }),
      }),
    })
    : await fetch(provider.url, {
      method: "POST",
      headers: { "x-api-key": key, "anthropic-version": "2023-06-01", "Content-Type": "application/json" },
      signal: AbortSignal.timeout(timeoutMs),
      body: JSON.stringify({ model, max_tokens: maxTokens, system, messages: [{ role: "user", content: user }], ...(temperature === undefined ? {} : { temperature }) }),
    });
  if (!res.ok) throw new Error(`LLM ${res.status}: ${await res.text()}`);
  const reply = await res.json();
  const usage = usageOf(reply);
  await recordUsage(task, `${name}/${model}`, usage, costUSD(model, usage));
  const text: string = provider.style === "openai"
    ? reply.choices[0].message.content
    : reply.content.map((b: { text?: string }) => b.text ?? "").join("");
  return parseJSON<T>(text);
}

/** Token counts from either API's usage block. Cache hits are OpenAI's cached prompt tokens. */
// deno-lint-ignore no-explicit-any
export function usageOf(reply: any): Usage {
  const u = reply?.usage ?? {};
  if (u.input_tokens !== undefined) {
    const hit = (u.cache_read_input_tokens ?? 0) as number;
    return { hit, miss: (u.input_tokens ?? 0) + (u.cache_creation_input_tokens ?? 0), output: u.output_tokens ?? 0, reasoning: 0 };
  }
  // DeepSeek reports its cache split directly; OpenAI reports cached tokens inside the prompt count.
  const hit = (u.prompt_cache_hit_tokens ?? u.prompt_tokens_details?.cached_tokens ?? 0) as number;
  return {
    hit,
    miss: u.prompt_cache_miss_tokens ?? Math.max(0, (u.prompt_tokens ?? 0) - hit),
    output: u.completion_tokens ?? 0,
    reasoning: u.completion_tokens_details?.reasoning_tokens ?? 0,
  };
}

/** The token cap plus the provider's reasoning switch. OpenAI reasons by default, so "off" sends the
 *  "none" effort (which Luna and GPT-6 Sol accept; GPT-6.1 Sol and Astra don't, so their tasks name
 *  an effort). OpenAI takes max_completion_tokens. */
export function thinkingFields(thinking: Provider["thinking"], maxTokens: number, effort: Effort): Record<string, unknown> {
  if (thinking === "openai") {
    if (effort === "off") return { max_completion_tokens: maxTokens, reasoning_effort: "none" };
    return { max_completion_tokens: maxTokens + REASONING_BUDGET[effort], reasoning_effort: effort };
  }
  // DeepSeek thinks by default too: "off" disables it explicitly.
  if (thinking === "deepseek") {
    if (effort === "off") return { max_tokens: maxTokens, thinking: { type: "disabled" } };
    return { max_tokens: maxTokens + REASONING_BUDGET[effort], thinking: { type: "enabled" }, reasoning_effort: effort };
  }
  return { max_tokens: maxTokens };
}

export function parseJSON<T>(text: string): T {
  const fenced = text.match(/```(?:json)?\s*(\{[\s\S]*\})\s*```/);
  const raw = fenced ? fenced[1] : text.slice(text.indexOf("{"), text.lastIndexOf("}") + 1);
  return JSON.parse(raw) as T;
}
