import { assertEquals } from "jsr:@std/assert@1";
import { entitled, environmentCounts, planCheckOff, planExempt, type PlanRow, toRecheck, toRefresh } from "./plan.ts";

const now = new Date("2026-10-19T12:00:00Z");
const later = new Date("2026-11-19T12:00:00Z");
const earlier = new Date("2026-09-19T12:00:00Z");
const hoursAgo = (h: number) => new Date(now.getTime() - h * 3600 * 1000);

const row = (over: Partial<PlanRow> = {}): PlanRow => ({
  original_transaction_id: "1", user_id: "a", expires_at: later, revoked: false,
  environment: "Production", updated_at: now, ...over,
});

Deno.test("an account is paid up only while a subscription runs and wasn't refunded", () => {
  assertEquals(entitled([row()], now), true);
  assertEquals(entitled([row({ expires_at: earlier })], now), false);
  assertEquals(entitled([row({ revoked: true })], now), false);
  assertEquals(entitled([], now), false);
});

Deno.test("the latest unrevoked subscription is the one to recheck", () => {
  const rows = [
    row({ original_transaction_id: "old", expires_at: earlier }),
    row({ original_transaction_id: "new", expires_at: now }),
    row({ original_transaction_id: "refunded", revoked: true }),
  ];
  assertEquals(toRecheck(rows), "new");
  assertEquals(toRecheck([]), null);
});

Deno.test("a paid-up record is rechecked with Apple once it's a day old, so refunds take effect", () => {
  assertEquals(toRefresh([row({ updated_at: hoursAgo(2) })], now), []);
  assertEquals(toRefresh([row({ original_transaction_id: "x", updated_at: hoursAgo(25) })], now), ["x"]);
});

Deno.test("a lapsed record is rechecked, since it may have renewed", () => {
  assertEquals(toRefresh([row({ original_transaction_id: "x", expires_at: earlier })], now), ["x"]);
  assertEquals(toRefresh([], now), []);
});

Deno.test("only App Store purchases count unless sandbox purchases are allowed", () => {
  for (const [environment, setting, user, counts] of [
    ["Production", "", "a", true],
    ["Sandbox", "", "a", false],
    ["Sandbox", "all", "a", true],
    ["Sandbox", "b, A ", "a", true],
    ["Sandbox", "b,c", "a", false],
  ] as const) {
    assertEquals(environmentCounts(environment, user, setting), counts, `${environment} ${setting} ${user}`);
  }
});

Deno.test("only listed developer accounts skip the plan check", () => {
  assertEquals(planExempt("a", ""), false);
  assertEquals(planExempt("a", "b,a"), true);
  assertEquals(planExempt("a", "ab"), false);
});

Deno.test("the plan check is off only for an exact \"off\"", () => {
  for (const raw of ["off", " OFF ", "Off"]) assertEquals(planCheckOff(raw), true);
  for (const raw of ["", "on", "false", "0", "of", "disabled"]) assertEquals(planCheckOff(raw), false);
});

