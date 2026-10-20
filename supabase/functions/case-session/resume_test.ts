import { assertEquals } from "jsr:@std/assert@1";
import { resumeState } from "./resume.ts";

const content = {
  facts: [{ id: "f1", label: "Onset" }, { id: "f2", label: "Fever" }],
  exam: [{ id: "x1", finding: "Tender right lower quadrant." }],
  tests: [{ id: "cbc", result: "WBC 14.2", abnormal: true }],
  rubric: { key_facts: [{ id: "f1" }, { id: "f2" }] },
};
const attempt = {
  id: "a1", exam_mode: false, started_at: new Date("2026-10-20T10:00:00Z"), time_limit_minutes: 15,
  transcript: [{ role: "student" as const, text: "When did it start?" }, { role: "patient" as const, text: "Last night." }],
  revealed_facts: ["f1"], examined: ["x1"], ordered_tests: [{ id: "cbc", at: "2026-10-20T10:05:00Z" }],
};

Deno.test("a left case comes back with its conversation, findings, results and progress", () => {
  const s = resumeState(attempt, content, ["ct_head"]);
  assertEquals(s.transcript.length, 2);
  assertEquals(s.revealed, [{ id: "f1", label: "Onset" }]);
  assertEquals(s.coverage, { got: 1, total: 2 });
  assertEquals(s.examined, [{ id: "x1", finding: "Tender right lower quadrant." }]);
  assertEquals(s.ordered, [{ id: "cbc", at: "2026-10-20T10:05:00Z", result: "WBC 14.2", abnormal: true }]);
  assertEquals(s.started_at, "2026-10-20T10:00:00.000Z");
  assertEquals(s.hidden_tests, ["ct_head"]);
});

Deno.test("exam mode keeps progress hidden on the way back, as it does during the case", () => {
  const s = resumeState({ ...attempt, exam_mode: true }, content, []);
  assertEquals(s.revealed, []);
  assertEquals(s.coverage, { got: 0, total: 0 });
  assertEquals(s.examined.length, 1);
});

Deno.test("ids the case no longer has are dropped, not sent as blanks", () => {
  const s = resumeState({ ...attempt, examined: ["x1", "gone"], ordered_tests: [{ id: "old", at: "t" }] }, content, []);
  assertEquals(s.examined.map((e) => e.id), ["x1"]);
  assertEquals(s.ordered, []);
});
