// Real chest X-ray images: which tests get one and the short-lived link that shows it. Pure apart
// from the injected signer, so the switch, the skipping and the no-caching rule are unit-tested.
// The client only ever receives {url, credit, citation, source_url}: never an asset id or object name.

/** What the app shows with a scan: a link to the image plus the credit it must display. */
export type ScanReply = { url: string; credit: string; citation: string; source_url: string };

/** Credit line shown under the image. */
export const SCAN_CREDIT = "Real de-identified teaching image · NIH Clinical Center";
/** Citation shown when the student taps through from the credit. */
export const SCAN_CITATION =
  "Wang X, Peng Y, Lu L, Lu Z, Bagheri M, Summers RM. ChestX-ray8: Hospital-scale Chest X-ray Database and Benchmarks on Weakly-Supervised Classification and Localization of Common Thorax Diseases. IEEE CVPR 2017.";
/** Where the dataset is published. */
export const SCAN_SOURCE_URL = "https://nihcc.app.box.com/v/ChestXray-NIHCC";
/** How long a signed link stays valid, seconds. Long enough for a case sitting, short enough that a
 *  leaked link soon dies. */
export const SCAN_URL_SECONDS = 3600;

/** Images are served only when the `REAL_SCANS` secret is exactly `on`; anything else keeps every
 *  result text-only. */
export function scansOn(env: (k: string) => string | undefined): boolean {
  return env("REAL_SCANS") === "on";
}

/** A signed link per test that has a scan. `sign` turns a storage object name into a full URL; it
 *  runs on every call, since a cached link would outlive its hour. A throw from `sign` propagates:
 *  the caller decides to serve the result without images. */
export async function signScans(
  tests: { id: string; scan_asset_id?: string | null }[],
  sign: (assetId: string) => Promise<string>,
): Promise<Map<string, ScanReply>> {
  const out = new Map<string, ScanReply>();
  for (const t of tests) {
    if (!t.scan_asset_id) continue;
    const url = await sign(t.scan_asset_id);
    out.set(t.id, { url, credit: SCAN_CREDIT, citation: SCAN_CITATION, source_url: SCAN_SOURCE_URL });
  }
  return out;
}

/** Asks Storage for a signed link to one object in the private `scans` bucket (service role). */
export async function signObject(
  supabaseUrl: string, serviceKey: string, objectName: string, fetcher: typeof fetch = fetch,
): Promise<string> {
  const res = await fetcher(`${supabaseUrl}/storage/v1/object/sign/scans/${objectName}`, {
    method: "POST",
    headers: { Authorization: `Bearer ${serviceKey}`, apikey: serviceKey, "Content-Type": "application/json" },
    body: JSON.stringify({ expiresIn: SCAN_URL_SECONDS }),
  });
  if (!res.ok) throw new Error(`sign failed: ${res.status}`);
  const { signedURL } = await res.json();
  if (typeof signedURL !== "string" || !signedURL.startsWith("/")) throw new Error("sign reply had no signedURL");
  return `${supabaseUrl}/storage/v1${signedURL}`;
}
