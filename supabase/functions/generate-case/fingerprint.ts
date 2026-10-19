// What makes two patients the same patient, so a student is never given one twice: the condition, how
// sick they are, sex, age to the decade and the symptoms they have. Name and wording don't count; a
// different name on the same story is the same patient. Stored only as a hash
// (private.patient_fingerprints). Pure, so the rule is unit-tested.

/** Plans tried for a fresh fingerprint before accepting a repeat of an earlier patient's shape; with
 *  ten symptoms drawn by frequency, a handful of tries almost always finds a new one. */
export const PLAN_TRIES = 8;

/** The parts of a plan that decide whether two patients are the same. */
export type Shape = { slug: string; severity: string; sex: string; age: number; symptomsPresent: readonly string[] };

/** The fields that decide whether two patients are the same, in a fixed order. */
export function fingerprintParts(plan: Shape): string {
  const symptoms = [...plan.symptomsPresent].map((s) => s.trim().toLowerCase()).sort();
  return [plan.slug, plan.severity, plan.sex, Math.floor(plan.age / 10), ...symptoms].join("|");
}

/** The patient's fingerprint: a SHA-256 hex hash of its parts. */
export async function fingerprint(plan: Shape): Promise<string> {
  const bytes = new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(fingerprintParts(plan))));
  return [...bytes].map((b) => b.toString(16).padStart(2, "0")).join("");
}
