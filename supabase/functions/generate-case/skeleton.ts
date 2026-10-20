// The case's content built in code, before any model writes a word: every history fact the student
// can uncover (what it says clinically, its label, how much it counts, which must-not-miss it
// screens for), the exam results for findings that are present, and each test's price and wait.
// template.ts then words them and fills in the door note, the person, normal exam results and study
// reports. So the medicine comes from the profile and the plan, never from a model.
// Pure, so the rules are unit-tested.
import { type CasePlan, leakTerms, type PlannedTest, type Profile } from "../_shared/casegen.ts";
import { backgroundForWriter, type PatientBackground } from "./background.ts";
import { historyFacts, priorCare } from "./history.ts";

export type SkeletonFact = {
  id: string;
  label: string;
  /** What the fact says, clinically; template.ts turns it into a plain first-person line. */
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
/** Other denied symptoms in that shared fact. */
const MAX_OTHER_DENIED = 6;
/** The illness's most typical present symptoms get a fact each; the rest share one. */
const MAX_OWN_SYMPTOMS = 4;
const FREQUENCY_ORDER = ["almost_always", "common", "sometimes", "rare"];
const MAX_HISTORY_ITEMS = 2;

const words = (text: string) => new Set(text.toLowerCase().match(/[a-z]{4,}/g) ?? []);

/** Words too common to tell two symptoms apart. */
const COMMON = new Set(["with", "without", "from", "that", "this", "have", "been", "more", "less", "than", "into", "over",
  "under", "feeling", "symptoms", "other", "only", "after", "before", "when", "worse", "sometimes", "often", "very", "some"]);
const keyWords = (text: string) => new Set([...words(text)].filter((w) => !COMMON.has(w)));

/** Whether two symptom phrases name the same thing ("Itchy eyes" and "Itchy, watery, red eyes";
 *  "Fever" and "No facial swelling or fever"): one's key words contain the other's, or they share two. */
export function overlaps(a: string, b: string): boolean {
  const x = keyWords(a), y = keyWords(b);
  if (!x.size || !y.size) return false;
  const shared = [...x].filter((w) => y.has(w)).length;
  return shared === x.size || shared === y.size || shared >= 2;
}

/** Review-of-systems names as a person would label them. */
const SYSTEM_LABEL: Record<string, string> = {
  ent: "Ear, nose and throat", heent: "Head, eyes, ears, nose and throat", constitutional: "General",
  allergic_immunologic: "Allergies", gastrointestinal: "Stomach and bowels", genitourinary: "Urinary",
  musculoskeletal: "Muscles and joints", neurologic: "Nervous system", psychiatric: "Mood", integumentary: "Skin",
  cardiovascular: "Heart", respiratory: "Breathing", hematologic_lymphatic: "Blood and glands", endocrine: "Hormones",
};
const systemLabel = (system: string) => SYSTEM_LABEL[system.toLowerCase()] ?? `${system[0].toUpperCase()}${system.slice(1).replace(/_/g, " ")}`;

/** Background records list every diagnosis a synthetic person ever had; a case wants their few
 *  ongoing conditions, not past sepsis or an old fracture. */
const ACUTE = /sepsis|fracture|injur|laceration|sprain|pregnan|acute|infection|poisoning|overdose|burn|bite|wound|contusion|concussion|dislocation/i;
const MAX_CHRONIC = 3;
/** A risk factor that's only the patient's age or sex. */
const DEMOGRAPHIC = /^(?:(?:male|female|young|older|advanced|increasing)\s+)?(?:sex|gender|age|childhood|adolescen\w*|infancy|elderly|older adults?|male|female)\b[^;]*$/i;
const MAX_MEDICATIONS = 4;

/** "Hydrochlorothiazide 25 MG Oral Tablet" → "hydrochlorothiazide 25 mg"; brand and package text dropped. */
export function medicationName(raw: string): string {
  const first = raw.split(/\s+\/\s+|\s*\[/)[0].trim();
  const m = first.match(/^(.+?\d+(?:\.\d+)?\s*(?:MG|MCG|UNT|ML|%)(?:\/ML)?)/i);
  return (m ? m[1] : first).replace(/\s+/g, " ").toLowerCase();
}

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

/** Generic words in diagnosis names that say nothing about which diagnosis it is. */
const GENERIC = new Set(["acute", "chronic", "disease", "disorder", "syndrome", "infection", "primary", "secondary", "severe",
  "simple", "complicated", "condition", "deficiency", "injury", "failure", "type", "with", "without", "due", "the", "and",
  // An injury's name says what happened, which the patient tells anyway ("my cat bit me").
  "animal", "human", "bite", "bites", "burn", "burns", "wound", "wounds", "foreign", "body", "trauma"]);

/** Every name of the diagnosis, and each distinctive word in them ("cholecystitis" from "Acute
 *  cholecystitis"), unless the patient's own history says it (an alcohol use disorder patient talks
 *  about alcohol). Text holding one of these would hand the student the answer. */
export function diagnosisWords(profile: Profile): string[] {
  const names = leakTerms(profile);
  const history = [
    ...profile.patient.risk_factors.map((r) => r.text), ...(profile.patient.social_history ?? []),
    ...profile.presentation.chief_complaints.map((c) => c.text),
    ...profile.presentation.hpi.associated_symptoms.map((s) => s.text),
  ].join(" ").toLowerCase();
  const words = names.flatMap((n) => n.split(/[^a-z0-9]+/)).filter((w) => w.length >= 5 && !GENERIC.has(w) && !history.includes(w));
  return [...new Set([...names, ...words])];
}

/** Profile text reasoning about the diagnosis rather than describing the patient ("suggests
 *  cholecystitis rather than biliary colic"): fine for a clinician, never for the patient's facts. */
const TEACHING = /\b(suggests?|suggestive|unlike|rather than|distinguish\w*|differentiat\w*|classic(?:al(?:ly)?)?|typical(?:ly)?|in contrast|consistent with|points? to|hallmark|diagnos\w*|criteria)\b/i;
const EMPTY = /^(not applicable|n\/a|none|variable|unknown|not relevant)\.?$/i;

/** A presentation detail cut to what describes this patient: sentences that teach or name the
 *  diagnosis, and empty values ("Not applicable"), are dropped. */
export function describing(value: string, banned: string[]): string {
  return value.replace(/\s*\([^)]*\)/g, "").split(/(?<=[.;])\s+/)
    .map((part) => part.trim().replace(/[.;]$/, ""))
    .filter((part) => part && !EMPTY.test(part) && !TEACHING.test(part) && !banned.some((w) => part.toLowerCase().includes(w)))
    .join("; ");
}

/** A trailing clause that reasons about the diagnosis (", more typical of viral conjunctivitis",
 *  ", which would argue against it"). */
const REASONING_CLAUSE = /,\s*(?:which\s+|that\s+)?(?:would\s+)?(?:be\s+)?(?:more\s+|less\s+|most\s+)?(?:typical|suggestive|consistent|characteristic|argu\w+|point\w*)\b.*$/i;

/** One short item (a pertinent negative, a history item, an exam finding) without the reasoning a
 *  clinician wrote next to it: parentheticals and reasoning clauses are cut. Empty when what's left
 *  still names the diagnosis, so the caller drops the item rather than give the answer away. */
export function plain(item: string, banned: string[]): string {
  const cut = item.replace(/\s*\([^)]*\)/g, "").replace(REASONING_CLAUSE, "").trim().replace(/[.;,]$/, "");
  return banned.some((w) => cut.toLowerCase().includes(w)) ? "" : cut;
}

