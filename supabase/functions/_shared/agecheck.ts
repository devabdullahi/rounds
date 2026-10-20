// Ages in condition profiles are in years. A model writing an infant condition sometimes gives the
// ages in weeks or months ("typical_max": 8 with "peak": "3–6 weeks" for pyloric stenosis), and the
// planner then draws a six-year-old. The shared rule check only catches this for conditions named
// "infant" or "newborn"; this catches it from the peak's own units. Pure, so it's unit-tested.
import { ageErrors } from "./profilegen.ts";

// deno-lint-ignore no-explicit-any
type Json = any;

const SUB_YEAR = /\b(days?|weeks?|wks?|months?|mos?)\b/i;
const YEARS = /\b(years?|yrs?)\b/i;
/** The oldest a patient can be when the peak is counted in days, weeks or months. */
const MAX_SUB_YEAR_AGE = 2;

/** Errors when the age range is in years but the peak says the condition is one of babies. */
export function ageUnitErrors(profile: Json): string[] {
  const age = profile?.patient?.age ?? {};
  const peak = String(age.peak ?? "");
  const oldest = age.typical_max;
  if (!SUB_YEAR.test(peak) || YEARS.test(peak) || typeof oldest !== "number" || oldest <= MAX_SUB_YEAR_AGE) return [];
  return [`patient.age.typical_max: ${oldest}, but the peak ("${peak}") is in days, weeks or months; ages are in years (a 3-week-old is 0.06)`];
}

/** Whether a profile's ages can be planned from: the shared age rules and the units check. */
export function agesUsable(profile: Json): boolean {
  return ageErrors(profile).length === 0 && ageUnitErrors(profile).length === 0;
}
