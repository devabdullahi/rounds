import { assertEquals } from "jsr:@std/assert@1";
import { compressedBody, sameText } from "./http.ts";

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

Deno.test("compressedBody refuses any encoded body, Brotli included", () => {
  for (const [encoding, refused] of [
    [null, false],
    ["identity", false],
    [" Identity ", false],
    ["br", true],
    ["BR", true],
    ["gzip", true],
    ["deflate", true],
    ["gzip, br", true],
    ["identity, br", true],
    ["", false],
  ] as const) {
    const headers = new Headers();
    if (encoding !== null) headers.set("Content-Encoding", encoding);
    assertEquals(compressedBody(new Request("https://x", { method: "POST", headers })), refused, `${encoding}`);
  }
});
