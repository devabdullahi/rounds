import { assertEquals, assertStrictEquals } from "jsr:@std/assert@1";
import { applyScan, scanWant } from "./scan.ts";
import type { CasePlan, PlannedTest } from "../_shared/casegen.ts";
import type { ScanAsset } from "../_shared/scans.ts";

const xray = (findings: string[]): PlannedTest => ({
  id: "cxr", name: "Chest X-ray", kind: "study", findings, role: "indicated",
});

const plan = (tests: PlannedTest[], exam: string[] = []): CasePlan => ({
  slug: "pneumonia", condition: "Pneumonia", severity: "moderate", severityText: "Moderate", age: 54, sex: "F",
  pregnant: false, symptomsPresent: [], symptomsAbsent: [],
  exam: exam.map((finding, i) => ({
    id: `e${i}`, region: "chest", finding, frequency: "common", significance: "", importance: "key", present: true,
  })),
  vitals: {} as CasePlan["vitals"], tests, psychology: false, dermatology: false,
});

const asset = (extra: Partial<ScanAsset> = {}): ScanAsset => ({
  id: "4f6c1d2e-0000-4000-8000-000000000001", object_name: "4f6c1d2e.jpg", finding: "opacity", side: "right",
  zone: "lower", view: "PA", age: 56, sex: "female",
  report: "Airspace opacity in the right lower zone. No pneumothorax.", ...extra,
});

Deno.test("a chosen asset becomes the chest X-ray's report and findings", () => {
  const before = plan([xray(["Right lower lobe consolidation"])]);
  const after = applyScan(before, asset(), []);
  const cxr = after.tests[0];
  assertEquals(cxr.findings, ["Airspace opacity in the right lower zone.", "No pneumothorax."]);
  assertEquals(cxr.scan_report, asset().report);
  assertEquals(cxr.scan_asset_id, asset().id);
  assertEquals(cxr.abnormal, true);
});

Deno.test("a normal asset's study is not abnormal", () => {
  const after = applyScan(plan([xray([])]), asset({ finding: "normal", side: null, report: "No acute cardiopulmonary abnormality." }), []);
  assertEquals(after.tests[0].abnormal, false);
});

Deno.test("no asset leaves the plan as it was", () => {
  const before = plan([xray(["Right lower lobe consolidation"])], ["Decreased breath sounds on the affected side"]);
  assertStrictEquals(applyScan(before, null, []), before);
});

Deno.test("an asset whose report names a banned term is not used", () => {
  const before = plan([xray(["Right pneumothorax"])]);
  assertStrictEquals(applyScan(before, asset({ finding: "pneumothorax", report: "Right pneumothorax." }), ["pneumothorax"]), before);
});

Deno.test("a plan without a chest X-ray is left as it was", () => {
  const before = plan([{ id: "ct", name: "Chest CT with IV contrast", kind: "study", findings: ["Consolidation"], role: "indicated" }]);
  assertStrictEquals(applyScan(before, asset(), []), before);
});

Deno.test("exam findings on the affected side take the image's side", () => {
  const before = plan([xray(["Right lower lobe consolidation"])], ["Decreased breath sounds on the affected side", "Rapid, shallow breathing"]);
  const after = applyScan(before, asset(), []);
  assertEquals(after.exam.map((f) => f.finding), ["Decreased breath sounds on the right side", "Rapid, shallow breathing"]);
});

Deno.test("a diffuse image leaves the affected side alone", () => {
  const before = plan([xray(["Pulmonary edema"])], ["Crackles on the affected side"]);
  const after = applyScan(before, asset({ finding: "edema", side: null, report: "Diffuse interstitial edema." }), []);
  assertEquals(after.exam[0].finding, "Crackles on the affected side");
});

Deno.test("what a case wants: positive findings only, its side, and the asset's sex words", () => {
  const p = plan([xray(["Normal chest x-ray early in the illness", "Right lower lobe consolidation"])]);
  assertEquals(scanWant(p), { test: p.tests[0], want: { finding: "opacity", side: "right", age: 54, sex: "female" } });
});

Deno.test("only negative findings want a normal film; diffuse findings want no side", () => {
  const normal = plan([xray(["No pneumothorax", "Without effusion"])]);
  assertEquals(scanWant(normal)?.want, { finding: "normal", side: null, age: 54, sex: "female" });
  const effusion = plan([xray(["Small right pleural effusion"])]);
  assertEquals(scanWant({ ...effusion, sex: "M" })?.want, { finding: "effusion", side: "right", age: 54, sex: "male" });
  const diffuse = plan([xray(["Kerley B lines"])], ["Crackles at the right base"]);
  assertEquals(scanWant(diffuse)?.want, { finding: "edema", side: null, age: 54, sex: "female" });
});

Deno.test("no chest X-ray or no library class means no want", () => {
  assertEquals(scanWant(plan([])), null);
  assertEquals(scanWant(plan([xray(["Cavitation"])])), null);
});
