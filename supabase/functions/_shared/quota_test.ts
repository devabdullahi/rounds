import { assertEquals } from "jsr:@std/assert@1";
import { burstLimit, dailyClaimLimit } from "./quota.ts";

Deno.test("burst limits sit far above human speed by default", () => {
  assertEquals(burstLimit("question"), 30);
  assertEquals(burstLimit("case"), 5);
  assertEquals(burstLimit("cards"), 5);
  assertEquals(burstLimit("grade"), 10);
  assertEquals(dailyClaimLimit(), 50);
});

Deno.test("a burst limit can be changed per deployment, and bad values fall back", () => {
  Deno.env.set("BURST_QUESTIONS_PER_MINUTE", "60");
  assertEquals(burstLimit("question"), 60);
  Deno.env.set("BURST_QUESTIONS_PER_MINUTE", "lots");
  assertEquals(burstLimit("question"), 30);
  Deno.env.delete("BURST_QUESTIONS_PER_MINUTE");
});
