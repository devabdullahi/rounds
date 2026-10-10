// Scoring a submitted attempt from its logged actions and the case rubric. Pure, so the point
// rules are unit-tested. The only judgment calls (is the free-text diagnosis right, is the plan
// sensible) come in as `judge`, decided by the LLM in index.ts.

export type Rubric = {
  diagnosis: string;
  accepted: string[];
  reasoning_points: string[];
  severity: string;
  key_facts: { id: string; label: string; weight: number }[];
  red_flags: { fact: string; flag: string; why: string }[];
  key_maneuvers: { id: string; title: string }[];
  indicated_tests: { id: string; name: string }[];
  first_tests: string[];
  unnecessary_tests: { id: string; name: string; why: string | null }[];
  must_not_miss: string[];
};

export type Actions = {
  revealed: string[];
  examined: string[];
  ordered: string[];      // in order
  /** Submitted after the chosen time limit (plus grace). Still graded; the grade says so. */
  overTime?: boolean;
};

export type Judge = { diagnosisCorrect: boolean; planAppropriate: boolean; planNote: string };

export type Feedback = { tone: "good" | "miss"; title: string; detail: string; covers_miss?: string };
type Ranked = Feedback & { rank: number };

// Which feedback survives the cap: safety first, then the answer, then process, then praise.
const RANK = { overTime: -1, redFlag: 0, diagnosis: 1, unnecessaryTest: 2, history: 3, exam: 4, plan: 5, praise: 6 };
export type Grade = {
  score: number;
  diagnosis_correct: boolean;
  diagnosis: string;
  verdict: string;
  rating_delta: number;
  /** False when this attempt didn't move the rating (see unrated); rating_delta is then 0. */
  rated: boolean;
  /** Submitted after the attempt's time limit. */
  over_time: boolean;
  feedback: Feedback[];
  missed_red_flags: { flag: string; why: string }[];
  /** Points earned out of the most available, per part, so the app can show where points go. */
  breakdown: Record<Part, { got: number; max: number }>;
};

export type Part = "diagnosis" | "history" | "exam" | "red_flags" | "tests" | "plan";

// Points per part; they sum to 100.
const POINTS = { diagnosis: 35, history: 25, exam: 15, redFlags: 10, tests: 10, plan: 5 };
const PENALTY = { unnecessaryTest: 3 };
const MAX_FEEDBACK = 4;

const slug = (s: string) => s.toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_|_$/g, "").slice(0, 60); // matches casegen ids

/** Lowercase words separated by single spaces, punctuation dropped ("R/O MI." → "r o mi"). */
export const words = (s: string) => slug(s).replace(/_/g, " ");

// Hedges a student puts around one answer ("probably appendicitis"); they don't make it two answers.
const FILLER = /\b(most likely|more likely|likely|probably|probable|possibly|possible|presumed|suspected|suspect|i think|consistent with|diagnosis|dx)\b/g;
// A part that is only a qualifier ("Acute appendicitis, uncomplicated") describes the answer
// beside it rather than naming a second condition.
const QUALIFIER = /^((acute|chronic|subacute|uncomplicated|complicated|mild|moderate|severe|early|late|left|right|bilateral|unilateral|primary|secondary|recurrent)\s*)+$/;
// Words that turn a name into "not this one". "r o" is "r/o" after punctuation is dropped.
const NEGATION = "(not|no|rule out|ruled out|rules out|r o|exclude|excluding|unlikely)";

/** The separate diagnoses an answer names, hedges stripped: "MI, PE or appendicitis" gives three.
 *  Splitting on "and" can break a name that contains it, which matchesDiagnosis allows for. */
export function diagnosisCandidates(answer: string): string[] {
  return answer.toLowerCase().replace(/r\/o/g, "rule out")
    .split(/[,;/\n]|\bor\b|\band\b|\bvs\b|\bversus\b/)
    .map((part) => words(part).replace(FILLER, " ").replace(/\s+/g, " ").trim())
    .filter((part) => part && !QUALIFIER.test(part));
}

/** True when the answer negates or rules something out, which a single committed diagnosis never does. */
export function isNegated(answer: string): boolean {
  return new RegExp(`(^| )${NEGATION}( |$)`).test(words(answer.replace(/r\/o/gi, "rule out")));
}

/** True when the answer commits to one diagnosis: one candidate, nothing ruled out. The model's
 *  synonym judgment is trusted only for answers like this (see judge in index.ts). */
export function isSingleDiagnosis(answer: string): boolean {
  return !isNegated(answer) && diagnosisCandidates(answer).length === 1;
}

/**
 * Accepted when the answer commits to exactly one diagnosis and it contains an accepted name as
 * whole words, ignoring case and punctuation. A list ("pneumonia, PE, MI, appendicitis") or a
 * negation ("not appendicitis", "r/o appendicitis") is never a match, so shotgun answers don't score.
 */
export function matchesDiagnosis(answer: string, accepted: string[]): boolean {
  const names = accepted.map(words).filter(Boolean);
  const text = words(answer.replace(/r\/o/gi, "rule out"));
  if (names.some((name) => new RegExp(`(^| )${NEGATION}( [a-z0-9]+){0,2} ${name}( |$)`).test(text))) return false;
  // A name that itself contains a separator ("Hand, foot and mouth disease") is one answer.
  const whole = ` ${text.replace(FILLER, " ").replace(/\s+/g, " ").trim()} `;
  if (names.some((name) => whole === ` ${name} `)) return true;
  const candidates = diagnosisCandidates(answer);
  return candidates.length === 1 && names.some((name) => ` ${candidates[0]} `.includes(` ${name} `));
}

