// Case planning: samples one patient from a condition profile (severity, age, sex, which symptoms
// and findings are present, vital signs, lab values). Pure and seeded, so it's testable; the LLM
// only writes words around this plan, it never picks numbers.
import { adultOf, deriveValues, interval, panelFor, type Patient, primaryValues, report, type Severity, type Sex, TESTS, type Values } from "./labs.ts";

type Range = { min: number; max: number };
type Frequency = "almost_always" | "common" | "sometimes" | "rare";
type Item = { text: string; frequency: Frequency };

export type Profile = {
  slug: string;
  triage: { name: string; primary_clerkship: string; organ_systems: string[]; settings: string[] };
  patient: { age: { typical_min: number; typical_max: number }; sex: string; risk_factors: { text: string }[]; comorbidities?: string[]; social_history?: string[]; family_history?: string[]; risk_medications?: string[] };
  presentation: {
    chief_complaints: Item[];
    hpi: Record<string, unknown> & { associated_symptoms: Item[]; pertinent_negatives: string[] };
    ros: { system: string; positives: Item[]; negatives: string[] }[];
  };
  exam: { general: Partial<Record<Severity, string>>; findings: ExamFinding[] };
  vitals?: Partial<Record<string, Partial<Record<Severity, Range>>>>;
  labs?: { test_id: string; ranges?: Partial<Record<Severity, Range>>; qualitative?: Partial<Record<Severity, string>> }[];
  ecg?: { findings: { feature: string; finding: string; frequency: Frequency; leads?: string[]; min_severity?: Severity }[] };
  imaging?: { study: string; modality: string; findings: Item[] }[];
  workup: Partial<Record<WorkupGroup, { test: string; why?: string; only_if?: string }[]>> & { scores?: string[] };
  differential: { name: string; must_not_miss: boolean; why_considered: string; trigger?: string }[];
  course: { severity: Partial<Record<Severity, string>> };
  teaching: { key_questions: { question: string; importance: string; looking_for: string; category: string }[]; accepted_names: string[]; reasoning_points: string[] };
};
type WorkupGroup = "initial" | "confirmatory" | "supporting" | "not_indicated";
type ExamFinding = {
  id: string;
  region: string;
  maneuver?: string;
  finding: string;
  frequency: Frequency;
  min_severity?: Severity;
  significance: string;
  importance: string;
};

const SEVERITY_ORDER: Severity[] = ["mild", "moderate", "severe", "critical"];
const SEVERITY_WEIGHT: Record<Severity, number> = { mild: 0.35, moderate: 0.4, severe: 0.2, critical: 0.05 };
const PRESENT_CHANCE: Record<Frequency, number> = { almost_always: 0.95, common: 0.7, sometimes: 0.3, rare: 0.05 };
const VITAL_IDS = ["temp", "hr", "rr", "sbp", "dbp", "spo2"];
const ALWAYS_OFFERED_PANELS = ["cbc", "bmp"];
/** Offered on every heart case, whatever the condition: students expect troponin on a cardiac
 *  workup, and a menu that showed it only for heart attacks would give the answer away. Ungraded
 *  (neutral) unless the profile's own workup makes it indicated. */
const CARDIAC_OFFERED_TESTS = ["hs_tnt"];
/** Standardized questionnaires (reference_ranges.json): the test menu of a psychology case. */
const ASSESSMENT_PANEL = "assessments";

/** How a case is framed. A clinical psychology case is an outpatient intake: the same screens, with
 *  mental status observations for the exam and questionnaires for the tests. */
export type PlanOptions = { psychology?: boolean; dermatology?: boolean; cardiac?: boolean };

export type PlannedTest = {
  id: string;
  name: string;
  kind: "lab" | "study";
  /** Lab report text (computed here), or the profile findings the writer turns into a report. */
  result?: string;
  abnormal?: boolean;
  findings?: string[];
  /** A microbiology or serology test the workup orders to find this condition: it comes back
   *  positive (the organism grown, the antigen detected). Profiles plan findings for imaging and
   *  ECGs only, so without this a confirming culture would read negative and mislead. */
  positive?: boolean;
  role: "indicated" | "conditional" | "not_indicated" | "neutral";
  why?: string;
};

export type CasePlan = {
  slug: string;
  condition: string;
  severity: Severity;
  severityText: string;
  age: number;
  sex: Sex;
  /** Pregnancy changes normal ranges and must be in the patient's story. */
  pregnant: boolean;
  symptomsPresent: string[];
  symptomsAbsent: string[];
  exam: (ExamFinding & { present: boolean })[];
  vitals: Values;
  tests: PlannedTest[];
  /** Written as a psychologist's intake (see PlanOptions). */
  psychology: boolean;
  /** Exam written as a full skin exam with lesion morphology. */
  dermatology: boolean;
};

