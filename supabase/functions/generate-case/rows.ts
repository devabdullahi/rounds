// The rows a written case saves: the door note and menus the student sees, and the private script,
// results and rubric. Pure.
import { acceptedNames, type CasePlan, type PlannedTest, type Profile } from "../_shared/casegen.ts";
import { flag, type Patient, TESTS } from "../_shared/labs.ts";
import type { Focus } from "../_shared/focus.ts";
import { currentModel } from "../_shared/llm.ts";
import { PROMPT_VERSION } from "../_shared/prompts.ts";
import { buildRubric, type Writing } from "./writer.ts";
import type { CaseRows } from "./types.ts";

/** The specialty a case files under: the one the student picked, when the condition belongs to it
 *  (a depression case made for Clinical psychology is a psychology case; a heart failure case made
 *  for Cardiology is a cardiology case), else the condition's own primary rotation. */
function caseClerkship(profile: Profile, topics: string[], focus: Focus): string {
  return focus.kind === "rotation" && topics.includes(focus.value) ? focus.value : profile.triage.primary_clerkship;
}

/** The body system a case files under: the one the student picked when the condition is in it, else
 *  the condition's first (from the catalog's re-filing, falling back to triage's). */
function caseSystem(profile: Profile, systems: string[], focus: Focus): string {
  if (focus.kind === "system" && systems.includes(focus.value)) return focus.value;
  return systems[0] ?? profile.triage.organ_systems[0];
}

const VITAL_LABELS: Record<string, string> = { hr: "HR", sbp: "BP", rr: "RR", spo2: "SpO₂", temp: "Temp" };

/** Door-note vitals with an abnormal flag from this patient's normal ranges (age, pregnancy);
 *  the app turns the flag into a color. */
export function doorVitals(plan: Pick<CasePlan, "vitals" | "sex" | "age" | "pregnant">) {
  const v = plan.vitals as Record<string, number>;
  const patient: Patient = { sex: plan.sex, age: plan.age, pregnant: plan.pregnant };
  const off = (id: string) => !!flag(TESTS.get(id)!, v[id], patient);
  const out = [
    { id: "hr", value: `${v.hr}`, abnormal: off("hr") },
    { id: "sbp", value: `${v.sbp}/${v.dbp}`, abnormal: off("sbp") || off("dbp") },
    { id: "spo2", value: `${v.spo2}%`, abnormal: off("spo2") },
    { id: "rr", value: `${v.rr}`, abnormal: off("rr") },
    { id: "temp", value: `${v.temp.toFixed(1)}°F`, abnormal: off("temp") },
  ];
  return out.map((x) => ({ ...x, label: VITAL_LABELS[x.id] }));
}

export function buildRows(
  profile: Profile, clerkships: string[], systems: string[], synonyms: string[], plan: CasePlan, w: Writing, focus: Focus,
  backgroundId: string | null, writtenBy = currentModel("case"),
): CaseRows {
  const meta = new Map(w.test_meta.map((m) => [m.test_id, m]));
  const reports = new Map(w.studies.map((s) => [s.test_id, s]));
  const tests = plan.tests.map((t) => {
    const m = meta.get(t.id)!;
    const study = reports.get(t.id);
    return {
      id: t.id, name: t.name, detail: m.detail, cost: m.cost, turnaround_s: m.turnaround_s,
      delays_care_min: m.delays_care_min ?? 0,
      result: t.kind === "lab" ? t.result : study!.result,
      abnormal: t.kind === "lab" ? t.abnormal : studyAbnormal(t, study!),
      role: t.role, why: t.why ?? null,
    };
  });

  return {
    case: {
      specialty: profile.triage.primary_clerkship, patient_name: w.patient.name, age: plan.age, sex: plan.sex,
      quote: w.patient.quote, complaint: w.patient.complaint, vitals: doorVitals(plan), minutes: 10,
      setting: w.patient.setting, demeanor: w.patient.demeanor, organ_system: caseSystem(profile, systems, focus),
      clerkship: caseClerkship(profile, clerkships, focus), suggested: w.suggested,
      maneuvers: w.maneuvers.map(({ id, title }) => ({ id, title })),
      test_menu: tests.map(({ id, name, detail, cost, turnaround_s, delays_care_min }) => ({ id, name, detail, cost, turnaround_s, delays_care_min })),
      key_history: w.facts.filter((f) => f.importance !== "optional").length,
    },
    content: {
      facts: w.facts, exam: w.maneuvers, tests,
      answer_key: { diagnosis: profile.triage.name, accepted: acceptedNames(profile.teaching.accepted_names, synonyms) },
      condition_slug: profile.slug, severity: plan.severity,
      persona: { ...w.persona, name: w.patient.name, age: plan.age, sex: plan.sex, pregnant: plan.pregnant, model: writtenBy, prompt_version: PROMPT_VERSION },
      rubric: buildRubric(profile, plan, w, tests), focus: focus.stored, background_id: backgroundId,
      // The profile this case was planned from: grading insights and mistake cards read it.
      profile,
    },
  };
}

/** A report's abnormal flag, kept true to what it says: a planned-positive test is abnormal, and a
 *  report worded as negative or normal never is (a writer once flagged "No pathogen isolated"). */
export function studyAbnormal(t: PlannedTest, study: { result: string; abnormal: boolean }): boolean {
  if (t.positive) return true;
  const result = study.result.trim();
  if (NEGATIVE_REPORT.test(result) || NEGATIVE_ONLY.test(result)) return false;
  return study.abnormal;
}

/** A one-line report that only says nothing was found ("Shiga toxin not detected."). */
const NEGATIVE_ONLY = /^[^.;]{0,60}\b(not detected|not isolated|none detected|no growth|negative)\.?$/i;
const NEGATIVE_REPORT = /^(negative|normal|within normal limits|no (?:acute |significant |diagnostic )?(?:abnormalit|pathogen|growth|enteric|bacterial|organism)|not detected|no \w+ (?:detected|isolated|seen))/i;
