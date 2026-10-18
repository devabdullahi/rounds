import { assertEquals } from "jsr:@std/assert@1";
import { entitled, ownerAfterClaim, toRecheck } from "./rules.ts";

const now = new Date("2026-10-19T12:00:00Z");
const later = new Date("2026-11-19T12:00:00Z");
const earlier = new Date("2026-09-19T12:00:00Z");

Deno.test("the first account to claim a subscription owns it", () => {
  assertEquals(ownerAfterClaim(null, "a"), { owner: "a", takenByAnother: false });
});

Deno.test("the owner claiming again keeps it", () => {
  assertEquals(ownerAfterClaim("a", "a"), { owner: "a", takenByAnother: false });
});

Deno.test("another account can't take a claimed subscription", () => {
  assertEquals(ownerAfterClaim("a", "b"), { owner: "a", takenByAnother: true });
});

Deno.test("an account is paid up only while a subscription runs and wasn't refunded", () => {
  assertEquals(entitled([{ user_id: "a", expires_at: later, revoked: false }], now), true);
  assertEquals(entitled([{ user_id: "a", expires_at: earlier, revoked: false }], now), false);
  assertEquals(entitled([{ user_id: "a", expires_at: later, revoked: true }], now), false);
  assertEquals(entitled([], now), false);
});

Deno.test("the latest unrevoked subscription is the one to recheck", () => {
  const rows = [
    { original_transaction_id: "old", user_id: "a", expires_at: earlier, revoked: false },
    { original_transaction_id: "new", user_id: "a", expires_at: now, revoked: false },
    { original_transaction_id: "refunded", user_id: "a", expires_at: later, revoked: true },
  ];
  assertEquals(toRecheck(rows), "new");
  assertEquals(toRecheck([]), null);
});
