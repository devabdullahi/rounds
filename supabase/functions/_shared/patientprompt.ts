// The patient model's input for one question. Kept apart from case-session so the exact same
// text can be replayed against real transcripts when the patient's behavior is tuned.
//
// Two kinds of knowledge go in:
//   facts      the history the patient can tell, each with an id (reveals a chip when used)
//   visible    what anyone could see on the body by looking, from the case's exam findings, so
//              "where is it?" and "how big?" get an answer instead of "I'm not sure". The prompt
//              limits the patient to plain-word looks: never results that need pressing,
//              instruments or tests, which stay behind the Examine tab.

export type PromptPersona = { name: string; age: string | number; sex: string; voice: string; background: string };
export type PromptFact = { id: string; reply: string };
export type PromptManeuver = { id: string; finding: string };
export type PromptTurn = { role: string; text: string };

export function patientPrompt(
  persona: PromptPersona,
  facts: PromptFact[],
  exam: PromptManeuver[],
  recent: PromptTurn[],
  question: string,
): string {
  return `You are ${persona.name}, ${persona.age}, ${persona.sex === "F" ? "female" : "male"}.
Voice: ${persona.voice}
Background: ${persona.background}
Facts you may reveal: ${JSON.stringify(facts.map(({ id, reply }) => ({ id, content: reply })))}
What can be seen on the body (clinical notes; describe only what anyone could see by looking, in plain words): ${JSON.stringify(exam.map(({ id, finding }) => ({ id, note: finding })))}
Conversation so far: ${JSON.stringify(recent.map(({ role, text }) => ({ role, text })))}
Student's latest message: ${JSON.stringify(question)}`;
}
