import { assertEquals } from "jsr:@std/assert@1";
import {
  chooseScan,
  isChestXray,
  isPositiveFinding,
  preferredView,
  type ScanAsset,
  scanFinding,
  type ScanFinding,
  type ScanWant,
  sideHint,
  type ScanZone,
  zoneHint,
} from "./scans.ts";

for (
  const [name, want] of [
    ["Chest X-ray", true],
    ["chest radiograph (PA and lateral)", true],
    ["CXR", true],
    ["CT chest", false],
    ["Abdominal X-ray", false],
  ] as const
) {
  Deno.test(`isChestXray: ${name}`, () => assertEquals(isChestXray(name), want));
}

// Real profile wording (knowledge-base/profiles): hedged or negated text never picks an abnormal film,
// mixed classes stay text-only, and only an empty list is a normal film.
for (
  const [findings, want] of [
    [[], "normal"],
    [["Right lower lobe consolidation"], "opacity"],
    [["Kerley B lines"], "edema"],
    [["Widened mediastinum"], null],
    [["Usually normal; no infiltrate, pneumothorax, or mediastinal widening"], null],
    [["Clear lungs without focal consolidation, infiltrate, or pleural effusion"], null],
    [["Usually normal; may show cardiomegaly or pulmonary vascular congestion"], null],
    [["Usually normal; no vascular congestion"], null],
    [["No pneumothorax", "Without effusion"], null],
    [["Normal chest x-ray early in the illness or in dehydrated patients", "Patchy or interstitial opacities"], "opacity"],
    [["Pulmonary nodule or mass"], "nodule_mass"],
    [["Pulmonary nodules or masses suggesting metastasis"], "nodule_mass"],
    [["Massive hemothorax"], null],
    [["Mass effect on the trachea"], null],
    [["Anterior mediastinal mass"], null],
    [["Subcutaneous emphysema"], null],
    [["Collapsed or compressed lung on the affected side"], null],
    [["Pneumothorax"], "pneumothorax"],
    [["Hyperinflation with flattened diaphragms"], "emphysema"],
    [["Patchy atelectasis, especially of the right middle lobe"], "atelectasis"],
    // Heart failure: cardiomegaly, edema and effusion together are more than one class.
    [["Cardiomegaly with increased cardiothoracic ratio", "Interstitial or alveolar edema with perihilar haziness", "Bilateral pleural effusions, often larger on the right"], null],
    [["Cardiomegaly with increased cardiothoracic ratio", "Kerley B lines"], null],
    [["Pulmonary vascular congestion with cephalization of vessels", "Kerley B lines"], "edema"],
    // Pneumonia: consolidation with an effusion is two classes.
    [["Lobar or segmental airspace opacity with air bronchograms", "Small pleural effusion"], null],
    [["Lobar or segmental airspace opacity with air bronchograms", "Patchy or interstitial opacities"], "opacity"],
    // Asthma / neonatal RDS: a secondary pneumothorax alongside other findings is not the picture.
    [["Peribronchial cuffing or thickened bronchial walls", "Pneumothorax"], null],
    [["Air bronchograms extending beyond the perihilar region", "Pneumothorax or pneumomediastinum (air leak from positive pressure ventilation)"], null],
    [["Cardiomegaly or pulmonary edema suggesting alcohol-related cardiomyopathy"], null],
    // A positive worded with a negation keeps the study text-only rather than letting another
    // finding pick a film without the defining sign (respiratory failure, collapsed lung).
    [["Pleural line with absent lung markings"], null],
    [["Focal consolidation suggesting pneumonia", "Pneumothorax with visible pleural line and absent lung markings"], null],
    [["Focal consolidation suggesting pneumonia", "Diffuse bilateral opacities without cardiomegaly suggesting ARDS"], null],
    [["No pneumothorax", "Right lower lobe opacity"], null],
    [["Normal or hyperinflated lungs with flattened diaphragms", "Focal consolidation suggesting pneumonia"], null],
    // Whole-film statements alone stay text-only (never a normal film from wording alone)…
    [["Usually normal"], null],
    [["Clear lungs"], null],
    [["No acute findings"], null],
    // …but beside a positive finding they hide nothing, so the positive picks the film.
    [["Normal lungs in uncomplicated influenza", "Patchy or lobar consolidation suggesting secondary bacterial pneumonia"], "opacity"],
    [["Normal chest radiograph", "Pulmonary nodules or masses suggesting metastasis"], "nodule_mass"],
    [["No acute cardiopulmonary process", "Small left pleural effusion"], "effusion"],
    [["Normal chest x-ray (for example in pulmonary embolism, neuromuscular weakness or early ARDS)", "Focal consolidation suggesting pneumonia"], "opacity"],
    [["Usually normal heart size and clear lungs", "Kerley B lines"], "edema"],
    [["Normal lung fields", "Kerley B lines"], "edema"],
    [["Normal or no acute cardiopulmonary process", "Small pleural effusion"], "effusion"],
    [["Normal heart size and clear lung fields", "Kerley B lines"], "edema"],
    [["Normal chest x-ray despite fever", "Kerley B lines"], "edema"],
    [["Normal-appearing lungs in mild disease", "Kerley B lines"], "edema"],
    // An opening like "Normal lungs" followed by another finding is not whole-film, even when the
    // library has no class for that finding.
    [["Normal lungs with widened mediastinum", "Right lower lobe opacity"], null],
    [["No acute findings, widened mediastinum", "Right lower lobe opacity"], null],
    [["Normal heart size; widened mediastinum", "Small left pleural effusion"], null],
    [["Normal lungs (with widened mediastinum)", "Right lower lobe opacity"], null],
    [["Normal chest x-ray (widened mediastinum)", "Right lower lobe opacity"], null],
    [["Normal chest x-ray despite symptoms (early disease)", "Kerley B lines"], "edema"],
  ] as [string[], ScanFinding | null][]
) {
  Deno.test(`scanFinding: ${JSON.stringify(findings)}`, () => assertEquals(scanFinding(findings), want));
}

