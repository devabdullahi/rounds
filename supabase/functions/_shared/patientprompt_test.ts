import { assert, assertStringIncludes } from "jsr:@std/assert@1";
import { liveSessionPrompt, patientPrompt, voiceTurnPrompt } from "./patientprompt.ts";

const persona = { name: "Dana", age: 34, sex: "F", voice: "calm", background: "teacher" };

Deno.test("the patient sees its facts and what can be seen on the body", () => {
  const prompt = patientPrompt(persona, [{ id: "f01", reply: "Since birth." }],
    [{ id: "x06", finding: "A single 2 cm lesion on the left buttock." }], [], "Where is it?");
  assertStringIncludes(prompt, '"id":"f01"');
  assertStringIncludes(prompt, '"id":"x06","note":"A single 2 cm lesion on the left buttock."');
  assertStringIncludes(prompt, 'Student\'s latest message: "Where is it?"');
});

Deno.test("maneuver titles stay out: the patient doesn't learn what the student could do", () => {
  const prompt = patientPrompt(persona, [], [{ id: "x04", finding: "Blanches." }], [], "Hi");
  assert(!prompt.includes("Press the lesion"));
});

Deno.test("the live patient gets the rules and its facts, without fact ids", () => {
  const prompt = liveSessionPrompt("RULES", persona, "a calm 34-year-old woman", [{ id: "f01", reply: "Since birth." }],
    [{ id: "x06", finding: "A lesion on the left buttock." }], [{ role: "student", text: "Hi" }]);
  assert(prompt.startsWith("RULES"));
  assertStringIncludes(prompt, '"Since birth."');
  assertStringIncludes(prompt, "A lesion on the left buttock.");
  assert(!prompt.includes("f01"));
  assert(!prompt.includes("x06"));
});

Deno.test("the voice-turn reviewer sees ids so it can name the facts a reply used", () => {
  const prompt = voiceTurnPrompt([{ id: "f01", reply: "Since birth." }], [], "How long?", "I've had it since I was born.");
  assertStringIncludes(prompt, '"id":"f01"');
  assertStringIncludes(prompt, 'Patient replied: "I\'ve had it since I was born."');
});
