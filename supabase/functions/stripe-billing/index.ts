// stripe-billing: the web side of paying for Rounds (US storefront; the app links out to it).
//
//   prices    {}                → {prices: [{plan, amount, currency, trial_days}]}   web prices, from Stripe
//   checkout  {plan}            → {url}   a Stripe Checkout page for this student
//   portal    {}                → {url}   Stripe's billing portal, to cancel or change card
//
// Every action: verify the caller first. Guests (anonymous) can't pay: a plan belongs to an account.

import { caller, HttpError, json, serve, body } from "../_shared/http.ts";
import { sql } from "../_shared/db.ts";
import { isPlan, lookupKey, PLANS, stripe, YEARLY_TRIAL_DAYS } from "../_shared/stripe.ts";

const SITE = Deno.env.get("ROUNDS_SITE_URL") ?? "https://rounds-2hg.pages.dev";

serve(async (req) => {
  const user = await caller(req);
  const input = await body<{ action?: string; plan?: unknown }>(req);
  switch (input.action) {
    case "prices": return json({ prices: await prices(user.id) });
    case "checkout": return json({ url: await checkout(user.id, user.email, user.is_anonymous === true, input.plan) });
    case "portal": return json({ url: await portal(user.id) });
    default: throw new HttpError(400, "action must be prices, checkout or portal");
  }
});

/** A student gets the yearly trial once: never if they've had any plan before. */
async function trialEligible(userId: string): Promise<boolean> {
  const rows = await sql`select 1 from public.subscriptions where user_id = ${userId}`;
  return rows.length === 0;
}

async function prices(userId: string) {
  const list = await stripe("GET", "/prices", { lookup_keys: PLANS.map(lookupKey), active: true, limit: 10 });
  const trial = await trialEligible(userId);
  return PLANS.flatMap((plan) => {
    // deno-lint-ignore no-explicit-any
    const price = list.data.find((p: any) => p.lookup_key === lookupKey(plan));
    return price ? [{ plan, amount: price.unit_amount / 100, currency: price.currency, trial_days: plan === "yearly" && trial ? YEARLY_TRIAL_DAYS : null }] : [];
  });
}

async function customerFor(userId: string, email: string | undefined): Promise<string> {
  const [known] = await sql<{ customer_id: string }[]>`select customer_id from private.stripe_customers where user_id = ${userId}`;
  if (known) return known.customer_id;
  const customer = await stripe("POST", "/customers", { email, metadata: { user_id: userId } });
  // Two first checkouts at once: keep whichever customer landed first.
  const [row] = await sql<{ customer_id: string }[]>`
    insert into private.stripe_customers (user_id, customer_id) values (${userId}, ${customer.id})
    on conflict (user_id) do update set user_id = excluded.user_id
    returning customer_id`;
  return row.customer_id;
}

async function checkout(userId: string, email: string | undefined, anonymous: boolean, plan: unknown): Promise<string> {
  if (anonymous) throw new HttpError(403, "sign in to subscribe");
  if (!isPlan(plan)) throw new HttpError(400, "plan must be weekly, monthly or yearly");
  const [active] = await sql`select 1 from public.subscriptions where user_id = ${userId}
    and status in ('trialing', 'active', 'past_due') and current_period_end > now()`;
  if (active) throw new HttpError(409, "you already have an active plan");

  const list = await stripe("GET", "/prices", { lookup_keys: [lookupKey(plan)], active: true });
  const price = list.data[0];
  if (!price) throw new HttpError(503, "that plan isn't on sale yet");

  const session = await stripe("POST", "/checkout/sessions", {
    mode: "subscription",
    customer: await customerFor(userId, email),
    client_reference_id: userId,
    line_items: [{ price: price.id, quantity: 1 }],
    subscription_data: {
      metadata: { user_id: userId },
      trial_period_days: plan === "yearly" && await trialEligible(userId) ? YEARLY_TRIAL_DAYS : undefined,
    },
    allow_promotion_codes: true,
    success_url: `${SITE}/welcome?paid=1`,
    cancel_url: `${SITE}/welcome?cancelled=1`,
  });
  return session.url;
}

async function portal(userId: string): Promise<string> {
  const [known] = await sql<{ customer_id: string }[]>`select customer_id from private.stripe_customers where user_id = ${userId}`;
  if (!known) throw new HttpError(404, "no web subscription on this account");
  const session = await stripe("POST", "/billing_portal/sessions", { customer: known.customer_id, return_url: `${SITE}/welcome` });
  return session.url;
}
