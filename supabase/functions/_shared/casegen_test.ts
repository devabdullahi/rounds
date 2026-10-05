import { assert, assertEquals } from "jsr:@std/assert@1";
import { isPregnant, leaks, leakTerms, planCase, type Profile } from "./casegen.ts";
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
