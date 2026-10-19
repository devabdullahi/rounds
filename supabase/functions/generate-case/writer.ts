// The written case's shape, how it's assembled from the skeleton and template, the checks on it,
// and the rubric derived from the profile plus what was written. Kept apart from index.ts so it's testable without a DB.
import { type CasePlan, leaks, type Profile } from "../_shared/casegen.ts";
import { SNOMED_TAG } from "./background.ts";
import type { Skeleton } from "./skeleton.ts";

export type Writing = {
  patient: { name: string; quote: string; demeanor: string; setting: string; complaint: string };
  persona: { voice: string; background: string; fallback: string };
  facts: { id: string; label: string; reply: string; importance: "essential" | "important" | "optional"; screens_for: string | null }[];
  suggested: { text: string; fact: string }[];
  maneuvers: { id: string; title: string; finding: string; key: boolean }[];
  studies: { test_id: string; result: string; abnormal: boolean }[];
  test_meta: { test_id: string; detail: string; cost: number; turnaround_s: number; delays_care_min?: number }[];
};

/** The human parts of a code-built case, filled in by template.ts. */
export type Voice = {
  patient: Writing["patient"];
  persona: Writing["persona"];
  facts: Record<string, { label?: string; reply?: string }>;
  normals: Record<string, string>;
  studies: Writing["studies"];
  suggested: Writing["suggested"];
};

/** The writing a student plays: the skeleton's medicine with the template's wording. A fact or
 *  result the voice left out falls back to the skeleton's own wording, so nothing planned goes missing. */
export function assemble(skeleton: Skeleton, voice: Voice): Writing {
  const facts = skeleton.facts.map((f) => ({
    id: f.id,
    label: voice.facts?.[f.id]?.label?.trim() || f.label,
    reply: voice.facts?.[f.id]?.reply?.trim() || f.content,
    importance: f.importance,
    screens_for: f.screens_for,
  }));
  const ids = new Set(facts.map((f) => f.id));
  return {
    patient: voice.patient,
    persona: voice.persona,
    facts,
    suggested: (voice.suggested ?? []).filter((s) => ids.has(s.fact)),
    maneuvers: skeleton.maneuvers.map((m) => ({ id: m.id, title: m.title, finding: m.finding ?? voice.normals?.[m.id]?.trim() ?? "Normal.", key: m.key })),
    studies: voice.studies ?? [],
    test_meta: skeleton.test_meta,
  };
}

// Any short, unique id works: neutralIds() replaces them all before saving.
const ID = /^[A-Za-z0-9_-]{1,60}$/;

export function checkWriting(w: Writing, plan: CasePlan, terms: string[]): string[] {
  const problems: string[] = [];
  if (!w?.patient?.name || !w.patient.complaint || !w.patient.quote) problems.push("patient needs name, quote and complaint");
  if (!w?.persona?.voice || !w.persona.fallback) problems.push("persona needs voice and fallback");
  if (!Array.isArray(w?.facts) || w.facts.length < 8) problems.push("need at least 8 facts");
  const factIds = new Set<string>();
  for (const f of w.facts ?? []) {
    if (!ID.test(f.id) || factIds.has(f.id)) problems.push(`fact id ${JSON.stringify(f.id)} must be unique and 1–60 letters, digits, - or _`);
    factIds.add(f.id);
    if (!["essential", "important", "optional"].includes(f.importance)) problems.push(`fact ${f.id}: bad importance`);
  }
  for (const s of w.suggested ?? []) if (!factIds.has(s.fact)) problems.push(`suggested question points to unknown fact ${s.fact}`);
  const maneuverIds = new Set<string>();
  for (const m of w.maneuvers ?? []) {
    if (!ID.test(m.id) || maneuverIds.has(m.id)) problems.push(`maneuver id ${JSON.stringify(m.id)} must be unique and 1–60 letters, digits, - or _`);
    maneuverIds.add(m.id);
  }
  if (maneuverIds.size < 3) problems.push("need at least 3 maneuvers");
  const studies = new Set((w.studies ?? []).map((s) => s.test_id));
  for (const t of plan.tests.filter((t) => t.kind === "study")) if (!studies.has(t.id)) problems.push(`missing report for ${t.id}`);
  const meta = new Map((w.test_meta ?? []).map((m) => [m.test_id, m]));
  for (const t of plan.tests) {
    const m = meta.get(t.id);
    if (!m) problems.push(`missing test_meta for ${t.id}`);
    else if (!(m.cost >= 0 && m.cost <= 5000 && m.turnaround_s >= 1 && m.turnaround_s <= 30 && (m.delays_care_min ?? 0) >= 0)) {
      problems.push(`test_meta for ${t.id} out of range`);
    }
  }
  const visible = visibleFields(w).map(([, text]) => text ?? "").join(" \n ");
  // Synthetic backgrounds arrive in SNOMED CT wording, which is licensed and never reaches the app.
  const coded = [...`${visible} \n ${w.persona?.background ?? ""}`.matchAll(SNOMED_TAG)].map((m) => m[0].trim());
  if (coded.length) problems.push(`uses coding wording (${[...new Set(coded)].join(", ")}); say it in the patient's own words`);
  const { leaked, where } = leakSpots(w, terms);
  if (leaked.length) {
    problems.push(`reveals the diagnosis (${leaked.join(", ")}) in: ${where.join("; ")}. Reword those fields without naming the diagnosis or any of its names (the patient describes symptoms, not what they think they have); the student must work it out`);
  }
  return problems;
}

