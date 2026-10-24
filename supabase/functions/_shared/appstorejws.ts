// Verifies a StoreKit 2 signed transaction (Transaction.jwsRepresentation) the app sends from the
// phone. Only the Apple ID that bought a plan can produce one, so it's how `subscription transfer`
// knows the caller holds the purchase rather than just its transaction id.
//
// Checks, as Apple's own server library does: ES256 signature by the leaf certificate in `x5c`;
// leaf issued by the intermediate and the intermediate by the root; the root is Apple Root CA - G3
// (pinned by SHA-256); Apple's marker OIDs on the leaf (receipt signing) and the intermediate (WWDR);
// every certificate valid when the transaction was signed. No network calls.
import { X509Certificate } from "node:crypto";

/** SHA-256 of Apple Root CA - G3 (https://www.apple.com/certificateauthority/AppleRootCA-G3.cer). */
export const APPLE_ROOT_G3_SHA256 = "63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179";

// DER encodings of 1.2.840.113635.100.6.11.1 (Mac App Store receipt signing, on the leaf) and
// 1.2.840.113635.100.6.2.1 (Apple WWDR intermediate).
const LEAF_OID = [0x06, 0x0a, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x63, 0x64, 0x06, 0x0b, 0x01];
const INTERMEDIATE_OID = [0x06, 0x0a, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x63, 0x64, 0x06, 0x02, 0x01];

export type SignedTransaction = {
  originalTransactionId?: string;
  transactionId?: string;
  bundleId?: string;
  productId?: string;
  environment?: string;
  signedDate?: number;
  [key: string]: unknown;
};

function fromBase64(b64: string): Uint8Array<ArrayBuffer> {
  const normal = b64.replace(/-/g, "+").replace(/_/g, "/");
  return Uint8Array.from(atob(normal + "=".repeat((4 - normal.length % 4) % 4)), (c) => c.charCodeAt(0));
}

function contains(haystack: Uint8Array, needle: number[]): boolean {
  outer: for (let i = 0; i + needle.length <= haystack.length; i++) {
    for (let j = 0; j < needle.length; j++) if (haystack[i + j] !== needle[j]) continue outer;
    return true;
  }
  return false;
}

async function sha256Hex(bytes: Uint8Array<ArrayBuffer>): Promise<string> {
  return [...new Uint8Array(await crypto.subtle.digest("SHA-256", bytes))].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function validAt(cert: X509Certificate, at: Date): boolean {
  return new Date(cert.validFrom).getTime() <= at.getTime() && at.getTime() <= new Date(cert.validTo).getTime();
}

/** The transaction's payload once every check passes; throws otherwise. `pinnedRoot` exists for tests. */
export async function verifySignedTransaction(jws: string, pinnedRoot = APPLE_ROOT_G3_SHA256): Promise<SignedTransaction> {
  const parts = typeof jws === "string" ? jws.split(".") : [];
  if (parts.length !== 3 || parts.some((p) => !p)) throw new Error("not a JWS");
  const [headerPart, payloadPart, signaturePart] = parts;

  let header: { alg?: string; x5c?: unknown };
  let payload: SignedTransaction;
  try {
    header = JSON.parse(new TextDecoder().decode(fromBase64(headerPart)));
    payload = JSON.parse(new TextDecoder().decode(fromBase64(payloadPart)));
  } catch {
    throw new Error("not a JWS");
  }
  if (header.alg !== "ES256") throw new Error("unexpected alg");
  if (!Array.isArray(header.x5c) || header.x5c.length !== 3 || header.x5c.some((c) => typeof c !== "string")) {
    throw new Error("expected a three-certificate chain");
  }

  const raw = (header.x5c as string[]).map(fromBase64);
  if (await sha256Hex(raw[2]) !== pinnedRoot) throw new Error("chain doesn't end in Apple's root");
  const [leaf, intermediate, root] = raw.map((bytes) => new X509Certificate(bytes));

  if (!intermediate.checkIssued(root) || !intermediate.verify(root.publicKey)) throw new Error("intermediate not issued by the root");
  if (!leaf.checkIssued(intermediate) || !leaf.verify(intermediate.publicKey)) throw new Error("leaf not issued by the intermediate");
  if (!contains(raw[0], LEAF_OID)) throw new Error("leaf isn't an App Store signing certificate");
  if (!contains(raw[1], INTERMEDIATE_OID)) throw new Error("intermediate isn't Apple's WWDR certificate");

  const signedAt = typeof payload.signedDate === "number" ? new Date(payload.signedDate) : new Date();
  if (![leaf, intermediate, root].every((c) => validAt(c, signedAt))) throw new Error("certificate not valid when signed");

  const spki = new Uint8Array(leaf.publicKey.export({ type: "spki", format: "der" }));
  const key = await crypto.subtle.importKey("spki", spki, { name: "ECDSA", namedCurve: "P-256" }, false, ["verify"]);
  const ok = await crypto.subtle.verify({ name: "ECDSA", hash: "SHA-256" }, key, fromBase64(signaturePart),
    new TextEncoder().encode(`${headerPart}.${payloadPart}`));
  if (!ok) throw new Error("bad signature");
  return payload;
}
