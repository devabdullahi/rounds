import { assert, assertEquals } from "jsr:@std/assert@1";
import { aiCaseProblems, aiCaseRows, aiOnlyListed, leakedFields } from "./aionly.ts";
import { parseFocus } from "../_shared/focus.ts";

const draft = () => ({
  diagnosis: "Acute appendicitis", accepted: ["Appendicitis"], severity: "moderate", clerkship: "surgery", organ_system: "gastrointestinal",
  reasoning_points: ["Pain migrated to the right lower quadrant"], must_not_miss: ["Ectopic pregnancy"],
  patient: { name: "Dana Reyes", age: 24, sex: "F", pregnant: false, quote: "My stomach hurts so bad.", complaint: "24-year-old woman with abdominal pain for 1 day.", demeanor: "Guarding, uncomfortable", setting: "Walk-in, emergency department" },
  vitals: { hr: 104, sbp: 122, dbp: 76, rr: 18, temp: 100.9, spo2: 99 },
  persona: { voice: "Plain words", background: "Barista.", fallback: "Sorry, what do you mean?", asks: ["Will I need surgery?"] },
  facts: Array.from({ length: 12 }, (_, i) => ({ id: `a${i}`, label: `Topic ${i}`, reply: `Reply ${i}.`, importance: i < 3 ? "essential" : "important", screens_for: i === 5 ? "Ectopic pregnancy" : null })),
  suggested: [{ text: "When did it start?", fact: "a0" }, { text: "Bad link", fact: "zz" }],
  maneuvers: Array.from({ length: 6 }, (_, i) => ({ id: `m${i}`, title: `Exam ${i}`, finding: "Normal.", key: i === 0 })),
  tests: [
    { id: "q1", name: "CBC", result: "WBC 14.2 x10^3/uL (4.5-11.0)", abnormal: true, role: "indicated" },
    { id: "q2", name: "CT abdomen and pelvis with IV contrast", result: "Dilated appendix with periappendiceal stranding.", abnormal: true, role: "indicated" },
    { id: "q3", name: "Urine hCG", result: "Negative.", abnormal: false, role: "indicated" },
    { id: "q4", name: "Lipase", result: "32 U/L (10-60)", abnormal: false, role: "neutral" },
    { id: "q5", name: "BMP", result: "Within normal limits.", abnormal: false, role: "neutral" },
    { id: "q6", name: "MRI brain", result: "Normal.", abnormal: false, role: "not_indicated", why: "No neurologic symptoms" },
  ],
});

Deno.test("a complete draft has no problems and maps to case rows", () => {
  const c = draft();
  assertEquals(aiCaseProblems(c), []);
  const rows = aiCaseRows(c, parseFocus("rotation:surgery"), "gpt-test");
  assertEquals(rows.case.clerkship, "surgery");
  assertEquals(rows.content.facts[0].id, "f1");
  assertEquals(rows.case.suggested, [{ text: "When did it start?", fact: "f1" }]);
  assertEquals(rows.content.rubric.indicated_tests.length, 3);
  assertEquals(rows.content.rubric.red_flags[0].flag, "Ectopic pregnancy");
  assertEquals(rows.content.condition_slug, null);
  assert(rows.case.vitals.find((v: { id: string }) => v.id === "temp").abnormal);
});

Deno.test("a draft naming the diagnosis where the student can see it is sent back", () => {
  const c = draft();
  c.facts[2].reply = "I read online it might be appendicitis.";
  assertEquals(leakedFields(c), ["fact a2 reply"]);
  assert(aiCaseProblems(c).some((p) => p.includes("fact a2 reply")));
});

Deno.test("test results may name the diagnosis", () => {
  const c = draft();
  c.tests[1].result = "Findings consistent with acute appendicitis.";
  assertEquals(aiCaseProblems(c), []);
});

Deno.test("missing pieces are listed for the rewrite", () => {
  const c = draft() as Record<string, unknown>;
  c.facts = [];
  c.severity = "awful";
  const problems = aiCaseProblems(c);
  assert(problems.includes("need at least 12 facts"));
  assert(problems.some((p) => p.startsWith("severity")));
});

Deno.test("only listed accounts get AI-only cases", () => {
  assertEquals(aiOnlyListed("ABC-1", null, "abc-1, def-2"), true);
  assertEquals(aiOnlyListed("xyz", "Sam@School.edu", "abc-1,sam@school.edu"), true);
  assertEquals(aiOnlyListed("xyz", "other@school.edu", "abc-1,sam@school.edu"), false);
  assertEquals(aiOnlyListed("abc-1", null, ""), false);
});
