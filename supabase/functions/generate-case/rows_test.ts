import { assertEquals } from "jsr:@std/assert@1";
import { studyAbnormal } from "./rows.ts";
import type { PlannedTest } from "../_shared/casegen.ts";

const study = (extra: Partial<PlannedTest> = {}): PlannedTest => ({ id: "stool_culture", name: "Stool culture", kind: "study", role: "indicated", ...extra });

Deno.test("a negative report is never flagged abnormal", () => {
  assertEquals(studyAbnormal(study(), { result: "No enteric bacterial pathogen isolated.", abnormal: true }), false);
  assertEquals(studyAbnormal(study(), { result: "Shiga toxin not detected.", abnormal: true }), false);
  assertEquals(studyAbnormal(study(), { result: "Negative.", abnormal: true }), false);
});

Deno.test("a planned-positive test is abnormal; other reports keep the writer's flag", () => {
  assertEquals(studyAbnormal(study({ positive: true }), { result: "Growth of E. coli O157:H7.", abnormal: false }), true);
  assertEquals(studyAbnormal(study(), { result: "Colonic wall thickening.", abnormal: true }), true);
});
