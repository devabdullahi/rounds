// The AI-only experiment: one model call invents the whole case, the medicine included, with no
// condition catalog, profile, lab tables or reference APIs. Only accounts listed in
// AI_ONLY_USER_IDS get these cases, so they can be played side by side with the code-built ones.
// Code only checks the shape, the topic ids and that nothing the student sees names the diagnosis;
// it can't check the medicine, which is the point of the comparison. The checks are pure and tested.
import { sql } from "../_shared/db.ts";
import type { Focus } from "../_shared/focus.ts";
import { completeJSON, currentModel } from "../_shared/llm.ts";
import { AI_ONLY_CASE, PROMPT_VERSION } from "../_shared/prompts.ts";
import { doorVitals } from "./rows.ts";
import { testMeta } from "./skeleton.ts";
import type { CaseRows, History } from "./types.ts";

/** The app's Clerkship and OrganSystem ids (Model/Study): a case must file under one of each. */
export const CLERKSHIPS = ["internalMedicine", "surgery", "pediatrics", "obgyn", "psychiatry", "familyMedicine", "neurology",
  "emergency", "clinicalPsychology", "dermatology", "allergyImmunology", "cardiology", "endocrinology", "geriatrics",
  "hematologyOncology", "infectiousDisease", "nephrology", "ophthalmology", "orthopedicSurgery", "otolaryngology",
  "rehabilitation", "rheumatology", "urology", "neonatology", "nutrition"];
export const ORGAN_SYSTEMS = ["cardiovascular", "respiratory", "gastrointestinal", "renal", "nervous", "endocrine", "blood",
  "musculoskeletal", "reproductive", "behavioral", "skin", "eye", "ent", "immune"];

const SEVERITIES = ["mild", "moderate", "severe", "critical"];
const IMPORTANCE = ["essential", "important", "optional"];
const ROLES = ["indicated", "conditional", "not_indicated", "neutral"];
/** Lab tests by name, for their price and wait (everything else is priced as a study). */
const LAB = /\b(cbc|bmp|cmp|panel|troponin|lipase|amylase|level|count|a1c|tsh|crp|esr|lactate|bnp|d-dimer|inr|pt|ptt|hcg|urinalysis|ua|gas|electrolytes|glucose|creatinine|ferritin|b12)\b/i;

/** Whether this account gets AI-only cases: AI_ONLY_USER_IDS lists account ids or sign-in emails
 *  (an email covers every account a tester makes with it). */
export function aiOnlyListed(userId: string, email: string | null, raw = Deno.env.get("AI_ONLY_USER_IDS") ?? ""): boolean {
  const listed = raw.split(/[\s,]+/).map((s) => s.trim().toLowerCase()).filter(Boolean);
  return listed.includes(userId.toLowerCase()) || (!!email && listed.includes(email.toLowerCase()));
}

export async function aiOnlyUser(userId: string): Promise<boolean> {
  if (!(Deno.env.get("AI_ONLY_USER_IDS") ?? "").trim()) return false;
  const [user] = await sql<{ email: string | null }[]>`select email from auth.users where id = ${userId}`;
  return aiOnlyListed(userId, user?.email ?? null);
}

// deno-lint-ignore no-explicit-any
type Json = any;

/** What's wrong with a written case, as lines the model can fix. Empty when it's usable. */
export function aiCaseProblems(c: Json): string[] {
  const p: string[] = [];
  const str = (v: unknown) => typeof v === "string" && v.trim().length > 0;
  if (!str(c?.diagnosis)) p.push("diagnosis is missing");
  if (!SEVERITIES.includes(c?.severity)) p.push(`severity must be one of ${SEVERITIES.join(", ")}`);
  const pt = c?.patient ?? {};
  if (!str(pt.name) || !str(pt.quote) || !str(pt.complaint)) p.push("patient needs name, quote and complaint");
  if (!(Number.isInteger(pt.age) && pt.age >= 0 && pt.age <= 105)) p.push("patient.age must be a whole number 0-105");
  if (pt.sex !== "F" && pt.sex !== "M") p.push('patient.sex must be "F" or "M"');
  const v = c?.vitals ?? {};
  for (const [k, lo, hi] of [["hr", 20, 250], ["sbp", 40, 260], ["dbp", 20, 160], ["rr", 4, 70], ["temp", 90, 108], ["spo2", 50, 100]] as const) {
    if (typeof v[k] !== "number" || v[k] < lo || v[k] > hi) p.push(`vitals.${k} must be a number ${lo}-${hi}`);
  }
  if (!str(c?.persona?.voice) || !str(c?.persona?.fallback)) p.push("persona needs voice and fallback");
  const facts = Array.isArray(c?.facts) ? c.facts : [];
  if (facts.length < 12) p.push("need at least 12 facts");
  if (facts.some((f: Json) => !str(f?.label) || !str(f?.reply) || !IMPORTANCE.includes(f?.importance))) p.push("every fact needs label, reply and importance");
  const maneuvers = Array.isArray(c?.maneuvers) ? c.maneuvers : [];
  if (maneuvers.length < 6) p.push("need at least 6 exam maneuvers");
  if (maneuvers.some((m: Json) => !str(m?.title) || !str(m?.finding))) p.push("every maneuver needs title and finding");
  const tests = Array.isArray(c?.tests) ? c.tests : [];
  if (tests.length < 6) p.push("need at least 6 tests");
  if (tests.some((t: Json) => !str(t?.name) || !str(t?.result) || !ROLES.includes(t?.role))) p.push("every test needs name, result and role");
  if (!tests.some((t: Json) => t?.role === "indicated")) p.push("at least one test must be indicated");
  const leaked = leakedFields(c);
  if (leaked.length) p.push(`the diagnosis is named in: ${leaked.join("; ")}. Reword those without it`);
  return p;
}

