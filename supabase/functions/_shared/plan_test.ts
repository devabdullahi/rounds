import { assertEquals } from "jsr:@std/assert@1";
import { appBuild, entitled, environmentCounts, FREE_CASES, FREE_CASES_FROM_BUILD, freeAllows, type FreeUse, offersFreeCases, planCheckOff, planExempt, type PlanRow, toRecheck, toRefresh } from "./plan.ts";

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


Deno.test("three free cases: written, played through their grades, then the gate closes", () => {
  const cases: [written: number, waiting: number, unplayed: boolean, use: FreeUse, allowed: boolean][] = [
    [0, 0, false, "open", true],
    [2, 0, false, "write", true],
    [3, 0, false, "write", false],
    [2, 1, false, "ahead", false],
    [1, 1, false, "ahead", true],
    [3, 0, true, "open", true],    // the third patient is still to play
    [3, 0, false, "open", false],  // all three graded: the paywall
    [3, 0, false, "play", true],   // reviewing a graded free case still works
    [8, 0, true, "play", false],   // a lapsed plan with more patients needs a plan again
  ];
  for (const [written, waiting, unplayed, use, allowed] of cases) {
    assertEquals(freeAllows({ written, waiting, unplayed }, use), allowed, `${use} at ${written}+${waiting}`);
  }
  assertEquals(FREE_CASES, 3);
});

Deno.test("appBuild reads the build number iOS puts in the User-Agent", () => {
  assertEquals(appBuild("Rounds/38 CFNetwork/3896.100.1.2.1 Darwin/27.2.0"), 38);
  assertEquals(appBuild("Rounds/37 CFNetwork/1568 Darwin/25.0.0"), 37);
  assertEquals(appBuild("Mozilla/5.0 Rounds/40"), null);
  assertEquals(appBuild("RoundsX/40 CFNetwork"), null);
  assertEquals(appBuild(""), null);
  assertEquals(appBuild(null), null);
});

Deno.test("free cases start at FREE_CASES_FROM_BUILD; 1.0 and unknown clients keep the hard paywall", () => {
  assertEquals(offersFreeCases("Rounds/37 CFNetwork/1568 Darwin/25.0.0"), false);
  assertEquals(offersFreeCases(`Rounds/${FREE_CASES_FROM_BUILD} CFNetwork/1 Darwin/1`), true);
  assertEquals(offersFreeCases("Rounds/120 CFNetwork/1 Darwin/1"), true);
  assertEquals(offersFreeCases("curl/8.0"), false);
  assertEquals(offersFreeCases(null), false);
});
