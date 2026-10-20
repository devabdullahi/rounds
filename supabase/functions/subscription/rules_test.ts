import { assertEquals } from "jsr:@std/assert@1";
import { ownerAfterClaim } from "./rules.ts";

Deno.test("the first account to claim a subscription owns it", () => {
  assertEquals(ownerAfterClaim(null, "a"), { owner: "a", takenByAnother: false });
});

Deno.test("the owner claiming again keeps it", () => {
  assertEquals(ownerAfterClaim("a", "a"), { owner: "a", takenByAnother: false });
});

Deno.test("another account can't take a claimed subscription", () => {
  assertEquals(ownerAfterClaim("a", "b"), { owner: "a", takenByAnother: true });
});

Deno.test("the account that made the purchase owns it, whoever claimed it first", () => {
  assertEquals(ownerAfterClaim(null, "b", "a"), { owner: "a", takenByAnother: true });
  assertEquals(ownerAfterClaim("b", "a", "a"), { owner: "a", takenByAnother: false });
});
