import { assertEquals } from "jsr:@std/assert@1";
import { examLens, parseGoal } from "./lens.ts";

const profile = {
  workup: { decision_points: ["Ultrasound first", " ", "Peritonitis goes to surgery", "Check the bile duct", "A fourth one"] },
  teaching: {
    key_questions: [
      { question: "Does the pain go anywhere?", importance: "important" },
      { question: "Where exactly is the pain?", importance: "essential" },
      { question: "Any fever?", importance: "essential" },
    ],
  },
  course: { complications: [{ name: "Perforation", clues: ["Sudden worsening of pain"] }, { name: "Abscess" }] },
};

Deno.test("Step 2 CK and shelf get the next best steps, blanks dropped, at most three", () => {
  assertEquals(examLens(profile, "step2CK"), { title: "For Step 2 CK: next best steps", points: ["Ultrasound first", "Peritonitis goes to surgery", "Check the bile duct"] });
  assertEquals(examLens(profile, "shelf")?.title, "For your shelf: next best steps");
});

Deno.test("OSCE gets the questions that mattered, essential ones first", () => {
  assertEquals(examLens(profile, "osce")?.points, ["Where exactly is the pain?", "Any fever?", "Does the pain go anywhere?"]);
});

Deno.test("Step 1 gets complications, each with its first clue", () => {
  assertEquals(examLens(profile, "step1")?.points, ["Perforation: sudden worsening of pain", "Abscess"]);
});

Deno.test("no goal, a general goal, or an empty profile gives no lens", () => {
  assertEquals(examLens(profile, null), null);
  assertEquals(examLens(profile, "practicing"), null);
  assertEquals(examLens({}, "step2CK"), null);
});

Deno.test("only known goals are accepted", () => {
  assertEquals(parseGoal("step2CK"), "step2CK");
  assertEquals(parseGoal("STEP2"), null);
  assertEquals(parseGoal(42), null);
});
