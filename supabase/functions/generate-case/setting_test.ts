import { assertEquals, assertStrictEquals } from "jsr:@std/assert@1";
import { forSetting } from "./setting.ts";
import type { Profile } from "../_shared/casegen.ts";

const profile = (settings: string[], tiers: string[]) => ({
  slug: "pneumonia",
  triage: { name: "Pneumonia", primary_clerkship: "internalMedicine", organ_systems: ["respiratory"], settings },
  course: { severity: Object.fromEntries(tiers.map((t) => [t, `${t} course`])) },
}) as unknown as Profile;

Deno.test("a clinic pick keeps only clinic settings and drops the critical tier", () => {
  const fit = forSetting(profile(["inpatient", "clinic", "emergency"], ["mild", "moderate", "severe", "critical"]), "clinic");
  assertEquals(fit.triage.settings, ["clinic"]);
  assertEquals(Object.keys(fit.course.severity), ["mild", "moderate", "severe"]);
});

Deno.test("a hospital pick keeps the hospital settings, in catalog order, and every tier", () => {
  const fit = forSetting(profile(["clinic", "emergency", "icu"], ["moderate", "critical"]), "hospital");
  assertEquals(fit.triage.settings, ["emergency", "icu"]);
  assertEquals(Object.keys(fit.course.severity), ["moderate", "critical"]);
});

Deno.test("a condition with only a critical tier keeps it, even in a clinic", () => {
  assertEquals(Object.keys(forSetting(profile(["clinic"], ["critical"]), "clinic").course.severity), ["critical"]);
});

Deno.test("no pick, or no matching setting, leaves the profile as it is", () => {
  const p = profile(["inpatient"], ["severe"]);
  assertStrictEquals(forSetting(p, ""), p);
  assertStrictEquals(forSetting(p, "clinic"), p);
});
