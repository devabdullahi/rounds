// What a student gets back when they return to a case they left mid-way: the conversation, the
// facts it uncovered, the exam steps done with their findings and the tests ordered with their
// results, so the case picks up where it stopped. Pure, so what's returned (and what exam mode
// keeps hidden) is unit-tested.

type Turn = { role: "student" | "patient"; text: string; conduct?: string };
type ResumeAttempt = {
  id: string; exam_mode: boolean; started_at: Date; time_limit_minutes: number | null; transcript: Turn[];
  revealed_facts: string[]; examined: string[]; ordered_tests: { id: string; at: string }[];
};
type ResumeContent = {
  facts: { id: string; label: string }[];
  exam: { id: string; finding: string }[];
  tests: { id: string; result: string; abnormal: boolean }[];
  rubric: { key_facts: { id: string }[] };
};

export function resumeState(a: ResumeAttempt, c: ResumeContent, hidden: string[]) {
  const label = new Map(c.facts.map((f) => [f.id, f.label]));
  const finding = new Map(c.exam.map((m) => [m.id, m.finding]));
  const test = new Map(c.tests.map((t) => [t.id, t]));
  const key = c.rubric.key_facts;
  return {
    attempt_id: a.id,
    exam_mode: a.exam_mode,
    time_limit_minutes: a.time_limit_minutes,
    started_at: new Date(a.started_at).toISOString(),
    // Off-topic and refused turns stay too: they're part of what the student saw.
    transcript: a.transcript.map((t) => ({ role: t.role, text: t.text })),
    // Exam mode shows no progress while the case runs, the same as `ask` replies.
    revealed: a.exam_mode ? [] : a.revealed_facts.filter((id) => label.has(id)).map((id) => ({ id, label: label.get(id)! })),
    revealed_ids: a.exam_mode ? [] : a.revealed_facts,
    coverage: a.exam_mode ? { got: 0, total: 0 } : { got: key.filter((f) => a.revealed_facts.includes(f.id)).length, total: key.length },
    examined: a.examined.filter((id) => finding.has(id)).map((id) => ({ id, finding: finding.get(id)! })),
    ordered: a.ordered_tests.filter((o) => test.has(o.id)).map((o) => {
      const t = test.get(o.id)!;
      return { id: o.id, at: o.at, result: t.result, abnormal: t.abnormal };
    }),
    hidden_tests: hidden,
  };
}
