import { assert, assertEquals } from "jsr:@std/assert@1";
import { grade, matchesDiagnosis, type Rubric } from "./grade.ts";

const rubric: Rubric = {
  diagnosis: "Acute appendicitis", accepted: ["Appendicitis"], reasoning_points: ["Migrating pain", "RLQ tenderness"], severity: "moderate",
  key_facts: [{ id: "onset", label: "onset", weight: 2 }, { id: "migration", label: "pain migration", weight: 2 }, { id: "appetite", label: "appetite", weight: 1 }],
  red_flags: [{ fact: "lmp", flag: "Ectopic pregnancy", why: "Any patient who could be pregnant." }],
  key_maneuvers: [{ id: "rlq", title: "Palpate the abdomen" }],
  indicated_tests: [{ id: "cbc", name: "CBC" }, { id: "hcg", name: "hCG" }],
  first_tests: ["cbc", "hcg"],
  unnecessary_tests: [{ id: "abdominal_x_ray", name: "Abdominal x-ray", why: "Rarely changes management" }],
  must_not_miss: ["Ectopic pregnancy"],
};
const right = { diagnosisCorrect: true, planAppropriate: true, planNote: "" };

Deno.test("a complete workup scores 100", () => {
  const g = grade(rubric, { revealed: ["onset", "migration", "appetite", "lmp"], examined: ["rlq"], ordered: ["hcg", "cbc"], spent: 50, budget: 300 }, right);
  assertEquals(g.score, 100);
  assertEquals(g.verdict, "Textbook workup");
  assertEquals(g.missed_red_flags, []);
});

Deno.test("missing a must-not-miss screen is reported first", () => {
  const g = grade(rubric, { revealed: ["onset", "migration", "appetite"], examined: ["rlq"], ordered: ["cbc"], spent: 30, budget: 300 }, right);
  assertEquals(g.missed_red_flags.map((m) => m.flag), ["Ectopic pregnancy"]);
  assertEquals(g.feedback[0].covers_miss, "Ectopic pregnancy");
  assert(g.score < 100);
});

Deno.test("one question screens a condition even when several facts could", () => {
  const r = { ...rubric, red_flags: [...rubric.red_flags, { fact: "bleeding", flag: "Ectopic pregnancy", why: "x" }] };
  const g = grade(r, { revealed: ["bleeding"], examined: [], ordered: [], spent: 0, budget: 300 }, right);
  assertEquals(g.missed_red_flags, []);
});

Deno.test("unneeded tests, budget and a wrong diagnosis cost points", () => {
  const g = grade(rubric, { revealed: [], examined: [], ordered: ["abdominal_x_ray"], spent: 500, budget: 300 },
    { diagnosisCorrect: false, planAppropriate: false, planNote: "No plan was given." });
  assertEquals(g.score, 0);
  assertEquals(g.verdict, "Missed diagnosis");
  assert(g.feedback.some((f) => f.title === "Abdominal x-ray wasn't indicated"));
});

Deno.test("diagnosis matching accepts names inside longer answers only on word boundaries", () => {
  assert(matchesDiagnosis("Acute appendicitis, uncomplicated", ["Appendicitis"]));
  assert(matchesDiagnosis("APPENDICITIS", ["Appendicitis"]));
  assert(!matchesDiagnosis("Mesenteric adenitis", ["Appendicitis"]));
});
