import { assertEquals } from "jsr:@std/assert@1";
import { decodeJWS, maskEmail, summarize } from "./appstore.ts";

const b64u = (o: unknown) => btoa(JSON.stringify(o)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
const jws = (payload: unknown) => `${b64u({ alg: "ES256" })}.${b64u(payload)}.sig`;

const tx = (over: Record<string, unknown> = {}) => ({
  originalTransactionId: "2000000111", productId: "com.abdul.rounds.yearly", bundleId: "com.abdul.rounds",
  expiresDate: 1_800_000_000_000, environment: "Sandbox", ...over,
});
const response = (status: number, info: Record<string, unknown>) => ({
  environment: "Sandbox", bundleId: "com.abdul.rounds",
  data: [{ lastTransactions: [{ originalTransactionId: String(info.originalTransactionId), status, signedTransactionInfo: jws(info) }] }],
});

Deno.test("decodes the payload of a JWS", () => {
  assertEquals(decodeJWS(jws({ a: 1, b: "x" })), { a: 1, b: "x" });
});

Deno.test("an active or grace-period subscription is active; expired and billing retry are not", () => {
  for (const [status, active] of [[1, true], [4, true], [2, false], [3, false]] as const) {
    assertEquals(summarize(response(status, tx()))?.active, active, `status ${status}`);
  }
});

Deno.test("a revoked subscription is revoked and inactive", () => {
  const s = summarize(response(5, tx()));
  assertEquals([s?.active, s?.revoked], [false, true]);
  assertEquals(summarize(response(1, tx({ revocationDate: 1 })))?.revoked, true);
});

Deno.test("reads the subscription's identity and expiry", () => {
  const s = summarize(response(1, tx()));
  assertEquals(s?.originalTransactionId, "2000000111");
  assertEquals(s?.productId, "com.abdul.rounds.yearly");
  assertEquals(s?.expiresAt.getTime(), 1_800_000_000_000);
  assertEquals(s?.environment, "Sandbox");
});

Deno.test("another app's or another product's subscription is ignored", () => {
  assertEquals(summarize({ ...response(1, tx()), bundleId: "com.other.app" }), null);
  assertEquals(summarize(response(1, tx({ productId: "com.other.pro" }))), null);
  assertEquals(summarize(response(1, tx({ bundleId: "com.other.app" }))), null);
});

Deno.test("emails are masked; Apple relay addresses say Apple", () => {
  assertEquals(maskEmail("jane.doe@gmail.com"), "j•••@gmail.com");
  assertEquals(maskEmail("x7@privaterelay.appleid.com"), "an account signed in with Apple");
  assertEquals(maskEmail(null), "another account");
});

Deno.test("reads the account the app tagged the purchase with, lowercased", () => {
  assertEquals(summarize(response(1, tx({ appAccountToken: "AB12CD34-0000-4000-8000-000000000000" })))?.appAccountToken,
    "ab12cd34-0000-4000-8000-000000000000");
  assertEquals(summarize(response(1, tx()))?.appAccountToken, undefined);
});
