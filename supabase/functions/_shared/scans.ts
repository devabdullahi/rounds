// Pure rules for matching a real chest X-ray to a generated case. Kept free of
// I/O so the picking logic is testable; the library lives in a private table
// and only expert-labeled images are ever loaded into it.

/** Finding classes the library covers; anything else stays text-only. */
export type ScanFinding =
  | "normal"
  | "pneumothorax"
  | "opacity"
  | "nodule_mass"
  | "fracture"
  | "effusion"
  | "atelectasis"
  | "cardiomegaly"
  | "edema"
  | "emphysema";

/** One library image (a row of private.scan_assets). Never sent to the client. */
export type ScanAsset = {
  id: string;
  object_name: string;
  finding: ScanFinding;
  side: "left" | "right" | null;
  zone: string | null;
  view: "PA" | "AP";
  age: number;
  sex: "female" | "male";
  report: string;
};

/** What a case needs from the library. */
export type ScanWant = { finding: ScanFinding; side: "left" | "right" | null; age: number; sex: "female" | "male" };

/** True when an ordered test is a chest radiograph (the only study with real images). */
export function isChestXray(testName: string): boolean {
  return /\bchest\b.*\b(x-?ray|radiograph|film)\b|\bcxr\b/i.test(testName);
}

// Order matters: the first matching class wins, so a study with an effusion and
// a consolidation is shown as the effusion.
const FINDING_KEYWORDS: [ScanFinding, RegExp][] = [
  ["pneumothorax", /pneumothorax/i],
  ["effusion", /effusion/i],
  ["opacity", /consolidation|infiltrate|opacit|airspace/i],
  ["nodule_mass", /nodule|mass/i],
  ["atelectasis", /atelectasis|collapse/i],
  ["edema", /edema|kerley|vascular congestion|cephalization/i],
  ["cardiomegaly", /cardiomegaly|enlarged cardiac|cardiac silhouette/i],
  ["emphysema", /hyperinflat|emphysema|flattened diaphragm/i],
  ["fracture", /rib fracture|fracture/i],
];

/** Maps a case's imaging findings to a library class; null means no real image fits. */
export function scanFinding(findings: string[]): ScanFinding | null {
  if (findings.length === 0) return "normal";
  const text = findings.join("\n");
  for (const [finding, pattern] of FINDING_KEYWORDS) {
    if (pattern.test(text)) return finding;
  }
  return null;
}

/** The side the case text names, or null when it names both or neither. */
export function sideHint(texts: string[]): "left" | "right" | null {
  const text = texts.join("\n");
  const left = /\bleft\b/i.test(text);
  const right = /\bright\b/i.test(text);
  if (left === right) return null;
  return left ? "left" : "right";
}

/**
 * Picks one asset for the case: same finding and sex, same adult/child band
 * within 15 years, and the wanted side when one is set. Unseen assets are
 * preferred so a student does not meet the same image twice.
 */
export function chooseScan(
  candidates: ScanAsset[],
  want: ScanWant,
  seen: Set<string>,
  rng: () => number,
): ScanAsset | null {
  const fits = candidates.filter((a) =>
    a.finding === want.finding &&
    a.sex === want.sex &&
    (a.age < 18) === (want.age < 18) &&
    Math.abs(a.age - want.age) <= 15 &&
    (want.side === null || a.side === want.side)
  );
  const unseen = fits.filter((a) => !seen.has(a.id));
  const pool = unseen.length > 0 ? unseen : fits;
  if (pool.length === 0) return null;
  return pool[Math.min(pool.length - 1, Math.floor(rng() * pool.length))];
}
