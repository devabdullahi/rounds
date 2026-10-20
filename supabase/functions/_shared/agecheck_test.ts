import { assertEquals } from "jsr:@std/assert@1";
import { agesUsable, ageUnitErrors } from "./agecheck.ts";

const profile = (age: Record<string, unknown>, slug = "x") => ({ slug, triage: { name: slug }, patient: { age } });

Deno.test("an age range in years with a peak in weeks or months is caught", () => {
  assertEquals(ageUnitErrors(profile({ typical_min: 2, typical_max: 8, peak: "3–6 weeks" })).length, 1);
  assertEquals(ageUnitErrors(profile({ typical_min: 6, typical_max: 60, peak: "12–18 months" })).length, 1);
});

Deno.test("real infant ranges and ordinary ranges pass", () => {
  assertEquals(ageUnitErrors(profile({ typical_min: 0, typical_max: 0.2, peak: "3–6 weeks" })), []);
  assertEquals(ageUnitErrors(profile({ typical_min: 5, typical_max: 45, peak: "childhood onset" })), []);
  assertEquals(ageUnitErrors(profile({ typical_min: 1, typical_max: 5, peak: "6 months to 5 years" })), []);
});

Deno.test("a stored infant profile with an age over 2 isn't used", () => {
  assertEquals(agesUsable(profile({ typical_min: 0, typical_max: 12, peak: "first months" }, "reflux-in-infants")), false);
  assertEquals(agesUsable(profile({ typical_min: 20, typical_max: 60, peak: "middle age" }, "gout")), true);
});