/** Fields the student sees before testing that name the diagnosis or an accepted name. */
export function leakedFields(c: Json): string[] {
  const terms = [c?.diagnosis, ...(Array.isArray(c?.accepted) ? c.accepted : [])]
    .filter((t): t is string => typeof t === "string" && t.trim().length >= 4).map((t) => t.toLowerCase().trim());
  const seen: [string, unknown][] = [
    ["patient quote", c?.patient?.quote], ["door note", c?.patient?.complaint],
    ...(c?.facts ?? []).flatMap((f: Json): [string, unknown][] => [[`fact ${f?.id} label`, f?.label], [`fact ${f?.id} reply`, f?.reply]]),
    ...(c?.suggested ?? []).map((s: Json, i: number): [string, unknown] => [`one-tap question ${i + 1}`, s?.text]),
    ...(c?.maneuvers ?? []).flatMap((m: Json): [string, unknown][] => [[`maneuver ${m?.id} title`, m?.title], [`maneuver ${m?.id} finding`, m?.finding]]),
  ];
  return seen.filter(([, text]) => typeof text === "string" && terms.some((t) => text.toLowerCase().includes(t))).map(([where]) => where);
}

/** The rows a usable written case saves, in the same shape as a code-built case (no profile). */
export function aiCaseRows(c: Json, focus: Focus, writtenBy: string): CaseRows {
  const factId = new Map<string, string>();
  const facts = c.facts.map((f: Json, i: number) => {
    const id = `f${i + 1}`;
    factId.set(String(f.id), id);
    return { id, label: f.label.trim(), reply: f.reply.trim(), importance: f.importance, screens_for: typeof f.screens_for === "string" && f.screens_for.trim() ? f.screens_for.trim() : null };
  });
  const exam = c.maneuvers.map((m: Json, i: number) => ({ id: `x${i + 1}`, title: m.title.trim(), finding: m.finding.trim(), key: m.key === true }));
  const tests = c.tests.map((t: Json, i: number) => {
    const id = `t${i + 1}`;
    const meta = testMeta({ id, name: t.name, kind: LAB.test(t.name) ? "lab" : "study", role: t.role });
    return {
      id, name: t.name.trim(), detail: meta.detail, cost: meta.cost, turnaround_s: meta.turnaround_s, delays_care_min: meta.delays_care_min,
      result: t.result.trim(), abnormal: t.abnormal === true, role: t.role, why: typeof t.why === "string" ? t.why : null,
    };
  });
  const suggested = (Array.isArray(c.suggested) ? c.suggested : [])
    .map((s: Json) => ({ text: String(s?.text ?? "").trim(), fact: factId.get(String(s?.fact)) ?? "" }))
    .filter((s: { text: string; fact: string }) => s.text && s.fact).slice(0, 8);
  const pt = c.patient;
  const pregnant = pt.sex === "F" && pt.pregnant === true;
  const accepted = [...new Set([c.diagnosis, ...(Array.isArray(c.accepted) ? c.accepted : [])].filter((s) => typeof s === "string" && s.trim()))];
  const clerkship = focus.kind === "rotation" && CLERKSHIPS.includes(focus.value) ? focus.value
    : CLERKSHIPS.includes(c.clerkship) ? c.clerkship : "internalMedicine";
  const system = focus.kind === "system" && ORGAN_SYSTEMS.includes(focus.value) ? focus.value
    : ORGAN_SYSTEMS.includes(c.organ_system) ? c.organ_system : "gastrointestinal";
  const indicated = tests.filter((t: { role: string }) => t.role === "indicated");
  return {
    case: {
      specialty: clerkship, patient_name: pt.name.trim(), age: pt.age, sex: pt.sex, quote: pt.quote.trim(), complaint: pt.complaint.trim(),
      vitals: doorVitals({ vitals: c.vitals, sex: pt.sex, age: pt.age, pregnant }), minutes: 10,
      setting: String(pt.setting ?? "Walk-in, clinic"), demeanor: String(pt.demeanor ?? ""), organ_system: system, clerkship, suggested,
      maneuvers: exam.map(({ id, title }: { id: string; title: string }) => ({ id, title })),
      test_menu: tests.map(({ id, name, detail, cost, turnaround_s, delays_care_min }: Json) => ({ id, name, detail, cost, turnaround_s, delays_care_min })),
      key_history: facts.filter((f: { importance: string }) => f.importance !== "optional").length,
    },
    content: {
      facts, exam, tests,
      answer_key: { diagnosis: c.diagnosis.trim(), accepted },
      condition_slug: null, severity: c.severity,
      persona: {
        voice: c.persona.voice, background: String(c.persona.background ?? ""), fallback: c.persona.fallback,
        asks: (Array.isArray(c.persona.asks) ? c.persona.asks : []).filter((a: unknown) => typeof a === "string").slice(0, 2),
        name: pt.name.trim(), age: pt.age, sex: pt.sex, pregnant, model: writtenBy, prompt_version: PROMPT_VERSION, source: "ai_only",
      },
      rubric: {
        diagnosis: c.diagnosis.trim(), accepted, severity: c.severity,
        reasoning_points: (Array.isArray(c.reasoning_points) ? c.reasoning_points : []).filter((r: unknown) => typeof r === "string"),
        key_facts: facts.filter((f: { importance: string }) => f.importance !== "optional")
          .map((f: { id: string; label: string; importance: string }) => ({ id: f.id, label: f.label, weight: f.importance === "essential" ? 2 : 1 })),
        red_flags: facts.filter((f: { screens_for: string | null }) => f.screens_for)
          .map((f: { id: string; screens_for: string }) => ({ fact: f.id, flag: f.screens_for, why: `Screen for ${f.screens_for}.` })),
        key_maneuvers: exam.filter((m: { key: boolean }) => m.key).map(({ id, title }: { id: string; title: string }) => ({ id, title })),
        indicated_tests: indicated.map(({ id, name }: { id: string; name: string }) => ({ id, name })),
        first_tests: indicated.map((t: { name: string }) => t.name),
        unnecessary_tests: tests.filter((t: { role: string }) => t.role === "not_indicated").map(({ id, name, why }: Json) => ({ id, name, why })),
        must_not_miss: (Array.isArray(c.must_not_miss) ? c.must_not_miss : []).filter((m: unknown) => typeof m === "string"),
      },
      focus: focus.stored, background_id: null, profile: null,
    },
  };
}

