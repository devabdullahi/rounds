// Daily limits on model-backed actions (private.usage, migration 20261009000000_daily_limits).
// Defaults suit real study; each can be changed per deployment with an env var.

import { HttpError } from "./http.ts";
import { sql } from "./db.ts";

export type QuotaKind = "case" | "question" | "cards" | "grade" | "voice";

const LIMITS: Record<QuotaKind, { env: string; fallback: number; noun: string }> = {
  case: { env: "LIMIT_CASES_PER_DAY", fallback: 10, noun: "new patients" },
  question: { env: "LIMIT_QUESTIONS_PER_DAY", fallback: 200, noun: "patient questions" },
  cards: { env: "LIMIT_CARD_DECKS_PER_DAY", fallback: 3, noun: "generated card decks" },
  // Above the case limit: shared published cases and resubmits are graded too.
  grade: { env: "LIMIT_GRADES_PER_DAY", fallback: 30, noun: "graded submissions" },
  // Each spoken turn is two units: the student's words transcribed, the patient's reply spoken.
  voice: { env: "LIMIT_VOICE_PER_DAY", fallback: 400, noun: "voice turns" },
};

export function dailyLimit(kind: QuotaKind): number {
  const raw = Number(Deno.env.get(LIMITS[kind].env));
  return Number.isInteger(raw) && raw > 0 ? raw : LIMITS[kind].fallback;
}

/** Takes one unit of today's allowance, or refuses with a 429 the app shows as is. */
export async function takeQuota(userId: string, kind: QuotaKind): Promise<void> {
  const cap = dailyLimit(kind);
  const [{ ok }] = await sql<{ ok: boolean }[]>`select private.take_quota(${userId}, ${kind}, ${cap}) as ok`;
  if (!ok) throw new HttpError(429, `you've reached today's limit of ${cap} ${LIMITS[kind].noun}; it resets at midnight UTC`);
}

/** Units of today's allowance still free, for showing "2 of 3 left today". */
export async function remainingToday(userId: string, kind: QuotaKind): Promise<{ remaining: number; limit: number }> {
  const limit = dailyLimit(kind);
  const [row] = await sql<{ used: number }[]>`
    select used from private.usage
    where user_id = ${userId} and day = (now() at time zone 'utc')::date and kind = ${kind}`;
  return { remaining: Math.max(0, limit - (row?.used ?? 0)), limit };
}

/** Gives a unit back when the action it paid for failed, so a model error costs the student nothing. */
export async function refundQuota(userId: string, kind: QuotaKind): Promise<void> {
  await sql`select private.refund_quota(${userId}, ${kind})`.catch((error) => console.error("quota refund failed", error));
}

/** Runs `work` against one unit of allowance, refunding it if `work` throws. */
export async function withQuota<T>(userId: string, kind: QuotaKind, work: () => Promise<T>): Promise<T> {
  await takeQuota(userId, kind);
  try {
    return await work();
  } catch (error) {
    await refundQuota(userId, kind);
    throw error;
  }
}
