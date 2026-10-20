// The patient model's input for one question. Kept apart from case-session so the exact same
// text can be replayed against real transcripts when the patient's behavior is tuned.
//
// Two kinds of knowledge go in:
//   facts      the history the patient can tell, each with an id (reveals a chip when used)
//   visible    what anyone could see on the body by looking, from the case's exam findings, so
//              "where is it?" and "how big?" get an answer instead of "I'm not sure". The prompt
//              limits the patient to plain-word looks: never results that need pressing,
//              instruments or tests, which stay behind the Examine tab.

/** `asks`: questions the patient may put to the doctor (older cases have none). */
export type PromptPersona = { name: string; age: string | number; sex: string; voice: string; background: string; asks?: string[] };

/** The patient's questions for the doctor, as one prompt line (nothing when there are none). */
function asksLine(persona: PromptPersona): string {
  return persona.asks?.length ? `\nQuestions you may ask the doctor (each at most once): ${JSON.stringify(persona.asks)}` : "";
}
export type PromptFact = { id: string; reply: string };
export type PromptManeuver = { id: string; finding: string };
export type PromptTurn = { role: string; text: string };

export function patientPrompt(
  persona: PromptPersona,
  facts: PromptFact[],
  exam: PromptManeuver[],
  recent: PromptTurn[],
  question: string,
  told: ReadonlySet<string> = new Set(),
): string {
  // `told` marks facts already shared, so a long visit stays consistent ("like I said, Sunday").
  return `You are ${persona.name}, ${persona.age}, ${persona.sex === "F" ? "female" : "male"}.
Voice: ${persona.voice}
Background: ${persona.background}${asksLine(persona)}
Facts you may reveal: ${JSON.stringify(facts.map(({ id, reply }) => (told.has(id) ? { id, content: reply, told: true } : { id, content: reply })))}
What can be seen on the body (clinical notes; describe only what anyone could see by looking, in plain words): ${JSON.stringify(exam.map(({ id, finding }) => ({ id, note: finding })))}
Conversation so far: ${JSON.stringify(recent.map(({ role, text }) => ({ role, text })))}
Student's latest message: ${JSON.stringify(question)}`;
}

/** The live voice session's instructions: the rules, then who the patient is, how they sound, what
 *  they may reveal and the conversation so far (typed questions carry over into voice). Never the
 *  diagnosis or the rubric. */
export function liveSessionPrompt(
  rules: string,
  persona: PromptPersona,
  howTheySound: string,
  facts: PromptFact[],
  exam: PromptManeuver[],
  recent: PromptTurn[],
): string {
  return `${rules}

You are ${persona.name}, ${persona.age}, ${persona.sex === "F" ? "female" : "male"}.
How you sound: ${howTheySound}
Background: ${persona.background}${asksLine(persona)}
Facts you may reveal: ${JSON.stringify(facts.map(({ reply }) => reply))}
What can be seen on the body (clinical notes; describe only what anyone could see by looking, in plain words): ${JSON.stringify(exam.map(({ finding }) => finding))}
Conversation so far: ${JSON.stringify(recent.map(({ role, text }) => ({ role, text })))}`;
}

/** One finished live-voice exchange for the reviewer: the facts and notes with ids, then what was said. */
export function voiceTurnPrompt(facts: PromptFact[], exam: PromptManeuver[], question: string, reply: string): string {
  return `Facts: ${JSON.stringify(facts.map(({ id, reply }) => ({ id, content: reply })))}
Visible notes: ${JSON.stringify(exam.map(({ id, finding }) => ({ id, note: finding })))}
Student said: ${JSON.stringify(question)}
Patient replied: ${JSON.stringify(reply)}`;
}
