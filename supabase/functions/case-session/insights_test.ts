import { assertEquals } from "jsr:@std/assert@1";
import { conditionInsights, type InsightProfile } from "./insights.ts";

// Shaped like knowledge-base/profiles/heart-attack.json, trimmed.
const profile: InsightProfile = {
  teaching: { reasoning_points: ["Chest pressure over 20 minutes", "Diaphoresis and nausea", "Cardiac risk factors", "Territorial ST changes", "Troponin rise and fall"] },
  presentation: {
    chief_complaints: [
      { text: "I have pressure in my chest", frequency: "almost_always" },
      { text: "My chest feels heavy and tight", frequency: "common" },
      { text: "My chest is burning like heartburn", frequency: "sometimes" },
    ],
    ros: [
      { positives: [{ text: "Feeling sweaty and clammy", frequency: "common" }, { text: "Feeling weak or washed out", frequency: "common" }] },
      { positives: [{ text: "Chest pressure", frequency: "almost_always" }, { text: "Feeling faint", frequency: "sometimes" }] },
      { positives: [{ text: "Nausea", frequency: "common" }, { text: "Short of breath", frequency: "common" }] },
    ],
  },
  patient: {
    risk_factors: [
      { text: "Obesity", strength: "moderate" },
      { text: "Cigarette smoking", strength: "strong" },
      { text: "Sedentary lifestyle", strength: "weak" },
      { text: "High LDL cholesterol", strength: "strong" },
      { text: "Chronic kidney disease", strength: "moderate" },
      { text: "Diabetes", strength: "strong" },
    ],
  },
  differential: [
    { name: "Gastroesophageal reflux disease", slug: "gerd", must_not_miss: false, why_considered: "Burning chest pain", discriminators: { history: ["Worse after meals"], exam: [] } },
    { name: "Unstable angina", slug: "unstable-angina", must_not_miss: true, why_considered: "Same cause without necrosis",
      discriminators: { history: ["New or worsening pain at rest", "Relieved by rest"], exam: ["Often normal"], labs: ["Troponin stays normal"], ecg: ["No ST elevation"] } },
    { name: "Aortic dissection", slug: "aortic-dissection", must_not_miss: true, why_considered: "Pain radiating to the back",
      discriminators: { labs: ["D-dimer often elevated"], imaging: ["Intimal flap on CT angiography"] } },
    { name: "Pulmonary embolism (PE)", must_not_miss: true, why_considered: "Chest pain with dyspnea", discriminators: { history: ["Pleuritic pain"], exam: ["Calf swelling"] } },
    { name: "Pericarditis", slug: "pericarditis", must_not_miss: false, why_considered: "Chest pain with ST changes" },
    { name: "Costochondritis", slug: "costochondritis", must_not_miss: false, why_considered: "Chest wall pain" },
  ],
};
const answer = ["Myocardial infarction", "Heart attack", "MI"];

Deno.test("about: first four reasoning points, frequent symptoms deduped, strong risk factors first", () => {
  const { about } = conditionInsights(profile, [], answer);
  assertEquals(about.summary_points.length, 4);
  // "Chest pressure" repeats "I have pressure in my chest"; "Feeling faint" and heartburn are not frequent enough to beat the cap.
  assertEquals(about.symptoms, [
    "I have pressure in my chest", "My chest feels heavy and tight", "Feeling sweaty and clammy",
    "Feeling weak or washed out", "Nausea", "Short of breath",
  ]);
  assertEquals(about.risk_factors, ["Cigarette smoking", "High LDL cholesterol", "Diabetes", "Obesity", "Chronic kidney disease"]);
});

Deno.test("differential: must-not-miss first, capped at five, tell-apart prefers history then exam", () => {
  const { differential } = conditionInsights(profile, [], answer);
  assertEquals(differential.map((d) => d.name), ["Unstable angina", "Aortic dissection", "Pulmonary embolism (PE)", "Gastroesophageal reflux disease", "Pericarditis"]);
  assertEquals(differential.map((d) => d.must_not_miss), [true, true, true, false, false]);
  assertEquals(differential[0].tell_apart, ["New or worsening pain at rest", "Often normal"]);
  assertEquals(differential[1].tell_apart, ["D-dimer often elevated", "Intimal flap on CT angiography"]);
  assertEquals(differential[3].tell_apart, ["Worse after meals"]);
  assertEquals(differential[4].tell_apart, []);
  assertEquals(differential[0].why, "Same cause without necrosis");
});

Deno.test("in_yours matches names, slugs, short forms and partial names, ignoring case and hedges", () => {
  const { differential } = conditionInsights(profile, ["probably UNSTABLE angina.", "PE", "GERD"], answer);
  const yours = Object.fromEntries(differential.map((d) => [d.name, d.in_yours]));
  assertEquals(yours, {
    "Unstable angina": true, "Aortic dissection": false, "Pulmonary embolism (PE)": true,
    "Gastroesophageal reflux disease": true, "Pericarditis": false,
  });
  assertEquals(conditionInsights(profile, ["dissection"], answer).differential[1].in_yours, true);
});

Deno.test("a vague entry doesn't claim an alternative", () => {
  const { differential, your_extras } = conditionInsights(profile, ["disease", "pain"], answer);
  assertEquals(differential.every((d) => !d.in_yours), true);
  assertEquals(your_extras, ["disease", "pain"]);
});

Deno.test("your_extras: entries outside the profile's differential, never the answer", () => {
  const { your_extras } = conditionInsights(profile, ["Myocardial infarction", "heart attack", "Costochondritis", "Panic attack", "Pneumothorax", "Panic attack"], answer);
  // Costochondritis is in the profile though not among the five shown, so it isn't an extra.
  assertEquals(your_extras, ["Panic attack", "Pneumothorax"]);
});

Deno.test("a profile missing parts gives empty lists, not a failure", () => {
  const insights = conditionInsights({}, ["Pneumothorax"], answer);
  assertEquals(insights, { about: { summary_points: [], symptoms: [], risk_factors: [] }, differential: [], your_extras: ["Pneumothorax"] });
});
