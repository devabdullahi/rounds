import { assert, assertAlmostEquals, assertEquals } from "jsr:@std/assert@1";
import { deriveValues, egfr, flag, interval, type Patient, primaryValues, report, seeded, shortName, TESTS } from "./labs.ts";

const adultM: Patient = { sex: "M", age: 40, pregnant: false };
const adultF: Patient = { sex: "F", age: 40, pregnant: false };

Deno.test("reference table copy matches knowledge-base", async () => {
  const shared = await Deno.readTextFile(new URL("./reference_ranges.json", import.meta.url));
  const source = await Deno.readTextFile(new URL("../../../knowledge-base/reference_ranges.json", import.meta.url));
  assertEquals(shared, source);
});

Deno.test("unlisted tests come out normal", () => {
  const values = primaryValues(["bmp", "cbc"], [], "moderate", adultM, seeded(1));
  for (const [id, value] of Object.entries(values)) {
    assertEquals(flag(TESTS.get(id)!, value, adultM), "", `${id}=${value}`);
  }
});

Deno.test("profile ranges apply at the chosen severity only", () => {
  const labs = [{ test_id: "wbc", ranges: { severe: { min: 15, max: 20 } } }];
  const severe = primaryValues(["cbc"], labs, "severe", adultF, seeded(2));
  assert((severe.wbc as number) >= 15 && (severe.wbc as number) <= 20);
  const mild = primaryValues(["cbc"], labs, "mild", adultF, seeded(2));
  assertEquals(flag(TESTS.get("wbc")!, mild.wbc, adultF), "");
});

Deno.test("qualitative results use the profile value or the normal result", () => {
  const labs = [{ test_id: "ua_ketones", qualitative: { severe: "Large" } }];
  assertEquals(primaryValues(["ua"], labs, "severe", adultM, seeded(3)).ua_ketones, "Large");
  assertEquals(primaryValues(["ua"], labs, "mild", adultM, seeded(3)).ua_ketones, "Negative");
});

Deno.test("derived values follow the primaries", () => {
  const v = deriveValues({ na: 140, cl: 100, hco3: 12, bun: 28, cr: 1.4, glucose: 450, paco2: 25 }, { sex: "M", age: 30, pregnant: false });
  assertEquals(v.anion_gap, 28);
  assertEquals(v.bun_cr, 20);
  assertEquals(v.abg_hco3, 12);
  assertAlmostEquals(v.ph as number, 7.30, 0.01); // 6.1 + log10(12 / 0.75)
  assertEquals(v.calc_osm, 315);
});

Deno.test("CKD-EPI 2021 matches published examples", () => {
  assertEquals(egfr(1.0, 50, "M"), 92);
  assertEquals(egfr(1.0, 50, "F"), 69);
});

Deno.test("reports flag abnormal values", () => {
  const r = report("bmp", { na: 128, k: 4.0 }, adultM);
  assert(r.abnormal);
  assert(r.text.includes("Sodium 128 mmol/L (L)"));
  assertEquals(report("crp", { crp: 3.2 }, adultM).text, "3.2 mg/dL (H)");
  assert(r.text.includes("Potassium 4 mmol/L") && !r.text.includes("Potassium 4 mmol/L ("));
});

Deno.test("short names use real abbreviations only", () => {
  assertEquals(shortName("Mean corpuscular volume (MCV)"), "MCV");
  assertEquals(shortName("Activated partial thromboplastin time (aPTT)"), "aPTT");
  assertEquals(shortName("Glucose (fasting)"), "Glucose");
  assertEquals(shortName("Bicarbonate (total CO₂)"), "Bicarbonate");
  assertEquals(shortName("Sodium"), "Sodium");
});

Deno.test("children get their age band's normal ranges", () => {
  const toddler: Patient = { sex: "F", age: 2, pregnant: false };
  assertEquals(interval(TESTS.get("hr")!, toddler), [98, 140]);
  assertEquals(flag(TESTS.get("hr")!, 130, toddler), "");         // normal at 2, tachycardic at 40
  assertEquals(flag(TESTS.get("hr")!, 130, adultF), "H");
  assertEquals(flag(TESTS.get("alp")!, 300, { sex: "M", age: 10, pregnant: false }), "");  // growing bones
});

Deno.test("pregnancy replaces the adult interval where it differs", () => {
  const pregnant: Patient = { sex: "F", age: 29, pregnant: true };
  assertEquals(flag(TESTS.get("cr")!, 1.0, adultF), "");
  assertEquals(flag(TESTS.get("cr")!, 1.0, pregnant), "H");        // 1.0 is high in pregnancy
  assertEquals(flag(TESTS.get("hco3")!, 20, pregnant), "");        // compensated respiratory alkalosis
  assertEquals(flag(TESTS.get("na")!, 138, pregnant), "");         // no pregnancy band: adult range
});

Deno.test("children don't get an adult eGFR", () => {
  const v = deriveValues({ cr: 0.4 }, { sex: "M", age: 6, pregnant: false });
  assertEquals(v.egfr, undefined);
});
