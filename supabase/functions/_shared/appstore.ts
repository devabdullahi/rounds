// Asking Apple about a subscription (App Store Server API), so access can follow the Rounds account
// that paid rather than whatever Apple ID is signed in on the phone.
//
// Requests are signed with the In-App Purchase key: APPSTORE_KEY_ID, APPSTORE_ISSUER_ID and
// APPSTORE_PRIVATE_KEY (the .p8's PEM text), set with `supabase secrets set`. Apple's answer comes
// back over TLS from Apple itself, so its signed transaction payloads are read without re-verifying
// their signatures.

export const BUNDLE_ID = "com.abdul.rounds";
export const PRODUCT_IDS = ["com.abdul.rounds.weekly", "com.abdul.rounds.monthly", "com.abdul.rounds.yearly"];

const HOSTS = { Production: "api.storekit.itunes.apple.com", Sandbox: "api.storekit-sandbox.itunes.apple.com" } as const;
const TIMEOUT_MS = 15_000;

/** One subscription as Rounds needs it. */
export type Subscription = {
  originalTransactionId: string;
  productId: string;
  expiresAt: Date;
  environment: string;
  /** Paid up now: Apple's status is active or in the billing grace period. */
  active: boolean;
  /** Refunded or revoked: never entitles again. */
  revoked: boolean;
  /** The Rounds account id the app tagged the purchase with (lowercased), when it did. */
  appAccountToken?: string;
};

/** The JSON inside a JWS Apple sent us. */
export function decodeJWS(jws: string): Record<string, unknown> {
  const part = jws.split(".")[1] ?? "";
  const padded = part.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(part.length / 4) * 4, "=");
  return JSON.parse(new TextDecoder().decode(Uint8Array.from(atob(padded), (c) => c.charCodeAt(0))));
}

type StatusResponse = {
  environment?: string;
  bundleId?: string;
  data?: { lastTransactions?: { originalTransactionId?: string; status?: number; signedTransactionInfo?: string }[] }[];
};

/**
 * The subscription in Apple's "all subscription statuses" answer, or null when it isn't one of ours
 * (wrong app or product). Apple's status codes: 1 active, 2 expired, 3 billing retry, 4 grace
 * period, 5 revoked.
 */
export function summarize(response: StatusResponse, originalTransactionId?: string): Subscription | null {
  if (response.bundleId && response.bundleId !== BUNDLE_ID) return null;
  const last = (response.data ?? []).flatMap((group) => group.lastTransactions ?? [])
    .filter((t) => !originalTransactionId || t.originalTransactionId === originalTransactionId);
  for (const t of last) {
    if (!t.signedTransactionInfo) continue;
    const info = decodeJWS(t.signedTransactionInfo);
    const productId = String(info.productId ?? "");
    if (!PRODUCT_IDS.includes(productId) || (info.bundleId && info.bundleId !== BUNDLE_ID)) continue;
    const revoked = t.status === 5 || info.revocationDate != null;
    return {
      originalTransactionId: String(info.originalTransactionId ?? t.originalTransactionId),
      productId,
      expiresAt: new Date(Number(info.expiresDate ?? 0)),
      environment: String(info.environment ?? response.environment ?? "Production"),
      active: !revoked && (t.status === 1 || t.status === 4),
      revoked,
      appAccountToken: typeof info.appAccountToken === "string" ? info.appAccountToken.toLowerCase() : undefined,
    };
  }
  return null;
}

/** "jane@gmail.com" → "j•••@gmail.com"; Apple relay addresses read as an Apple sign-in. */
export function maskEmail(email: string | null | undefined): string {
  if (!email) return "another account";
  const [name, domain] = email.split("@");
  if (!domain) return "another account";
  if (domain.endsWith("privaterelay.appleid.com")) return "an account signed in with Apple";
  return `${name.slice(0, 1)}•••@${domain}`;
}

function base64url(bytes: Uint8Array | string): string {
  const raw = typeof bytes === "string" ? bytes : String.fromCharCode(...bytes);
  return btoa(raw).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

/** A short-lived ES256 token for the App Store Server API. */
async function appleToken(): Promise<string> {
  const keyId = Deno.env.get("APPSTORE_KEY_ID");
  const issuer = Deno.env.get("APPSTORE_ISSUER_ID");
  const pem = Deno.env.get("APPSTORE_PRIVATE_KEY");
  if (!keyId || !issuer || !pem) throw new Error("App Store Server API secrets are not set");
  const der = Uint8Array.from(atob(pem.replace(/-----[^-]+-----|\s/g, "")), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey("pkcs8", der, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const now = Math.floor(Date.now() / 1000);
  const head = base64url(JSON.stringify({ alg: "ES256", kid: keyId, typ: "JWT" }));
  const body = base64url(JSON.stringify({ iss: issuer, iat: now, exp: now + 300, aud: "appstoreconnect-v1", bid: BUNDLE_ID }));
  const signature = new Uint8Array(await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, new TextEncoder().encode(`${head}.${body}`)));
  return `${head}.${body}.${base64url(signature)}`;
}

/**
 * Apple's current word on the subscription a transaction belongs to: production first, then the
 * sandbox (TestFlight). Null when neither environment knows the transaction.
 */
export async function lookUp(transactionId: string): Promise<Subscription | null> {
  if (!/^\d{1,20}$/.test(transactionId)) return null;
  const token = await appleToken();
  for (const host of [HOSTS.Production, HOSTS.Sandbox]) {
    const res = await fetch(`https://${host}/inApps/v1/subscriptions/${transactionId}`, {
      headers: { Authorization: `Bearer ${token}` },
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
    // Unknown here (404), or an app not yet live in production (401): try the other environment.
    if (res.status === 404 || res.status === 401) continue;
    if (!res.ok) throw new Error(`App Store Server API ${res.status}: ${await res.text()}`);
    return summarize(await res.json() as StatusResponse);
  }
  return null;
}
