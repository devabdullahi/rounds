// Limits on model-backed actions. Students' actions have no daily allowance (2026-10-25: every
// student is a paying customer, unlimited): only a per-minute burst guard (private.burst, migration
// 20261025000000_burst_limits), set far above human speed, so a script or a stuck retry loop can't
// run up the AI bill. Purchase checks keep a daily allowance (private.usage); they're not usage.
// Each limit can be changed per deployment with an env var.

import { HttpError } from "./http.ts";
import { sql } from "./db.ts";

/** Kinds with a per-minute burst guard; `claim` has a daily allowance instead. */
export type QuotaKind = "case" | "question" | "cards" | "grade" | "claim";
type BurstKind = Exclude<QuotaKind, "claim">;

const BURSTS: Record<BurstKind, { env: string; fallback: number; noun: string }> = {
  // A fast typist asks 3 to 5 a minute; voice turns are similar.
  question: { env: "BURST_QUESTIONS_PER_MINUTE", fallback: 30, noun: "questions" },
  // Writing one takes a minute or more anyway.
  case: { env: "BURST_CASES_PER_MINUTE", fallback: 5, noun: "new patients" },
  cards: { env: "BURST_CARD_DECKS_PER_MINUTE", fallback: 5, noun: "card decks" },
  grade: { env: "BURST_GRADES_PER_MINUTE", fallback: 10, noun: "submissions" },
};

const CLAIMS = { env: "LIMIT_CLAIMS_PER_DAY", fallback: 50 };

function positiveInt(env: string, fallback: number): number {
  const raw = Number(Deno.env.get(env));
  return Number.isInteger(raw) && raw > 0 ? raw : fallback;
}

/** This minute's cap for a burst-guarded kind. */
export function burstLimit(kind: BurstKind): number {
  return positiveInt(BURSTS[kind].env, BURSTS[kind].fallback);
}

/** Today's cap on purchase checks (each one asks Apple). */
export function dailyClaimLimit(): number {
  return positiveInt(CLAIMS.env, CLAIMS.fallback);
}

/** Takes one unit; false when none is left (this minute's for students' actions, today's for claims). */
export async function tryQuota(userId: string, kind: QuotaKind): Promise<boolean> {
  const [{ ok }] = kind === "claim"
    ? await sql<{ ok: boolean }[]>`select private.take_quota(${userId}, 'claim', ${dailyClaimLimit()}) as ok`
    : await sql<{ ok: boolean }[]>`select private.take_burst(${userId}, ${kind}, ${burstLimit(kind)}) as ok`;
  return ok;
}

/** Takes one unit, or refuses with a 429 the app shows as is. */
export async function takeQuota(userId: string, kind: QuotaKind): Promise<void> {
  if (await tryQuota(userId, kind)) return;
  if (kind === "claim") throw new HttpError(429, "too many plan checks today; try again tomorrow");
  console.error("burst limit reached", userId, kind);
  throw new HttpError(429, `that's a lot of ${BURSTS[kind].noun} in one minute; wait a few seconds and try again`);
}

/** Gives a unit back when the action it paid for failed, so a model error costs the student nothing. */
export async function refundQuota(userId: string, kind: QuotaKind): Promise<void> {
  const refund = kind === "claim" ? sql`select private.refund_quota(${userId}, 'claim')` : sql`select private.refund_burst(${userId}, ${kind})`;
  await refund.catch((error) => console.error("quota refund failed", error));
}

/** Runs `work` against one unit, refunding it if `work` throws. */
export async function withQuota<T>(userId: string, kind: QuotaKind, work: () => Promise<T>): Promise<T> {
  await takeQuota(userId, kind);
  try {
    return await work();
  } catch (error) {
    await refundQuota(userId, kind);
    throw error;
  }
}
