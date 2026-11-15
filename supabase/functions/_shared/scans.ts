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
  zone: ScanZone | null;
  view: "PA" | "AP";
  age: number;
  sex: "female" | "male";
  report: string;
};

/** Lung zone of a radiologist box (upper, middle or lower third of the film). */
export type ScanZone = "upper" | "middle" | "lower";

/**
 * What a case needs from the library. `zone` is set only for findings that sit in one zone; `view`
 * is a preference (a portable film is AP), never a filter.
 */
export type ScanWant = {
  finding: ScanFinding;
  side: "left" | "right" | null;
  zone: ScanZone | null;
  view: "PA" | "AP";
  age: number;
  sex: "female" | "male";
};

/** True when an ordered test is a chest radiograph (the only study with real images). */
export function isChestXray(testName: string): boolean {
  return /\bchest\b.*\b(x-?ray|radiograph|film)\b|\bcxr\b/i.test(testName);
}

/** The view a study name asks for: portable and AP films are AP, everything else PA. */
export function preferredView(testName: string): "PA" | "AP" {
  return /\bportable\b|anteroposterior/i.test(testName) || /\bAP\b/.test(testName) ? "AP" : "PA";
}

// Profile findings often hedge ("Usually normal; may show cardiomegaly") or list what is absent
// ("Clear lungs without consolidation or effusion"). Such text names findings the film does not
// show, so a finding with any negation or hedge anywhere is never read as positive.
const NOT_POSITIVE =
  /\b(normal|no|without|absent|may show|may reveal|can show|possible|possibly|occasionally|rarely|if present)\b|\bclear lungs?\b/i;

/** True when a finding states something the film shows, with no negation or hedge in it. */
export function isPositiveFinding(text: string): boolean {
  return !NOT_POSITIVE.test(text);
}

// Each positive finding maps to every class it names; "Cardiomegaly or pulmonary edema" names two.
const FINDING_KEYWORDS: [ScanFinding, RegExp][] = [
  ["pneumothorax", /pneumothorax/i],
  ["effusion", /effusion/i],
  ["opacity", /consolidation|infiltrate|opacit|airspace/i],
  // "Mass effect" and a mediastinal mass are not a lung mass; "massive" is not a mass at all.
  ["nodule_mass", /\bnodules?\b|(?<!mediastinal )\bmass(es)?\b(?! effect)/i],
  // "Collapsed lung" is the lay word for a pneumothorax, not atelectasis.
  ["atelectasis", /atelectasis|\bcollapse\b/i],
  ["edema", /edema|kerley|vascular congestion|cephalization/i],
  ["cardiomegaly", /cardiomegaly|enlarged cardiac|cardiac silhouette/i],
  // Subcutaneous emphysema is air in the soft tissues, not emphysematous lungs.
  ["emphysema", /hyperinflat|(?<!subcutaneous )emphysema|flattened diaphragm/i],
  ["fracture", /fracture/i],
];

function findingClasses(text: string): ScanFinding[] {
  return FINDING_KEYWORDS.filter(([, pattern]) => pattern.test(text)).map(([finding]) => finding);
}

// A whole-film statement ("Usually normal", "Normal lung fields", "Normal lungs in uncomplicated
// influenza", "No acute findings"): it opens like one and names no finding class, so it says nothing
// about one finding and can sit beside a positive one without hiding anything. "No pneumothorax"
// and "Usually normal; may show cardiomegaly" are not: the first names a class after a plain "no",
// the second names one at all.
const WHOLE_FILM_OPENING =
  /^\s*(?:(?:usually|typically|often|may be)\s+)?(?:normal|clear lungs?|clear lung fields|unremarkable|no acute)\b/i;

function isWholeFilm(text: string): boolean {
  return WHOLE_FILM_OPENING.test(text) && findingClasses(text).length === 0;
}

/**
 * Maps a case's sampled imaging findings to one library class; null means no real image fits.
 * Only an empty list is a normal film: findings that are all whole-film statements say too little
 * to pick a picture. Any other negated or hedged finding makes the study text-only, even beside a
 * positive one: "pleural line with absent lung markings" is a pneumothorax worded with a negation,
 * and dropping it would let another finding pick an image that lacks the defining sign. The
 * positive findings must all name the same single class: a study that also shows something else
 * (a second class, or a finding the library has no class for, like a widened mediastinum) would
 * lose that finding when the image's report replaces the text, so it stays text-only.
 */
export function scanFinding(findings: string[]): ScanFinding | null {
  if (findings.length === 0) return "normal";
  const specific = findings.filter((f) => !isWholeFilm(f));
  if (specific.length === 0 || !specific.every(isPositiveFinding)) return null;
  const classes = new Set<ScanFinding>();
  for (const text of specific) {
    const named = findingClasses(text);
    if (named.length === 0) return null;
    named.forEach((c) => classes.add(c));
  }
  return classes.size === 1 ? [...classes][0] : null;
}

/** The side the case text names, or null when it names both or neither. */
export function sideHint(texts: string[]): "left" | "right" | null {
  const text = texts.join("\n");
  const left = /\bleft\b/i.test(text);
  const right = /\bright\b/i.test(text);
  if (left === right) return null;
  return left ? "left" : "right";
}

const ZONE_WORDS: [ScanZone, RegExp][] = [
  ["lower", /\bbases?\b|\bbasal\b|\bbasilar\b|\blower lobes?\b|\blower zones?\b/i],
  ["upper", /\bapex\b|\bapices\b|\bapical\b|\bupper lobes?\b|\bupper zones?\b/i],
  ["middle", /\bmiddle lobe\b|\blingula|\bmid zones?\b|\bmid-zones?\b/i],
];

/** The lung zone the case text names, or null when it names none or more than one. */
export function zoneHint(texts: string[]): ScanZone | null {
  const text = texts.join("\n");
  const named = ZONE_WORDS.filter(([, pattern]) => pattern.test(text));
  return named.length === 1 ? named[0][0] : null;
}

/** Findings that sit in one zone of one lung, so the image's zone must match the case's. */
export const ZONED_FINDINGS: ReadonlySet<ScanFinding> = new Set(["opacity", "nodule_mass", "atelectasis"]);

/** Children's chests change fast with age, so a child's film must be close in age; an infant's
 *  film (under 2) differs too much to borrow at all. */
function ageFits(assetAge: number, caseAge: number): boolean {
  if (caseAge < 2) return false;
  if (caseAge < 18) return assetAge < 18 && Math.abs(assetAge - caseAge) <= 3;
  return assetAge >= 18 && Math.abs(assetAge - caseAge) <= 15;
}

/**
 * Picks one asset for the case: same finding and sex, a close age (see ageFits), the wanted side
 * when one is set, and the wanted zone when one is set and the finding is zoned. Unseen assets are
 * preferred so a student does not meet the same image twice; within those, the wanted view.
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
    ageFits(a.age, want.age) &&
    (want.side === null || a.side === want.side) &&
    (want.zone === null || !ZONED_FINDINGS.has(a.finding) || a.zone === want.zone)
  );
  const unseen = fits.filter((a) => !seen.has(a.id));
  const fresh = unseen.length > 0 ? unseen : fits;
  const inView = fresh.filter((a) => a.view === want.view);
  const pool = inView.length > 0 ? inView : fresh;
  if (pool.length === 0) return null;
  return pool[Math.min(pool.length - 1, Math.floor(rng() * pool.length))];
}
