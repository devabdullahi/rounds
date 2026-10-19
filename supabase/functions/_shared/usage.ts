// What model calls cost, and a project-wide daily spending cap (private.llm_usage, migration
// 20261018000000_llm_usage). Per-student limits live in quota.ts; this cap is the backstop that
// holds even if many students, a bug or a retry loop all spend at once.

import { HttpError } from "./http.ts";
import { sql } from "./db.ts";

/** Tokens one call used. `output` includes `reasoning`, which OpenAI bills as output. */
export type Usage = { hit: number; miss: number; output: number; reasoning: number };

/** USD per million tokens, OpenAI at Standard. `hit` is the cached-input price.
 *  Models missing here are logged with tokens but cost 0, and don't count toward the cap. */
const PRICES: Record<string, { hit: number; miss: number; output: number }> = {
  "gpt-6.1-sol": { hit: 0.10, miss: 2.00, output: 10.00 },
  "gpt-6-luna": { hit: 0.01, miss: 0.10, output: 0.50 },
  // DeepSeek at its peak rate (off-peak is half), so spend is never undercounted.
  "deepseek-flash": { hit: 0.006, miss: 0.30, output: 1.20 },
};

/** Default daily cap in USD; LLM_DAILY_BUDGET_USD overrides it per deployment. */
const DEFAULT_DAILY_BUDGET_USD = 25;

/** Tasks that make content (cases, profiles, flashcards) rather than serve a student mid-visit. */
const CONTENT_TASKS = ["case", "audit", "template", "profile", "cards"];
/** Share of the daily cap content may use; the rest is kept for chat, grading and voice, so a rush
 *  of new patients can't stop students in the middle of a case. LLM_CONTENT_BUDGET_SHARE overrides it. */
const DEFAULT_CONTENT_SHARE = 0.6;

export function isContentTask(task: string | undefined): boolean {
  return !!task && CONTENT_TASKS.includes(task);
}

export function contentShare(raw = Deno.env.get("LLM_CONTENT_BUDGET_SHARE")): number {
  const value = Number(raw);
  return raw !== undefined && Number.isFinite(value) && value > 0 && value <= 1 ? value : DEFAULT_CONTENT_SHARE;
}

export function costUSD(model: string, u: Usage): number {
  const p = PRICES[model];
  if (!p) return 0;
  return (u.hit * p.hit + u.miss * p.miss + u.output * p.output) / 1_000_000;
}

export function dailyBudgetUSD(raw = Deno.env.get("LLM_DAILY_BUDGET_USD")): number {
  const value = Number(raw);
  return raw !== undefined && Number.isFinite(value) && value > 0 ? value : DEFAULT_DAILY_BUDGET_USD;
}

/** The daily spending cap refused a call. Retrying today won't help, so callers pass it on as is. */
export class BudgetExceeded extends HttpError {
  constructor(message: string) {
    super(503, message);
  }
}

/** Whether a call may go ahead, from today's spend: content stops at its share of the cap, and
 *  everything stops at the whole cap. Pure, so the split is unit-tested. */
export function withinBudget(task: string | undefined, spent: { total: number; content: number }, cap = dailyBudgetUSD(), share = contentShare()): boolean {
  if (spent.total >= cap) return false;
  return !isContentTask(task) || spent.content < cap * share;
}

/** Refuses the call once today's spend reaches its cap (see withinBudget). A failed lookup lets the
 *  call through: the cap guards cost, not access, and the per-student quotas still apply. */
export async function takeBudget(task?: string): Promise<void> {
  let spent = { total: 0, content: 0 };
  try {
    [spent] = await sql<{ total: number; content: number }[]>`
      select coalesce(sum(cost_usd), 0)::float8 as total,
        coalesce(sum(cost_usd) filter (where task = any(${CONTENT_TASKS}::text[])), 0)::float8 as content
      from private.llm_usage where day = (now() at time zone 'utc')::date`;
  } catch (error) {
    console.error("llm budget check failed", error);
    return;
  }
  if (!withinBudget(task, spent)) {
    console.error("llm daily budget reached", task, spent);
    throw new BudgetExceeded(isContentTask(task)
      ? "Rounds is writing a lot of patients right now. Please try again in a little while."
      : "Rounds is very busy right now. Please try again tomorrow.");
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
