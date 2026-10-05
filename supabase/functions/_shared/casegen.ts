// Case planning: samples one patient from a condition profile (severity, age, sex, which symptoms
// and findings are present, vital signs, lab values). Pure and seeded, so it's testable; the LLM
// only writes words around this plan, it never picks numbers.
import { deriveValues, panelFor, primaryValues, report, type Severity, type Sex, TESTS, type Values } from "./labs.ts";

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
  workup: Record<"initial" | "confirmatory" | "supporting" | "not_indicated", { test: string; why?: string; only_if?: string }[]> & { scores?: string[] };
  differential: { name: string; must_not_miss: boolean; why_considered: string; trigger?: string }[];
  course: { severity: Partial<Record<Severity, string>> };
  teaching: { key_questions: { question: string; importance: string; looking_for: string; category: string }[]; accepted_names: string[]; reasoning_points: string[] };
};
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

export type PlannedTest = {
  id: string;
  name: string;
  kind: "lab" | "study";
  /** Lab report text (computed here), or the profile findings the writer turns into a report. */
  result?: string;
  abnormal?: boolean;
  findings?: string[];
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
  symptomsPresent: string[];
  symptomsAbsent: string[];
  exam: (ExamFinding & { present: boolean })[];
  vitals: Values;
  tests: PlannedTest[];
};

function pick<T>(items: T[], rng: () => number): T {
  return items[Math.floor(rng() * items.length)];
}

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

const atLeast = (severity: Severity, min?: Severity) => !min || SEVERITY_ORDER.indexOf(severity) >= SEVERITY_ORDER.indexOf(min);

export function planCase(profile: Profile, rng: () => number): CasePlan {
  const severities = SEVERITY_ORDER.filter((s) => profile.course.severity[s]);
  const severity = weighted(severities.map((s) => [s, SEVERITY_WEIGHT[s]] as [Severity, number]), rng);
  const sex = sexFor(profile.patient.sex, rng);
  const { typical_min, typical_max } = profile.patient.age;
  const age = Math.round(typical_min + (typical_max - typical_min) * rng());

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
    vitals[id] = range ? Math.round((range.min + (range.max - range.min) * rng()) * (id === "temp" ? 10 : 1)) / (id === "temp" ? 10 : 1) : NaN;
  }
  const normalVitals = primaryValues(["vitals"], [], severity, sex, rng);
  for (const id of VITAL_IDS) if (Number.isNaN(vitals[id])) vitals[id] = normalVitals[id];

  return { slug: profile.slug, condition: profile.triage.name, severity, severityText: profile.course.severity[severity] ?? "", age, sex,
    symptomsPresent: present, symptomsAbsent: absent, exam, vitals, tests: planTests(profile, severity, sex, age, rng) };
}

/** The test menu: everything the profile's workup mentions plus routine panels, with lab results filled in. */
function planTests(profile: Profile, severity: Severity, sex: Sex, age: number, rng: () => number): PlannedTest[] {
  const roles = new Map<string, { role: PlannedTest["role"]; why?: string }>();
  const notIndicated = new Set(profile.workup.not_indicated.map((t) => t.test.toLowerCase()));
  for (const group of ["initial", "confirmatory", "supporting"] as const) {
    for (const ref of profile.workup[group]) {
      const conditional = !!ref.only_if || notIndicated.has(ref.test.toLowerCase());
      roles.set(ref.test, { role: conditional ? "conditional" : "indicated", why: ref.only_if ?? ref.why });
    }
  }
  for (const ref of profile.workup.not_indicated) {
    if (!roles.has(ref.test)) roles.set(ref.test, { role: "not_indicated", why: ref.why });
  }
  for (const panel of ALWAYS_OFFERED_PANELS) if (!roles.has(panel)) roles.set(panel, { role: "neutral" });

  // Lab panels share one set of values so overlapping tests agree.
  const labIds = [...roles.keys()].filter((t) => panelFor(t));
  const panels = [...new Set(labIds.map((t) => panelFor(t)!))];
  const values = deriveValues(primaryValues(panels, profile.labs ?? [], severity, sex, rng), age, sex);

  return [...roles.entries()].map(([test, { role, why }]) => {
    if (panelFor(test)) {
      const r = report(test, values, sex);
      const name = TESTS.get(test)?.name ?? test.toUpperCase();
      return { id: slug(test), name, kind: "lab", result: r.text, abnormal: r.abnormal, role, why };
    }
    const study = profile.imaging?.find((i) => i.study.toLowerCase() === test.toLowerCase());
    const isEcg = /\b(ecg|ekg|electrocardiogram)\b/i.test(test);
    const findings = isEcg
      ? (profile.ecg?.findings ?? []).filter((f) => atLeast(severity, f.min_severity) && rng() < PRESENT_CHANCE[f.frequency]).map((f) => f.finding)
      : (study?.findings ?? []).filter((f) => rng() < PRESENT_CHANCE[f.frequency]).map((f) => f.text);
    return { id: slug(test), name: test, kind: "study", findings, role, why };
  });
}

function slug(text: string): string {
  return text.toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_|_$/g, "").slice(0, 40);
}

/** Names that would give the answer away; door note, facts and exam text must not contain them. */
export function leakTerms(profile: Profile): string[] {
  const names = [profile.triage.name, ...profile.teaching.accepted_names];
  return [...new Set(names.map((n) => n.toLowerCase().replace(/\s*\([^)]*\)/g, "").trim()).filter((n) => n.length > 3))];
}

export function leaks(text: string, terms: string[]): string[] {
  const lower = text.toLowerCase();
  return terms.filter((t) => lower.includes(t));
}

export { pick };
