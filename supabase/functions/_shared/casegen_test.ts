import { assert, assertEquals } from "jsr:@std/assert@1";
import { leaks, leakTerms, planCase, type Profile } from "./casegen.ts";
import { seeded } from "./labs.ts";

const dir = new URL("../../../knowledge-base/profiles/", import.meta.url);
const profiles: Profile[] = [];
for await (const entry of Deno.readDir(dir)) {
  if (entry.name.endsWith(".json")) profiles.push(JSON.parse(await Deno.readTextFile(new URL(entry.name, dir))));
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