for (
  const [text, want] of [
    ["Usually normal; may show cardiomegaly", false],
    ["No acute cardiopulmonary process", false],
    ["Clear lung fields", false],
    ["Possible small effusion", false],
    ["Effusion if present is small", false],
    ["Rarely a pneumothorax", false],
    ["Small left pleural effusion", true],
    ["Nodular opacity in the right upper lobe", true],
    ["Abnormal cardiac silhouette", true],
  ] as const
) {
  Deno.test(`isPositiveFinding: ${text}`, () => assertEquals(isPositiveFinding(text), want));
}

for (
  const [name, want] of [
    ["Chest X-ray", "PA"],
    ["Chest x-ray, posteroanterior and lateral", "PA"],
    ["Portable chest X-ray", "AP"],
    ["Chest X-ray (AP)", "AP"],
    ["Chest radiograph, anteroposterior", "AP"],
  ] as const
) {
  Deno.test(`preferredView: ${name}`, () => assertEquals(preferredView(name), want));
}

for (
  const [texts, want] of [
    [["Crackles at the right base"], "lower"],
    [["Right lower lobe consolidation"], "lower"],
    [["Bibasilar crackles"], null],
    [["Left basilar crackles"], "lower"],
    [["Right upper lobe infiltrate"], "upper"],
    [["Apical cavitation"], "upper"],
    [["Patchy atelectasis, especially of the right middle lobe"], "middle"],
    [["Lingular opacity"], "middle"],
    [["Right upper lobe opacity", "Crackles at the right base"], null],
    [["Patchy or interstitial opacities"], null],
  ] as [string[], ScanZone | null][]
) {
  Deno.test(`zoneHint: ${JSON.stringify(texts)}`, () => assertEquals(zoneHint(texts), want));
}

for (
  const [texts, want] of [
    [["left basilar crackles"], "left"],
    [["left effusion", "right consolidation"], null],
    [["bilateral infiltrates"], null],
  ] as [string[], "left" | "right" | null][]
) {
  Deno.test(`sideHint: ${JSON.stringify(texts)}`, () => assertEquals(sideHint(texts), want));
}

function asset(id: string, over: Partial<ScanAsset> = {}): ScanAsset {
  return {
    id,
    object_name: `${id}.jpg`,
    finding: "opacity",
    side: "left",
    zone: null,
    view: "PA",
    age: 50,
    sex: "female",
    report: "",
    ...over,
  };
}
const want: ScanWant = { finding: "opacity", side: "left", zone: null, view: "PA", age: 50, sex: "female" };
const first = () => 0;