function weighted<T extends string>(weights: [T, number][], rng: () => number): T {
  const total = weights.reduce((s, [, w]) => s + w, 0);
  let roll = rng() * total;
  for (const [value, w] of weights) {
    roll -= w;
    if (roll <= 0) return value;
  }
  return weights[weights.length - 1][0];
}

function sexFor(rule: string, rng: () => number): Sex {
  switch (rule) {
    case "female_only": return "F";
    case "male_only": return "M";
    case "female_predominant": return rng() < 0.75 ? "F" : "M";
    case "male_predominant": return rng() < 0.75 ? "M" : "F";
    default: return rng() < 0.5 ? "F" : "M";
  }
}

/** Conditions that only happen in pregnancy, judged from the profile's name and category. Profiles
 *  don't yet say so explicitly; a schema field would replace this. */
const PREGNANCY_CONDITION = /pregnan|preeclampsia|eclampsia|ectopic|gestational|placent|miscarriage|hyperemesis|preterm labor|labor and delivery/i;

/** Abbreviations that are also ordinary words: "an" would match "an infection". */
const WORD_ABBREVIATIONS = new Set(["an", "as", "at", "be", "do", "go", "he", "if", "in", "is", "it", "me", "my", "no", "of", "on", "or", "so", "to", "up", "us", "we", "all", "and", "are", "can", "for", "had", "has", "her", "him", "his", "its", "not", "one", "our", "the", "was", "who", "you"]);

/**
 * A case's accepted diagnosis names: the profile's own, plus standard synonyms from UMLS (SNOMED CT).
 * Grading accepts an answer that contains one as whole words, so terms that would match ordinary
 * sentences are dropped: "AN - Acoustic neuroma" keeps only "Acoustic neuroma", and short terms
 * survive only as real all-caps abbreviations (MI, CVA, DKA) that aren't also English words.
 */
export function acceptedNames(profileNames: string[], synonyms: string[]): string[] {
  const out = new Map<string, string>();
  const add = (name: string) => {
    const key = name.trim().toLowerCase();
    if (key && !out.has(key)) out.set(key, name.trim());
  };
  profileNames.forEach(add);
  for (const raw of synonyms) {
    for (const part of raw.split(/\s+-\s+/)) {
      const term = part.trim().replace(/\s*\[[^\]]*\]$/, "").replace(/\s*\((disorder|finding)\)$/, "");
      if (term.length >= 4 && !/\bNOS\b|, unspecified/i.test(term)) add(term);
      else if (/^[A-Z][A-Z0-9]{1,4}$/.test(term) && !WORD_ABBREVIATIONS.has(term.toLowerCase())) add(term);
    }
  }
  return [...out.values()];
}

export function isPregnant(profile: Profile, sex: Sex, age: number): boolean {
  const text = `${profile.triage.name} ${(profile.triage as { category?: string }).category ?? ""}`;
  return sex === "F" && age >= 14 && PREGNANCY_CONDITION.test(text);
}

/** Vital ranges in profiles are written for adults. For a child, shift them by the gap between the
 *  child's and an adult's normal midpoint, so "severe tachycardia" stays severe for a toddler. */
function forPatient(id: string, value: number, patient: Patient): number {
  if (patient.age >= 18 || id === "temp" || id === "spo2") return value;
  const test = TESTS.get(id);
  if (!test) return value;
  const mid = ([lo, hi]: [number | null, number | null]) => ((lo ?? 0) + (hi ?? 0)) / 2;
  return Math.round(value + mid(interval(test, patient)) - mid(interval(test, adultOf(patient))));
}

const atLeast = (severity: Severity, min?: Severity) => !min || SEVERITY_ORDER.indexOf(severity) >= SEVERITY_ORDER.indexOf(min);

