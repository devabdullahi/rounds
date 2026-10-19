// The case's content built in code, before any model writes a word: every history fact the student
// can uncover (what it says clinically, its label, how much it counts, which must-not-miss it
// screens for), the exam results for findings that are present, and each test's price and wait.
// The model then only says these in the patient's own words (writer.ts voicePrompt) and writes the
// door note, the voice, normal exam results and study reports. So the medicine comes from the
// profile and the plan, never from the model, and the model writes about half as much.
// Pure, so the rules are unit-tested.
import type { CasePlan, PlannedTest, Profile } from "../_shared/casegen.ts";
import { backgroundForWriter, type PatientBackground } from "./background.ts";

export type SkeletonFact = {
  id: string;
  label: string;
  /** What the fact says, clinically; the model turns it into the patient's words. */
  content: string;
  importance: "essential" | "important" | "optional";
  screens_for: string | null;
};
export type SkeletonManeuver = { id: string; title: string; finding: string | null; key: boolean };
export type TestMeta = { test_id: string; detail: string; cost: number; turnaround_s: number; delays_care_min: number };
export type Skeleton = { facts: SkeletonFact[]; maneuvers: SkeletonManeuver[]; test_meta: TestMeta[] };

/** The presentation details a strong history covers, paired the way a student asks about them. */
const HPI: [keys: string[], label: string, importance: SkeletonFact["importance"]][] = [
  [["onset", "duration"], "Onset", "essential"], [["location", "radiation"], "Location", "essential"],
  [["quality", "severity"], "Character", "important"], [["timing", "progression"], "Course", "important"],
  [["aggravating", "relieving"], "What changes it", "important"],
];
/** Pertinent negatives that become their own fact; the rest of the denied symptoms share one. */
const MAX_NEGATIVES = 5;
/** The illness's most typical present symptoms get a fact each; the rest share one. */
const MAX_OWN_SYMPTOMS = 4;
const FREQUENCY_ORDER = ["almost_always", "common", "sometimes", "rare"];
const MAX_HISTORY_ITEMS = 2;

const words = (text: string) => new Set(text.toLowerCase().match(/[a-z]{4,}/g) ?? []);

/** The must-not-miss alternative a pertinent negative helps rule out: the one whose trigger or
 *  reason shares the most meaningful words with it (at least two), else none. */
export function screensFor(negative: string, mustNotMiss: { name: string; trigger?: string; why_considered: string }[]): string | null {
  const n = words(negative);
  let best: string | null = null;
  let bestShared = 1;
  for (const d of mustNotMiss) {
    const shared = [...words(`${d.trigger ?? ""} ${d.why_considered}`)].filter((w) => n.has(w)).length;
    if (shared > bestShared) { best = d.name; bestShared = shared; }
  }
  return best;
}

function text(value: unknown): string {
  if (typeof value === "string") return value.trim();
  if (Array.isArray(value)) return value.map((v) => (typeof v === "string" ? v : (v as { text?: string })?.text ?? "")).filter(Boolean).join("; ");
  return "";
}

/** Every history fact for this patient, from the presentation, the plan's present and absent
 *  symptoms, the profile's history and the synthetic background record. */
