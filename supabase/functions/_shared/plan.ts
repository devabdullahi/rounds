// Who has a paid plan right now. The app's paywall is only the face of it: every model-backed action
// calls requirePlan, so a modified app or a scripted guest account can't spend model calls unpaid.
//
// One graded case is free (2026-10-22): until a student's first submission, cases and the interview
// work without a plan (requirePlanOrFreeCase), and at most FREE_CASES patients are written for them.
//
// Our record of a subscription is refreshed from Apple when it may be wrong: a lapsed one (it may have
// renewed) and a paid-up one we haven't checked for a day (it may have been refunded).
//
// Env: SANDBOX_PURCHASES is "all" while TestFlight testers buy in the sandbox before launch, or a
// comma list of user ids allowed to use sandbox purchases after it; unset, only App Store purchases
// count. PLAN_EXEMPT_USER_IDS lists developer accounts that use Xcode builds, whose local StoreKit
// purchases Apple can't confirm. PLAN_CHECK=off gives every account access without buying, for
// testers before launch; unset (or anything else), the check runs.

import { lookUp } from "./appstore.ts";
import { sql } from "./db.ts";
import { HttpError } from "./http.ts";

export type PlanRow = {
  original_transaction_id: string;
  user_id: string;
  expires_at: Date;
  revoked: boolean;
  environment: string;
  updated_at: Date;
};

/** How long a paid-up record is trusted before Apple is asked again, so refunds take effect. */
const TRUST_MS = 24 * 3600 * 1000;

function idList(raw: string): string[] {
  return raw.split(",").map((id) => id.trim().toLowerCase()).filter(Boolean);
}

/** Whether a subscription from this App Store environment gives this account access. */
export function environmentCounts(environment: string, userId: string, raw = Deno.env.get("SANDBOX_PURCHASES") ?? ""): boolean {
  if (environment === "Production") return true;
  return raw.trim() === "all" || idList(raw).includes(userId.toLowerCase());
}

/** Whether the plan check is switched off for everyone (testers before launch). Only an exact
 *  "off" counts, so a typo or a missing secret leaves the check on. */
export function planCheckOff(raw = Deno.env.get("PLAN_CHECK") ?? ""): boolean {
  return raw.trim().toLowerCase() === "off";
}

/** Developer accounts that skip the plan check (Xcode builds can't buy through Apple). */
export function planExempt(userId: string, raw = Deno.env.get("PLAN_EXEMPT_USER_IDS") ?? ""): boolean {
  return idList(raw).includes(userId.toLowerCase());
}

/** Paid up: some subscription runs past now and wasn't refunded. */
export function entitled(rows: Pick<PlanRow, "expires_at" | "revoked">[], now: Date = new Date()): boolean {
  return rows.some((r) => !r.revoked && r.expires_at.getTime() > now.getTime());
}

/** The lapsed subscription worth asking Apple about again (it may have renewed): the latest one. */
export function toRecheck(rows: Pick<PlanRow, "original_transaction_id" | "expires_at" | "revoked">[]): string | null {
  const live = rows.filter((r) => !r.revoked).sort((a, b) => b.expires_at.getTime() - a.expires_at.getTime());
  return live[0]?.original_transaction_id ?? null;
}

/** Subscriptions to ask Apple about before answering: unchecked paid-up ones, else the lapsed one. */
export function toRefresh(rows: PlanRow[], now: Date = new Date()): string[] {
  if (!entitled(rows, now)) {
    const recheck = toRecheck(rows);
    return recheck ? [recheck] : [];
  }
  return rows
    .filter((r) => entitled([r], now) && now.getTime() - r.updated_at.getTime() > TRUST_MS)
    .map((r) => r.original_transaction_id);
}

/** The caller's access, on any device, refreshed from Apple where our record may be stale. */
export async function accountPlan(userId: string): Promise<{ entitled: boolean; expires_at?: Date }> {
  // The app opens on this answer too (subscription status), so switching the check off opens both.
  if (planCheckOff()) return { entitled: true };
  const load = async () =>
    (await sql<PlanRow[]>`
      select original_transaction_id, user_id, expires_at, revoked, environment, updated_at
      from public.subscriptions where user_id = ${userId}`)
      .filter((r) => environmentCounts(r.environment, userId));

  let rows = await load();
  const refresh = toRefresh(rows);
  for (const transactionId of refresh) {
    try {
      const sub = await lookUp(transactionId);
      // Gone from Apple's records: leave the row; it lapses on its own date.
      if (!sub) continue;
      await sql`
        update public.subscriptions set expires_at = ${sub.expiresAt}, revoked = ${sub.revoked}, updated_at = now()
        where original_transaction_id = ${sub.originalTransactionId} and user_id = ${userId}`;
    } catch (error) {
      // Apple unreachable: answer from the record. A lapsed one stays lapsed; nothing is granted.
      console.error("app store recheck failed", error);
    }
  }
  if (refresh.length) rows = await load();

  const now = new Date();
  const live = rows.filter((r) => entitled([r], now));
  if (!live.length) return { entitled: false };
  return { entitled: true, expires_at: live.map((r) => r.expires_at).sort((a, b) => b.getTime() - a.getTime())[0] };
}

/** Patients written for a student without a plan, before their first graded case: the one they
 *  play plus the few the app writes ahead so it opens instantly. Bounds what a fresh account costs. */
export const FREE_CASES = 3;

/** What the free case allows, from what the student has done: nothing once they've submitted a case,
 *  and (when `writing`) no new patients past FREE_CASES. Pure, so the rule is tested. */
export function freeCaseAllows(record: { graded: boolean; written: number }, writing: boolean): boolean {
  if (record.graded) return false;
  return !writing || record.written < FREE_CASES;
}

/** Whether the caller's free case is still unused, and, for `writing`, whether another patient may be
 *  written for it (cases they own plus ones waiting for them). */
export async function freeCaseLeft(userId: string, writing = false): Promise<boolean> {
  const [record] = await sql<{ graded: boolean; written: number }[]>`
    select exists (select 1 from public.attempts where user_id = ${userId} and submitted_at is not null) as graded,
      (select count(*)::int from public.cases where created_by = ${userId})
        + (select count(*)::int from private.ready_cases where user_id = ${userId}) as written`;
  return freeCaseAllows(record, writing);
}

/** requirePlan, except that a student who hasn't submitted a case yet may play their free one.
 *  `writing` is for writing patients, which the free case caps at FREE_CASES. */
export async function requirePlanOrFreeCase(userId: string, writing = false): Promise<void> {
  if (planExempt(userId)) return;
  if ((await accountPlan(userId)).entitled) return;
  if (await freeCaseLeft(userId, writing)) return;
  throw new HttpError(402, "an active plan is required");
}

/** Refuses with a 402 unless the caller has a paid plan. Run it before taking any quota. */
export async function requirePlan(userId: string): Promise<void> {
  if (planExempt(userId)) return;
  if (!(await accountPlan(userId)).entitled) throw new HttpError(402, "an active plan is required");
}
