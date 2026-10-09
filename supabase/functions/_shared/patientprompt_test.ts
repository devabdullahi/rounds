import { assert, assertStringIncludes } from "jsr:@std/assert@1";
import { patientPrompt } from "./patientprompt.ts";

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
