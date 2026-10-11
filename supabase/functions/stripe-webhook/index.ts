// stripe-webhook: Stripe calls this when a web subscription starts, renews, changes or ends.
//
// The posted event is never trusted. Only its type and the subscription id are read; the
// subscription itself is fetched from Stripe with our secret key, so a forged call can at most make
// us re-read a real subscription. No webhook signing secret is needed.

import { json } from "../_shared/http.ts";
import { sql } from "../_shared/db.ts";
import { stripe, subscriptionRow } from "../_shared/stripe.ts";

const HANDLED = new Set([
  "checkout.session.completed",
  "customer.subscription.created",
  "customer.subscription.updated",
  "customer.subscription.deleted",
  "customer.subscription.paused",
  "customer.subscription.resumed",
]);

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  // deno-lint-ignore no-explicit-any
  let event: any;
  try {
    event = await req.json();
  } catch {
    return json({ error: "body must be JSON" }, 400);
  }
  if (!HANDLED.has(event?.type)) return json({ received: true });

  const object = event.data?.object;
  const subscriptionId = event.type === "checkout.session.completed" ? object?.subscription : object?.id;
  if (typeof subscriptionId !== "string" || !subscriptionId.startsWith("sub_")) return json({ received: true });

  try {
    const sub = await stripe("GET", `/subscriptions/${subscriptionId}`);
    const userId = sub.metadata?.user_id;
    const row = subscriptionRow(sub);
    if (typeof userId !== "string" || !row) {
      console.error("stripe-webhook: subscription without a user or a known plan", subscriptionId);
      return json({ received: true });
    }
    await sql`
      insert into public.subscriptions (user_id, source, status, plan, current_period_end, cancel_at_period_end, stripe_subscription_id, updated_at)
      values (${userId}, 'stripe', ${row.status}, ${row.plan}, ${row.periodEnd}, ${row.cancelAtPeriodEnd}, ${subscriptionId}, now())
      on conflict (user_id) do update set source = 'stripe', status = excluded.status, plan = excluded.plan,
        current_period_end = excluded.current_period_end, cancel_at_period_end = excluded.cancel_at_period_end,
        stripe_subscription_id = excluded.stripe_subscription_id, updated_at = now()`;
    return json({ received: true });
  } catch (error) {
    // A 5xx makes Stripe retry later, which is what we want if Stripe or the database blipped.
    console.error("stripe-webhook failed", subscriptionId, error instanceof Error ? error.message : error);
    return json({ error: "try again" }, 500);
  }
});
