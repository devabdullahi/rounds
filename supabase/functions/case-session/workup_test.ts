import { assertEquals } from "jsr:@std/assert@1";
import { workupText } from "./workup.ts";

const tests = [
  { id: "ecg", name: "ECG", abnormal: true },
  { id: "troponin", name: "Troponin", abnormal: false },
  { id: "cbc", name: "CBC", abnormal: false },
];
const exam = [{ id: "heart", title: "Heart sounds" }, { id: "lungs", title: "Lung exam" }];

Deno.test("lists ordered tests in order, abnormal marked, and exam steps done", () => {
  assertEquals(
    workupText(tests, exam, ["troponin", "ecg"], ["lungs"]),
    "Tests ordered: Troponin; ECG (abnormal)\nExam done: Lung exam",
  );
});

Deno.test("says none when nothing was done, and skips unknown ids", () => {
  assertEquals(workupText(tests, exam, ["gone"], []), "Tests ordered: (none)\nExam done: (none)");
});
