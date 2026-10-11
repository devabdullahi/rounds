// stripe-setup: one-time, idempotent setup of the Stripe account. Admin only (x-admin-token).
//
//   - the three web prices, found by lookup key (created when missing)
//   - the webhook endpoint pointing at stripe-webhook
//   - a billing portal configuration (cancel, change card, invoices)
//
// Refuses a live key unless {"live": true}, so test setup can't touch real money by accident.

import { body, HttpError, json, serve } from "../_shared/http.ts";
import { isTestKey, lookupKey, type Plan, PLANS, stripe } from "../_shared/stripe.ts";

/** Web prices in cents: a little under the App Store's, yet each nets more after Stripe's fees than
 *  the App Store does after Apple's 15% (Small Business Program). */
const WEB_PRICES: Record<Plan, { cents: number; interval: "week" | "month" | "year"; name: string }> = {
  weekly: { cents: 749, interval: "week", name: "Rounds Weekly" },
  monthly: { cents: 2299, interval: "month", name: "Rounds Monthly" },
  yearly: { cents: 10999, interval: "year", name: "Rounds Yearly" },
};

const WEBHOOK_EVENTS = [
  "checkout.session.completed", "customer.subscription.created", "customer.subscription.updated",
  "customer.subscription.deleted", "customer.subscription.paused", "customer.subscription.resumed",
];

serve(async (req) => {
  // A dedicated random token (ADMIN_TASK_TOKEN, in supabase secrets and the git-ignored cloud.env):
  // the service role key a function sees isn't the one the CLI hands out, so it can't be compared.
  const token = Deno.env.get("ADMIN_TASK_TOKEN");
  if (!token || req.headers.get("x-admin-token") !== token) throw new HttpError(401, "admin only");
  const input = await body<{ live?: boolean }>(req);
  const live = !isTestKey();
  if (live && input.live !== true) throw new HttpError(409, "STRIPE_SECRET_KEY is a live key; pass {\"live\": true} to set up live mode");

  const prices: Record<string, string> = {};
  const existing = await stripe("GET", "/prices", { lookup_keys: PLANS.map(lookupKey), active: true, limit: 10 });
  for (const plan of PLANS) {
    // deno-lint-ignore no-explicit-any
    const found = existing.data.find((p: any) => p.lookup_key === lookupKey(plan));
    const spec = WEB_PRICES[plan];
    if (found && found.unit_amount === spec.cents && found.recurring?.interval === spec.interval) { prices[plan] = `kept ${found.id}`; continue; }
    // Stripe prices can't change: a new price takes over the lookup key and the old one is archived.
    // Existing subscribers keep the price they signed up at.
    const product = found?.product ?? (await stripe("POST", "/products", { name: spec.name, metadata: { app: "rounds" } })).id;
    const price = await stripe("POST", "/prices", {
      product, currency: "usd", unit_amount: spec.cents, recurring: { interval: spec.interval },
      lookup_key: lookupKey(plan), transfer_lookup_key: true,
    });
    if (found) await stripe("POST", `/prices/${found.id}`, { active: false });
    prices[plan] = `${found ? "replaced" : "created"} ${price.id}`;
  }

  const url = `${Deno.env.get("SUPABASE_URL")}/functions/v1/stripe-webhook`;
  const hooks = await stripe("GET", "/webhook_endpoints", { limit: 100 });
  // deno-lint-ignore no-explicit-any
  const hook = hooks.data.find((h: any) => h.url === url);
  const webhook = hook
    ? (await stripe("POST", `/webhook_endpoints/${hook.id}`, { enabled_events: WEBHOOK_EVENTS }), `kept ${hook.id}`)
    : `created ${(await stripe("POST", "/webhook_endpoints", { url, enabled_events: WEBHOOK_EVENTS, description: "Rounds subscriptions" })).id}`;

  const configs = await stripe("GET", "/billing_portal/configurations", { is_default: true, limit: 1 });
  const portal = configs.data[0]
    ? `kept ${configs.data[0].id}`
    : `created ${(await stripe("POST", "/billing_portal/configurations", {
      business_profile: { headline: "Manage your Rounds plan" },
      features: {
        subscription_cancel: { enabled: true, mode: "at_period_end" },
        payment_method_update: { enabled: true },
        invoice_history: { enabled: true },
      },
    })).id}`;

  return json({ mode: live ? "live" : "test", prices, webhook, portal });
});