/** Every history fact for this patient, from the presentation, the plan's present and absent
 *  symptoms, the profile's history and the synthetic background record. */
export function skeletonFacts(profile: Profile, plan: CasePlan, background: PatientBackground | null, rng: () => number): SkeletonFact[] {
  const facts: SkeletonFact[] = [];
  const add = (label: string, content: string, importance: SkeletonFact["importance"], screens_for: string | null = null) => {
    if (content) facts.push({ id: `f${facts.length + 1}`, label, content, importance, screens_for });
  };
  const hpi = profile.presentation.hpi;
  const banned = diagnosisWords(profile);
  for (const [keys, label, importance] of HPI) {
    add(label, keys.map((k) => describing(text(hpi[k]), banned)).map((v, i) => v && `${keys[i]}: ${v}`).filter(Boolean).join(". "), importance);
  }

  // The illness's own associated symptoms are a fact each (the ones a student must find); the rest of
  // the review of systems is one fact per body system, so the case stays 15–25 facts, not 40.
  const associated = new Set(hpi.associated_symptoms.map((s) => s.text));
  const present = new Set(plan.symptomsPresent);
  const typical = hpi.associated_symptoms.filter((s) => present.has(s.text))
    .sort((a, b) => FREQUENCY_ORDER.indexOf(a.frequency) - FREQUENCY_ORDER.indexOf(b.frequency)).map((s) => s.text);
  for (const symptom of typical.slice(0, MAX_OWN_SYMPTOMS)) add(symptom, `Has ${symptom.toLowerCase()}.`, "important");
  if (typical.length > MAX_OWN_SYMPTOMS) add("Other symptoms", `Also has ${typical.slice(MAX_OWN_SYMPTOMS).join("; ").toLowerCase()}.`, "important");
  // What the patient has, in every wording the profile uses, so the same symptom isn't told twice
  // and nothing they have is also denied.
  const has = [...typical, ...profile.presentation.chief_complaints.flatMap((c) => [c.text, (c as { term?: string }).term ?? ""])].filter(Boolean);
  for (const system of profile.presentation.ros) {
    const positives = system.positives.map((p) => p.text)
      .filter((t) => present.has(t) && !associated.has(t) && !has.some((h) => overlaps(h, t)));
    has.push(...positives);
    if (positives.length) add(`${systemLabel(system.system)} symptoms`, `Has ${positives.join("; ").toLowerCase()}.`, "important");
  }
  const contradicts = (denied: string) => has.some((h) => overlaps(h, denied));

  const mustNotMiss = profile.differential.filter((d) => d.must_not_miss);
  const negatives = hpi.pertinent_negatives.slice(0, MAX_NEGATIVES);
  const deniedSoFar: string[] = [];
  for (const negative of negatives) {
    const said = plain(negative, banned);
    if (!said || contradicts(said)) continue;
    deniedSoFar.push(said);
    const screens = screensFor(negative, mustNotMiss);
    add(`No ${said.toLowerCase()}`, `Denies: ${said}.`, screens ? "important" : "optional", screens);
  }
  // Absent symptoms the patient may deny: never one they have under another name, never one already
  // denied, and only a handful (a list of twenty reads like a form, not a person).
  const otherDenied: string[] = [];
  for (const symptom of plan.symptomsAbsent) {
    const said = plain(symptom, banned);
    if (!said || contradicts(said) || [...deniedSoFar, ...otherDenied].some((d) => overlaps(d, said))) continue;
    otherDenied.push(said);
    if (otherDenied.length >= MAX_OTHER_DENIED) break;
  }
  if (otherDenied.length) add("Other denied symptoms", `Denies: ${otherDenied.join("; ")}.`, "optional");

  // How far along depends on the condition (an ectopic is weeks in, preeclampsia past 20), so
  // template.ts takes the weeks from the profile.
  if (plan.pregnant) add("Pregnancy", "Pregnant.", "essential");

  const record = background ? backgroundForWriter(background) : null;
  // Items that still name the diagnosis after their reasoning is cut ("Mother with urinary
  // incontinence" for urinary incontinence) are left out rather than hand the student the answer.
  const pick = (list: string[], n: number) => [...list].map((x) => plain(x, banned)).filter(Boolean).sort(() => rng() - 0.5).slice(0, n);
  // Age and sex are risk factors on paper but not something a patient reports ("male sex in childhood").
  const risks = pick(profile.patient.risk_factors.map((r) => r.text).filter((r) => !DEMOGRAPHIC.test(r)), MAX_HISTORY_ITEMS);
  const chronic = (record?.chronic_conditions ?? []).filter((c) => !ACUTE.test(c) && plain(c, banned)).slice(0, MAX_CHRONIC);
  const conditions = [...chronic, ...pick(profile.patient.comorbidities ?? [], 1)];
  const medications = [...new Set((record?.current_medications ?? []).map(medicationName))].slice(0, MAX_MEDICATIONS);
  // Each condition with its age, medicine and what the doctor said; medicines with doses; allergies
  // with the reaction (history.ts).
  for (const f of historyFacts(conditions, medications, record?.allergies ?? [], rng)) add(f.label, f.content, f.importance);
  if (risks.length) add("Risk factors", risks.join("; "), "important");
  const care = priorCare(rng);
  add(care.label, care.content, care.importance);
  const social = [record?.smoking && record.smoking !== "unknown" ? record.smoking : "", ...(record?.social ?? []), ...pick(profile.patient.social_history ?? [], 1)].filter(Boolean);
  add("Social history", social.join("; ") || "Nothing notable.", "optional");
  const family = pick(profile.patient.family_history ?? [], 1);
  add("Family history", family.length ? family.join("; ") : "No relevant family history.", "optional");
  return facts;
}

/** Exam steps from the plan: present findings from the profile, without reasoning clauses; absent
 *  ones left for a normal result from the template (finding null). A finding that can only be said
 *  by naming the diagnosis keeps its wording, and the leak check rewords it. */
export function skeletonManeuvers(plan: CasePlan, banned: string[] = []): SkeletonManeuver[] {
  return plan.exam.map((f, i) => ({
    id: `x${i + 1}`,
    title: f.maneuver ?? f.region,
    finding: f.present ? plain(f.finding, banned) || f.finding : null,
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
    maneuvers: skeletonManeuvers(plan, diagnosisWords(profile)),
    test_meta: plan.tests.map((t) => testMeta(t, plan.psychology)),
  };
}
