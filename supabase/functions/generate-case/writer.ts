// The case writer's prompt, the shape it must return, the checks on it, and the rubric derived
// from the profile plus what was written. Kept apart from index.ts so it's testable without a DB.
import { type CasePlan, leaks, type Profile } from "../_shared/casegen.ts";

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

export function writerPrompt(profile: Profile, plan: CasePlan): string {
  const studies = plan.tests.filter((t) => t.kind === "study");
  const mustNotMiss = profile.differential.filter((d) => d.must_not_miss).map((d) => ({ name: d.name, trigger: d.trigger ?? d.why_considered }));
  return `${plan.psychology ? PSYCHOLOGY_FRAME : ""}Hidden diagnosis (never reveal): ${plan.condition}
Severity: ${plan.severity}: ${plan.severityText}
Patient: ${plan.age}-year-old ${plan.age < 18 ? (plan.sex === "F" ? "girl" : "boy") : plan.sex === "F" ? "woman" : "man"}${plan.pregnant ? ", pregnant (choose a gestational age that fits the condition and say it in her facts)" : ""}. Typical setting: ${profile.triage.settings.join(", ")}.${plan.age < 13 ? " A child this age answers simply; a parent or guardian is present and can answer for them, so write facts as the child or the parent would say them." : ""}
Vitals (already decided): ${JSON.stringify(plan.vitals)}

Presentation pattern: ${JSON.stringify(profile.presentation.hpi)}
Chief complaints to choose from (patient's words): ${JSON.stringify(profile.presentation.chief_complaints.map((c) => c.text))}
Symptoms PRESENT: ${JSON.stringify(plan.symptomsPresent)}
Symptoms ABSENT (deny if asked): ${JSON.stringify(plan.symptomsAbsent)}
Background to draw from (pick a plausible subset): risk factors ${JSON.stringify(profile.patient.risk_factors.map((r) => r.text))}, comorbidities ${JSON.stringify(profile.patient.comorbidities ?? [])}, social ${JSON.stringify(profile.patient.social_history ?? [])}, family ${JSON.stringify(profile.patient.family_history ?? [])}, medications ${JSON.stringify(profile.patient.risk_medications ?? [])}
Questions a strong student asks (each must be answerable by some fact): ${JSON.stringify(profile.teaching.key_questions.map((q) => ({ question: q.question, importance: q.importance })))}
Must-not-miss alternatives the student should screen for (write facts whose replies rule them in or out per this case): ${JSON.stringify(mustNotMiss)}
Exam findings (present ones as written; absent ones as a normal result for that maneuver): ${JSON.stringify(plan.exam.map((f) => ({ id: f.id, maneuver: f.maneuver ?? f.region, finding: f.finding, present: f.present, key: f.importance !== "optional" })))}
Studies needing a written report (base it on these findings; if none listed, write a normal or nonspecific report): ${JSON.stringify(studies.map((s) => ({ test_id: s.id, name: s.name, findings: s.findings })))}
Every test on the menu needs a price and wait (USD (0 for free bedside items), seconds 1–20 of in-app wait, delays_care_min = real-world minutes it delays definitive care, 0 for quick bedside tests): ${JSON.stringify(plan.tests.map((t) => ({ test_id: t.id, name: t.name })))}

Return JSON:
{
  "patient": {"name": "First Last", "quote": "what they say walking in", "demeanor": "how they look and act, 3–6 words", "setting": "where they're seen, e.g. 'Walk-in, emergency department'", "complaint": "door note: who they are and the chief complaint with its duration, as a triage nurse would write it. No pertinent negatives, history details or diagnosis; the student finds those out"},
  "persona": {"voice": "how they talk", "background": "job, family, context in 1–2 sentences", "fallback": "what they say, in character, when a question makes no sense to them"},
  "facts": [{"id": "snake_case", "label": "2–4 word topic shown when revealed, e.g. 'onset'", "reply": "patient's answer", "importance": "essential|important|optional", "screens_for": "a must-not-miss name from the list, or null"}],
  "suggested": [{"text": "a one-tap question", "fact": "fact id"}],
  "maneuvers": [{"id": "snake_case", "title": "e.g. 'Palpate the abdomen'", "finding": "result", "key": true}],
  "studies": [{"test_id": "...", "result": "report text", "abnormal": true}],
  "test_meta": [{"test_id": "...", "detail": "e.g. 'Bloods · 4 min'", "cost": 30, "turnaround_s": 5, "delays_care_min": 0}]
}
Include 10–16 facts (onset/timeline, character, associated symptoms, pertinent negatives, past history, medications, allergies, family, social, and the must-not-miss screens), 5–8 suggested questions, every exam finding above as a maneuver plus 2–3 routine ones (key false).`;
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
  const visible = [w.patient?.quote, w.patient?.complaint, w.patient?.demeanor,
    ...(w.facts ?? []).flatMap((f) => [f.label, f.reply]), ...(w.suggested ?? []).map((s) => s.text),
    ...(w.maneuvers ?? []).flatMap((m) => [m.title, m.finding])].join(" \n ");
  const leaked = leaks(visible, terms);
  if (leaked.length) problems.push(`reveals the diagnosis (${leaked.join(", ")}); remove it from everything the student sees before tests`);
  return problems;
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
