// The part of a debrief seen through the student's exam: the same case, taught the way their exam
// asks about it. Built from the condition profile at submit, so it's only ever shown after grading.
// Pure, so the choices are tested.
//
//   Step 2 CK, shelf: the next best steps (the profile's decision points)
//   OSCE:             the questions that mattered (the profile's essential key questions)
//   Step 1:           complications to know, each with a clue (the profile's complications)
//   anything else:    no lens

/** The study goals the app sends (StudyGoal raw values). */
export const GOALS = ["step1", "step2CK", "shelf", "osce", "other", "practicing"] as const;
export type Goal = typeof GOALS[number];

/** The parts of a condition profile the lens reads; each is optional on older profiles. */
export type LensProfile = {
  workup?: { decision_points?: string[] };
  teaching?: { key_questions?: { question: string; importance?: string }[] };
  course?: { complications?: { name: string; clues?: string[] }[] };
};

export type Lens = { title: string; points: string[] };

const MAX_POINTS = 3;
const MAX_QUESTIONS = 4;

export function examLens(profile: LensProfile, goal: Goal | null): Lens | null {
  const lens = build(profile, goal);
  return lens && lens.points.length > 0 ? lens : null;
}

function build(profile: LensProfile, goal: Goal | null): Lens | null {
  const clean = (items: (string | undefined)[]) => items.map((s) => s?.trim() ?? "").filter(Boolean);
  switch (goal) {
    case "step2CK":
    case "shelf":
      return {
        title: goal === "step2CK" ? "For Step 2 CK: next best steps" : "For your shelf: next best steps",
        points: clean(profile.workup?.decision_points ?? []).slice(0, MAX_POINTS),
      };
    case "osce": {
      const questions = profile.teaching?.key_questions ?? [];
      // Essential questions first, keeping the profile's order within each group.
      const ordered = [...questions.filter((q) => q.importance === "essential"), ...questions.filter((q) => q.importance !== "essential")];
      return { title: "For your OSCE: questions that mattered", points: clean(ordered.map((q) => q.question)).slice(0, MAX_QUESTIONS) };
    }
    case "step1":
      return {
        title: "For Step 1: complications to know",
        points: clean((profile.course?.complications ?? []).map((c) => {
          const clue = c.clues?.find((s) => s.trim());
          return c.name?.trim() ? (clue ? `${c.name.trim()}: ${clue.trim().replace(/^./, (x) => x.toLowerCase())}` : c.name.trim()) : undefined;
        })).slice(0, MAX_POINTS),
      };
    default:
      return null;
  }
}

/** The goal the app sent, or null when it's missing or not one we know. */
export function parseGoal(value: unknown): Goal | null {
  return typeof value === "string" && (GOALS as readonly string[]).includes(value) ? value as Goal : null;
}
