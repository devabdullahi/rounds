import { assert, assertEquals } from "jsr:@std/assert@1";
import { acceptedNames, caseBudget, isPregnant, leaks, leakTerms, MIN_BUDGET, planCase, type Profile } from "./casegen.ts";
import { seeded } from "./labs.ts";

const dir = new URL("../../../knowledge-base/profiles/", import.meta.url);
const profiles: Profile[] = [];
for await (const entry of Deno.readDir(dir)) {
  if (!entry.name.endsWith(".json")) continue;
  const profile = JSON.parse(await Deno.readTextFile(new URL(entry.name, dir)));
  // Only validated profiles reach generate-case, so only those are planned here.
  if (profile.generation.validation.status === "passed") profiles.push(profile);
}

Deno.test("every generated profile plans a complete case", () => {
  assert(profiles.length > 0);
  for (const profile of profiles) {
    for (let seed = 0; seed < 20; seed++) {
      const plan = planCase(profile, seeded(seed));
      assert(plan.age >= profile.patient.age.typical_min && plan.age <= profile.patient.age.typical_max, profile.slug);
      for (const id of ["temp", "hr", "rr", "sbp", "dbp", "spo2"]) assert(typeof plan.vitals[id] === "number", `${profile.slug} ${id}`);
      assert(plan.tests.some((t) => t.id === "cbc") && plan.tests.some((t) => t.id === "bmp"), profile.slug);
      for (const t of plan.tests.filter((t) => t.kind === "lab")) assert(t.result && t.result.length > 0, `${profile.slug} ${t.id}`);
      assertEquals(new Set(plan.tests.map((t) => t.id)).size, plan.tests.length, `${profile.slug} duplicate test ids`);
    }
  }
});

Deno.test("same seed, same case", () => {
  assertEquals(planCase(profiles[0], seeded(7)), planCase(profiles[0], seeded(7)));
});

Deno.test("leak check finds diagnosis names case-insensitively", () => {
  const terms = leakTerms(profiles[0]);
  assert(terms.length > 0);
  assertEquals(leaks(`I think I have ${terms[0].toUpperCase()}`, terms).length > 0, true);
  assertEquals(leaks("My chest hurts when I cough.", terms.filter((t) => !"my chest hurts when i cough.".includes(t))), []);
});

Deno.test("pregnancy comes from pregnancy-only conditions, for women of childbearing age", () => {
  const profile = { ...profiles[0], triage: { ...profiles[0].triage, name: "Ectopic Pregnancy" } };
  assert(isPregnant(profile, "F", 28));
  assert(!isPregnant(profile, "M", 28));
  assert(!isPregnant(profile, "F", 9));
  assert(!isPregnant(profiles.find((p) => p.slug === "acute-bronchitis") ?? profiles[0], "F", 28));
});

Deno.test("a child's vitals are judged against child norms", () => {
  for (const profile of profiles.filter((p) => p.patient.age.typical_max < 12)) {
    const plan = planCase(profile, seeded(4));
    assert((plan.vitals.hr as number) > 60, `${profile.slug} child HR ${plan.vitals.hr}`);
  }
});

Deno.test("a psychology case offers questionnaires instead of blood work", () => {
  const base = profiles.find((p) => p.slug === "major-depressive-disorder") ?? profiles[0];
  const scored = structuredClone(base);
  scored.labs = [{ test_id: "phq9", ranges: { mild: { min: 5, max: 9 }, moderate: { min: 10, max: 14 }, severe: { min: 15, max: 19 }, critical: { min: 20, max: 27 } } }];
  const plan = planCase(scored, seeded(7), { psychology: true });
  assert(plan.psychology);
  assertEquals(plan.tests.map((t) => t.id).sort(), ["audit", "gad7", "pcl5", "phq9"]);
  const phq = plan.tests.find((t) => t.id === "phq9")!;
  assertEquals(phq.role, "indicated");
  assert(phq.abnormal, "a depressed patient's PHQ-9 is out of the normal range");
});

Deno.test("a psychology case keeps the usual tests when its profile scores no questionnaire", () => {
  const plain = structuredClone(profiles[0]);
  plain.labs = (plain.labs ?? []).filter((l) => !["phq9", "gad7", "audit", "pcl5"].includes(l.test_id));
  const plan = planCase(plain, seeded(7), { psychology: true });
  assert(plan.tests.some((t) => t.id === "cbc"));
});

Deno.test("a dermatology plan keeps the usual tests and is flagged for a skin exam", () => {
  const plan = planCase(profiles[0], seeded(3), { dermatology: true });
  assert(plan.dermatology && !plan.psychology);
  assert(plan.tests.some((t) => t.id === "cbc"));
});

Deno.test("a case's budget is never under $1,000, and covers 1.5x its indicated tests", () => {
  assertEquals(caseBudget(0), MIN_BUDGET);
  assertEquals(caseBudget(400), 1000);
  assertEquals(caseBudget(1200), 1800);
  assertEquals(caseBudget(1010), 1550); // 1515 rounds up to the next $50
});

Deno.test("UMLS synonyms join the accepted names, without terms that match ordinary sentences", () => {
  const names = acceptedNames(["Heart attack"], ["MI - myocardial infarction", "Cardiac infarction", "Heart attack", "AN - Acoustic neuroma", "OR", "Myocardial infarction NOS"]);
  assertEquals(names, ["Heart attack", "MI", "myocardial infarction", "Cardiac infarction", "Acoustic neuroma"]);
});
