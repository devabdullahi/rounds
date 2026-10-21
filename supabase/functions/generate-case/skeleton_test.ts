import { assert, assertEquals } from "jsr:@std/assert@1";
import { buildSkeleton, injuryEvent, medicationName, overlaps, screensFor, skeletonFacts, testMeta } from "./skeleton.ts";
import { assemble } from "./writer.ts";
import type { CasePlan, Profile } from "../_shared/casegen.ts";

const profile = {
  slug: "x", triage: { name: "X", primary_clerkship: "surgery", organ_systems: [], settings: ["ED"] },
  patient: { age: { typical_min: 20, typical_max: 40 }, sex: "any", risk_factors: [{ text: "Smoking" }], family_history: ["Father with ulcers"] },
  presentation: { chief_complaints: [{ text: "My belly hurts" }], ros: [],
    hpi: { onset: "Sudden, after a meal", location: "Right upper abdomen", associated_symptoms: [{ text: "Nausea" }], pertinent_negatives: ["Black or bloody stools", "Fever"] } },
  exam: { general: {}, findings: [] },
  differential: [{ name: "Upper GI bleed", must_not_miss: true, why_considered: "black stools or bloody vomit", trigger: "melena, black stools" }],
  workup: {}, course: { severity: {} }, teaching: { key_questions: [], accepted_names: [], reasoning_points: [] },
} as unknown as Profile;
const plan = {
  slug: "x", condition: "X", severity: "moderate", severityText: "", age: 30, sex: "M", pregnant: false,
  symptomsPresent: ["Nausea"], symptomsAbsent: ["Fever", "Jaundice"],
  exam: [{ id: "e1", region: "abdomen", maneuver: "Palpate abdomen", finding: "RUQ tenderness", present: true, importance: "essential" },
    { id: "e2", region: "skin", maneuver: "Inspect skin", finding: "Jaundice", present: false, importance: "optional" }],
  vitals: {}, tests: [{ id: "cbc", name: "Complete blood count", kind: "lab", role: "indicated" }, { id: "us", name: "Abdominal ultrasound", kind: "study", role: "indicated" }],
  psychology: false, dermatology: false,
} as unknown as CasePlan;

Deno.test("a pertinent negative screens for the must-not-miss it shares words with", () => {
  assertEquals(screensFor("Black or bloody stools", profile.differential), "Upper GI bleed");
  assertEquals(screensFor("Fever", profile.differential), null);
});

Deno.test("the skeleton holds the medicine: presentation, symptoms, denials, history, exam, prices", () => {
  const s = buildSkeleton(profile, plan, null, () => 0.5);
  const contents = s.facts.map((f) => f.content);
  assert(contents.some((c) => c.includes("Sudden, after a meal")));
  assert(contents.includes("Has nausea."));
  assert(contents.includes("Denies: Black or bloody stools."));
  assert(contents.some((c) => c.includes("Jaundice")), "other denied symptoms are listed");
  assertEquals(s.facts.find((f) => f.content === "Denies: Black or bloody stools.")?.screens_for, "Upper GI bleed");
  assertEquals(s.maneuvers.map((m) => m.finding), ["RUQ tenderness", null]);
  assertEquals(s.test_meta.map((m) => m.cost), [30, 300]);
});

Deno.test("anything the voice leaves out falls back to the skeleton's own wording", () => {
  const s = buildSkeleton(profile, plan, null, () => 0.5);
  const w = assemble(s, {
    patient: { name: "A B", quote: "q", demeanor: "d", setting: "s", complaint: "c" }, persona: { voice: "v", background: "b", fallback: "f" },
    facts: { f1: { label: "Onset", reply: "It hit me right after lunch." } }, normals: {}, studies: [],
    suggested: [{ text: "When did it start?", fact: "f1" }, { text: "?", fact: "nope" }],
  });
  assertEquals(w.facts[0].reply, "It hit me right after lunch.");
  assertEquals(w.facts[1].reply, s.facts[1].content);
  assertEquals(w.maneuvers[1].finding, "Normal.");
  assertEquals(w.suggested.length, 1);
  assertEquals(testMeta({ id: "ct", name: "CT abdomen", kind: "study", role: "indicated" } as never).cost, 700);
});

Deno.test("two wordings of one symptom overlap; different symptoms don't", () => {
  for (const [a, b, same] of [
    ["Itchy eyes", "Itchy, watery, red eyes", true],
    ["Fever", "No facial swelling or fever", true],
    ["Sneezing", "Sneezing fits", true],
    ["Chest pain", "Abdominal pain", false],
    ["Nausea", "Vomiting", false],
  ] as const) {
    assertEquals(overlaps(a, b), same, `${a} / ${b}`);
  }
});

Deno.test("medications read as name and strength", () => {
  assertEquals(medicationName("Hydrochlorothiazide 25 MG Oral Tablet"), "hydrochlorothiazide 25 mg");
  assertEquals(medicationName("insulin isophane, human 70 UNT/ML / insulin, regular, human 30 UNT/ML Injectable Suspension [Humulin]"), "insulin isophane, human 70 unt/ml");
  assertEquals(medicationName("Acetaminophen"), "acetaminophen");
});

Deno.test("nothing the patient has is also denied, and the other denials are few", () => {
  const p = { ...profile, presentation: { ...profile.presentation,
    hpi: { ...profile.presentation.hpi, associated_symptoms: [{ text: "Fever", frequency: "common" }], pertinent_negatives: ["No facial swelling or fever", "Black or bloody stools"] } } } as unknown as Profile;
  const pl = { ...plan, symptomsPresent: ["Fever"], symptomsAbsent: ["High fever", "Rash", "Cough", "Headache", "Chills", "Sore throat", "Earache", "Diarrhea", "Joint pain"] } as unknown as CasePlan;
  const facts = skeletonFacts(p, pl, null, () => 0.5);
  const denials = facts.filter((f) => f.content.startsWith("Denies")).map((f) => f.content).join(" ");
  assert(!/fever/i.test(denials), denials);
  const other = facts.find((f) => f.label === "Other denied symptoms")!;
  assert(other.content.split(";").length <= 6, other.content);
});

Deno.test("age and sex aren't told as risk factors", () => {
  const p = { ...profile, patient: { ...profile.patient, risk_factors: [{ text: "Male sex in childhood" }, { text: "Childhood or adolescent age" }, { text: "Smoking" }] } } as unknown as Profile;
  const risk = skeletonFacts(p, plan, null, () => 0.5).find((f) => f.label === "Risk factors")!;
  assertEquals(risk.content, "Smoking");
});

Deno.test("an injury gets a what-happened fact; an illness without an event doesn't", () => {
  const injury = { presentation: { hpi: { onset: "Sudden, immediately after a blow to the head or body; symptoms may not be noticed until hours later" } },
    patient: { risk_factors: [{ text: "Prior concussion" }, { text: "Participation in contact or collision sports (e.g., football, soccer)" }] } } as unknown as Profile;
  assertEquals(injuryEvent(injury, []), "how: Sudden, immediately after a blow to the head or body. during: Participation in contact or collision sports");
  const illness = { presentation: { hpi: { onset: "Gradual over several days" } }, patient: { risk_factors: [{ text: "Smoking" }] } } as unknown as Profile;
  assertEquals(injuryEvent(illness, []), null);
});