/** Each student-visible field with where it sits, so a leak can be pointed at precisely: the model
 *  fixes "fact uti_history reply" far more reliably than "somewhere in the case". */
function visibleFields(w: Writing): [string, string | undefined][] {
  return [
    ["patient quote", w.patient?.quote], ["patient complaint", w.patient?.complaint], ["patient demeanor", w.patient?.demeanor],
    ...(w.facts ?? []).flatMap((f): [string, string][] => [[`fact ${f.id} label`, f.label], [`fact ${f.id} reply`, f.reply]]),
    ...(w.suggested ?? []).map((s, i): [string, string] => [`suggested question ${i + 1}`, s.text]),
    ...(w.maneuvers ?? []).flatMap((m): [string, string][] => [[`maneuver ${m.id} title`, m.title], [`maneuver ${m.id} finding`, m.finding]]),
  ];
}

/** The diagnosis names a writing reveals, and the fields that reveal them. */
export function leakSpots(w: Writing, terms: string[]): { leaked: string[]; where: string[] } {
  const fields = visibleFields(w);
  const leaked = leaks(fields.map(([, text]) => text ?? "").join(" \n "), terms);
  return { leaked, where: fields.filter(([, text]) => leaks(text ?? "", leaked).length).map(([where]) => where) };
}

/** Asks for new wording of only the leaking fields: a few lines back in 2–3 s, where rewriting the
 *  whole case takes 15–20 s and can leak somewhere else. */
export function fixPrompt(w: Writing, where: string[], leaked: string[]): string {
  const current = new Map(visibleFields(w));
  return `Names that must not appear: ${JSON.stringify(leaked)}
Lines to rewrite: ${JSON.stringify(where.map((at) => ({ where: at, text: current.get(at) ?? "" })))}`;
}

/** The writing with each fix applied to the field it names; fixes for fields that don't exist are ignored. */
export function applyFixes(w: Writing, fixes: { where: string; text: string }[]): Writing {
  const out: Writing = structuredClone(w);
  for (const { where, text } of fixes) {
    if (typeof text !== "string" || !text.trim()) continue;
    let m: RegExpMatchArray | null;
    if (where === "patient quote") out.patient.quote = text;
    else if (where === "patient complaint") out.patient.complaint = text;
    else if (where === "patient demeanor") out.patient.demeanor = text;
    else if ((m = where.match(/^fact (\S+) (label|reply)$/))) {
      const fact = out.facts.find((f) => f.id === m![1]);
      if (fact) fact[m[2] as "label" | "reply"] = text;
    } else if ((m = where.match(/^suggested question (\d+)$/))) {
      const s = out.suggested[Number(m[1]) - 1];
      if (s) s.text = text;
    } else if ((m = where.match(/^maneuver (\S+) (title|finding)$/))) {
      const maneuver = out.maneuvers.find((x) => x.id === m![1]);
      if (maneuver) maneuver[m[2] as "title" | "finding"] = text;
    }
  }
  return out;
}

/** Replaces the writer's descriptive ids ("diffuse_rhonchi") with neutral ones, since the app
 *  receives maneuver ids and suggested-question fact ids and a telling id would hint at the answer. */
export function neutralIds(w: Writing): Writing {
  const facts = new Map(w.facts.map((f, i) => [f.id, `f${String(i + 1).padStart(2, "0")}`]));
  const maneuvers = new Map(w.maneuvers.map((m, i) => [m.id, `x${String(i + 1).padStart(2, "0")}`]));
  return {
    ...w,
    facts: w.facts.map((f) => ({ ...f, id: facts.get(f.id)! })),
    suggested: w.suggested.map((s) => ({ ...s, fact: facts.get(s.fact)! })),
    maneuvers: w.maneuvers.map((m) => ({ ...m, id: maneuvers.get(m.id)! })),
  };
}

/** Grading inputs, derived from the profile and what was written. Read only by case-session. */
export function buildRubric(profile: Profile, plan: CasePlan, w: Writing, tests: { id: string; role: string; why: string | null; name: string }[]) {
  const must = new Map(profile.differential.filter((d) => d.must_not_miss).map((d) => [d.name.toLowerCase(), d]));
  return {
    diagnosis: profile.triage.name,
    accepted: profile.teaching.accepted_names,
    reasoning_points: profile.teaching.reasoning_points,
    severity: plan.severity,
    key_facts: w.facts.filter((f) => f.importance !== "optional").map((f) => ({ id: f.id, label: f.label, weight: f.importance === "essential" ? 2 : 1 })),
    red_flags: w.facts.filter((f) => f.screens_for).map((f) => {
      const d = must.get(f.screens_for!.toLowerCase());
      return { fact: f.id, flag: f.screens_for, why: d?.trigger ?? d?.why_considered ?? `Screen for ${f.screens_for}.` };
    }),
    key_maneuvers: w.maneuvers.filter((m) => m.key).map((m) => ({ id: m.id, title: m.title })),
    indicated_tests: tests.filter((t) => t.role === "indicated").map((t) => ({ id: t.id, name: t.name })),
    first_tests: (profile.workup.initial ?? []).filter((r) => !r.only_if).map((r) => r.test),
    unnecessary_tests: tests.filter((t) => t.role === "not_indicated").map((t) => ({ id: t.id, name: t.name, why: t.why })),
    must_not_miss: [...must.values()].map((d) => d.name),
  };
}
