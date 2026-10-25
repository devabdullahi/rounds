import { assertAlmostEquals, assertEquals } from "jsr:@std/assert@1";
import { contentShare, costUSD, dailyBudgetUSD, isContentTask, withinBudget } from "./usage.ts";

Deno.test("cost uses peak prices per million tokens", () => {
  // 1M cache hits + 1M misses + 1M output on v4-pro = 0.044 + 1.32 + 3.96
  assertAlmostEquals(costUSD("gpt-6.1-sol", { hit: 1e6, miss: 1e6, output: 1e6, reasoning: 5e5 }), 12.1, 1e-9);
  assertAlmostEquals(costUSD("gpt-6-luna", { hit: 0, miss: 2000, output: 150, reasoning: 0 }), 0.000275, 1e-12);
});

Deno.test("unpriced models cost nothing rather than guessing", () => {
  assertEquals(costUSD("gpt-4.1", { hit: 1e6, miss: 1e6, output: 1e6, reasoning: 0 }), 0);
});

Deno.test("no daily budget unless a positive one is set", () => {
  const table: [string | undefined, number | null][] = [[undefined, null], ["", null], ["abc", null], ["0", null], ["-5", null], ["40", 40], ["12.5", 12.5]];
  for (const [raw, want] of table) assertEquals(dailyBudgetUSD(raw), want, String(raw));
});

Deno.test("with no cap every call goes ahead", () => {
  assertEquals(withinBudget("case", { total: 1e6, content: 1e6 }, null, 0.6), true);
  assertEquals(withinBudget("patient", { total: 1e6, content: 0 }, null, 0.6), true);
});

Deno.test("content stops at its share of the cap; chat, grading and voice keep the rest", () => {
  const cap = 25, share = 0.6;
  assertEquals(withinBudget("case", { total: 10, content: 14 }, cap, share), true);
  assertEquals(withinBudget("case", { total: 16, content: 15 }, cap, share), false);
  assertEquals(withinBudget("template", { total: 16, content: 15 }, cap, share), false);
  assertEquals(withinBudget("patient", { total: 16, content: 15 }, cap, share), true);
  assertEquals(withinBudget("grade", { total: 25, content: 15 }, cap, share), false);
  assertEquals(withinBudget(undefined, { total: 24, content: 20 }, cap, share), true);
  assertEquals([isContentTask("cards"), isContentTask("check")], [true, false]);
  assertEquals([contentShare("0.5"), contentShare("2"), contentShare(undefined)], [0.5, 0.6, 0.6]);
});
