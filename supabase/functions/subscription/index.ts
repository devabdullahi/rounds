// subscription: ties App Store subscriptions to the Rounds account that bought them.
//
//   claim   {transaction_id}  → {entitled, owner?}  after a purchase or restore, and whenever the
//           phone holds a subscription: Apple confirms it. The account the purchase was tagged with
//           (appAccountToken, set by the app at purchase) owns it; an untagged one goes to the first
//           account to claim it. Another account gets entitled false and `owner` (a masked email).
//   status  {}                → {entitled, expires_at?}  the caller's own access, on any device,
//           refreshed from Apple where our record may be stale (_shared/plan.ts).
//
// Verify the caller → ask Apple (never trust the app's word on a purchase) → write with the service
// role. Students can read their own rows (RLS) but never write them.
import { body, callerId, HttpError, json, serve } from "../_shared/http.ts";
import { sql } from "../_shared/db.ts";
import { lookUp, maskEmail, type Subscription } from "../_shared/appstore.ts";
import { accountPlan, environmentCounts } from "../_shared/plan.ts";
import { tryQuota } from "../_shared/quota.ts";
import { ownerAfterClaim } from "./rules.ts";

serve(async (req) => {
  const userId = await callerId(req);
  const input = await body<Record<string, unknown>>(req);
  switch (input.action) {
    case "claim": return json(await claim(userId, input.transaction_id));
    case "status": return json(await accountPlan(userId));
    default: throw new HttpError(400, "unknown action");
  }
});

async function claim(userId: string, transactionId: unknown) {
  if (typeof transactionId !== "string" || !/^\d{1,20}$/.test(transactionId)) throw new HttpError(400, "transaction_id required");
  // Each claim asks Apple. Past the daily allowance, answer from our record instead.
  if (!(await tryQuota(userId, "claim"))) return { entitled: (await accountPlan(userId)).entitled };
  let sub: Subscription | null;
  try {
    sub = await lookUp(transactionId);
  } catch (error) {
    console.error("app store lookup failed", error);
    throw new HttpError(502, "couldn't reach the App Store; try again");
  }
  if (!sub) throw new HttpError(404, "no Rounds subscription found for that purchase");

  // The tag counts only when it names a real account; an untagged purchase, or one tagged before the
  // app knew the account, falls back to first claim.
  const [tagged] = sub.appAccountToken
    ? await sql<{ id: string; email: string | null }[]>`select id, email from auth.users where id::text = ${sub.appAccountToken}`
    : [];
  if (tagged && tagged.id !== userId) return { entitled: false, owner: maskEmail(tagged.email) };

  // Insert for the caller, or refresh the row if the caller already owns it or made the purchase.
  // A row another account owns is otherwise left untouched (the WHERE on the conflict), so
  // concurrent claims can't steal it.
  const madeIt = tagged?.id === userId;
  await sql`
    insert into public.subscriptions (original_transaction_id, user_id, product_id, expires_at, environment, revoked, updated_at)
    values (${sub.originalTransactionId}, ${userId}, ${sub.productId}, ${sub.expiresAt}, ${sub.environment}, ${sub.revoked}, now())
    on conflict (original_transaction_id) do update
      set user_id = excluded.user_id, product_id = excluded.product_id, expires_at = excluded.expires_at,
          environment = excluded.environment, revoked = excluded.revoked, updated_at = now()
      where public.subscriptions.user_id = excluded.user_id or ${madeIt}`;
  const [row] = await sql<{ user_id: string; email: string | null }[]>`
    select s.user_id, u.email from public.subscriptions s join auth.users u on u.id = s.user_id
    where s.original_transaction_id = ${sub.originalTransactionId}`;
  const decision = ownerAfterClaim(row?.user_id ?? null, userId, tagged?.id ?? null);
  if (decision.takenByAnother) return { entitled: false, owner: maskEmail(row?.email) };
  return { entitled: sub.active && sub.expiresAt.getTime() > Date.now() && environmentCounts(sub.environment, userId) };
}
