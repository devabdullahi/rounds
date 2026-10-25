// subscription: ties App Store subscriptions to the Rounds account that bought them.
//
//   claim    {transaction_id}  → {entitled, owner?, transferable?}  after a purchase or restore, and
//            whenever the phone holds a subscription: Apple confirms it. Our record decides who has
//            it; a new plan goes to the account it was tagged with (appAccountToken), else the first
//            to claim. A plan in use by another account answers entitled false, `owner` (masked email)
//            and `transferable`; a lapsed or refunded one goes to the caller (rules.ts).
//   transfer {transaction_id, signed_transaction}  → {entitled}  the student asked to move the phone's
//            plan to their account; the other account loses it. `signed_transaction` is StoreKit's
//            Transaction.jwsRepresentation from the phone: only the Apple ID that bought the plan can
//            produce it, so knowing a transaction id alone can't take someone's plan.
//   status  {}                → {entitled, expires_at?, free_case}  the caller's own access, on any
//           device, refreshed from Apple where our record may be stale (_shared/plan.ts). `free_case`:
//           no plan, but the one free graded case is still unused, so the app opens for it.
//
// Verify the caller → ask Apple (never trust the app's word on a purchase) → write with the service
// role. Students can read their own rows (RLS) but never write them.
import { body, callerId, HttpError, json, serve } from "../_shared/http.ts";
import { sql } from "../_shared/db.ts";
import { BUNDLE_ID, lookUp, maskEmail, type Subscription } from "../_shared/appstore.ts";
import { verifySignedTransaction } from "../_shared/appstorejws.ts";
import { accountPlan, environmentCounts } from "../_shared/plan.ts";
import { tryQuota } from "../_shared/quota.ts";
import { decideClaim } from "./rules.ts";

serve(async (req) => {
  const userId = await callerId(req);
  const input = await body<Record<string, unknown>>(req);
  switch (input.action) {
    case "claim": return json(await claim(userId, input.transaction_id));
    case "transfer": return json(await transfer(userId, input.transaction_id, input.signed_transaction));
    case "status": return json(await status(userId));
    default: throw new HttpError(400, "unknown action");
  }
});

/** The caller's access. `free_case` is always false since the hard paywall (2026-10-25); it stays
 *  in the reply for app builds that still read it. */
async function status(userId: string) {
  return { ...(await accountPlan(userId)), free_case: false };
}

/** Apple's record of the purchase, or a 4xx/5xx a student can act on. */
async function confirmed(transactionId: unknown): Promise<Subscription> {
  if (typeof transactionId !== "string" || !/^\d{1,20}$/.test(transactionId)) throw new HttpError(400, "transaction_id required");
  let sub: Subscription | null;
  try {
    sub = await lookUp(transactionId);
  } catch (error) {
    console.error("app store lookup failed", error);
    throw new HttpError(502, "couldn't reach the App Store; try again");
  }
  if (!sub) throw new HttpError(404, "no Rounds subscription found for that purchase");
  return sub;
}

/** Paid up right now by Apple's account: not lapsed, refunded or revoked. */
const current = (sub: Subscription) => sub.active && !sub.revoked && sub.expiresAt.getTime() > Date.now();

/** What a claim or transfer answers about the caller's access, from Apple's record. */
const access = (userId: string, sub: Subscription) => ({ entitled: current(sub) && environmentCounts(sub.environment, userId) });

/** Writes the record for `owner`. With `onlyIf`, an existing row another account holds is left
 *  alone unless the condition holds (so a concurrent claim can't take a plan that's in use). */
async function record(owner: string, sub: Subscription, replaceOthers: boolean) {
  await sql`
    insert into public.subscriptions (original_transaction_id, user_id, product_id, expires_at, environment, revoked, updated_at)
    values (${sub.originalTransactionId}, ${owner}, ${sub.productId}, ${sub.expiresAt}, ${sub.environment}, ${sub.revoked}, now())
    on conflict (original_transaction_id) do update
      set user_id = excluded.user_id, product_id = excluded.product_id, expires_at = excluded.expires_at,
          environment = excluded.environment, revoked = excluded.revoked, updated_at = now()
      where public.subscriptions.user_id = excluded.user_id or ${replaceOthers}`;
}

async function claim(userId: string, transactionId: unknown) {
  // Each claim asks Apple. Past the daily allowance, answer from our record instead.
  if (!(await tryQuota(userId, "claim"))) return { entitled: (await accountPlan(userId)).entitled };
  const sub = await confirmed(transactionId);

  const [row] = await sql<{ user_id: string }[]>`
    select user_id from public.subscriptions where original_transaction_id = ${sub.originalTransactionId}`;
  // The tag counts only when it names a real account, and only before our record exists.
  const [tagged] = !row && sub.appAccountToken
    ? await sql<{ id: string }[]>`select id from auth.users where id::text = ${sub.appAccountToken}`
    : [];
  const decision = decideClaim({ caller: userId, rowOwner: row?.user_id ?? null, taggedAccount: tagged?.id ?? null, current: current(sub) });
  if (decision.kind === "taken") return taken(decision.owner);

  // A lapsed plan is free to take; one in use stays put even if another claim raced us here.
  await record(userId, sub, !current(sub));
  const [after] = await sql<{ user_id: string }[]>`
    select user_id from public.subscriptions where original_transaction_id = ${sub.originalTransactionId}`;
  if (after && after.user_id !== userId) return taken(after.user_id);
  return access(userId, sub);
}

/** The student asked to move the phone's plan to their account: the other account loses it. Apple
 *  still confirms the purchase first, and it counts against the same daily allowance as claims. */
async function transfer(userId: string, transactionId: unknown, signed: unknown) {
  if (typeof signed !== "string" || signed.length > 16_384) throw new HttpError(400, "update Rounds to move a plan");
  if (!(await tryQuota(userId, "claim"))) throw new HttpError(429, "too many plan checks today; try again tomorrow");
  const sub = await confirmed(transactionId);
  // Proof the caller's phone holds this purchase: Apple signed it, for our app, for this same plan.
  let held;
  try {
    held = await verifySignedTransaction(signed);
  } catch (error) {
    console.error("signed transaction refused", (error as Error).message);
    throw new HttpError(403, "this phone's purchase couldn't be confirmed");
  }
  if (held.bundleId !== BUNDLE_ID || held.originalTransactionId !== sub.originalTransactionId) {
    throw new HttpError(403, "this phone's purchase couldn't be confirmed");
  }
  const [before] = await sql<{ user_id: string }[]>`
    select user_id from public.subscriptions where original_transaction_id = ${sub.originalTransactionId}`;
  await record(userId, sub, true);
  console.log(JSON.stringify({ event: "plan_transferred", from: before?.user_id ?? null, to: userId, environment: sub.environment }));
  return access(userId, sub);
}

/** Another account holds the plan: say whose (masked), and that it can be moved here. */
async function taken(owner: string) {
  const [u] = await sql<{ email: string | null }[]>`select email from auth.users where id = ${owner}`;
  return { entitled: false, owner: maskEmail(u?.email ?? null), transferable: true };
}
