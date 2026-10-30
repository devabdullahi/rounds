import { assertEquals } from "jsr:@std/assert@1";
import { vitalErrors } from "./vitalcheck.ts";

const profile = (typical_min: number, typical_max: number, vitals: Record<string, unknown>) =>
  ({ patient: { age: { typical_min, typical_max } }, vitals });

Deno.test("a newborn profile written in a newborn's own numbers is caught", () => {
  // Shifted for a newborn a second time, 160–200 plans a heart rate of 210–250.
  const errors = vitalErrors(profile(0, 0, { hr: { severe: { min: 160, max: 200 } }, rr: { severe: { min: 80, max: 120 } } }));
  assertEquals(errors.map((e) => e.split(":")[0]), ["vitals.hr.severe", "vitals.rr.severe"]);
});

Deno.test("a condition spanning babies and adults can't plan a baby's breathing rate for an adult", () => {
  const errors = vitalErrors(profile(0, 90, { rr: { critical: { min: 70, max: 100 } } }));
  assertEquals(errors.length, 1);
  assertEquals(errors[0].includes("at age"), true);
});

Deno.test("adult-referenced ranges pass at every typical age", () => {
  const cases = [
    profile(0, 1, { hr: { severe: { min: 110, max: 140 } }, rr: { severe: { min: 24, max: 34 } } }),
    profile(50, 80, { hr: { critical: { min: 110, max: 150 } }, sbp: { critical: { min: 50, max: 90 } }, dbp: { critical: { min: 30, max: 60 } } }),
    profile(55, 90, { hr: { critical: { min: 150, max: 220 } } }),
    // An adult's shock pressures shifted for a toddler are low, but they can happen.
    profile(1, 90, { sbp: { critical: { min: 50, max: 90 } }, dbp: { critical: { min: 30, max: 60 } } }),
  ];
  for (const p of cases) assertEquals(vitalErrors(p), []);
});

Deno.test("a diastolic range reaching the systolic one is caught", () => {
  const errors = vitalErrors(profile(30, 60, { sbp: { severe: { min: 90, max: 110 } }, dbp: { severe: { min: 60, max: 115 } } }));
  assertEquals(errors, ["vitals.dbp.severe: reaches the systolic range"]);
});

Deno.test("a profile without vitals or ages has nothing to check", () => {
  assertEquals(vitalErrors({}), []);
  assertEquals(vitalErrors(profile(20, 40, {})), []);
});
