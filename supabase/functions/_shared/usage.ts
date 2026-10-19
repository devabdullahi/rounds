// What model calls cost, and a project-wide daily spending cap (private.llm_usage, migration
// 20261018000000_llm_usage). Per-student limits live in quota.ts; this cap is the backstop that
// holds even if many students, a bug or a retry loop all spend at once.

import { HttpError } from "./http.ts";
import { sql } from "./db.ts";

/** Tokens one call used. `output` includes `reasoning`, which DeepSeek bills as output. */
export type Usage = { hit: number; miss: number; output: number; reasoning: number };

/** USD per million tokens: DeepSeek at its peak rate (off-peak is half), so spend is never
 *  undercounted; OpenAI at Standard. `hit` is the cached-input price.
 *  Models missing here are logged with tokens but cost 0, and don't count toward the cap. */
const PRICES: Record<string, { hit: number; miss: number; output: number }> = {
  "deepseek-flash": { hit: 0.006, miss: 0.30, output: 1.20 },
  "deepseek-v4-pro": { hit: 0.044, miss: 1.32, output: 3.96 },
  "gpt-6.1-sol": { hit: 0.10, miss: 2.00, output: 10.00 },
  "gpt-6-luna": { hit: 0.01, miss: 0.10, output: 0.50 },
};

/** Default daily cap in USD; LLM_DAILY_BUDGET_USD overrides it per deployment. */
const DEFAULT_DAILY_BUDGET_USD = 25;

export function costUSD(model: string, u: Usage): number {
  const p = PRICES[model];
  if (!p) return 0;
  return (u.hit * p.hit + u.miss * p.miss + u.output * p.output) / 1_000_000;
}

export function dailyBudgetUSD(raw = Deno.env.get("LLM_DAILY_BUDGET_USD")): number {
  const value = Number(raw);
  return raw !== undefined && Number.isFinite(value) && value > 0 ? value : DEFAULT_DAILY_BUDGET_USD;
}

/** Refuses the call once today's spend reaches the cap. A failed lookup lets the call through:
 *  the cap guards cost, not access, and the per-student quotas still apply. */
export async function takeBudget(): Promise<void> {
  let spent = 0;
  try {
    [{ spent }] = await sql<{ spent: number }[]>`select private.llm_spend_today()::float8 as spent`;
  } catch (error) {
    console.error("llm budget check failed", error);
    return;
  }
  if (spent >= dailyBudgetUSD()) {
    console.error("llm daily budget reached", spent);
    throw new HttpError(503, "Rounds is very busy right now. Please try again tomorrow.");
  }
}

/** Adds one call to today's totals. Never throws: the model already answered, and losing a log line
 *  must not cost the student that answer. */
export async function recordUsage(task: string, model: string, u: Usage, cost: number): Promise<void> {
  try {
    await sql`select private.record_llm_usage(${task}, ${model}, ${u.hit}, ${u.miss}, ${u.output}, ${u.reasoning}, ${cost})`;
  } catch (error) {
    console.error("llm usage log failed", error);
  }
}