export function planCase(profile: Profile, rng: () => number, options: PlanOptions = {}): CasePlan {
  const severities = SEVERITY_ORDER.filter((s) => profile.course.severity[s]);
  const severity = weighted(severities.map((s) => [s, SEVERITY_WEIGHT[s]] as [Severity, number]), rng);
  const sex = sexFor(profile.patient.sex, rng);
  const { typical_min, typical_max } = profile.patient.age;
  const age = Math.round(typical_min + (typical_max - typical_min) * rng());
  const patient: Patient = { sex, age, pregnant: isPregnant(profile, sex, age) };

  const symptoms = [...profile.presentation.hpi.associated_symptoms, ...profile.presentation.ros.flatMap((r) => r.positives)];
  const present = symptoms.filter((s) => rng() < PRESENT_CHANCE[s.frequency]).map((s) => s.text);
  const absent = [...profile.presentation.hpi.pertinent_negatives, ...profile.presentation.ros.flatMap((r) => r.negatives),
    ...symptoms.map((s) => s.text).filter((t) => !present.includes(t))];

  const exam = profile.exam.findings.map((f) => ({
    ...f,
    present: f.significance === "neutral" ||
      (f.significance !== "argues_against" && atLeast(severity, f.min_severity) && rng() < PRESENT_CHANCE[f.frequency]),
  }));

  const vitals: Values = {};
  for (const id of VITAL_IDS) {
    const range = profile.vitals?.[id]?.[severity];
    const raw = range ? range.min + (range.max - range.min) * rng() : NaN;
    vitals[id] = id === "temp" ? Math.round(raw * 10) / 10 : forPatient(id, Math.round(raw), patient);
  }
  const normalVitals = primaryValues(["vitals"], [], severity, patient, rng);
  for (const id of VITAL_IDS) if (Number.isNaN(vitals[id])) vitals[id] = normalVitals[id];

  return { slug: profile.slug, condition: profile.triage.name, severity, severityText: profile.course.severity[severity] ?? "", age, sex,
    pregnant: patient.pregnant, symptomsPresent: present, symptomsAbsent: absent, exam, vitals,
    tests: planTests(profile, severity, patient, rng, !!options.psychology, !!options.cardiac), psychology: !!options.psychology,
    dermatology: !!options.dermatology };
}

/** The test menu: everything the profile's workup mentions plus routine panels, with lab results filled in. */
function planTests(profile: Profile, severity: Severity, patient: Patient, rng: () => number, psychology: boolean, cardiac: boolean): PlannedTest[] {
  let roles = new Map<string, { role: PlannedTest["role"]; why?: string; core?: boolean }>();
  const group = (g: WorkupGroup) => profile.workup?.[g] ?? [];
  const notIndicated = new Set(group("not_indicated").map((t) => t.test.toLowerCase()));
  // Supporting tests are fine to order but aren't the core workup, so they don't count toward test
  // points; only a profile with no initial or confirmatory tests scores its supporting ones.
  const hasCore = group("initial").length + group("confirmatory").length > 0;
  for (const g of ["initial", "confirmatory", "supporting"] as const) {
    for (const ref of group(g)) {
      const conditional = !!ref.only_if || notIndicated.has(ref.test.toLowerCase()) || (g === "supporting" && hasCore);
      roles.set(ref.test, { role: conditional ? "conditional" : "indicated", why: ref.only_if ?? ref.why, core: g !== "supporting" });
    }
  }
  for (const ref of group("not_indicated")) {
    if (!roles.has(ref.test)) roles.set(ref.test, { role: "not_indicated", why: ref.why });
  }
  const assessments = psychology ? assessmentRoles(profile, roles) : null;
  if (assessments) roles = assessments;
  else {
    const offered = cardiac ? [...ALWAYS_OFFERED_PANELS, ...CARDIAC_OFFERED_TESTS] : ALWAYS_OFFERED_PANELS;
    for (const panel of offered) if (!roles.has(panel)) roles.set(panel, { role: "neutral" });
  }

  // Lab panels share one set of values so overlapping tests agree.
  const labIds = [...roles.keys()].filter((t) => panelFor(t));
  const panels = [...new Set(labIds.map((t) => panelFor(t)!))];
  const values = deriveValues(primaryValues(panels, profile.labs ?? [], severity, patient, rng), patient);

  // Ids come from names; long names that share a beginning get a numbered suffix to stay unique.
  const used = new Set<string>();
  const uniqueId = (name: string) => {
    let id = slug(name);
    for (let n = 2; used.has(id); n++) id = `${slug(name).slice(0, 56)}_${n}`;
    used.add(id);
    return id;
  };

  return [...roles.entries()].map(([test, { role, why, core }]) => {
    if (panelFor(test)) {
      const r = report(test, values, patient);
      const name = TESTS.get(test)?.name ?? test.toUpperCase();
      return { id: uniqueId(test), name, kind: "lab", result: r.text, abnormal: r.abnormal, role, why };
    }
    const study = profile.imaging?.find((i) => i.study.toLowerCase() === test.toLowerCase());
    const isEcg = /\b(ecg|ekg|electrocardiogram)\b/i.test(test);
    const findings = isEcg
      ? (profile.ecg?.findings ?? []).filter((f) => atLeast(severity, f.min_severity) && rng() < PRESENT_CHANCE[f.frequency]).map((f) => f.finding)
      : (study?.findings ?? []).filter((f) => rng() < PRESENT_CHANCE[f.frequency]).map((f) => f.text);
    // Only the core workup confirms: supporting extras (hepatitis screening alongside chlamydia)
    // aren't the test that finds this condition.
    const positive = !study && !isEcg && !!core && confirmsCondition(test, role, why);
    return { id: uniqueId(test), name: test, kind: "study", findings, role, why, ...(positive ? { positive } : {}) };
  });
}

