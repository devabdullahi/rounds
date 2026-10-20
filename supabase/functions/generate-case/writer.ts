// The case writer's prompt, the shape it must return, how it's assembled from the skeleton, the checks on it,
// and the rubric derived from the profile plus what was written. Kept apart from index.ts so it's testable without a DB.
import { type CasePlan, leaks, type Profile } from "../_shared/casegen.ts";
import { backgroundForWriter, type PatientBackground, SNOMED_TAG } from "./background.ts";
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

/** A clinical psychology case: same screens and JSON, written as a psychologist's intake. */
const PSYCHOLOGY_FRAME = `Clinician: a clinical psychology trainee doing a 50-minute outpatient intake. The setting is an outpatient psychology clinic and the door note is the referral (who referred them and why), not a triage note.
Maneuvers are mental status exam observations a psychologist makes by watching and talking (appearance, behavior, speech, mood, affect, thought process, thought content, perception, cognition, insight and judgment). Write each exam finding below as that kind of observation, titled like "Observe affect" or "Assess thought content"; a finding that needs touch or instruments becomes what can be seen or reported (e.g. "Appears tremulous"). The 2–3 routine maneuvers are other mental status domains. No physical exam maneuvers.
Tests are standardized questionnaires the patient fills in: in test_meta use cost 0, detail like "Questionnaire · 3 min", turnaround_s 3–6 and delays_care_min 0.

`;

/** A dermatology case: same screens; the exam is a skin exam charted the way a dermatologist does. */
const DERMATOLOGY_FRAME = `Clinician: a student on a dermatology clinic rotation. The setting is an outpatient dermatology clinic.
Maneuvers center on the skin, hair, nails and mucosa (e.g. "Inspect the rash", "Palpate the lesion", "Examine the scalp and nails", "Dermoscopy of the lesion"). Write every skin finding with its morphology as a dermatologist charts it: primary lesion type, size, color, shape and border, distribution and arrangement, and secondary changes (scale, crust, erosion). The student can't see a photo, so the words must carry the picture without naming the diagnosis.

`;

/** What the model returns for a code-built case: the human parts only (template.ts fills the same
 *  shape when the model can't). */
export type Voice = {
  patient: Writing["patient"];
  persona: Writing["persona"];
  facts: Record<string, { label?: string; reply?: string }>;
  normals: Record<string, string>;
  studies: Writing["studies"];
  suggested: Writing["suggested"];
};

/** The voice step's input: the skeleton's facts and maneuvers to word, and the person to write. */
export function voicePrompt(profile: Profile, plan: CasePlan, skeleton: Skeleton, background?: PatientBackground | null, name?: string): string {
  const studies = plan.tests.filter((t) => t.kind === "study");
  const who = `${plan.age}-year-old ${plan.age < 18 ? (plan.sex === "F" ? "girl" : "boy") : plan.sex === "F" ? "woman" : "man"}${plan.pregnant ? ", pregnant" : ""}`;
  return `${plan.psychology ? PSYCHOLOGY_FRAME : ""}${plan.dermatology ? DERMATOLOGY_FRAME : ""}Hidden diagnosis (never reveal): ${plan.condition}
Severity: ${plan.severity}: ${plan.severityText}
Patient: ${who}${name ? `, named ${name} (use this name exactly)` : ""}. Typical setting: ${profile.triage.settings.join(", ")}.${plan.age < 13 ? " A child this age answers simply; a parent or guardian is present and answers for them, so write replies as the child or the parent would say them." : ""}${background ? `\nTheir life outside this illness (for persona.background; the medical items are already in the facts): ${JSON.stringify({ marital_status: backgroundForWriter(background).marital_status, social: backgroundForWriter(background).social })}` : ""}
Chief complaints, in patients' words: ${JSON.stringify(profile.presentation.chief_complaints.map((c) => c.text))}
Facts to word: ${JSON.stringify(skeleton.facts.map((f) => ({ id: f.id, topic: f.label, content: f.content })))}
Maneuvers needing a normal result: ${JSON.stringify(skeleton.maneuvers.filter((m) => m.finding === null).map((m) => ({ id: m.id, maneuver: m.title })))}
Studies needing a report: ${JSON.stringify(studies.map((s) => ({ test_id: s.id, name: s.name, findings: s.findings })))}
Questions a strong student asks: ${JSON.stringify(profile.teaching.key_questions.map((q) => q.question))}

Return JSON:
{
  "patient": {"name": "First Last", "quote": "what they say walking in", "demeanor": "how they look and act, 3–6 words", "setting": "where they're seen, e.g. 'Walk-in, emergency department'", "complaint": "door note, under 20 words, as a triage nurse writes it: age, sex, the chief complaint in plain terms and its duration. Nothing that points to the diagnosis"},
  "persona": {"voice": "how they talk", "background": "job, family, context in 1–2 sentences", "fallback": "what they say, in character, when a question makes no sense to them"},
  "facts": {"f1": {"label": "2–4 words", "reply": "the patient's words"}},
  "normals": {"x1": "normal result"},
  "studies": [{"test_id": "...", "result": "report text", "abnormal": true}],
  "suggested": [{"text": "a one-tap question", "fact": "f1"}]
}`;
}

/** The writing a student plays: the skeleton's medicine with the template's wording. A fact or
 *  result the voice left out falls back to the skeleton's own wording, so nothing planned goes missing. */
export function assemble(skeleton: Skeleton, voice: Voice, name?: string): Writing {
  const facts = skeleton.facts.map((f) => ({
    id: f.id,
    label: voice.facts?.[f.id]?.label?.trim() || f.label,
    reply: voice.facts?.[f.id]?.reply?.trim() || f.content,
    importance: f.importance,
    screens_for: f.screens_for,
  }));
  const ids = new Set(facts.map((f) => f.id));
  return {
    // The name is picked in code (_shared/names.ts): models asked for one reuse the same few.
    patient: name ? { ...voice.patient, name } : voice.patient,
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
