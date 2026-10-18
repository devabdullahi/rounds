// What the student already did during the case, in words the grader can read. The plan is judged
// alongside it: a student who ordered troponin at the bedside shouldn't be told their plan forgot it.

/** The tests ordered (in order, with abnormal results marked) and exam steps done, one line each;
 *  ids no longer on the case are skipped. */
export function workupText(
  tests: { id: string; name: string; abnormal: boolean }[],
  exam: { id: string; title: string }[],
  ordered: string[],
  examined: string[],
): string {
  const testNames = ordered.flatMap((id) => {
    const t = tests.find((x) => x.id === id);
    return t ? [t.abnormal ? `${t.name} (abnormal)` : t.name] : [];
  });
  const examTitles = examined.flatMap((id) => exam.find((m) => m.id === id)?.title ?? []);
  return [
    `Tests ordered: ${testNames.join("; ") || "(none)"}`,
    `Exam done: ${examTitles.join("; ") || "(none)"}`,
  ].join("\n");
}
