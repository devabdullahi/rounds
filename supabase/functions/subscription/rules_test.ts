import { assertEquals } from "jsr:@std/assert@1";
import { decideClaim } from "./rules.ts";

const claim = (rowOwner: string | null, taggedAccount: string | null, current: boolean) =>
  decideClaim({ caller: "b", rowOwner, taggedAccount, current });

Deno.test("a new plan with no record or tag goes to whoever claims it", () => {
  assertEquals(claim(null, null, true), { kind: "own" });
});

Deno.test("the caller's own plan stays theirs", () => {
  assertEquals(claim("b", null, true), { kind: "own" });
  assertEquals(claim(null, "b", true), { kind: "own" });
});

Deno.test("a plan in use by another account is taken, by record or by tag", () => {
  assertEquals(claim("a", null, true), { kind: "taken", owner: "a" });
  assertEquals(claim(null, "a", true), { kind: "taken", owner: "a" });
});

Deno.test("a lapsed or refunded plan blocks nobody", () => {
  assertEquals(claim("a", null, false), { kind: "own" });
  assertEquals(claim(null, "a", false), { kind: "own" });
});

Deno.test("once recorded, the record decides, not a newer tag (no silent moves on a tier change)", () => {
  assertEquals(claim("a", "b", true), { kind: "taken", owner: "a" });
});
