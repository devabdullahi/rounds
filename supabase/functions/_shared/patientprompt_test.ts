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

Deno.test("facts already told are marked, and the patient's questions are listed", () => {
  const prompt = patientPrompt(
    { name: "Ray", age: 58, sex: "M", voice: "plain", background: "retired", asks: ["Is this serious?"] },
    [{ id: "f1", reply: "Started Sunday." }, { id: "f2", reply: "No fever." }], [], [], "When did it start?", new Set(["f1"]),
  );
  assert(prompt.includes('{"id":"f1","content":"Started Sunday.","told":true}'));
  assert(prompt.includes('{"id":"f2","content":"No fever."}'));
  assert(prompt.includes('Questions you may ask the doctor (each at most once): ["Is this serious?"]'));
});

Deno.test("an older case without questions adds no questions line", () => {
  const prompt = patientPrompt({ name: "Ray", age: 58, sex: "M", voice: "plain", background: "retired" }, [], [], [], "Hi");
  assert(!prompt.includes("Questions you may ask"));
});
