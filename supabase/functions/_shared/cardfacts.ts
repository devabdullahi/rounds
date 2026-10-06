// Facts a flashcard may be written from, pulled from a condition profile by code. The card writer
// only words questions around these; it never brings its own medicine. Pure, covered by cardfacts_test.ts.
import { type Profile } from "./casegen.ts";
import { TESTS } from "./labs.ts";

export type CardFacts = { source: string; condition: string; facts: string[] };

const KEEP = new Set(["almost_always", "common"]);

export function cardFacts(profile: Profile): CardFacts {
  const facts: string[] = [];
  const p = profile.presentation;
  const symptoms = p.hpi.associated_symptoms.filter((s) => KEEP.has(s.frequency)).map((s) => s.text);
  if (symptoms.length) facts.push(`Typical symptoms: ${symptoms.join("; ")}`);
  if (typeof p.hpi.onset === "string") facts.push(`Onset: ${p.hpi.onset}`);

  const signs = profile.exam.findings.filter((f) => f.significance === "strongly_supports").map((f) => f.finding);
  if (signs.length) facts.push(`Exam findings that strongly support it: ${signs.join("; ")}`);

  for (const lab of profile.labs ?? []) {
    const r = lab.ranges?.moderate ?? lab.ranges?.severe ?? lab.ranges?.mild;
    const test = TESTS.get(lab.test_id);
    if (r && test) facts.push(`${test.name} at moderate severity: ${r.min}–${r.max} ${test.unit ?? ""}`.trim());
  }

  const first = (profile.workup.initial ?? []).filter((t) => !t.only_if).map((t) => t.test);
  const confirm = (profile.workup.confirmatory ?? []).map((t) => t.test);
  if (first.length) facts.push(`First tests: ${first.join(", ")}`);
  if (confirm.length) facts.push(`Confirmatory tests: ${confirm.join(", ")}`);
  if (profile.workup.scores?.length) facts.push(`Clinical scores used: ${profile.workup.scores.join(", ")}`);

  for (const d of profile.differential.filter((d) => d.must_not_miss)) {
    facts.push(`Must-not-miss alternative: ${d.name}${d.trigger ? ` (think of it when: ${d.trigger})` : ""}`);
  }
  const redFlags = (profile.course as { red_flags?: { finding: string; meaning: string }[] }).red_flags ?? [];
  for (const f of redFlags) facts.push(`Red flag: ${f.finding} means ${f.meaning}`);
  for (const point of profile.teaching.reasoning_points) facts.push(`Reasoning point: ${point}`);

  return { source: profile.slug, condition: profile.triage.name, facts };
}

/** Facts from the student's own misses on graded cases. */
export function missFacts(misses: { flag: string; why: string }[]): CardFacts | null {
  if (!misses.length) return null;
  return { source: "missed", condition: "Red flags you missed", facts: misses.map((m) => `Red flag: ${m.flag}. ${m.why}`) };
}
