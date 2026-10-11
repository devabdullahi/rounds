import { assertEquals } from "jsr:@std/assert@1";
import { formEncode, isPlan, isTestKey, lookupKey, subscriptionRow } from "./stripe.ts";

Deno.test("form encoding nests objects and arrays the way Stripe reads them", () => {
  const query = formEncode({
    mode: "subscription",
    line_items: [{ price: "price_1", quantity: 1 }],
    subscription_data: { metadata: { user_id: "u1" }, trial_period_days: undefined },
    lookup_keys: ["a", "b"],
  }).map(decodeURIComponent);
  assertEquals(query, [
    "mode=subscription",
    "line_items[0][price]=price_1",
    "line_items[0][quantity]=1",
    "subscription_data[metadata][user_id]=u1",
    "lookup_keys[0]=a",
    "lookup_keys[1]=b",
  ]);
});

Deno.test("a subscription maps to its plan by price lookup key, with the item's period end", () => {
  const sub = {
    status: "trialing", cancel_at_period_end: false,
    items: { data: [{ price: { lookup_key: lookupKey("yearly") }, current_period_end: 1_800_000_000 }] },
  };
  assertEquals(subscriptionRow(sub), { status: "trialing", plan: "yearly", periodEnd: new Date(1_800_000_000_000), cancelAtPeriodEnd: false });
});

Deno.test("a subscription for some other product is ignored", () => {
  const sub = { status: "active", items: { data: [{ price: { lookup_key: "something_else" }, current_period_end: 1 }] } };
  assertEquals(subscriptionRow(sub), null);
});

Deno.test("only the three plans are accepted", () => {
  assertEquals(["weekly", "monthly", "yearly", "lifetime", 3, null].map(isPlan), [true, true, true, false, false, false]);
});

Deno.test("test and sandbox keys are recognised; live keys aren't", () => {
  const before = Deno.env.get("STRIPE_SECRET_KEY");
  for (const [key, test] of [["sk_test_x", true], ["rk_test_x", true], ["sk_live_x", false], ["rk_live_x", false]] as const) {
    Deno.env.set("STRIPE_SECRET_KEY", key);
    assertEquals(isTestKey(), test);
  }
  if (before === undefined) Deno.env.delete("STRIPE_SECRET_KEY"); else Deno.env.set("STRIPE_SECRET_KEY", before);
});
