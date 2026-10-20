import { assert, assertEquals } from "jsr:@std/assert@1";
import { hints, patientConcerns } from "./concerns.ts";

const fixed = () => 0.1;

Deno.test("a patient gets an idea, a worry, a hope and two questions to ask", () => {
  const c = patientConcerns({ systems: ["gastrointestinal"], surgical: false, age: 45, banned: ["appendicitis"] }, fixed);
  assertEquals(c.facts.map((f) => f.label), ["What they think it is", "What worries them", "What they're hoping for"]);
  assert(c.facts.every((f) => f.importance === "optional"), "concerns don't change grading");
  assertEquals(c.asks.length, 2);
  assert(c.asks[0] !== c.asks[1]);
});

Deno.test("surgical cases ask about surgery; children's concerns are the parent's", () => {
  assertEquals(patientConcerns({ systems: [], surgical: true, age: 30, banned: [] }, fixed).asks[0], "Will I need surgery?");
  const child = patientConcerns({ systems: ["respiratory"], surgical: false, age: 6, banned: [] }, fixed);
  assert(child.facts.every((f) => f.content.startsWith("The parent") || f.label === "What they're hoping for"));
});

Deno.test("the lay guess never shares a word with the diagnosis", () => {
  assert(hints("heartburn", ["heartburn", "reflux"]));
  assert(!hints("a pulled muscle", ["myocardial", "infarction"]));
  for (let i = 0; i < 20; i++) {
    const c = patientConcerns({ systems: ["cardiovascular"], surgical: false, age: 60, banned: ["heartburn", "muscle"] }, () => i / 20);
    const idea = c.facts.find((f) => f.label === "What they think it is");
    assert(!idea || (!idea.content.includes("heartburn") && !idea.content.includes("muscle")), idea?.content);
  }
});