export function skeletonFacts(profile: Profile, plan: CasePlan, background: PatientBackground | null, rng: () => number): SkeletonFact[] {
  const facts: SkeletonFact[] = [];
  const add = (label: string, content: string, importance: SkeletonFact["importance"], screens_for: string | null = null) => {
    if (content) facts.push({ id: `f${facts.length + 1}`, label, content, importance, screens_for });
  };
  const hpi = profile.presentation.hpi;
  for (const [keys, label, importance] of HPI) {
    add(label, keys.map((k) => text(hpi[k]) && `${k}: ${text(hpi[k])}`).filter(Boolean).join(". "), importance);
  }

  // The illness's own associated symptoms are a fact each (the ones a student must find); the rest of
  // the review of systems is one fact per body system, so the case stays 15–25 facts, not 40.
  const associated = new Set(hpi.associated_symptoms.map((s) => s.text));
  const present = new Set(plan.symptomsPresent);
  const typical = hpi.associated_symptoms.filter((s) => present.has(s.text))
    .sort((a, b) => FREQUENCY_ORDER.indexOf(a.frequency) - FREQUENCY_ORDER.indexOf(b.frequency)).map((s) => s.text);
  for (const symptom of typical.slice(0, MAX_OWN_SYMPTOMS)) add(symptom, `Has ${symptom.toLowerCase()}.`, "important");
  if (typical.length > MAX_OWN_SYMPTOMS) add("Other symptoms", `Also has ${typical.slice(MAX_OWN_SYMPTOMS).join("; ").toLowerCase()}.`, "important");
  for (const system of profile.presentation.ros) {
    const positives = system.positives.map((p) => p.text).filter((t) => present.has(t) && !associated.has(t));
    if (positives.length) add(`${system.system[0].toUpperCase()}${system.system.slice(1)} symptoms`, `Has ${positives.join("; ").toLowerCase()}.`, "important");
  }

  const mustNotMiss = profile.differential.filter((d) => d.must_not_miss);
  const negatives = hpi.pertinent_negatives.slice(0, MAX_NEGATIVES);
  for (const negative of negatives) {
    const screens = screensFor(negative, mustNotMiss);
    add(`No ${negative.toLowerCase()}`, `Denies: ${negative}.`, screens ? "important" : "optional", screens);
  }
  const otherDenied = plan.symptomsAbsent.filter((s) => !negatives.includes(s));
  if (otherDenied.length) add("Other denied symptoms", `Denies: ${otherDenied.join("; ")}.`, "optional");

  // How far along depends on the condition (an ectopic is weeks in, preeclampsia past 20), so the
  // writer picks a gestational age that fits and says it.
  if (plan.pregnant) add("Pregnancy", "Pregnant: give a gestational age that fits the condition.", "essential");

  const record = background ? backgroundForWriter(background) : null;
  const pick = <T>(list: T[], n: number) => [...list].sort(() => rng() - 0.5).slice(0, n);
  const risks = pick(profile.patient.risk_factors.map((r) => r.text), MAX_HISTORY_ITEMS);
  const history = [...(record?.chronic_conditions ?? []), ...pick(profile.patient.comorbidities ?? [], 1)];
  add("Past medical history", history.length ? history.join("; ") : "No significant past medical history.", "important");
  if (risks.length) add("Risk factors", risks.join("; "), "important");
  add("Medications", record?.current_medications.length ? `Takes ${record.current_medications.join(", ")}.` : "Takes no regular medications.", "important");
  add("Allergies", record?.allergies.length ? `Allergic to ${record.allergies.join(", ")}.` : "No known drug allergies.", "optional");
  const social = [record?.smoking && record.smoking !== "unknown" ? record.smoking : "", ...(record?.social ?? []), ...pick(profile.patient.social_history ?? [], 1)].filter(Boolean);
  add("Social history", social.join("; ") || "Nothing notable.", "optional");
  const family = pick(profile.patient.family_history ?? [], 1);
  add("Family history", family.length ? family.join("; ") : "No relevant family history.", "optional");
  return facts;
}

/** Exam steps from the plan: present findings verbatim from the profile; absent ones left for a
 *  normal result in the model's words (finding null). */
export function skeletonManeuvers(plan: CasePlan): SkeletonManeuver[] {
  return plan.exam.map((f, i) => ({
    id: `x${i + 1}`,
    title: f.maneuver ?? f.region,
    finding: f.present ? f.finding : null,
    key: f.importance !== "optional",
  }));
}

/** Price, in-app wait and real-world delay to care by kind of test: list prices, not this
 *  patient's bill. The in-app wait is 1–20 s; delays_care_min is how long it holds up treatment. */
export function testMeta(test: PlannedTest, psychology = false): TestMeta {
  const name = test.name.toLowerCase();
  const meta = (detail: string, cost: number, turnaround_s: number, delays_care_min: number): TestMeta =>
    ({ test_id: test.id, detail, cost, turnaround_s, delays_care_min });
  if (psychology) return meta("Questionnaire · 3 min", 0, 4, 0);
  if (test.kind === "lab") return meta("Bloods · 45 min", /cbc|count/.test(name) ? 30 : /panel|metabolic|bmp|cmp/.test(name) ? 45 : 60, 6, 45);
  if (/\becg\b|\bekg\b|electrocardiogram/.test(name)) return meta("Bedside · 5 min", 50, 3, 5);
  if (/echo/.test(name)) return meta("Imaging · 45 min", 600, 12, 60);
  if (/\bmri\b|magnetic/.test(name)) return meta("Imaging · 2 h", 1500, 15, 180);
  if (/\bct\b|tomograph/.test(name)) return meta("Imaging · 1 h", 700, 12, 60);
  if (/ultrasound|sonograph|\bus\b|doppler/.test(name)) return meta("Imaging · 40 min", 300, 10, 40);
  if (/x-?ray|radiograph/.test(name)) return meta("Imaging · 30 min", 120, 8, 30);
  if (/scope|endoscop|colonoscop|bronchoscop/.test(name)) return meta("Procedure · 4 h", 1500, 15, 240);
  if (/biopsy|aspirat|puncture|tap\b/.test(name)) return meta("Procedure · 2 h", 800, 12, 120);
  if (/culture|swab|pcr|antigen|serolog/.test(name)) return meta("Lab · 1 day", 60, 8, 0);
  if (/urin/.test(name)) return meta("Lab · 30 min", 25, 5, 30);
  return meta("Test · 1 h", 200, 10, 60);
}

export function buildSkeleton(profile: Profile, plan: CasePlan, background: PatientBackground | null, rng: () => number): Skeleton {
  return {
    facts: skeletonFacts(profile, plan, background, rng),
    maneuvers: skeletonManeuvers(plan),
    test_meta: plan.tests.map((t) => testMeta(t, plan.psychology)),
  };
}