export function grade(r: Rubric, act: Actions, judge: Judge): Grade {
  const feedback: Ranked[] = [];
  const missed: { flag: string; why: string }[] = [];
  let score = 0;
  const got: Record<Part, number> = { diagnosis: 0, history: 0, exam: 0, red_flags: 0, tests: 0, plan: 0 };

  if (act.overTime) feedback.push({ rank: RANK.overTime, tone: "miss", title: "Over the time limit", detail: "You submitted after the time you set for this case ran out." });

  if (judge.diagnosisCorrect) got.diagnosis = POINTS.diagnosis;
  else feedback.push({ rank: RANK.diagnosis, tone: "miss", title: `The diagnosis was ${r.diagnosis}`, detail: r.reasoning_points.slice(0, 3).join(". ") + "." });

  const totalWeight = r.key_facts.reduce((s, f) => s + f.weight, 0);
  const gotWeight = r.key_facts.filter((f) => act.revealed.includes(f.id)).reduce((s, f) => s + f.weight, 0);
  got.history = totalWeight ? Math.round((gotWeight / totalWeight) * POINTS.history) : POINTS.history;
  const gap = [...r.key_facts].sort((a, b) => b.weight - a.weight).find((f) => !act.revealed.includes(f.id));
  if (gap) feedback.push({ rank: RANK.history, tone: "miss", title: `History gap: ${gap.label}`, detail: "You never asked about it." });

  const examined = r.key_maneuvers.filter((m) => act.examined.includes(m.id));
  got.exam = r.key_maneuvers.length ? Math.round((examined.length / r.key_maneuvers.length) * POINTS.exam) : POINTS.exam;
  const skipped = r.key_maneuvers.find((m) => !act.examined.includes(m.id));
  if (skipped) feedback.push({ rank: RANK.exam, tone: "miss", title: `Exam gap: ${skipped.title}`, detail: "A key part of this exam was skipped." });

  // Several facts can screen for one condition; asking any of them counts as screening it.
  const flags = new Map<string, { why: string; screened: boolean }>();
  for (const f of r.red_flags) {
    const entry = flags.get(f.flag) ?? { why: f.why, screened: false };
    flags.set(f.flag, { ...entry, screened: entry.screened || act.revealed.includes(f.fact) });
  }
  const screened = [...flags.values()].filter((f) => f.screened).length;
  got.red_flags = flags.size ? Math.round((screened / flags.size) * POINTS.redFlags) : POINTS.redFlags;
  for (const [flag, f] of flags) if (!f.screened) missed.push({ flag, why: f.why });
  if (missed.length) {
    feedback.push({ rank: RANK.redFlag, tone: "miss", title: `You didn't screen for ${missed[0].flag}`, detail: missed[0].why, covers_miss: missed[0].flag });
  }

  let tests = 0;
  const indicated = r.indicated_tests.filter((t) => act.ordered.includes(t.id));
  tests += r.indicated_tests.length ? (indicated.length / r.indicated_tests.length) * (POINTS.tests - 3) : POINTS.tests - 3;
  const firstGood = act.ordered.length > 0 && r.first_tests.map(slug).includes(act.ordered[0]);
  if (firstGood) {
    tests += 3;
    feedback.push({ rank: RANK.praise, tone: "good", title: "Good first test", detail: "The right place to start." });
  }
  const wasted = r.unnecessary_tests.filter((t) => act.ordered.includes(t.id));
  tests -= wasted.length * PENALTY.unnecessaryTest;
  if (wasted.length) feedback.push({ rank: RANK.unnecessaryTest, tone: "miss", title: `${wasted[0].name} wasn't indicated`, detail: wasted[0].why ?? "It didn't change management." });
  // Penalties can push tests below zero, which still lowers the total; the breakdown floors at 0.
  const testPoints = Math.round(tests);
  got.tests = Math.max(0, testPoints);

  if (judge.planAppropriate) got.plan = POINTS.plan;
  else if (judge.planNote) feedback.push({ rank: RANK.plan, tone: "miss", title: "Plan needs work", detail: judge.planNote });

  score = got.diagnosis + got.history + got.exam + got.red_flags + testPoints + got.plan;
  score = Math.min(100, Math.max(0, score));
  const max: Record<Part, number> = {
    diagnosis: POINTS.diagnosis, history: POINTS.history, exam: POINTS.exam,
    red_flags: POINTS.redFlags, tests: POINTS.tests, plan: POINTS.plan,
  };
  const verdict = !judge.diagnosisCorrect ? "Missed diagnosis" : score >= 85 ? "Textbook workup" : "Right diagnosis, incomplete path";
  const ordered = feedback.sort((a, b) => a.rank - b.rank).map(({ rank: _, ...f }) => f);
  return {
    score, diagnosis_correct: judge.diagnosisCorrect, diagnosis: r.diagnosis, verdict,
    rating_delta: Math.round((score - 60) / 2), rated: true, over_time: act.overTime === true, feedback: ordered.slice(0, MAX_FEEDBACK), missed_red_flags: missed,
    breakdown: Object.fromEntries((Object.keys(got) as Part[]).map((k) => [k, { got: got[k], max: max[k] }])) as Grade["breakdown"],
  };
}

/** The grade of a repeat attempt: scored and explained as usual, but the rating stays put, so
 *  restarting a case after seeing its answer can't farm rating. Only a first attempt is rated. */
export function unrated<G extends Grade>(g: G): G {
  return { ...g, rating_delta: 0, rated: false };
}