/** The request: the topic and setting, and the diagnoses and names this student already had. */
export function aiCasePrompt(focus: Focus, avoid: string[], names: string[]): string {
  const topic = focus.kind === "rotation" ? `Rotation: ${focus.value}` : focus.kind === "system" ? `Organ system: ${focus.value}` : "Any rotation or organ system";
  const setting = focus.setting === "clinic" ? "an outpatient clinic" : focus.setting === "hospital" ? "the hospital (emergency department or a ward)" : "any setting";
  return `${topic}
Care setting: ${setting}
Clerkship ids: ${CLERKSHIPS.join(", ")}
Organ system ids: ${ORGAN_SYSTEMS.join(", ")}
Avoid these diagnoses (the student had them recently): ${JSON.stringify(avoid)}
Don't reuse these patient names: ${JSON.stringify(names.slice(0, 30))}

Write the case.`;
}

/** One AI-only case for the student, with one rewrite when the first draft has problems. */
export async function aiOnlyCase(userId: string, focus: Focus, history: History, deadline: number): Promise<CaseRows> {
  const recent = await sql<{ diagnosis: string }[]>`
    select k.answer_key->>'diagnosis' as diagnosis from private.case_content k join public.cases c on c.id = k.case_id
    where c.created_by = ${userId} order by c.created_at desc limit 15`;
  const prompt = aiCasePrompt(focus, recent.map((r) => r.diagnosis).filter(Boolean), [...history.names]);
  const left = () => Math.max(5_000, deadline - Date.now());
  let draft = await completeJSON<Json>(AI_ONLY_CASE, prompt, 6000, { task: "case", timeoutMs: left() });
  let problems = aiCaseProblems(draft);
  if (problems.length) {
    console.warn("generate-case: AI-only draft needs a rewrite", problems.join(" | ").slice(0, 300));
    draft = await completeJSON<Json>(AI_ONLY_CASE,
      `${prompt}\n\nYour last draft:\n${JSON.stringify(draft)}\n\nFix these problems and return the whole case again:\n- ${problems.join("\n- ")}`,
      6000, { task: "case", timeoutMs: left() });
    problems = aiCaseProblems(draft);
    if (problems.length) throw new Error(`AI-only case unusable: ${problems.join(" | ").slice(0, 300)}`);
  }
  console.log(JSON.stringify({ event: "case_generated", source: "ai_only", focus: focus.stored, diagnosis: draft.diagnosis }));
  return aiCaseRows(draft, focus, currentModel("case"));
}
