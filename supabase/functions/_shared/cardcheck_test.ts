import { assertEquals } from "jsr:@std/assert@1";
import { cardProblems } from "./cardcheck.ts";

const card = (front: string, back = "Sepsis.") => ({ front, back });

Deno.test("a plain one-question card passes", () => {
  assertEquals(cardProblems(card("In suspected pyelonephritis, what does hypotension with a heart rate of 128 indicate?")), []);
  assertEquals(cardProblems(card("Name two scores used before anticoagulating atrial fibrillation.", "CHA2DS2-VASc and HAS-BLED.")), []);
  // "and" inside one question isn't a second question.
  assertEquals(cardProblems(card("A woman has fever, flank pain, and dysuria. Which exam finding supports pyelonephritis?")), []);
});

Deno.test("two questions on one front are caught", () => {
  assertEquals(cardProblems(card("What must you suspect? Which drugs should you avoid?")), ["asks more than one question"]);
  assertEquals(cardProblems(card("What should you suspect, and which drugs should you avoid?")), ["asks more than one question"]);
  assertEquals(cardProblems(card("Which test confirms it, and should it be drawn before antibiotics?")), ["asks more than one question"]);
});

Deno.test("app labels on either face are caught", () => {
  const cases = [
    card("Which must-not-miss alternative causes colicky groin pain?"),
    card("What is the hemoglobin at moderate severity?"),
    card("What should you suspect?", "Reasoning point: obstruction."),
    card("What is a dangerous look-alike of appendicitis?"),
  ];
  for (const c of cases) assertEquals(cardProblems(c), ["uses an app label instead of plain clinical words"]);
});
