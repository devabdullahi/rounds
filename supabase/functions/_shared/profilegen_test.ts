import { assert, assertEquals, assertThrows } from "jsr:@std/assert@1";
import {
  autoFix,
  ageErrors, baseTerm, directionErrors, dropEmptyOptional, duplicateErrors, emptyStringErrors, repair, ruleErrors,
  schemaErrors, snomedIdErrors, STAGES, stageOutput, stagePrompt, termSummary, workupKey,
} from "./profilegen.ts";
import { parseFocus } from "./focus.ts";

// deno-lint-ignore no-explicit-any
type Json = any;

const dir = new URL("../../../knowledge-base/profiles/", import.meta.url);
const profiles: Json[] = [];
for await (const entry of Deno.readDir(dir)) {
  if (entry.name.endsWith(".json")) profiles.push(JSON.parse(await Deno.readTextFile(new URL(entry.name, dir))));
}

Deno.test("the port agrees with the Python checks on every profile: rules, repairs, and rules after repair", async () => {
  const run = await new Deno.Command("python3", {
    args: [new URL("../../../tools/kb-generate/checks.py", import.meta.url).pathname], stdout: "piped",
  }).output();
  assert(run.success, "python3 checks.py failed");
  const python: Record<string, { rules: string[]; repairs: string[]; after_repair: string[] }> =
    JSON.parse(new TextDecoder().decode(run.stdout));
  assert(profiles.length > 0);
  for (const profile of profiles) {
    const expected = python[profile.slug];
    assertEquals(ruleErrors(profile), expected.rules, profile.slug);
    const repaired = structuredClone(profile);
    assertEquals(repair(repaired), expected.repairs, profile.slug);
    assertEquals(ruleErrors(repaired), expected.after_repair, profile.slug);
  }
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
  assertEquals(profile.workup.confirmatory, [{ test: "CT abdomen", why: "if the diagnosis is unclear" }]);
  assertEquals(profile.workup.not_indicated, []);
  assertEquals(notes.length, 3);
  assert(notes[2].includes("contradicted itself"));
  assertEquals(repair(profile), [], "a second pass has nothing left to fix or report");
});

Deno.test("repair: a conditional not_indicated entry becomes a conditional order", () => {
  const profile: Json = {
    workup: { initial: [{ test: "Chest X-ray" }], not_indicated: [{ test: "chest x ray", only_if: "crackles on exam" }] },
  };
  const notes = repair(profile);
  assertEquals(profile.workup, { initial: [{ test: "Chest X-ray", only_if: "crackles on exam" }], not_indicated: [] });
  assertEquals(notes, ["workup: 'Chest X-ray' was in initial, not_indicated; kept initial as a conditional order (only if crackles on exam)"]);
  assertEquals(ruleErrors(profile), []);
});

Deno.test("rules: a test in two workup groups blocks, conditional or not", () => {
  const profile = { workup: { initial: [{ test: "CT abdomen", only_if: "x" }], not_indicated: [{ test: "ct abdomen" }] } };
  assertEquals(ruleErrors(profile), ["workup: 'ct abdomen' appears in initial, not_indicated; list it once (use only_if for a conditional order)"]);
  for (const name of ["Chest X-ray", "chest x ray", "CHEST  X-RAY "]) assertEquals(workupKey(name), "chest x ray");
});

const AGE_CASES: [string, Json, number][] = [
  ["appendicitis", { typical_min: 10, typical_max: 30, possible_max: 90 }, 0],
  ["appendicitis", { typical_min: 10, typical_max: 30, possible_max: 150 }, 1],
  ["neonatal-sepsis", { typical_min: 0, typical_max: 90, possible_max: 90 }, 1],
  ["neonatal-sepsis", { typical_min: 0, typical_max: 0, possible_max: 1 }, 0],
  ["reflux-in-infants", { typical_min: 0, typical_max: 12 }, 1],
  ["transient-tachypnea-of-the-newborn", { typical_min: 0, typical_max: 0, possible_max: 400 }, 1],
];
for (const [slug, age, count] of AGE_CASES) {
  Deno.test(`rules: ages in years, ${slug} ${JSON.stringify(age)}`, () => {
    assertEquals(ageErrors({ slug, patient: { age } }).length, count);
  });
}

