// subscription: ties App Store subscriptions to the Rounds account that bought them.
//
//   claim   {transaction_id}  → {entitled, owner?}  after a purchase or restore, and whenever the
//           phone holds a subscription: Apple confirms it, and the first account to claim it owns
//           it. Another account gets entitled false and `owner` (a masked email) to explain why.
//   status  {}                → {entitled, expires_at?}  the caller's own access, on any device.
//           A lapsed subscription is checked with Apple again, since it may have renewed.
//
// Verify the caller → ask Apple (never trust the app's word on a purchase) → write with the service
// role. Students can read their own rows (RLS) but never write them.
import { body, callerId, HttpError, json, serve } from "../_shared/http.ts";
import { sql } from "../_shared/db.ts";
import { lookUp, maskEmail, type Subscription } from "../_shared/appstore.ts";
import { entitled, ownerAfterClaim, type Row, toRecheck } from "./rules.ts";

serve(async (req) => {
  const userId = await callerId(req);
  const input = await body<Record<string, unknown>>(req);
  switch (input.action) {
    case "claim": return json(await claim(userId, input.transaction_id));
    case "status": return json(await status(userId));
    default: throw new HttpError(400, "unknown action");
  }
});

async function claim(userId: string, transactionId: unknown) {
  if (typeof transactionId !== "string" || !/^\d{1,20}$/.test(transactionId)) throw new HttpError(400, "transaction_id required");
  let sub: Subscription | null;
  try {
    sub = await lookUp(transactionId);
  } catch (error) {
    console.error("app store lookup failed", error);
    throw new HttpError(502, "couldn't reach the App Store; try again");
  }
  if (!sub) throw new HttpError(404, "no Rounds subscription found for that purchase");

  // Insert for the caller, or refresh the row if the caller already owns it. A row another account
  // owns is left untouched (the WHERE on the conflict), so concurrent claims can't steal it.
  await sql`
    insert into public.subscriptions (original_transaction_id, user_id, product_id, expires_at, environment, revoked, updated_at)
    values (${sub.originalTransactionId}, ${userId}, ${sub.productId}, ${sub.expiresAt}, ${sub.environment}, ${sub.revoked}, now())
    on conflict (original_transaction_id) do update
      set product_id = excluded.product_id, expires_at = excluded.expires_at, environment = excluded.environment,
          revoked = excluded.revoked, updated_at = now()
      where public.subscriptions.user_id = excluded.user_id`;
  const [row] = await sql<{ user_id: string; email: string | null }[]>`
    select s.user_id, u.email from public.subscriptions s join auth.users u on u.id = s.user_id
    where s.original_transaction_id = ${sub.originalTransactionId}`;
  const decision = ownerAfterClaim(row?.user_id ?? null, userId);
  if (decision.takenByAnother) return { entitled: false, owner: maskEmail(row?.email) };
  return { entitled: sub.active && sub.expiresAt.getTime() > Date.now() };
}

async function status(userId: string) {
  const rows = await sql<(Row & { original_transaction_id: string })[]>`
    select original_transaction_id, user_id, expires_at, revoked from public.subscriptions where user_id = ${userId}`;
  if (entitled(rows)) return { entitled: true, expires_at: latest(rows) };

  // Lapsed by our record: Apple may have renewed it since the owner last opened the app on that phone.
  const recheck = toRecheck(rows);
  if (!recheck) return { entitled: false };
  try {
    const sub = await lookUp(recheck);
    if (sub) {
      await sql`
        update public.subscriptions set expires_at = ${sub.expiresAt}, revoked = ${sub.revoked}, updated_at = now()
        where original_transaction_id = ${sub.originalTransactionId} and user_id = ${userId}`;
      return { entitled: sub.active && sub.expiresAt.getTime() > Date.now(), expires_at: sub.expiresAt };
    }
  } catch (error) {
    // Apple unreachable: answer from the record (lapsed), never grant on a failure.
    console.error("app store recheck failed", error);
  }
  return { entitled: false };
}

function latest(rows: Row[]): Date | undefined {
  return rows.map((r) => r.expires_at).sort((a, b) => b.getTime() - a.getTime())[0];
}
