import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { careFor, historyFacts, priorCare } from "./history.ts";

const fixed = () => 0.5;

Deno.test("each common condition gets its age, medicine and what the doctor said", () => {
  const facts = historyFacts(["Essential hypertension", "Diabetes mellitus type 2"], [], [], fixed);
  const pmh = facts.find((f) => f.label === "Past medical history")!;
  assertStringIncludes(pmh.content, "high blood pressure (for about 8 years)");
  const bp = facts.find((f) => f.label === "High blood pressure")!;
  assertStringIncludes(bp.content, "lisinopril 10 mg once a day");
  assertStringIncludes(bp.content, "primary care doctor");
  const meds = facts.find((f) => f.label === "Medications")!;
  assertEquals(meds.content, "Takes lisinopril 10 mg once a day; metformin 500 mg twice a day with meals. Takes them as prescribed.");
});

Deno.test("a record's own medicines win, and conditions don't add made-up ones", () => {
  const facts = historyFacts(["Hypertension"], ["amlodipine 5 mg"], [], fixed);
  assertStringIncludes(facts.find((f) => f.label === "Medications")!.content, "amlodipine 5 mg");
  assert(!facts.some((f) => f.content.includes("lisinopril")));
});

Deno.test("the same condition named twice is told once", () => {
  const facts = historyFacts(["Anxiety disorder", "Generalized anxiety"], [], [], fixed);
  assertEquals(facts.filter((f) => f.label === "Anxiety").length, 1);
});

Deno.test("an uncommon condition keeps its age and gets no invented medicine", () => {
  const facts = historyFacts(["Sarcoidosis"], [], [], fixed);
  assertStringIncludes(facts[0].content, "sarcoidosis (for about 8 years)");
  assertEquals(facts.find((f) => f.label === "Medications")!.content, "Takes no regular medications, prescription or over the counter.");
  assertEquals(careFor("Sarcoidosis"), null);
});

Deno.test("allergies say what happened", () => {
  const facts = historyFacts([], [], ["Penicillin V", "Bee venom"], fixed);
  assertEquals(facts.find((f) => f.label === "Allergies")!.content, "Allergic to penicillin: broke out in hives. Allergic to bee venom: swelled up a lot.");
});

Deno.test("a healthy patient says so", () => {
  const facts = historyFacts([], [], [], fixed);
  assertEquals(facts.map((f) => f.label), ["Past medical history", "Medications", "Allergies"]);
});

Deno.test("care so far is one of the safe stories", () => {
  for (const r of [0, 0.4, 0.99]) assert(priorCare(() => r).content.length > 20);
});
