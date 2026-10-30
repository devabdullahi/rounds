// Facts a flashcard may be written from, pulled from a condition profile by code. The card writer
// only words questions around these; it never brings its own medicine. Pure, covered by cardfacts_test.ts.
import { type Profile } from "./casegen.ts";

export type CardFacts = { source: string; condition: string; facts: string[] };

const KEEP = new Set(["almost_always", "common"]);

export function cardFacts(profile: Profile): CardFacts {
  // Each fact names the condition and uses plain words, since the card face shows only its question
  // and answer: a label like "must-not-miss alternative" ends up in a card that never says to what.
  const name = profile.triage.name;
  const facts: string[] = [];
  const p = profile.presentation;
  const symptoms = p.hpi.associated_symptoms.filter((s) => KEEP.has(s.frequency)).map((s) => s.text);
  if (symptoms.length) facts.push(`Typical symptoms of ${name}: ${symptoms.join("; ")}`);
  if (typeof p.hpi.onset === "string") facts.push(`Onset of ${name}: ${p.hpi.onset}`);

  const signs = profile.exam.findings.filter((f) => f.significance === "strongly_supports").map((f) => f.finding);
  if (signs.length) facts.push(`Exam findings that strongly support ${name}: ${signs.join("; ")}`);

  // Lab ranges are left out: they're the planner's severity bands, which read as clinical cutoffs on a card.
  const first = (profile.workup.initial ?? []).filter((t) => !t.only_if).map((t) => t.test);
  const confirm = (profile.workup.confirmatory ?? []).map((t) => t.test);
  if (first.length) facts.push(`First tests when ${name} is suspected: ${first.join(", ")}`);
  if (confirm.length) facts.push(`Tests that confirm ${name}: ${confirm.join(", ")}`);
  if (profile.workup.scores?.length) facts.push(`Scores used in ${name}: ${profile.workup.scores.join(", ")}`);

  for (const d of profile.differential.filter((d) => d.must_not_miss)) {
    facts.push(`Dangerous look-alike of ${name}: ${d.name}${d.trigger ? `. Suspect it when: ${d.trigger}` : ""}`);
  }
  // Finding and meaning apart, so a card asks what the finding indicates without assuming more.
  const redFlags = (profile.course as { red_flags?: { finding: string; meaning: string }[] }).red_flags ?? [];
  for (const f of redFlags) facts.push(`Warning sign in ${name}: ${f.finding}. It indicates: ${f.meaning}`);
  for (const point of profile.teaching.reasoning_points) facts.push(`About ${name}: ${point}`);

  return { source: profile.slug, condition: name, facts };
}

/** Facts from the student's own misses on graded cases. */
export function missFacts(misses: { flag: string; why: string }[]): CardFacts | null {
  if (!misses.length) return null;
  return { source: "missed", condition: "Red flags you missed", facts: misses.map((m) => `Warning sign: ${m.flag}. Why it matters: ${m.why}`) };
}
