import { assertEquals } from "jsr:@std/assert@1";
import { thinkingFields } from "./llm.ts";

Deno.test("providers without thinking get the plain token cap", () => {
  assertEquals(thinkingFields(false, 400, "high"), { max_tokens: 400 });
});

Deno.test("effort off disables thinking explicitly, since DeepSeek thinks by default", () => {
  assertEquals(thinkingFields(true, 400, "off"), { max_tokens: 400, thinking: { type: "disabled" } });
});

Deno.test("thinking calls get reasoning headroom on top of the answer budget", () => {
  assertEquals(thinkingFields(true, 7000, "high"), { max_tokens: 15000, thinking: { type: "enabled" }, reasoning_effort: "high" });
  assertEquals(thinkingFields(true, 8000, "low").max_tokens, 10000);
  assertEquals(thinkingFields(true, 200, "max").max_tokens, 16200);
});
