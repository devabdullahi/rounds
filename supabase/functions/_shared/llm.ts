// One JSON-returning LLM call behind a provider switch (same variables as tools/kb-generate):
//   LLM_PROVIDER      = deepseek (default) | anthropic | openai
//   LLM_MODEL         = optional override for every task (a one-line rollback)
//   LLM_MODEL_<TASK>  = optional override for one task, e.g. LLM_MODEL_PATIENT=deepseek-v4-pro
//   DEEPSEEK_API_KEY / ANTHROPIC_API_KEY / OPENAI_API_KEY
// Keys come from supabase/functions/.env locally and `supabase secrets set` when deployed.
//
// Each call names its task, and the task picks the model and reasoning effort. Thinking is slow:
// the case writer took 41 s without it and 168 s at high effort, and a profile stage 77 s at low and
// 172 s at high, so only work where accuracy matters thinks, at an effort that fits the time limit.

import { costUSD, recordUsage, takeBudget, type Usage } from "./usage.ts";

export type Provider = { url: string; keyEnv: string; model: string; style: "openai" | "anthropic"; tasks?: Record<Task, Setting> };

/** What a call is for. Every call names one, so cost and model choice are tracked per feature. */
export type Task = "patient" | "check" | "case" | "grade" | "cards" | "profile";

/** How hard the model reasons before answering. Only providers with per-task settings use it. */
export type Effort = "off" | "low" | "high" | "max";

type Setting = { model: string; effort: Effort };

/** Reasoning tokens count against max_tokens, so thinking calls get this much extra room or the
 *  answer is cut off after the reasoning (finish_reason "length", empty content). */
const REASONING_BUDGET: Record<Exclude<Effort, "off">, number> = { low: 2000, high: 8000, max: 16000 };

/** DeepSeek per task: the cheap fast model where speed matters and the facts are already decided
 *  (patient chat, the reply check, case writing, flashcards); the large model where the output is
 *  clinical truth or a judgment (profiles, grading). */
const DEEPSEEK_TASKS: Record<Task, Setting> = {
  patient: { model: "deepseek-flash", effort: "off" },
  check: { model: "deepseek-flash", effort: "off" },
  cards: { model: "deepseek-flash", effort: "off" },
  case: { model: "deepseek-flash", effort: "off" }, // facts come from the profile; 16-20 s vs ~40 s on v4-pro
  grade: { model: "deepseek-v4-pro", effort: "high" },
  // Low, not high: one stage must finish inside prepare-profile's 140 s. tools/kb-generate runs high.
  profile: { model: "deepseek-v4-pro", effort: "low" },
};

export type CallOptions = { task: Task; temperature?: number; timeoutMs?: number };

export const PROVIDERS: Record<string, Provider> = {
  deepseek: { url: "https://api.deepseek.com/chat/completions", keyEnv: "DEEPSEEK_API_KEY", model: "deepseek-v4-pro", style: "openai", tasks: DEEPSEEK_TASKS },
  openai: { url: "https://api.openai.com/v1/chat/completions", keyEnv: "OPENAI_API_KEY", model: "gpt-4.1", style: "openai" },
  anthropic: { url: "https://api.anthropic.com/v1/messages", keyEnv: "ANTHROPIC_API_KEY", model: "claude-sonnet-5-5", style: "anthropic" },
};

function providerName(): string {
  return Deno.env.get("LLM_PROVIDER") ?? "deepseek";
}

/** The model and effort a task runs with, after env overrides. An overridden model keeps the
 *  task's effort only on a provider that supports thinking. */
export function settingFor(provider: Provider, task: Task, env: (key: string) => string | undefined = (k) => Deno.env.get(k)): Setting {
  const base = provider.tasks?.[task] ?? { model: provider.model, effort: "off" as Effort };
  const model = env(`LLM_MODEL_${task.toUpperCase()}`) ?? env("LLM_MODEL") ?? base.model;
  return { model, effort: provider.tasks ? base.effort : "off" };
}

export function currentModel(task: Task): string {
  const name = providerName();
  const provider = PROVIDERS[name];
  return `${name}/${provider ? settingFor(provider, task).model : "unknown"}`;
}

/** How long one model call may take. A hung provider must fail the call (so withQuota refunds and
 *  the student can retry) well before the edge runtime kills the whole request. */
export const LLM_TIMEOUT_MS = 90_000;

export async function completeJSON<T>(
  system: string, user: string, maxTokens: number, { task, temperature, timeoutMs = LLM_TIMEOUT_MS }: CallOptions,
): Promise<T> {
  const name = providerName();
  const provider = PROVIDERS[name];
  if (!provider) throw new Error(`unknown LLM_PROVIDER ${name}`);
  const key = Deno.env.get(provider.keyEnv);
  if (!key) throw new Error(`${provider.keyEnv} is not set`);
  const { model, effort } = settingFor(provider, task);
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
        ...thinkingFields(provider.tasks !== undefined, maxTokens, effort),
        temperature: temperature ?? 0.7,
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

/** max_tokens plus the provider's thinking switch. DeepSeek thinks by default, so "off" must say so. */
export function thinkingFields(thinking: boolean, maxTokens: number, effort: Effort): Record<string, unknown> {
  if (!thinking) return { max_tokens: maxTokens };
  if (effort === "off") return { max_tokens: maxTokens, thinking: { type: "disabled" } };
  return { max_tokens: maxTokens + REASONING_BUDGET[effort], thinking: { type: "enabled" }, reasoning_effort: effort };
}

export function parseJSON<T>(text: string): T {
  const fenced = text.match(/```(?:json)?\s*(\{[\s\S]*\})\s*```/);
  const raw = fenced ? fenced[1] : text.slice(text.indexOf("{"), text.lastIndexOf("}") + 1);
  return JSON.parse(raw) as T;
}
