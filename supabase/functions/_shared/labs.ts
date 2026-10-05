// Lab value engine: turns a profile's per-severity ranges into one patient's numbers, then
// computes every derived value (anion gap, eGFR, pH…) from those numbers so results agree.
// Pure: no I/O, randomness injected, covered by labs_test.ts.
import ranges from "./reference_ranges.json" with { type: "json" };

export type Severity = "mild" | "moderate" | "severe" | "critical";
export type Sex = "F" | "M";
type Range = { min: number; max: number };
type Interval = [number | null, number | null];

export type RefTest = {
  id: string;
  name: string;
  unit?: string;
  low?: number | null;
  high?: number | null;
  female?: Interval;
  male?: Interval;
  decimals?: number;
  derived?: string;
  normal?: string;
  abnormal?: string[];
};
export type RefPanel = { id: string; name: string; tests: RefTest[] };
export type ProfileLab = {
  test_id: string;
  ranges?: Partial<Record<Severity, Range>>;
  qualitative?: Partial<Record<Severity, string>>;
};

export const PANELS: RefPanel[] = (ranges as { panels: RefPanel[] }).panels;
export const TESTS: Map<string, RefTest> = new Map(PANELS.flatMap((p) => p.tests.map((t) => [t.id, t])));

export type Value = number | string;
export type Values = Record<string, Value>;

export function interval(test: RefTest, sex: Sex): Interval {
  const bySex = sex === "F" ? test.female : test.male;
  return bySex ?? [test.low ?? null, test.high ?? null];
}

function round(value: number, decimals = 0): number {
  const f = 10 ** decimals;
  return Math.round(value * f) / f;
}

function between(rng: () => number, min: number, max: number): number {
  return min + (max - min) * rng();
}

/** A normal value, kept to the middle 60% of the interval so it never reads borderline. */
function normalValue(test: RefTest, sex: Sex, rng: () => number): number {
  let [low, high] = interval(test, sex);
  if (low === null && high === null) return 0;
  if (low === null) low = high! * 0.4;
  if (high === null) high = low * 1.6;
  const pad = (high - low) * 0.2;
  return between(rng, low + pad, high - pad);
}

/** Primary (non-derived) values for every test in the given panels. */
export function primaryValues(
  panelIds: string[],
  labs: ProfileLab[],
  severity: Severity,
  sex: Sex,
  rng: () => number,
): Values {
  const byId = new Map(labs.map((l) => [l.test_id, l]));
  const values: Values = {};
  for (const panel of PANELS.filter((p) => panelIds.includes(p.id))) {
    for (const test of panel.tests) {
      if (test.derived) continue;
      const lab = byId.get(test.id);
      if (test.normal !== undefined) {
        values[test.id] = lab?.qualitative?.[severity] ?? test.normal;
        continue;
      }
      const r = lab?.ranges?.[severity];
      values[test.id] = round(r ? between(rng, r.min, r.max) : normalValue(test, sex, rng), test.decimals);
    }
  }
  // Hct tracks Hgb unless the profile sets it.
  if (typeof values.hgb === "number" && !byId.get("hct")?.ranges?.[severity]) {
    values.hct = round(values.hgb * 3 + between(rng, -1, 1), 1);
  }
  return values;
}

/** CKD-EPI 2021 creatinine equation (race-free). */
export function egfr(creatinine: number, age: number, sex: Sex): number {
  const k = sex === "F" ? 0.7 : 0.9;
  const a = sex === "F" ? -0.241 : -0.302;
  const ratio = creatinine / k;
  const value = 142 * Math.min(ratio, 1) ** a * Math.max(ratio, 1) ** -1.2 * 0.9938 ** age * (sex === "F" ? 1.012 : 1);
  return Math.round(value);
}

