// Stripe's REST API with the secret key from STRIPE_SECRET_KEY (a supabase secret, never in git).
// Form-encoded like Stripe expects; nested params become a[b][c]=v.

import { HttpError } from "./http.ts";

/** The web plans: one Stripe price each, found by lookup key so ids never live in code. */
export const PLANS = ["weekly", "monthly", "yearly"] as const;
export type Plan = typeof PLANS[number];
export const lookupKey = (plan: Plan) => `rounds_web_${plan}`;
/** Free days on the yearly plan, for a student who has never had a subscription. */
export const YEARLY_TRIAL_DAYS = 3;

export function isPlan(value: unknown): value is Plan {
  return typeof value === "string" && (PLANS as readonly string[]).includes(value);
}

/** Flattens {a: {b: 1}, c: [x]} into a=…&a[b]=1&c[0]=x, Stripe's form encoding. */
export function formEncode(params: Record<string, unknown>, prefix = ""): string[] {
  const out: string[] = [];
  for (const [key, value] of Object.entries(params)) {
    if (value === undefined || value === null) continue;
    const name = prefix ? `${prefix}[${key}]` : key;
    if (Array.isArray(value)) {
      value.forEach((item, i) => {
        if (item !== null && typeof item === "object") out.push(...formEncode(item as Record<string, unknown>, `${name}[${i}]`));
        else out.push(`${encodeURIComponent(`${name}[${i}]`)}=${encodeURIComponent(String(item))}`);
      });
    } else if (typeof value === "object") {
      out.push(...formEncode(value as Record<string, unknown>, name));
    } else {
      out.push(`${encodeURIComponent(name)}=${encodeURIComponent(String(value))}`);
    }
  }
  return out;
}

// deno-lint-ignore no-explicit-any
export async function stripe(method: "GET" | "POST" | "DELETE", path: string, params: Record<string, unknown> = {}): Promise<any> {
  const key = Deno.env.get("STRIPE_SECRET_KEY");
  if (!key) throw new HttpError(503, "payments aren't set up");
  const query = formEncode(params).join("&");
  const url = `https://api.stripe.com/v1${path}${method === "GET" && query ? `?${query}` : ""}`;
  const res = await fetch(url, {
    method,
    headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/x-www-form-urlencoded", "Stripe-Version": "2025-08-27.basil" },
    body: method === "GET" ? undefined : query,
    signal: AbortSignal.timeout(20_000),
  });
  const data = await res.json();
  if (!res.ok) {
    console.error("stripe", method, path, res.status, data?.error?.type, data?.error?.message);
    throw new HttpError(502, "the payment service didn't answer; try again");
  }
  return data;
}

/** True for a test or sandbox key; live keys charge real cards. */
export function isTestKey(): boolean {
  return /^(sk|rk)_test_/.test(Deno.env.get("STRIPE_SECRET_KEY") ?? "");
}

/** A Stripe subscription as our row: the plan from its price's lookup key, and when access ends. */
// deno-lint-ignore no-explicit-any
export function subscriptionRow(sub: any): { status: string; plan: Plan; periodEnd: Date; cancelAtPeriodEnd: boolean } | null {
  const item = sub?.items?.data?.[0];
  const plan = PLANS.find((p) => item?.price?.lookup_key === lookupKey(p));
  // Since the 2025 "basil" API the period lives on the item; older versions kept it on the subscription.
  const end = item?.current_period_end ?? sub?.current_period_end;
  if (!plan || typeof end !== "number" || typeof sub?.status !== "string") return null;
  return { status: sub.status, plan, periodEnd: new Date(end * 1000), cancelAtPeriodEnd: sub.cancel_at_period_end === true };
}

/** Statuses that keep the app open. past_due gets Stripe's retry window rather than an instant lockout. */
export const ACTIVE_STATUSES = ["trialing", "active", "past_due"];