Deno.test("chooseScan requires the same sex", () => {
  assertEquals(chooseScan([asset("m", { sex: "male" })], want, new Set(), first), null);
});

Deno.test("chooseScan never matches a child to adult assets", () => {
  assertEquals(chooseScan([asset("a", { age: 20 })], { ...want, age: 10 }, new Set(), first), null);
});

Deno.test("chooseScan has no image for an infant", () => {
  assertEquals(chooseScan([asset("a", { age: 1 }), asset("b", { age: 0 })], { ...want, age: 0 }, new Set(), first), null);
  assertEquals(chooseScan([asset("a", { age: 1 })], { ...want, age: 1 }, new Set(), first), null);
});

Deno.test("chooseScan keeps children within 3 years and below 18", () => {
  const child = { ...want, age: 8 };
  assertEquals(chooseScan([asset("a", { age: 10 })], child, new Set(), first)?.id, "a");
  assertEquals(chooseScan([asset("a", { age: 11 })], child, new Set(), first)?.id, "a");
  assertEquals(chooseScan([asset("a", { age: 12 })], child, new Set(), first), null);
  assertEquals(chooseScan([asset("a", { age: 18 })], { ...want, age: 16 }, new Set(), first), null);
  assertEquals(chooseScan([asset("a", { age: 15 })], { ...want, age: 17 }, new Set(), first)?.id, "a");
});

Deno.test("chooseScan never matches an adult to a child's film", () => {
  assertEquals(chooseScan([asset("a", { age: 17 })], { ...want, age: 18 }, new Set(), first), null);
});

Deno.test("chooseScan matches the wanted zone for zoned findings", () => {
  const lower = { ...want, zone: "lower" as const };
  assertEquals(chooseScan([asset("u", { zone: "upper" })], lower, new Set(), first), null);
  assertEquals(chooseScan([asset("u", { zone: "upper" }), asset("l", { zone: "lower" })], lower, new Set(), first)?.id, "l");
  assertEquals(chooseScan([asset("u", { zone: "upper" })], want, new Set(), first)?.id, "u");
});

Deno.test("chooseScan ignores zone for unzoned findings", () => {
  const pool = [asset("e", { finding: "effusion", zone: "upper" })];
  assertEquals(chooseScan(pool, { ...want, finding: "effusion", zone: "lower" }, new Set(), first)?.id, "e");
});

Deno.test("chooseScan prefers the wanted view but falls back to the other", () => {
  const pool = [asset("pa", { view: "PA" }), asset("ap", { view: "AP" })];
  assertEquals(chooseScan(pool, { ...want, view: "AP" }, new Set(), first)?.id, "ap");
  assertEquals(chooseScan(pool, want, new Set(), () => 0.99)?.id, "pa");
  assertEquals(chooseScan([asset("pa", { view: "PA" })], { ...want, view: "AP" }, new Set(), first)?.id, "pa");
});

Deno.test("chooseScan excludes assets more than 15 years apart", () => {
  assertEquals(chooseScan([asset("a", { age: 66 })], want, new Set(), first), null);
  assertEquals(chooseScan([asset("a", { age: 65 })], want, new Set(), first)?.id, "a");
});

Deno.test("chooseScan respects the wanted side", () => {
  assertEquals(chooseScan([asset("r", { side: "right" })], want, new Set(), first), null);
});

Deno.test("chooseScan accepts either side when none is wanted", () => {
  const pool = [asset("r", { side: "right" })];
  assertEquals(chooseScan(pool, { ...want, side: null }, new Set(), first)?.id, "r");
});

Deno.test("chooseScan filters by finding", () => {
  assertEquals(chooseScan([asset("e", { finding: "effusion" })], want, new Set(), first), null);
});

Deno.test("chooseScan prefers unseen assets", () => {
  const pool = [asset("a"), asset("b")];
  assertEquals(chooseScan(pool, want, new Set(["a"]), first)?.id, "b");
});

Deno.test("chooseScan falls back to a seen asset", () => {
  const pool = [asset("a"), asset("b")];
  assertEquals(chooseScan(pool, want, new Set(["a", "b"]), () => 0.99)?.id, "b");
});

Deno.test("chooseScan returns null with no candidates", () => {
  assertEquals(chooseScan([], want, new Set(), first), null);
});
