import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { factReply, gestationalWeeks, normalReport, positiveReport, studyReport, templateVoice } from "./template.ts";
import { buildSkeleton, describing, diagnosisWords, plain } from "./skeleton.ts";
import { assemble, checkWriting } from "./writer.ts";
import type { CasePlan, Profile } from "../_shared/casegen.ts";

const profile = {
  slug: "x", triage: { name: "Cholecystitis", primary_clerkship: "surgery", organ_systems: [], settings: ["emergency"] },
  patient: { age: { typical_min: 20, typical_max: 40 }, sex: "any", risk_factors: [{ text: "Obesity" }], family_history: [] },
  presentation: { chief_complaints: [{ text: "My belly hurts on the right", term: "Right upper quadrant pain" }], ros: [],
    hpi: { onset: "Sudden, after a fatty meal", duration: "6 hours", location: "Right upper abdomen", associated_symptoms: [{ text: "Nausea", frequency: "common" }], pertinent_negatives: ["Fever"] } },
  exam: { general: {}, findings: [] },
  differential: [], workup: {}, course: { severity: {} }, teaching: { key_questions: [], accepted_names: [], reasoning_points: [] },
} as unknown as Profile;
const plan = {
  slug: "x", condition: "Cholecystitis", severity: "moderate", severityText: "", age: 34, sex: "F", pregnant: false,
  symptomsPresent: ["Nausea"], symptomsAbsent: ["Fever"],
  exam: [{ region: "abdomen", maneuver: "Palpate the RUQ", finding: "RUQ tenderness", present: true, importance: "essential" },
    { region: "skin", maneuver: "Inspect the skin", finding: "Jaundice", present: false, importance: "optional" },
    { region: "abdomen", maneuver: "Murphy sign", finding: "Positive Murphy sign", present: true, importance: "essential" }],
  vitals: {}, tests: [
    { id: "us", name: "Right upper quadrant ultrasound", kind: "study", role: "indicated", findings: ["Gallbladder wall thickening", "pericholecystic fluid"] },
    { id: "cx", name: "Blood culture", kind: "study", role: "neutral", findings: [] },
  ],
  psychology: false, dermatology: false,
} as unknown as CasePlan;

Deno.test("fact content becomes a plain first-person line", () => {
  for (const [content, reply] of [
    ["Has nausea.", "Yes, nausea."],
    ["Also has bloating; belching.", "Also bloating; belching."],
    ["Denies: Fever.", "No fever."],
    ["Denies: Fever; Jaundice.", "No fever, no jaundice."],
    ["Takes lisinopril, metformin.", "I take lisinopril, metformin."],
    ["Takes no regular medications.", "I don't take any regular medications."],
    ["No known drug allergies.", "No allergies that I know of."],
    ["Allergic to penicillin.", "I'm allergic to penicillin."],
    ["onset: Sudden, after a fatty meal. duration: 6 hours", "Sudden, after a fatty meal. 6 hours."],
    ["obesity; smoking", "Obesity; smoking."],
  ]) {
    assertEquals(factReply(content), reply, content);
  }
});

Deno.test("a study with planned findings reports them; one without gets its kind's normal wording", () => {
  const voice = templateVoice(profile, plan, buildSkeleton(profile, plan, null, () => 0.5), null, () => 0.5);
  assertEquals(voice.studies, [
    { test_id: "us", result: "Gallbladder wall thickening. Pericholecystic fluid.", abnormal: true },
    { test_id: "cx", result: "Negative.", abnormal: false },
  ]);
  assertEquals(normalReport("12-lead ECG", false), "Normal sinus rhythm. No acute ST-segment or T-wave changes.");
  assertEquals(normalReport("CT abdomen", false), "No acute abnormality.");
  assertEquals(normalReport("PHQ-9", true), "Score within the normal range.");
});

Deno.test("an absent exam finding reads as its normal", () => {
  const voice = templateVoice(profile, plan, buildSkeleton(profile, plan, null, () => 0.5), null, () => 0.5);
  assertEquals(voice.normals, { x2: "No jaundice." });
});

Deno.test("the door note gives age, sex, complaint and duration; the case passes the writing checks", () => {
  const skeleton = buildSkeleton(profile, plan, null, () => 0.5);
  const voice = templateVoice(profile, plan, skeleton, null, () => 0.5);
  assertEquals(voice.patient.complaint, "34-year-old woman with right upper quadrant pain for 6 hours.");
  assertEquals(voice.patient.quote, "My belly hurts on the right");
  assertEquals(voice.patient.setting, "Walk-in, emergency department");
  assert(voice.suggested.length >= 3 && voice.suggested.every((s) => skeleton.facts.some((f) => f.id === s.fact)));
  const writing = assemble(skeleton, voice);
  assertEquals(checkWriting(writing, plan, ["cholecystitis"]), []);
});

