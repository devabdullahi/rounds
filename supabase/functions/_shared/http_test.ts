import { assertEquals } from "jsr:@std/assert@1";
import { sameText } from "./http.ts";

Deno.test("sameText matches only identical text", () => {
  for (const [a, b, same] of [
    ["Bearer abc", "Bearer abc", true],
    ["Bearer abc", "Bearer abd", false],
    ["Bearer ab", "Bearer abc", false],
    ["", "Bearer abc", false],
    ["", "", true],
  ] as const) {
    assertEquals(sameText(a, b), same, `${a} vs ${b}`);
  }
});
