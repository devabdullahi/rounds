import { assertEquals, assertNotEquals } from "jsr:@std/assert@1";
import { fingerprint, fingerprintParts, type Shape } from "./fingerprint.ts";

const plan: Shape = { slug: "asthma", severity: "moderate", sex: "F", age: 16, symptomsPresent: ["Wheezing", "Night cough"] };

Deno.test("the same story is the same patient, whatever the order of symptoms or exact age", async () => {
  const same = { ...plan, age: 19, symptomsPresent: ["night cough", "Wheezing"] };
  assertEquals(fingerprintParts(same), fingerprintParts(plan));
  assertEquals(await fingerprint(same), await fingerprint(plan));
  assertEquals((await fingerprint(plan)).length, 64);
});

Deno.test("a different severity, sex, decade or symptom set is a different patient", async () => {
  const base = await fingerprint(plan);
  for (const change of [{ severity: "severe" }, { sex: "M" }, { age: 21 }, { symptomsPresent: ["Wheezing"] }, { slug: "copd" }] as Partial<Shape>[]) {
    assertNotEquals(await fingerprint({ ...plan, ...change }), base, JSON.stringify(change));
  }
});