/** Tests that find an organism or antibody: their result is the organism, not a picture. */
const MICROBIOLOGY = /culture|\bpcr\b|\bnaat\b|antigen|toxin|swab|serolog|smear|gram stain|pathogen panel|viral panel|\brapid\b|titer|\big[gm]\b|antibod|monospot|nucleic acid/i;
/** Reasons that say the test finds this condition... */
const FINDS = /\b(identif\w*|confirm\w*|detect\w*|diagnos\w*|isolat\w*|establish\w*|grows?|proves?)\b/i;
/** ...unless it's there to rule something else out (a stool culture in Crohn's disease). */
const RULES_OUT = /\b(exclud\w*|rul(?:e|es|ed|ing) out|other than|alternative|mimic\w*)\b/i;

/** Whether an indicated microbiology or serology test confirms this condition, so it should come
 *  back positive. Conditional tests (ordered only in some patients) stay negative: a blood culture
 *  for "fever or sepsis" isn't positive in an uncomplicated case. */
export function confirmsCondition(test: string, role: PlannedTest["role"], why?: string): boolean {
  return role === "indicated" && MICROBIOLOGY.test(test) && !!why && FINDS.test(why) && !RULES_OUT.test(why);
}

/** A psychology case's menu: the questionnaires the profile scores, then the rest as optional ones
 *  with normal scores. Nil when the profile scores none (written before assessments existed): a
 *  menu of normal scores would mislead, so the case keeps its usual tests. */
function assessmentRoles(profile: Profile, roles: Map<string, { role: PlannedTest["role"]; why?: string }>) {
  const isAssessment = (id: string) => panelFor(id) === ASSESSMENT_PANEL && id !== ASSESSMENT_PANEL;
  const scored = (profile.labs ?? []).map((l) => l.test_id).filter(isAssessment);
  const named = [...roles.keys()].filter(isAssessment);
  if (!scored.length && !named.length) return null;
  const menu = new Map<string, { role: PlannedTest["role"]; why?: string }>();
  for (const id of named) menu.set(id, roles.get(id)!);
  for (const id of scored) if (!menu.has(id)) menu.set(id, { role: "indicated" });
  for (const id of ASSESSMENT_TESTS) if (!menu.has(id)) menu.set(id, { role: "neutral" });
  return menu;
}

const ASSESSMENT_TESTS = [...TESTS.values()].filter((t) => panelFor(t.id) === ASSESSMENT_PANEL).map((t) => t.id);

function slug(text: string): string {
  return text.toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_|_$/g, "").slice(0, 60);
}

/** Names that would give the answer away; door note, facts and exam text must not contain them.
 *  A name the patient must be able to say (an exposure or habit, e.g. "cannabis" for cannabis use
 *  disorder) isn't a leak, so terms found in the patient's own history are left out. */
export function leakTerms(profile: Profile): string[] {
  const names = [profile.triage.name, ...profile.teaching.accepted_names];
  const history = [
    ...profile.patient.risk_factors.map((r) => r.text), ...(profile.patient.social_history ?? []),
    ...((profile.patient as { exposures?: string[] }).exposures ?? []), ...(profile.patient.risk_medications ?? []),
    ...profile.presentation.chief_complaints.map((c) => c.text),
  ].join(" ").toLowerCase();
  const terms = names.map((n) => n.toLowerCase().replace(/\s*\([^)]*\)/g, "").trim()).filter((n) => n.length > 3);
  return [...new Set(terms.filter((t) => !history.includes(t)))];
}

export function leaks(text: string, terms: string[]): string[] {
  const lower = text.toLowerCase();
  return terms.filter((t) => lower.includes(t));
}
