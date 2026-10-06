// One JSON-returning LLM call behind a provider switch (same variables as tools/kb-generate):
//   LLM_PROVIDER = deepseek (default) | anthropic | openai
//   LLM_MODEL    = optional override
//   DEEPSEEK_API_KEY / ANTHROPIC_API_KEY / OPENAI_API_KEY
// Keys come from supabase/functions/.env locally and `supabase secrets set` when deployed.

type Provider = { url: string; keyEnv: string; model: string; style: "openai" | "anthropic" };

const PROVIDERS: Record<string, Provider> = {
  deepseek: { url: "https://api.deepseek.com/chat/completions", keyEnv: "DEEPSEEK_API_KEY", model: "deepseek-chat", style: "openai" },
  openai: { url: "https://api.openai.com/v1/chat/completions", keyEnv: "OPENAI_API_KEY", model: "gpt-4.1", style: "openai" },
  anthropic: { url: "https://api.anthropic.com/v1/messages", keyEnv: "ANTHROPIC_API_KEY", model: "claude-sonnet-5-5", style: "anthropic" },
};

export function currentModel(): string {
  const name = Deno.env.get("LLM_PROVIDER") ?? "deepseek";
  return `${name}/${Deno.env.get("LLM_MODEL") ?? PROVIDERS[name]?.model}`;
}

export async function completeJSON<T>(system: string, user: string, maxTokens = 4000, temperature?: number): Promise<T> {
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
      body: JSON.stringify({
        model,
        messages: [{ role: "system", content: system }, { role: "user", content: user }],
        response_format: { type: "json_object" },
        max_tokens: maxTokens,
        temperature: temperature ?? 0.7,
      }),
    })
    : await fetch(provider.url, {
      method: "POST",
      headers: { "x-api-key": key, "anthropic-version": "2023-06-01", "Content-Type": "application/json" },
      body: JSON.stringify({ model, max_tokens: maxTokens, system, messages: [{ role: "user", content: user }], ...(temperature === undefined ? {} : { temperature }) }),
    });
  if (!res.ok) throw new Error(`LLM ${res.status}: ${await res.text()}`);
  const reply = await res.json();
  const text: string = provider.style === "openai"
    ? reply.choices[0].message.content
    : reply.content.map((b: { text?: string }) => b.text ?? "").join("");
  return parseJSON<T>(text);
}

export function parseJSON<T>(text: string): T {
  const fenced = text.match(/```(?:json)?\s*(\{[\s\S]*\})\s*```/);
  const raw = fenced ? fenced[1] : text.slice(text.indexOf("{"), text.lastIndexOf("}") + 1);
  return JSON.parse(raw) as T;
}
