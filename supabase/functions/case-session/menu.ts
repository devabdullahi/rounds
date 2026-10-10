// Which tests a student sees. Practice mode teaches the workup, so tests the condition doesn't call
// for are left off the menu; exam mode shows the full menu, decoys included, and grading penalizes
// ordering them. The ids come from the private rubric, so they're sent per attempt, never stored
// with the public case.

import type { Rubric } from "./grade.ts";

/** Test ids hidden from this attempt's menu: the not-indicated ones in practice, none in exam mode. */
export function hiddenTests(rubric: Pick<Rubric, "unnecessary_tests">, examMode: boolean): string[] {
  return examMode ? [] : rubric.unnecessary_tests.map((t) => t.id);
}
