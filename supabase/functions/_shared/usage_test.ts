import { assertAlmostEquals, assertEquals } from "jsr:@std/assert@1";
import { costUSD, dailyBudgetUSD } from "./usage.ts";

Deno.test("cost uses peak prices per million tokens", () => {
  // 1M cache hits + 1M misses + 1M output on v4-pro = 0.044 + 1.32 + 3.96
  assertAlmostEquals(costUSD("deepseek-v4-pro", { hit: 1e6, miss: 1e6, output: 1e6, reasoning: 5e5 }), 5.324, 1e-9);
  assertAlmostEquals(costUSD("deepseek-flash", { hit: 0, miss: 2000, output: 150, reasoning: 0 }), 0.00078, 1e-12);
});

Deno.test("unpriced models cost nothing rather than guessing", () => {
  assertEquals(costUSD("gpt-4.1", { hit: 1e6, miss: 1e6, output: 1e6, reasoning: 0 }), 0);
});

Deno.test("the daily budget falls back to the default for missing or bad values", () => {
  const table: [string | undefined, number][] = [[undefined, 25], ["", 25], ["abc", 25], ["-5", 25], ["0", 25], ["40", 40], ["7.5", 7.5]];
  for (const [raw, want] of table) assertEquals(dailyBudgetUSD(raw), want, String(raw));
});
