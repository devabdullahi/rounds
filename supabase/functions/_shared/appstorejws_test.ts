import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { APPLE_ROOT_G3_SHA256, verifySignedTransaction } from "./appstorejws.ts";

// A throwaway chain shaped like Apple's (testdata/jws/README.md); its root is passed explicitly.
const dir = new URL("./testdata/jws/", import.meta.url);
const pem = (name: string) => Deno.readTextFileSync(new URL(name, dir));
const der = (text: string) => text.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
const [root, int, leaf, leafNoOid] = ["root.pem", "int.pem", "leaf.pem", "leaf-nooid.pem"].map((n) => der(pem(n)));

async function sha256Hex(b64: string): Promise<string> {
  const bytes = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
  return [...new Uint8Array(await crypto.subtle.digest("SHA-256", bytes))].map((b) => b.toString(16).padStart(2, "0")).join("");
}

const b64url = (bytes: Uint8Array) => btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
const text = (s: string) => b64url(new TextEncoder().encode(s));

async function sign(payload: Record<string, unknown>, x5c: string[], alg = "ES256"): Promise<string> {
  const key = await crypto.subtle.importKey("pkcs8", Uint8Array.from(atob(der(pem("leaf.p8.pem"))), (c) => c.charCodeAt(0)),
    { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const input = `${text(JSON.stringify({ alg, x5c }))}.${text(JSON.stringify(payload))}`;
  const signature = new Uint8Array(await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, new TextEncoder().encode(input)));
  return `${input}.${b64url(signature)}`;
}

const payload = { originalTransactionId: "2000000123456789", bundleId: "com.abdul.rounds", environment: "Sandbox", signedDate: Date.now() };

Deno.test("Apple's root fingerprint is pinned", () => {
  assertEquals(APPLE_ROOT_G3_SHA256, "63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179");
});

Deno.test("a transaction signed through the trusted chain verifies", async () => {
  const jws = await sign(payload, [leaf, int, root]);
  const got = await verifySignedTransaction(jws, await sha256Hex(root));
  assertEquals(got.originalTransactionId, payload.originalTransactionId);
  assertEquals(got.bundleId, payload.bundleId);
});

Deno.test("refused: a chain that doesn't end in the pinned root (e.g. Apple's real root expected)", async () => {
  const jws = await sign(payload, [leaf, int, root]);
  await assertRejects(() => verifySignedTransaction(jws), Error, "root");
});

Deno.test("refused: an edited payload", async () => {
  const [h, , s] = (await sign(payload, [leaf, int, root])).split(".");
  const forged = `${h}.${text(JSON.stringify({ ...payload, originalTransactionId: "2000000999999999" }))}.${s}`;
  await assertRejects(async () => verifySignedTransaction(forged, await sha256Hex(root)), Error, "signature");
});

Deno.test("refused: a leaf without Apple's receipt-signing marker", async () => {
  const jws = await sign(payload, [leafNoOid, int, root]);
  await assertRejects(async () => verifySignedTransaction(jws, await sha256Hex(root)), Error, "leaf");
});

Deno.test("refused: certificates out of order (leaf not issued by the intermediate)", async () => {
  const jws = await sign(payload, [int, leaf, root]);
  await assertRejects(async () => verifySignedTransaction(jws, await sha256Hex(root)), Error);
});

Deno.test("refused: wrong algorithm, missing chain, junk", async () => {
  const pinned = await sha256Hex(root);
  await assertRejects(async () => verifySignedTransaction(await sign(payload, [leaf, int, root], "none"), pinned), Error, "alg");
  await assertRejects(async () => verifySignedTransaction(await sign(payload, [leaf, int]), pinned), Error, "chain");
  await assertRejects(() => verifySignedTransaction("not.a.jws", pinned), Error);
  await assertRejects(() => verifySignedTransaction("", pinned), Error);
});
