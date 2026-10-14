// One JSON-returning LLM call behind a provider switch (same variables as tools/kb-generate):
//   LLM_PROVIDER = deepseek (default) | anthropic | openai
//   LLM_MODEL    = optional override
// Each call picks a reasoning effort (default "off"). Thinking is slow: the case writer took 41s off,
// 80s at low and 168s at high, so only short-output calls where accuracy matters turn it on.
//   DEEPSEEK_API_KEY / ANTHROPIC_API_KEY / OPENAI_API_KEY
// Keys come from supabase/functions/.env locally and `supabase secrets set` when deployed.

type Provider = { url: string; keyEnv: string; model: string; style: "openai" | "anthropic"; thinking?: boolean };

/** How hard the model reasons before answering. Only providers with `thinking` honor it. */
export type Effort = "off" | "low" | "high" | "max";

/** Reasoning tokens count against max_tokens, so thinking calls get this much extra room or the
 *  answer is cut off after the reasoning (finish_reason "length", empty content). */
const REASONING_BUDGET: Record<Exclude<Effort, "off">, number> = { low: 2000, high: 8000, max: 16000 };

export type CallOptions = { temperature?: number; timeoutMs?: number; effort?: Effort };

const PROVIDERS: Record<string, Provider> = {
  deepseek: { url: "https://api.deepseek.com/chat/completions", keyEnv: "DEEPSEEK_API_KEY", model: "deepseek-v4-pro", style: "openai", thinking: true },
  openai: { url: "https://api.openai.com/v1/chat/completions", keyEnv: "OPENAI_API_KEY", model: "gpt-4.1", style: "openai" },
  anthropic: { url: "https://api.anthropic.com/v1/messages", keyEnv: "ANTHROPIC_API_KEY", model: "claude-sonnet-5-5", style: "anthropic" },
};

export function currentModel(): string {
  const name = Deno.env.get("LLM_PROVIDER") ?? "deepseek";
  return `${name}/${Deno.env.get("LLM_MODEL") ?? PROVIDERS[name]?.model}`;
}

/** How long one model call may take. A hung provider must fail the call (so withQuota refunds and
 *  the student can retry) well before the edge runtime kills the whole request. */
export const LLM_TIMEOUT_MS = 90_000;

export async function completeJSON<T>(
  system: string, user: string, maxTokens = 4000, { temperature, timeoutMs = LLM_TIMEOUT_MS, effort = "off" }: CallOptions = {},
): Promise<T> {
  const name = Deno.env.get("LLM_PROVIDER") ?? "deepseek";
  const provider = PROVIDERS[name];
  if (!provider) throw new Error(`unknown LLM_PROVIDER ${name}`);
  const key = Deno.env.get(provider.keyEnv);
  if (!key) throw new Error(`${provider.keyEnv} is not set`);
  const model = Deno.env.get("LLM_MODEL") ?? provider.model;

  const res = provider.style === "openai"
    ? await fetch(provider.url, {
      method: "POST",
      headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
      signal: AbortSignal.timeout(timeoutMs),
      body: JSON.stringify({
        model,
        messages: [{ role: "system", content: system }, { role: "user", content: user }],
        response_format: { type: "json_object" },
        ...thinkingFields(provider.thinking ?? false, maxTokens, effort),
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
  const text: string = provider.style === "openai"
    ? reply.choices[0].message.content
    : reply.content.map((b: { text?: string }) => b.text ?? "").join("");
  return parseJSON<T>(text);
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