Deno.test("a pregnant patient's weeks come from the profile when it gives them", () => {
  assertEquals(gestationalWeeks({ presentation: { hpi: { onset: "usually at 6–8 weeks of gestation" } }, course: {} } as unknown as Profile), 7);
  assertEquals(gestationalWeeks({ presentation: { hpi: { onset: "after 20 weeks" } }, course: {} } as unknown as Profile), 20);
  assertEquals(gestationalWeeks({ presentation: { hpi: {} }, course: {} } as unknown as Profile), null);
  const pregnant = { ...plan, pregnant: true } as CasePlan;
  const skeleton = buildSkeleton(profile, pregnant, null, () => 0.5);
  const voice = templateVoice(profile, pregnant, skeleton, null, () => 0.5);
  const fact = skeleton.facts.find((f) => f.label === "Pregnancy")!;
  assertEquals(voice.facts[fact.id].reply, "Yes, I'm pregnant.");
  assertStringIncludes(voice.patient.complaint, "pregnant");
});

Deno.test("the diagnosis's distinctive words are banned, unless the patient's history uses them", () => {
  const words = diagnosisWords({ ...profile, teaching: { ...profile.teaching, accepted_names: ["Acute cholecystitis"] } } as Profile);
  assert(words.includes("cholecystitis") && !words.includes("acute"));
  const aud = { ...profile, triage: { ...profile.triage, name: "Alcohol use disorder" },
    patient: { ...profile.patient, risk_factors: [{ text: "Heavy alcohol use in family" }] } } as unknown as Profile;
  assert(!diagnosisWords(aud).includes("alcohol"));
});

Deno.test("presentation details keep what describes the patient, not what teaches or names the diagnosis", () => {
  assertEquals(describing("Sudden, within hours. Pain beyond 6 hours suggests cholecystitis rather than biliary colic.", ["cholecystitis"]), "Sudden, within hours");
  assertEquals(describing("Not applicable", []), "");
  assertEquals(describing("Right upper quadrant (RUQ); to the right shoulder.", []), "Right upper quadrant; to the right shoulder");
});

Deno.test("study reports leave out diagnosis names and a normal line next to abnormal ones", () => {
  assertEquals(studyReport(["Normal.", "Right lower lobe infiltrate"], []), ["Right lower lobe infiltrate."]);
  assertEquals(studyReport(["Findings consistent with acute cholecystitis", "Gallstones"], ["cholecystitis"]), ["Gallstones."]);
  assertEquals(studyReport(["Usually normal"], []), []);
});

Deno.test("an eponym keeps its capital in a normal exam line", () => {
  const p = { ...plan, exam: [{ region: "abdomen", maneuver: "Deep breath under the costal margin", finding: "Murphy sign", present: false, importance: "key" },
    { region: "abdomen", maneuver: "Palpate", finding: "Rigid abdomen", present: false, importance: "key" },
    { region: "abdomen", maneuver: "Palpate", finding: "Guarding", present: false, importance: "key" }] } as unknown as CasePlan;
  const voice = templateVoice(profile, p, buildSkeleton(profile, p, null, () => 0.5), null, () => 0.5);
  assertEquals(Object.values(voice.normals), ["No Murphy sign.", "No rigid abdomen.", "No guarding."]);
});

Deno.test("short items lose the reasoning written next to them, and are dropped if they still name the diagnosis", () => {
  assertEquals(plain("No access to excessive free water (would argue against hypernatremia).", ["hypernatremia"]), "No access to excessive free water");
  assertEquals(plain("No tender preauricular lymph node, more typical of viral conjunctivitis.", ["conjunctivitis"]), "No tender preauricular lymph node");
  assertEquals(plain("Urinary incontinence in a mother or sister.", ["urinary incontinence"]), "");
  assertEquals(plain("Wheezing on expiration", []), "Wheezing on expiration");
});

Deno.test("a positive culture with no writer reads positive, never negative", () => {
  assertEquals(positiveReport("Stool culture"), "Growth of a pathogenic organism. Identification and susceptibilities to follow.");
  assertEquals(positiveReport("Rapid influenza test"), "Detected.");
});
