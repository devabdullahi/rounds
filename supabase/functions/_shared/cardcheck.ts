// A backstop for card wording, behind the writer's prompt: it catches the mechanical mistakes (two
// questions on one front, the app's own labels leaking into a card) so the writer retries them. It
// can't judge whether a front carries every clue its answer needs; the prompt owns that.

/** The fact labels and planner terms a student would never say. */
const JARGON = /\bmust[- ]not[- ]miss alternative|\breasoning point|\bteaching point|\b(at|of) (mild|moderate|severe|critical) severity\b|\bfact set\b|\bdangerous look-alike of\b/i;

/** A second question joined to the first: "What should you suspect, and which drugs should you avoid?" */
const SECOND_QUESTION = /, and (what|which|should|how|is|does|do|when)\b[^?]*\?/i;

/** Why a card would confuse a student, or none. */
export function cardProblems(card: { front: string; back: string }): string[] {
  const problems: string[] = [];
  if ((card.front.match(/\?/g) ?? []).length > 1 || SECOND_QUESTION.test(card.front)) problems.push("asks more than one question");
  if (JARGON.test(card.front) || JARGON.test(card.back)) problems.push("uses an app label instead of plain clinical words");
  return problems;
}
