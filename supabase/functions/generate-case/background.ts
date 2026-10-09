// Synthetic patient backgrounds (Synthea, private.patient_backgrounds): who a generated patient is
// before today's illness. Picking one and turning it into writer input are pure, so they're tested
// without a DB. The rows' wording is SNOMED CT (licensed): it goes only to the writer, which retells
// it in the patient's own words; checkWriting rejects SNOMED-style tags that slip through.
import type { CasePlan } from "../_shared/casegen.ts";

export type PatientBackground = {
  id: string;
  age: number;
  sex: string;
  marital: string | null;
  conditions: string[];
  medications: { rxcui?: string; name: string }[];
  allergies: string[];
  smoking: string | null;
  social: string[];
};

/** How far a background's age may be from the planned patient's. */
export const MAX_AGE_GAP = 7;

// SNOMED CT semantic tags ("Peanut (substance)"); never part of what a patient would say.
export const SNOMED_TAG = /\s*\((disorder|finding|substance|organism|situation|procedure|qualifier value|morphologic abnormality|observable entity|event|product|body structure)\)/gi;
const PREGNANCY = /pregnan/i;
const MARITAL: Record<string, string> = { M: "married", S: "single", D: "divorced", W: "widowed" };
/** Synthea's marker for "has allergies", not an allergy itself. */
const NOT_AN_ALLERGY = /^allergic disposition$/i;

/** Lowercase words with punctuation and SNOMED tags dropped, for whole-word comparison. */
function words(text: string): string {
  return text.replace(SNOMED_TAG, " ").toLowerCase().replace(/[^a-z0-9]+/g, " ").trim();
}

/** True when a background condition names the case's diagnosis, or is a word-for-word part of it
 *  ("Anemia" in an iron deficiency anemia case), so the patient's history would give it away. */
function reveals(condition: string, names: string[]): boolean {
  const c = ` ${words(condition)} `;
  return names.some((n) => c.includes(` ${n} `) || (c.trim().length >= 4 && ` ${n} `.includes(c)));
}

/**
 * The background for a planned patient: same sex, closest age within MAX_AGE_GAP years, chosen at
 * random among equally close ones. Backgrounds whose conditions mention the case's diagnosis (its
 * name or any accepted name) are skipped, and so are pregnancies when the patient isn't pregnant.
 * Null when none fits; the case is then written without one.
 */
export function pickBackground(
  rows: PatientBackground[], plan: Pick<CasePlan, "age" | "sex" | "pregnant">, diagnosisNames: string[], rng: () => number,
): PatientBackground | null {
  const names = diagnosisNames.map((n) => words(n.replace(/\s*\([^)]*\)/g, " "))).filter((n) => n.length >= 3);
  const fits = rows.filter((r) =>
    r.sex === plan.sex && Math.abs(r.age - plan.age) <= MAX_AGE_GAP &&
    !(r.conditions ?? []).some((c) => reveals(c, names)) &&
    (plan.pregnant || !(r.conditions ?? []).some((c) => PREGNANCY.test(c)))
  );
  if (fits.length === 0) return null;
  const gap = Math.min(...fits.map((r) => Math.abs(r.age - plan.age)));
  const closest = fits.filter((r) => Math.abs(r.age - plan.age) === gap);
  return closest[Math.min(closest.length - 1, Math.floor(rng() * closest.length))];
}

/** The background as writer input, SNOMED tags already dropped; the writer still rewords it. */
export function backgroundForWriter(b: PatientBackground) {
  const clean = (list: string[] | null | undefined) => (list ?? []).map((s) => s.replace(SNOMED_TAG, "").trim()).filter(Boolean);
  return {
    chronic_conditions: clean(b.conditions),
    current_medications: (b.medications ?? []).map((m) => m.name).filter(Boolean),
    allergies: clean(b.allergies).filter((a) => !NOT_AN_ALLERGY.test(a)),
    smoking: b.smoking ?? "unknown",
    marital_status: b.marital ? MARITAL[b.marital] ?? null : null,
    social: clean(b.social),
  };
}
