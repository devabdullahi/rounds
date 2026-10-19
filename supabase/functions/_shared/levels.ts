// Lab and vital levels: a live profile's model says how far from normal a value is ("markedly high"),
// and code turns that into the range planCase draws from, using the reference ranges. So every number
// a patient shows comes from code and the reference tables, never from the model.
// Pure, so the bands are unit-tested.

export const LEVELS = [
  "normal", "slightly_high", "high", "markedly_high", "severely_high", "slightly_low", "low", "markedly_low", "severely_low",
] as const;
export type Level = typeof LEVELS[number];
export type Range = { min: number; max: number };

/** Adult normal vital signs, in the profile's units (°F, /min, mm Hg, %). */
export const VITAL_NORMALS: Record<string, [number, number]> = {
  temp: [97.7, 99.5], hr: [60, 100], rr: [12, 20], sbp: [100, 130], dbp: [60, 85], spo2: [95, 100],
};

/** Fixed bands where multiples of normal don't fit: fever is a few degrees, hypoxia a few points. */
const FIXED: Record<string, Partial<Record<Level, [number, number]>>> = {
  temp: {
    slightly_high: [99.5, 100.4], high: [100.4, 102.2], markedly_high: [102.2, 104], severely_high: [104, 106.5],
    slightly_low: [96, 97.7], low: [94, 96], markedly_low: [91, 94], severely_low: [86, 91],
  },
  spo2: { slightly_high: [95, 100], high: [95, 100], markedly_high: [95, 100], severely_high: [95, 100],
    slightly_low: [92, 95], low: [88, 92], markedly_low: [82, 88], severely_low: [70, 82] },
};

/** Multiples of the normal limit for each level: vitals move less than labs (a heart rate of
 *  twice normal is extreme; a troponin of ten times normal is common). */
const FACTORS: Record<"vital" | "lab", Record<string, [number, number]>> = {
  vital: { slightly_high: [1, 1.1], high: [1.1, 1.3], markedly_high: [1.3, 1.6], severely_high: [1.6, 2],
    slightly_low: [0.9, 1], low: [0.75, 0.9], markedly_low: [0.6, 0.75], severely_low: [0.45, 0.6] },
  lab: { slightly_high: [1, 1.3], high: [1.3, 2], markedly_high: [2, 4], severely_high: [4, 10],
    slightly_low: [0.85, 1], low: [0.65, 0.85], markedly_low: [0.45, 0.65], severely_low: [0.25, 0.45] },
};

/** Rounds to a precision that suits the size: 132, 4.6, 0.82. */
function tidy(v: number): number {
  const digits = Math.abs(v) >= 100 ? 0 : Math.abs(v) >= 10 ? 1 : 2;
  return Number(v.toFixed(digits));
}

/** The range a level means for a value whose normal interval is [low, high]. Null when the level
 *  can't apply (a test with no upper limit can't be "high" by a multiple). */
export function levelRange(level: Level, normal: [number | null, number | null], kind: "vital" | "lab", id = ""): Range | null {
  const [low, high] = normal;
  const fixed = FIXED[id]?.[level];
  if (fixed) return { min: fixed[0], max: fixed[1] };
  if (level === "normal") return low != null && high != null ? { min: low, max: high } : null;
  const [a, b] = FACTORS[kind][level];
  const base = level === "high" || level.endsWith("_high") ? high : low;
  if (base == null || base <= 0) return null;
  return { min: tidy(base * a), max: tidy(base * b) };
}

/** The level a range sits at: its midpoint against the same bands (for showing the model examples). */
export function rangeLevel(range: Range, normal: [number | null, number | null], kind: "vital" | "lab", id = ""): Level {
  const mid = (range.min + range.max) / 2;
  let best: Level = "normal";
  let bestDistance = Infinity;
  for (const level of LEVELS) {
    const band = levelRange(level, normal, kind, id);
    if (!band) continue;
    const inside = mid >= band.min && mid <= band.max;
    const distance = inside ? 0 : Math.min(Math.abs(mid - band.min), Math.abs(mid - band.max));
    if (distance < bestDistance) { best = level; bestDistance = distance; }
  }
  return best;
}