/** Fills derived values from primaries that are present. Blood gas pH follows from HCO₃ and PaCO₂. */
export function deriveValues(v: Values, age: number, sex: Sex): Values {
  const out = { ...v };
  const n = (id: string) => (typeof out[id] === "number" ? out[id] as number : undefined);
  const set = (id: string, value: number) => {
    out[id] = round(value, TESTS.get(id)?.decimals ?? 0);
  };

  const [na, cl, hco3, bun, cr, glucose] = ["na", "cl", "hco3", "bun", "cr", "glucose"].map(n);
  if (na !== undefined && cl !== undefined && hco3 !== undefined) set("anion_gap", na - (cl + hco3));
  if (bun !== undefined && cr !== undefined) set("bun_cr", bun / cr);
  if (cr !== undefined) out.egfr = egfr(cr, age, sex);
  if (na !== undefined && glucose !== undefined && bun !== undefined) {
    set("calc_osm", 2 * na + glucose / 18 + bun / 2.8);
    const osm = n("osm");
    if (osm !== undefined) set("osm_gap", osm - (out.calc_osm as number));
  }

  const [wbc, neut, bands] = ["wbc", "neut_pct", "bands_pct"].map(n);
  if (wbc !== undefined && neut !== undefined) set("anc", wbc * (neut + (bands ?? 0)) / 100);

  const [ca, albumin] = ["ca", "albumin"].map(n);
  if (ca !== undefined && albumin !== undefined) set("corrected_ca", ca + 0.8 * (4.0 - albumin));

  const [iron, tibc] = ["iron", "tibc"].map(n);
  if (iron !== undefined && tibc !== undefined) set("tsat", iron / tibc * 100);

  const [sbp, dbp] = ["sbp", "dbp"].map(n);
  if (sbp !== undefined && dbp !== undefined) set("map", (sbp + 2 * dbp) / 3);

  // One bicarbonate for the whole patient: the gas uses the BMP value when both are drawn.
  const paco2 = n("paco2");
  const gasHco3 = hco3 ?? n("abg_hco3");
  if (paco2 !== undefined && gasHco3 !== undefined) {
    out.abg_hco3 = round(gasHco3);
    set("ph", 6.1 + Math.log10(gasHco3 / (0.03 * paco2)));
    set("base_excess", gasHco3 - 24);
  }
  return out;
}

export type Flag = "H" | "L" | "HH" | "LL" | "";

export function flag(test: RefTest, value: Value, sex: Sex): Flag {
  if (typeof value === "string") return test.normal !== undefined && value !== test.normal ? "H" : "";
  const [low, high] = interval(test, sex);
  const t = test as RefTest & { critical_low?: number; critical_high?: number };
  if (t.critical_low != null && value < t.critical_low) return "LL";
  if (t.critical_high != null && value > t.critical_high) return "HH";
  if (low !== null && value < low) return "L";
  if (high !== null && value > high) return "H";
  return "";
}

/** "Mean corpuscular volume (MCV)" → "MCV", as a lab report prints it. */
export function shortName(name: string): string {
  return name.match(/\(([^)]+)\)\s*$/)?.[1] ?? name;
}

export type PanelResult = { text: string; abnormal: boolean };

/** Report text for one panel or single test: "Na 138 mmol/L · K 5.9 mmol/L (H) · …". */
export function report(id: string, values: Values, sex: Sex): PanelResult {
  const panel = PANELS.find((p) => p.id === id);
  const tests = panel ? panel.tests : [TESTS.get(id)].filter((t): t is RefTest => !!t);
  let abnormal = false;
  const parts: string[] = [];
  for (const test of tests) {
    const value = values[test.id];
    if (value === undefined) continue;
    const f = flag(test, value, sex);
    if (f) abnormal = true;
    const unit = typeof value === "number" && test.unit ? ` ${test.unit}` : "";
    parts.push(`${shortName(test.name)} ${value}${unit}${f ? ` (${f})` : ""}`);
  }
  return { text: parts.join(" · "), abnormal };
}

/** Panels a lab-type test id belongs to: the panel itself, or the panel holding a single test. */
export function panelFor(id: string): string | undefined {
  if (PANELS.some((p) => p.id === id)) return id;
  return PANELS.find((p) => p.tests.some((t) => t.id === id))?.id;
}

/** Seeded generator (mulberry32) so a case can be regenerated identically in tests. */
export function seeded(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6D2B79F5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
