// Fictional patient names, picked in code so every case gets a different one (a model asked for a
// name lands on the same few). First names fit the patient's birth decade and sex, from Social
// Security baby-name data; surnames follow how common they are in the US, from the 2010 Census.
// Both are public-domain US government data (names.json says how it was cut down).

import names from "./names.json" with { type: "json" };

type Weighted = [string, number][];

const FIRST = names.first as unknown as Record<"F" | "M", Record<string, Weighted>>;
const LAST = names.last as unknown as Weighted;
const DECADES = Object.keys(FIRST.F).map(Number).sort((a, b) => a - b);

/** One entry, drawn by the square root of its weight: common names stay common, but Smith no longer
 *  turns up 800 times as often as the 3,000th surname. */
function draw(list: Weighted, rng: () => number): string {
  const weights = list.map(([, w]) => Math.sqrt(w));
  let left = rng() * weights.reduce((a, b) => a + b, 0);
  for (let i = 0; i < list.length; i++) {
    left -= weights[i];
    if (left <= 0) return list[i][0];
  }
  return list[list.length - 1][0];
}

/** The decade a patient of this age was born in, within the data's range (1920s–2000s). */
export function birthDecade(age: number, year = new Date().getUTCFullYear()): number {
  const decade = Math.floor((year - age) / 10) * 10;
  return Math.min(DECADES[DECADES.length - 1], Math.max(DECADES[0], decade));
}

/** "Linda Okafor" for a 70-year-old woman, "Aiden Ramirez" for a 9-year-old boy. Sex "X" draws from either. */
export function patientName(sex: string, age: number, rng: () => number, year?: number): string {
  const s: "F" | "M" = sex === "F" || sex === "M" ? sex : rng() < 0.5 ? "F" : "M";
  return `${draw(FIRST[s][String(birthDecade(age, year))], rng)} ${draw(LAST, rng)}`;
}
