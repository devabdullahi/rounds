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
  spent: number;
  budget: number;
};

export type Judge = { diagnosisCorrect: boolean; planAppropriate: boolean; planNote: string };

export type Feedback = { tone: "good" | "miss"; title: string; detail: string; covers_miss?: string };
type Ranked = Feedback & { rank: number };

// Which feedback survives the cap: safety first, then the answer, then process, then praise.
const RANK = { redFlag: 0, diagnosis: 1, unnecessaryTest: 2, history: 3, exam: 4, plan: 5, praise: 6 };
export type Grade = {
  score: number;
  diagnosis_correct: boolean;
  diagnosis: string;
  verdict: string;
  rating_delta: number;
  feedback: Feedback[];
  missed_red_flags: { flag: string; why: string }[];
};

// Points per part; they sum to 100.
const POINTS = { diagnosis: 35, history: 25, exam: 15, redFlags: 10, tests: 10, plan: 5 };
const PENALTY = { unnecessaryTest: 3, overBudget: 3 };
const MAX_FEEDBACK = 4;

const slug = (s: string) => s.toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_|_$/g, "").slice(0, 60); // matches casegen ids

/** Accepted when the answer contains an accepted name, ignoring case and punctuation. */
export function matchesDiagnosis(answer: string, accepted: string[]): boolean {
  const a = ` ${slug(answer).replace(/_/g, " ")} `;
  return accepted.some((name) => a.includes(` ${slug(name).replace(/_/g, " ")} `));
}

export function grade(r: Rubric, act: Actions, judge: Judge): Grade {
  const feedback: Ranked[] = [];
  const missed: { flag: string; why: string }[] = [];
  let score = 0;

  if (judge.diagnosisCorrect) score += POINTS.diagnosis;
  else feedback.push({ rank: RANK.diagnosis, tone: "miss", title: `The diagnosis was ${r.diagnosis}`, detail: r.reasoning_points.slice(0, 3).join(". ") + "." });

  const totalWeight = r.key_facts.reduce((s, f) => s + f.weight, 0);
  const gotWeight = r.key_facts.filter((f) => act.revealed.includes(f.id)).reduce((s, f) => s + f.weight, 0);
  score += totalWeight ? Math.round((gotWeight / totalWeight) * POINTS.history) : POINTS.history;
  const gap = [...r.key_facts].sort((a, b) => b.weight - a.weight).find((f) => !act.revealed.includes(f.id));
  if (gap) feedback.push({ rank: RANK.history, tone: "miss", title: `History gap: ${gap.label}`, detail: "You never asked about it." });

  const examined = r.key_maneuvers.filter((m) => act.examined.includes(m.id));
  score += r.key_maneuvers.length ? Math.round((examined.length / r.key_maneuvers.length) * POINTS.exam) : POINTS.exam;
  const skipped = r.key_maneuvers.find((m) => !act.examined.includes(m.id));
  if (skipped) feedback.push({ rank: RANK.exam, tone: "miss", title: `Exam gap: ${skipped.title}`, detail: "A key part of this exam was skipped." });

  // Several facts can screen for one condition; asking any of them counts as screening it.
  const flags = new Map<string, { why: string; screened: boolean }>();
  for (const f of r.red_flags) {
    const entry = flags.get(f.flag) ?? { why: f.why, screened: false };
    flags.set(f.flag, { ...entry, screened: entry.screened || act.revealed.includes(f.fact) });
  }
  const screened = [...flags.values()].filter((f) => f.screened).length;
  score += flags.size ? Math.round((screened / flags.size) * POINTS.redFlags) : POINTS.redFlags;
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
  if (act.spent > act.budget) tests -= PENALTY.overBudget;
  score += Math.round(tests);

  if (judge.planAppropriate) score += POINTS.plan;
  else if (judge.planNote) feedback.push({ rank: RANK.plan, tone: "miss", title: "Plan needs work", detail: judge.planNote });

  score = Math.min(100, Math.max(0, score));
  const verdict = !judge.diagnosisCorrect ? "Missed diagnosis" : score >= 85 ? "Textbook workup" : "Right diagnosis, incomplete path";
  const ordered = feedback.sort((a, b) => a.rank - b.rank).map(({ rank: _, ...f }) => f);
  return {
    score, diagnosis_correct: judge.diagnosisCorrect, diagnosis: r.diagnosis, verdict,
    rating_delta: Math.round((score - 60) / 2), feedback: ordered.slice(0, MAX_FEEDBACK), missed_red_flags: missed,
  };
}
