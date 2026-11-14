import { assertEquals, assertStrictEquals } from "jsr:@std/assert@1";
import { applyScan, scanWant } from "./scan.ts";
import type { CasePlan, PlannedTest } from "../_shared/casegen.ts";
import type { ScanAsset, ScanWant } from "../_shared/scans.ts";

const xray = (findings: string[]): PlannedTest => ({
  id: "cxr", name: "Chest X-ray", kind: "study", findings, role: "indicated",
});

/** Exam findings as text (a lung finding) or [region, text]. */
const plan = (tests: PlannedTest[], exam: (string | [string, string])[] = [], symptoms: string[] = []): CasePlan => ({
  slug: "pneumonia", condition: "Pneumonia", severity: "moderate", severityText: "Moderate", age: 54, sex: "F",
  pregnant: false, symptomsPresent: symptoms, symptomsAbsent: [],
  exam: exam.map((e, i) => {
    const [region, finding] = typeof e === "string" ? ["lung", e] : e;
    return { id: `e${i}`, region, finding, frequency: "common", significance: "", importance: "key", present: true };
  }),
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

const want = (extra: Partial<ScanWant> = {}): ScanWant => ({
  finding: "opacity", side: null, zone: null, view: "PA", age: 54, sex: "female", ...extra,
});

Deno.test("what a case wants: positive findings only, its side and zone, and the asset's sex words", () => {
  const p = plan([xray(["Normal chest x-ray early in the illness", "Right lower lobe consolidation"])]);
  assertEquals(scanWant(p), { test: p.tests[0], want: want({ side: "right", zone: "lower" }) });
});

Deno.test("an empty film wants a normal image; all-negated or hedged findings want none", () => {
  assertEquals(scanWant(plan([xray([])]))?.want, want({ finding: "normal" }));
  assertEquals(scanWant(plan([xray(["No pneumothorax", "Without effusion"])])), null);
  assertEquals(scanWant(plan([xray(["Usually normal; no infiltrate, pneumothorax, or mediastinal widening"])])), null);
  assertEquals(scanWant(plan([xray(["Clear lungs without focal consolidation, infiltrate, or pleural effusion"])])), null);
  assertEquals(scanWant(plan([xray(["Usually normal; may show cardiomegaly or pulmonary vascular congestion"])])), null);
  assertEquals(scanWant(plan([xray(["Usually normal; no vascular congestion"])])), null);
});

Deno.test("lateral findings take a side; diffuse findings want no side", () => {
  const effusion = plan([xray(["Small right pleural effusion"])]);
  assertEquals(scanWant({ ...effusion, sex: "M" })?.want, want({ finding: "effusion", side: "right", sex: "male" }));
  const diffuse = plan([xray(["Kerley B lines"])], ["Crackles at the right base"]);
  assertEquals(scanWant(diffuse)?.want, want({ finding: "edema" }));
});

Deno.test("a lateral finding on both sides wants no image", () => {
  assertEquals(scanWant(plan([xray(["Bilateral pleural effusions"])])), null);
  assertEquals(scanWant(plan([xray(["Small bilateral pleural effusions"])])), null);
  assertEquals(scanWant(plan([xray(["Patchy opacities in both lungs"])])), null);
});

Deno.test("findings that span more than one class want no image", () => {
  const heartFailure = plan([xray([
    "Cardiomegaly with increased cardiothoracic ratio",
    "Interstitial or alveolar edema with perihilar haziness",
    "Bilateral pleural effusions, often larger on the right",
  ])]);
  assertEquals(scanWant(heartFailure), null);
  assertEquals(scanWant(plan([xray(["Focal consolidation", "Small pleural effusion"])])), null);
});

Deno.test("the zone comes from the film or the chest exam, only for zoned findings", () => {
  const base = plan([xray(["Focal consolidation"])], ["Crackles at the left base"]);
  assertEquals(scanWant(base)?.want, want({ side: "left", zone: "lower" }));
  const middle = plan([xray(["Patchy atelectasis, especially of the right middle lobe"])]);
  assertEquals(scanWant(middle)?.want, want({ finding: "atelectasis", side: "right", zone: "middle" }));
  const effusion = plan([xray(["Small pleural effusion"])], ["Dullness to percussion at the right base"]);
  assertEquals(scanWant(effusion)?.want, want({ finding: "effusion", side: "right" }));
});

Deno.test("a portable or AP film prefers AP images", () => {
  const portable = plan([{ ...xray(["Focal consolidation"]), name: "Portable chest X-ray" }]);
  assertEquals(scanWant(portable)?.want.view, "AP");
  assertEquals(scanWant(plan([xray(["Focal consolidation"])]))?.want.view, "PA");
});

Deno.test("only chest exam findings and chest symptoms set the side", () => {
  const heart = plan([xray(["Focal consolidation"])], [["cardiac", "Signs of right heart strain"]]);
  assertEquals(scanWant(heart)?.want.side, null);
  const belly = plan([xray(["Focal consolidation"])], [["abdomen", "Right upper quadrant tenderness"]]);
  assertEquals(scanWant(belly)?.want.side, null);
  const lung = plan([xray(["Focal consolidation"])], ["Decreased breath sounds on the left"]);
  assertEquals(scanWant(lung)?.want.side, "left");
  const pleuritic = plan([xray(["Focal consolidation"])], [], ["Sharp right-sided pleuritic chest pain"]);
  assertEquals(scanWant(pleuritic)?.want.side, "right");
  const other = plan([xray(["Focal consolidation"])], [], ["Right knee pain"]);
  assertEquals(scanWant(other)?.want.side, null);
});

Deno.test("no chest X-ray or no library class means no want", () => {
  assertEquals(scanWant(plan([])), null);
  assertEquals(scanWant(plan([xray(["Cavitation"])])), null);
});
