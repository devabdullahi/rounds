// What the patient brings into the room besides symptoms, the way OSCE patients are written: their
// idea of what's wrong, what worries them, what they're hoping for, and a couple of questions they'll
// ask the doctor. Built in code like the rest of the history, so it's planned (and auditable), and
// never names the diagnosis: the idea is a lay guess picked from the body system, checked against
// the diagnosis's words. Pure, so it's unit-tested.

import type { HistoryFact } from "./history.ts";

/** Lay guesses a patient makes, by organ system: plausible and usually wrong, never a diagnosis. */
const IDEAS: Record<string, string[]> = {
  cardiovascular: ["heartburn", "a pulled muscle from lifting something"],
  respiratory: ["a cold that won't go away", "allergies acting up"],
  gastrointestinal: ["something they ate", "a stomach bug going around"],
  nervous: ["stress", "not sleeping enough"],
  musculoskeletal: ["overdoing it", "sleeping in a bad position"],
  renal: ["not drinking enough water"],
  reproductive: ["stress throwing their body off"],
  skin: ["a new soap or detergent", "a bug bite"],
  behavioral: ["just stress from everything going on"],
  endocrine: ["just getting older", "being run down"],
  blood: ["being run down"],
  ent: ["allergies acting up"],
  eye: ["allergies acting up", "too much screen time"],
};
const ANY_IDEA = ["a virus going around", "just stress"];

/** What worries them, in their words' substance. */
const WORRIES = [
  "that it's something serious, like cancer",
  "missing more work, since they can't afford the time off",
  "that it will keep coming back",
  "how they'll keep up with everything at home",
];
const CHILD_WORRIES = ["that it's something serious", "the child missing more school"];

/** What they're hoping the visit gives them. */
const HOPES = [
  "Hoping to find out what's causing it.",
  "Hoping for something to make them feel better soon.",
  "Hoping for tests to make sure it's nothing serious.",
  "Hoping to get back to work as soon as possible.",
];

/** Questions a patient asks the doctor back. Surgery comes up only on surgical cases. */
const QUESTIONS = ["Is this something serious?", "What do you think is causing it?", "Do I need any tests?", "When will I feel better?"];
const SURGICAL_QUESTION = "Will I need surgery?";
const WORK_QUESTION = "Can I still go to work?";

export type Concerns = { facts: HistoryFact[]; asks: string[] };

const pickFrom = <T>(list: T[], rng: () => number): T => list[Math.floor(rng() * list.length) % list.length];

/** Whether a lay guess shares a word with the diagnosis (or its names), so it can't hint at it. */
export function hints(idea: string, banned: string[]): boolean {
  const words = idea.toLowerCase().split(/[^a-z]+/).filter((w) => w.length >= 4);
  return banned.some((b) => words.some((w) => b.toLowerCase().includes(w) || w.includes(b.toLowerCase())));
}

/**
 * The patient's idea, worry and hope as facts, and two questions they'll ask. Children's are the
 * parent's. `banned` holds the diagnosis's words; an idea that shares one is never used.
 */
export function patientConcerns(
  input: { systems: string[]; surgical: boolean; age: number; banned: string[] }, rng: () => number,
): Concerns {
  const child = input.age < 13;
  const ideas = [...input.systems.flatMap((s) => IDEAS[s] ?? []), ...ANY_IDEA].filter((i) => !hints(i, input.banned));
  const idea = ideas.length ? pickFrom(ideas, rng) : null;
  const worry = pickFrom(child ? CHILD_WORRIES : WORRIES, rng);
  const hope = pickFrom(HOPES, rng);

  const facts: HistoryFact[] = [];
  if (idea) facts.push({ label: "What they think it is", content: `${child ? "The parent thinks" : "Thinks"} it might be ${idea}, but isn't sure.`, importance: "optional" });
  facts.push({ label: "What worries them", content: `${child ? "The parent is" : "Is"} worried ${worry}.`, importance: "optional" });
  facts.push({ label: "What they're hoping for", content: hope, importance: "optional" });

  // Two questions: one that fits the case if there is one, then a general one.
  const fitting = input.surgical ? SURGICAL_QUESTION : worry.includes("work") && !child ? WORK_QUESTION : null;
  const general = pickFrom(QUESTIONS, rng);
  const asks = fitting ? [fitting, general] : [general, pickFrom(QUESTIONS.filter((q) => q !== general), rng)];
  return { facts, asks };
}
