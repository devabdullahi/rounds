// Vital ranges in condition profiles are written for an adult; planCase shifts them for a child's
// age (casegen.ts forPatient). A model writing a newborn condition sometimes gives the newborn's own
// numbers ("rr": 80–120), and the shift then lands them a second time: a newborn with a heart rate
// of 250 and a systolic of 20, or, for a condition spanning infants and adults, an 80-year-old
// breathing 90 times a minute. This plans each range at the youngest and oldest typical age and
// rejects any that can't happen at that age. Pure, so it's unit-tested.
import { forPatient } from "./casegen.ts";

// deno-lint-ignore no-explicit-any
type Json = any;

/** Outer limits a planned vital may reach, by age: past them the value isn't a sick patient but a
 *  wrong number. Plausibility bounds for catching unit mistakes, not clinical thresholds. Low blood
 *  pressures aren't bounded: an adult's shock range shifted for a baby is low but can happen. */
const BOUNDS: { max_age: number; limits: Record<string, [number, number]> }[] = [
  { max_age: 1, limits: { hr: [50, 230], rr: [10, 100], sbp: [0, 130], dbp: [0, 90] } },
  { max_age: 18, limits: { hr: [25, 240], rr: [8, 80], sbp: [0, 230], dbp: [0, 140] } },
  { max_age: Infinity, limits: { hr: [25, 250], rr: [4, 60], sbp: [0, 260], dbp: [0, 160] } },
];

const boundsAt = (age: number) => BOUNDS.find((b) => age < b.max_age)!.limits;

/** Errors for vital ranges that plan an impossible value at either end of the typical age range,
 *  and for a diastolic range that reaches the systolic one. */
export function vitalErrors(profile: Json): string[] {
  const vitals = profile?.vitals ?? {};
  const age = profile?.patient?.age ?? {};
  const ages = [...new Set([age.typical_min, age.typical_max].filter((a): a is number => typeof a === "number"))];
  const errors: string[] = [];
  for (const [vital, bySeverity] of Object.entries<Json>(vitals)) {
    for (const [severity, r] of Object.entries<Json>(bySeverity ?? {})) {
      if (typeof r?.min !== "number" || typeof r?.max !== "number") continue;
      for (const a of ages) {
        const limits = boundsAt(a)[vital];
        if (!limits) continue;
        const patient = { sex: "M" as const, age: a, pregnant: false };
        const [lo, hi] = [forPatient(vital, Math.round(r.min), patient), forPatient(vital, Math.round(r.max), patient)];
        if (lo < limits[0] || hi > limits[1]) {
          errors.push(`vitals.${vital}.${severity}: ${r.min}–${r.max} plans ${lo}–${hi} at age ${a}, outside ${limits[0]}–${limits[1]}; write vital ranges for an adult (code adjusts them for a child's age)`);
          break;
        }
      }
    }
  }
  for (const severity of Object.keys(vitals.sbp ?? {})) {
    const s = vitals.sbp[severity], d = vitals.dbp?.[severity];
    if (d && s && (d.min >= s.min || d.max >= s.max)) errors.push(`vitals.dbp.${severity}: reaches the systolic range`);
  }
  return errors;
}
