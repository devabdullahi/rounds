import { assertEquals } from "jsr:@std/assert@1";
import { buildRows, studyAbnormal } from "./rows.ts";
import { planCase, type PlannedTest, type Profile } from "../_shared/casegen.ts";
import { isChestXray, type ScanAsset } from "../_shared/scans.ts";
import { parseFocus } from "../_shared/focus.ts";
import { applyScan } from "./scan.ts";
import { buildSkeleton } from "./skeleton.ts";
import { templateVoice } from "./template.ts";
import { assemble } from "./writer.ts";

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

Deno.test("a study with a real image keeps its report word for word and its asset id, off the menu", () => {
  const profile = JSON.parse(Deno.readTextFileSync(new URL("../../../knowledge-base/profiles/pneumonia.json", import.meta.url))) as Profile;
  const planned = planCase(profile, seeded(7));
  const cxr = planned.tests.find((t) => isChestXray(t.name))!;
  const report = "Airspace opacity in the right lower zone. No pneumothorax.";
  const asset: ScanAsset = {
    id: "4f6c1d2e-0000-4000-8000-000000000001", object_name: "4f6c1d2e.jpg", finding: "opacity", side: "right", zone: "lower",
    view: "PA", age: planned.age, sex: planned.sex === "F" ? "female" : "male", report,
  };
  const plan = applyScan(planned, asset, []);
  const skeleton = buildSkeleton(profile, plan, null, seeded(3));
  const writing = assemble(skeleton, templateVoice(profile, plan, skeleton, null, seeded(5)), "Ana Ruiz");
  const rows = buildRows(profile, ["internalMedicine"], ["respiratory"], [], plan, writing, parseFocus(""), null, "template");
  const stored = rows.content.tests.find((t: { id: string }) => t.id === cxr.id);
  assertEquals(stored.result, report);
  assertEquals(stored.abnormal, true);
  assertEquals(stored.scan_asset_id, asset.id);
  assertEquals(rows.content.tests.filter((t: { scan_asset_id: string | null }) => t.scan_asset_id !== null).length, 1);
  for (const item of rows.case.test_menu) assertEquals("scan_asset_id" in item, false);
});

/** A repeatable random source, so the planned patient is the same every run. */
function seeded(seed: number): () => number {
  let s = seed;
  return () => (s = (s * 16807) % 2147483647) / 2147483647;
}
