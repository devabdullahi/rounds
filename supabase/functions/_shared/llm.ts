// One JSON-returning LLM call behind a provider switch (same variables as tools/kb-generate):
//   LLM_PROVIDER      = deepseek (default) | anthropic | openai
//   LLM_MODEL         = optional override for every task (a one-line rollback)
//   LLM_MODEL_<TASK>  = optional override for one task, e.g. LLM_MODEL_PROFILE=deepseek-flash; the
//                       model name picks its provider (gpt-… OpenAI, claude-… Anthropic, deepseek-…)
//   DEEPSEEK_API_KEY / ANTHROPIC_API_KEY / OPENAI_API_KEY
// Keys come from supabase/functions/.env locally and `supabase secrets set` when deployed.
//
// Each call names its task, and the task picks the model and reasoning effort. Thinking is slow:
// the case writer took 41 s without it and 168 s at high effort, and a profile stage 77 s at low and
// 172 s at high, so only work where accuracy matters thinks, at an effort that fits the time limit.

import { costUSD, recordUsage, takeBudget, type Usage } from "./usage.ts";

/** `thinking` says how the provider takes a reasoning effort: DeepSeek's thinking switch, OpenAI's
 *  reasoning models (max_completion_tokens, reasoning_effort, no temperature), or not at all. */
export type Provider = {
  url: string; keyEnv: string; model: string; style: "openai" | "anthropic"; thinking?: "deepseek" | "openai";
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

/** Per task: V4.1 Flash (the `deepseek-flash` alias) in chat mode where speed matters and the facts
 *  are already decided (patient chat, the reply check, case writing, flashcards), thinking for
 *  grading. Condition profiles are written from memory, where OpenAI's GPT-6.1 Sol guesses far less
 *  often than DeepSeek (AA-Omniscience hallucination ~54% vs ~95%), so they go to Sol. Profiles carry
 *  no student data. Medium effort fits prepare-profile's time limit. */
const DEEPSEEK_TASKS: Record<Task, Setting> = {
  patient: { model: "deepseek-flash", effort: "off" },
  check: { model: "deepseek-flash", effort: "off" },
  cards: { model: "deepseek-flash", effort: "off" },
  case: { model: "deepseek-flash", effort: "off" }, // facts come from the profile; 16-20 s vs ~40 s on v4-pro
  grade: { model: "deepseek-flash", effort: "high" },
  // Low, not high: one stage must finish inside prepare-profile's 140 s. tools/kb-generate runs high.
  profile: { provider: "openai", model: "gpt-6.1-sol", effort: "medium" },
};

export type CallOptions = { task: Task; temperature?: number; timeoutMs?: number };

export const PROVIDERS: Record<string, Provider> = {
  deepseek: { url: "https://api.deepseek.com/chat/completions", keyEnv: "DEEPSEEK_API_KEY", model: "deepseek-flash", style: "openai", thinking: "deepseek", tasks: DEEPSEEK_TASKS },
  openai: { url: "https://api.openai.com/v1/chat/completions", keyEnv: "OPENAI_API_KEY", model: "gpt-6.1-sol", style: "openai", thinking: "openai" },
  anthropic: { url: "https://api.anthropic.com/v1/messages", keyEnv: "ANTHROPIC_API_KEY", model: "claude-sonnet-5-5", style: "anthropic" },
};

function providerName(): string {
  return Deno.env.get("LLM_PROVIDER") ?? "deepseek";
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

/** Token counts from either API's usage block. Cache hits are DeepSeek's (and OpenAI's cached) prompt tokens. */
// deno-lint-ignore no-explicit-any
export function usageOf(reply: any): Usage {
  const u = reply?.usage ?? {};
  if (u.input_tokens !== undefined) {
    const hit = (u.cache_read_input_tokens ?? 0) as number;
    return { hit, miss: (u.input_tokens ?? 0) + (u.cache_creation_input_tokens ?? 0), output: u.output_tokens ?? 0, reasoning: 0 };
  }
  const hit = (u.prompt_cache_hit_tokens ?? u.prompt_tokens_details?.cached_tokens ?? 0) as number;
  return {
    hit,
    miss: u.prompt_cache_miss_tokens ?? Math.max(0, (u.prompt_tokens ?? 0) - hit),
    output: u.completion_tokens ?? 0,
    reasoning: u.completion_tokens_details?.reasoning_tokens ?? 0,
  };
}

/** The token cap plus the provider's reasoning switch. DeepSeek thinks by default, so "off" must say
 *  so. OpenAI's reasoning models always reason: they take max_completion_tokens, and "off" leaves
 *  their default effort. */
export function thinkingFields(thinking: Provider["thinking"], maxTokens: number, effort: Effort): Record<string, unknown> {
  if (thinking === "openai") {
    if (effort === "off") return { max_completion_tokens: maxTokens + REASONING_BUDGET.medium };
    return { max_completion_tokens: maxTokens + REASONING_BUDGET[effort], reasoning_effort: effort };
  }
  if (!thinking) return { max_tokens: maxTokens };
  if (effort === "off") return { max_tokens: maxTokens, thinking: { type: "disabled" } };
  return { max_tokens: maxTokens + REASONING_BUDGET[effort], thinking: { type: "enabled" }, reasoning_effort: effort };
}

export function parseJSON<T>(text: string): T {
  const fenced = text.match(/```(?:json)?\s*(\{[\s\S]*\})\s*```/);
  const raw = fenced ? fenced[1] : text.slice(text.indexOf("{"), text.lastIndexOf("}") + 1);
  return JSON.parse(raw) as T;
}
