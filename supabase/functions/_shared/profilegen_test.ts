import { assert, assertEquals, assertThrows } from "jsr:@std/assert@1";
import {
  baseTerm, dropEmptyOptional, repair, ruleErrors, schemaErrors, STAGES, stageOutput, stagePrompt, termSummary, validate,
} from "./profilegen.ts";
import { parseFocus } from "./focus.ts";

// deno-lint-ignore no-explicit-any
type Json = any;

const dir = new URL("../../../knowledge-base/profiles/", import.meta.url);
const passed: Json[] = [];
for await (const entry of Deno.readDir(dir)) {
  if (!entry.name.endsWith(".json")) continue;
  const profile = JSON.parse(await Deno.readTextFile(new URL(entry.name, dir)));
  if (profile.generation.validation.status === "passed") passed.push(profile);
}

Deno.test("the port agrees with the Python validator on every passed profile", () => {
  assert(passed.length > 0);
  for (const profile of passed) assertEquals(validate(profile), [], profile.slug);
});

Deno.test("schema: wrong types, enums and unexpected keys are reported", () => {
  const schema = { type: "object", required: ["a"], additionalProperties: false, properties: { a: { enum: ["x", "y"] } } };
  assertEquals(schemaErrors({ a: "x" }, schema), []);
  assertEquals(schemaErrors({ a: "z" }, schema), ['$.a: "z" not in ["x","y"]']);
  assertEquals(schemaErrors({ b: 1 }, schema), ["$: missing a", "$: unexpected key b"]);
  assertEquals(schemaErrors([], schema), ["$: expected object"]);
});

Deno.test("repair: model-made test ids, unknown labs and duplicate workup entries", () => {
  const profile: Json = {
    labs: [{ test_id: "made_up_marker", ranges: {} }],
    workup: {
      initial: [{ test: "fungal_culture" }],
      not_indicated: [{ test: "CT abdomen", why: "radiation" }],
      confirmatory: [{ test: "CT abdomen", why: "if the diagnosis is unclear" }],
    },
  };
  const notes = repair(profile);
  assertEquals(profile.labs, []);
  assertEquals(profile.workup.initial[0].test, "Fungal culture");
  assertEquals(profile.workup.confirmatory[0].only_if, "if the diagnosis is unclear");
  assertEquals(notes.length, 3);
});

Deno.test("rules: Celsius temperatures and inverted ranges block", () => {
  const errors = ruleErrors({ vitals: { temp: { mild: { min: 37.5, max: 38 } }, hr: { severe: { min: 130, max: 110 } } } });
  assertEquals(errors, ["vitals.temp.mild: must be °F", "vitals.hr.severe: min above max"]);
});

Deno.test("stage prompt fills every slot and appends retry feedback", () => {
  for (let stage = 0; stage < STAGES.length; stage++) {
    const text = stagePrompt(stage, "Testitis", "Background.", { slug: "x", patient: {} }, []);
    for (const slot of ["{name}", "{instructions}", "{keys}", "{schema}", "{example}", "{background}", "{extra}", "{previous}"]) {
      assert(!text.includes(slot), `${STAGES[stage].name} left ${slot}`);
    }
  }
  assert(stagePrompt(0, "Testitis", "", {}, ["fix this"]).endsWith("- fix this"));
});

Deno.test("stage output keeps only the stage's sections and lists missing required ones", () => {
  const { output, missing } = stageOutput(0, { patient: {}, extra: 1 });
  assertEquals(output, { patient: {} });
  assertEquals(missing, ["missing section presentation"]);
});

Deno.test("empty optional sections are dropped", () => {
  const profile: Json = { ecg: { findings: [] }, cancer: {}, exam: {} };
  dropEmptyOptional(profile);
  assertEquals(Object.keys(profile), ["exam"]);
});

Deno.test("negated terms check the finding inside", () => {
  assertEquals(baseTerm("No rebound tenderness"), "rebound tenderness");
  assertEquals(baseTerm("Crackles absent"), "Crackles");
  assertEquals(baseTerm("Fever"), "Fever");
});

Deno.test("term summary fails a section only above the unverified share", () => {
  const items = (verified: number, total: number) =>
    Array.from({ length: total }, (_, i) => ({ term: `t${i}`, snomed_verified: i < verified }));
  assertEquals(termSummary({ exam: { findings: items(8, 10) } }).errors, []);
  assertEquals(termSummary({ exam: { findings: items(5, 10) } }).errors, ["exam: 5 of 10 terms aren't SNOMED CT findings"]);
});

Deno.test("focus parsing accepts the app's stored values only", () => {
  assertEquals(parseFocus("").kind, "");
  assertEquals(parseFocus("rotation:obgyn"), { kind: "rotation", value: "obgyn", stored: "rotation:obgyn" });
  assertThrows(() => parseFocus("rotation:ob gyn"));
  assertThrows(() => parseFocus("organ:renal"));
});
