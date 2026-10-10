import { assert, assertEquals } from "jsr:@std/assert@1";
import { grade, isSingleDiagnosis, matchesDiagnosis, PASSING_SCORE, type Rubric, unrated } from "./grade.ts";

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
  const g = grade(rubric, { revealed: ["onset", "migration", "appetite", "lmp"], examined: ["rlq"], ordered: ["hcg", "cbc"] }, right);
  assertEquals(g.score, 100);
  assertEquals(g.verdict, "Textbook workup");
  assertEquals(g.missed_red_flags, []);
});

Deno.test("missing a must-not-miss screen is reported first", () => {
  const g = grade(rubric, { revealed: ["onset", "migration", "appetite"], examined: ["rlq"], ordered: ["cbc"] }, right);
  assertEquals(g.missed_red_flags.map((m) => m.flag), ["Ectopic pregnancy"]);
  assertEquals(g.feedback[0].covers_miss, "Ectopic pregnancy");
  assert(g.score < 100);
});

Deno.test("one question screens a condition even when several facts could", () => {
  const r = { ...rubric, red_flags: [...rubric.red_flags, { fact: "bleeding", flag: "Ectopic pregnancy", why: "x" }] };
  const g = grade(r, { revealed: ["bleeding"], examined: [], ordered: [] }, right);
  assertEquals(g.missed_red_flags, []);
});

Deno.test("unneeded tests and a wrong diagnosis cost points", () => {
  const g = grade(rubric, { revealed: [], examined: [], ordered: ["abdominal_x_ray"] },
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

Deno.test("the breakdown shows where points went and adds up to the score", () => {
  const full = grade(rubric, { revealed: ["onset", "migration", "appetite", "lmp"], examined: ["rlq"], ordered: ["hcg", "cbc"] }, right);
  for (const part of Object.values(full.breakdown)) assertEquals(part.got, part.max);
  assertEquals(Object.values(full.breakdown).reduce((s, p) => s + p.max, 0), 100);

  const partial = grade(rubric, { revealed: ["onset"], examined: [], ordered: ["cbc"] }, right);
  assertEquals(partial.breakdown.exam, { got: 0, max: 15 });
  assertEquals(partial.breakdown.diagnosis, { got: 35, max: 35 });
  // The score is what the parts earned, raised to the passing floor for a right diagnosis.
  assertEquals(Math.max(PASSING_SCORE, Object.values(partial.breakdown).reduce((s, p) => s + p.got, 0)), partial.score);
});

Deno.test("test penalties never show as negative points", () => {
  const g = grade(rubric, { revealed: [], examined: [], ordered: ["abdominal_x_ray"] },
    { diagnosisCorrect: false, planAppropriate: false, planNote: "" });
  assertEquals(g.breakdown.tests.got, 0);
});

const appendicitis = ["Acute appendicitis", "Appendicitis"];
const mi = ["Myocardial infarction", "MI", "Heart attack"];
const matching: [string, string[], boolean][] = [
  // one right answer, however it's hedged or written
  ["Appendicitis", appendicitis, true],
  ["probably acute appendicitis", appendicitis, true],
  ["Most likely appendicitis.", appendicitis, true],
  ["MI", mi, true],
  ["Acute MI", mi, true],
  ["heart attack", mi, true],
  ["Hand, foot and mouth disease", ["Hand, foot and mouth disease"], true],
  // one wrong answer
  ["Mesenteric adenitis", appendicitis, false],
  ["STEMI", ["MI"], false],
  ["Mild", appendicitis, false],
  // shotgun lists
  ["pneumonia, PE, MI, appendicitis", appendicitis, false],
  ["appendicitis or ovarian torsion", appendicitis, false],
  ["Appendicitis / diverticulitis", appendicitis, false],
  ["MI and PE", mi, false],
  ["appendicitis vs mesenteric adenitis", appendicitis, false],
  // negations
  ["not appendicitis", appendicitis, false],
  ["Rule out appendicitis", appendicitis, false],
  ["r/o MI", mi, false],
  ["no MI", mi, false],
  ["not acute appendicitis", appendicitis, false],
];
for (const [answer, accepted, want] of matching) {
  Deno.test(`diagnosis match: ${JSON.stringify(answer)} → ${want}`, () => assertEquals(matchesDiagnosis(answer, accepted), want));
}

const single: [string, boolean][] = [
  ["Appy", true],
  ["probably an inflamed appendix", true],
  ["appendicitis, PE", false],
  ["not PE", false],
  ["r/o appendicitis", false],
];
for (const [answer, want] of single) {
  Deno.test(`single diagnosis: ${JSON.stringify(answer)} → ${want}`, () => assertEquals(isSingleDiagnosis(answer), want));
}

Deno.test("a late submission is graded and says it was over time", () => {
  const g = grade(rubric, { revealed: ["onset", "migration", "appetite", "lmp"], examined: ["rlq"], ordered: ["hcg", "cbc"], overTime: true }, right);
  assertEquals(g.score, 100);
  assertEquals(g.over_time, true);
  assertEquals(g.feedback[0].title, "Over the time limit");
});

Deno.test("a repeat attempt keeps its score but doesn't move the rating", () => {
  const first = grade(rubric, { revealed: ["onset", "migration", "appetite", "lmp"], examined: ["rlq"], ordered: ["hcg", "cbc"] }, right);
  assertEquals(first.rated, true);
  assert(first.rating_delta > 0);
  const again = unrated(first);
  assertEquals(again.score, first.score);
  assertEquals(again.rating_delta, 0);
  assertEquals(again.rated, false);
});

Deno.test("a right diagnosis always passes; a wrong one gets no floor", () => {
  const bare = { revealed: [], examined: [], ordered: [] };
  assertEquals(grade(rubric, bare, right).score, PASSING_SCORE);
  assert(grade(rubric, bare, { diagnosisCorrect: false, planAppropriate: true, planNote: "" }).score < PASSING_SCORE);
  const full = grade(rubric, { revealed: ["onset", "migration", "appetite", "lmp"], examined: ["rlq"], ordered: ["hcg", "cbc"] }, right);
  assertEquals(full.score, 100);
  assert(grade(rubric, bare, right).rating_delta > 0);
});
