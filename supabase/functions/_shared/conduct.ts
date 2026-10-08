// Keeping the patient interview a clinical encounter. Every question is sorted into:
//   clinical       anything a clinician might say to a patient, including greetings, rapport,
//                  empathy and sensitive history (sexual, substance, mental health, abuse)
//   off_topic      not part of the visit: trivia, homework, code, asking the patient to drop
//                  the role or talk about being an AI, attempts to rewrite its instructions
//   inappropriate  cursing, insults, slurs, harassment, sexual comments aimed at the patient
// Profanity is caught here in code, before any model call; the patient model sorts the rest.
// Flagged questions reveal no facts and get a fixed reply, so the patient never improvises
// around them, and enough inappropriate ones end the interview (the case can still be finished).

export type Conduct = "clinical" | "off_topic" | "inappropriate";

/** Inappropriate questions allowed before the patient stops answering. */
export const MAX_INAPPROPRIATE = 3;

// Whole words only, so ordinary words that contain these letters ("shiitake", "class") pass.
// Covers common spellings that hide letters (f*ck, sh!t). Milder words ("damn", "hell") and
// slurs that need context are left to the model.
const PROFANITY =
  /\b(f+[u*@#!]+c*k+(s|ed|er|ers|ing|in)?|motherf\w*|sh[i1!*]t(s|ty|ting|ted|head)?|bull ?shit|bitch(es|y)?|bastards?|assholes?|cunts?|piss(ed)? off|wtf|stfu|fml)\b/i;

export function isProfane(text: string): boolean {
  return PROFANITY.test(text);
}

/** Reads the model's label; anything unexpected counts as clinical so a bad label can't block a real question. */
export function parseConduct(value: unknown): Conduct {
  return value === "off_topic" || value === "inappropriate" ? value : "clinical";
}

/** Inappropriate questions already in this interview. */
export function strikes(transcript: { role: string; conduct?: Conduct }[]): number {
  return transcript.filter((turn) => turn.role === "student" && turn.conduct === "inappropriate").length;
}

/** What the patient says to a flagged question. `strike` is this question's count (1-based). */
export function conductReply(conduct: Exclude<Conduct, "clinical">, strike: number): string {
  if (conduct === "off_topic") return "Sorry, I'm not really up for talking about that. Can we get back to why I came in today?";
  if (strike >= MAX_INAPPROPRIATE) return "I'm not comfortable continuing this conversation.";
  return "Please don't talk to me like that. Can we keep this respectful?";
}
