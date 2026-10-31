// Who has a paid plan right now. The app's paywall is only the face of it: every model-backed action
// calls requirePlan, so a modified app or a scripted guest account can't spend model calls unpaid.
//
// Three free cases (2026-10-30): an account without a plan gets FREE_CASES patients, played through
// their grades (requireAccess). Counted from records deleting patients can't reset, so the free cases
// can't be earned again. Flashcards still need a plan.
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

/** Patients an account without a plan may have written for it. */
export const FREE_CASES = 3;

/** What the free cases have been used for. `written`: patients made for the account, from records
 *  delete_patients() leaves alone. `waiting`: cases written ahead and not yet taken. `unplayed`: one
 *  of its patients has no submitted attempt yet. */
export type FreeRecord = { written: number; waiting: number; unplayed: boolean };

/** What an account without a plan is doing: opening the app, playing one of its patients (any
 *  case-session action), writing a new one, or writing one ahead. */
export type FreeUse = "open" | "play" | "write" | "ahead";

/** Whether the free cases allow it. Pure, so the rule is tested. Playing is allowed for an account
 *  that never went past the free cases (a lapsed plan with more patients needs a plan again). */
export function freeAllows(r: FreeRecord, use: FreeUse): boolean {
  switch (use) {
    case "open": return r.written < FREE_CASES || r.unplayed;
    case "play": return r.written <= FREE_CASES;
    case "write": return r.written < FREE_CASES;
    case "ahead": return r.written + r.waiting < FREE_CASES;
  }
}

/** The caller's free-case record. */
export async function freeRecord(userId: string): Promise<FreeRecord> {
  const [r] = await sql<FreeRecord[]>`
    select greatest((select count(*)::int from public.cases where created_by = ${userId}),
                    (select count(*)::int from private.patient_fingerprints where user_id = ${userId})) as written,
      (select count(*)::int from private.ready_cases where user_id = ${userId}) as waiting,
      exists (select 1 from public.cases c where c.created_by = ${userId}
              and not exists (select 1 from public.attempts a where a.case_id = c.id and a.submitted_at is not null)) as unplayed`;
  return r;
}

/** The 402 text for an account whose free cases are used up. App 1.0 shows a 402's text as the error
 *  (capitalised, with a full stop added), so it reads as a sentence without one; newer apps open
 *  the paywall instead and ignore it. */
export const FREE_CASES_USED = `you've used your ${FREE_CASES} free patients. Choose a plan to get new ones`;

/** "paid" with a plan, "free" when the free cases allow `use`, else a 402. Run it before taking any quota. */
export async function requireAccess(userId: string, use: FreeUse): Promise<"paid" | "free"> {
  if (planExempt(userId) || (await accountPlan(userId)).entitled) return "paid";
  if (freeAllows(await freeRecord(userId), use)) return "free";
  // Playing is refused only past the free cases (a lapsed plan): new patients aren't the issue there.
  throw new HttpError(402, use === "play" ? "choose a plan to keep seeing patients" : FREE_CASES_USED);
}

/** Refuses with a 402 unless the caller has a paid plan. Run it before taking any quota. */
export async function requirePlan(userId: string): Promise<void> {
  if (planExempt(userId)) return;
  if (!(await accountPlan(userId)).entitled) throw new HttpError(402, "an active plan is required");
}