Deno.test("rules: duplicates, empty strings and SNOMED ids, outside the pipeline's bookkeeping", () => {
  const profile = {
    patient: { comorbidities: ["Obesity", "obesity "], risk_factors: [{ text: "Smoking", strength: "strong" }, { text: "smoking", strength: "weak" }] },
    labs: [{ test_id: "wbc" }, { test_id: "wbc" }],
    exam: { findings: [{ id: "rebound" }, { id: "guarding" }, { id: "rebound", snomed_id: "123" }] },
    teaching: { pearls: ["ok", ""] },
    generation: { validation: { review_issues: ["same", "same", ""] } },
  };
  assertEquals(duplicateErrors(profile), [
    "$.patient.comorbidities: duplicate 'obesity '",
    "$.patient.risk_factors: duplicate text 'smoking'",
    "$.labs: duplicate test_id 'wbc'",
    "$.exam.findings: duplicate id 'rebound'",
  ]);
  assertEquals(emptyStringErrors(profile), ["$.teaching.pearls[1]: empty string"]);
  assertEquals(snomedIdErrors(profile), ["$.exam.findings[2].snomed_id: SNOMED CT ids are licensed content; keep only snomed_verified"]);
});

const ranges = (...r: [string, number, number][]) => Object.fromEntries(r.map(([s, min, max]) => [s, { min, max }]));
const DIRECTION_CASES: [string, string, Json, string[]][] = [
  ["pancreatitis", "lipase", ranges(["mild", 180, 420], ["critical", 1500, 4000]), []],
  ["pancreatitis", "lipase", ranges(["mild", 800, 1200], ["severe", 300, 500]), ["labs lipase: should rise with severity, but severe is lower than mild"]],
  ["pancreatitis", "ca", ranges(["moderate", 10.3, 11.0], ["severe", 7.0, 8.0]), ["labs ca.moderate: should be normal or low, not high"]],
  ["pancreatitis", "ca", ranges(["severe", 7.0, 8.0]), []],
  ["heart-attack", "hs_tnt", ranges(["mild", 5, 10], ["critical", 10, 20]), ["labs hs_tnt.critical: should be above normal at the worst listed severity"]],
  ["diabetes-type-1", "k", ranges(["mild", 3.3, 3.5], ["critical", 1.5, 2.0]), ["labs k.critical: should be normal or high, not low"]],
  ["diabetes-type-1", "hco3", ranges(["mild", 20, 22], ["critical", 4, 8]), []],
  ["diabetes-type-1", "hco3", ranges(["mild", 20, 22], ["critical", 24, 26]), [
    "labs hco3: should fall with severity, but critical is higher than mild",
    "labs hco3.critical: should be below normal at the worst listed severity",
  ]],
  ["appendicitis", "ca", ranges(["mild", 12, 13]), []],
];
for (const [slug, test, r, expected] of DIRECTION_CASES) {
  Deno.test(`rules: lab direction, ${slug} ${test} ${JSON.stringify(r)}`, () => {
    assertEquals(directionErrors({ slug, labs: [{ test_id: test, ranges: r }] }), expected);
  });
}

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
  assertEquals(parseFocus("rotation:obgyn"), { kind: "rotation", value: "obgyn", setting: "", stored: "rotation:obgyn" });
  assertThrows(() => parseFocus("rotation:ob gyn"));
  assertThrows(() => parseFocus("organ:renal"));
});

Deno.test("autoFix: DKA potassium written low is set to normal, glucose reordered to rise", () => {
  const profile = {
    slug: "diabetic-ketoacidosis",
    labs: [
      { test_id: "k", ranges: { mild: { min: 4, max: 5 }, severe: { min: 2.5, max: 3.2 } } },
      { test_id: "glucose", ranges: { mild: { min: 500, max: 700 }, severe: { min: 250, max: 300 } } },
    ],
    vitals: { temp: { mild: { min: 37.8, max: 37 } } },
    workup: { initial: [{ test: "vitals" }, { test: "bmp" }] },
  };
  autoFix(profile);
  const [k, glucose] = profile.labs;
  assert(k.ranges.severe.min >= 3.5, "potassium no longer low");
  assert(glucose.ranges.severe.min > glucose.ranges.mild.min, "glucose rises with severity");
  assertEquals(profile.vitals.temp.mild, { min: 98.6, max: 100 });
  assertEquals(profile.workup.initial.map((r) => r.test), ["bmp"]);
});

Deno.test("autoFix drops keys the template doesn't define", () => {
  const profile = { slug: "x", imaging: [{ study: "Ultrasound", preferred_when_note: "extra" }] };
  autoFix(profile);
  assert(!("preferred_when_note" in profile.imaging[0]));
});
