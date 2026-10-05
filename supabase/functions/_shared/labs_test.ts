import { assert, assertAlmostEquals, assertEquals } from "jsr:@std/assert@1";
import { deriveValues, egfr, flag, primaryValues, report, seeded, TESTS } from "./labs.ts";

Deno.test("reference table copy matches knowledge-base", async () => {
  const shared = await Deno.readTextFile(new URL("./reference_ranges.json", import.meta.url));
  const source = await Deno.readTextFile(new URL("../../../knowledge-base/reference_ranges.json", import.meta.url));
  assertEquals(shared, source);
});

Deno.test("unlisted tests come out normal", () => {
  const values = primaryValues(["bmp", "cbc"], [], "moderate", "M", seeded(1));
  for (const [id, value] of Object.entries(values)) {
    assertEquals(flag(TESTS.get(id)!, value, "M"), "", `${id}=${value}`);
  }
});

Deno.test("profile ranges apply at the chosen severity only", () => {
  const labs = [{ test_id: "wbc", ranges: { severe: { min: 15, max: 20 } } }];
  const severe = primaryValues(["cbc"], labs, "severe", "F", seeded(2));
  assert((severe.wbc as number) >= 15 && (severe.wbc as number) <= 20);
  const mild = primaryValues(["cbc"], labs, "mild", "F", seeded(2));
  assertEquals(flag(TESTS.get("wbc")!, mild.wbc, "F"), "");
});

Deno.test("qualitative results use the profile value or the normal result", () => {
  const labs = [{ test_id: "ua_ketones", qualitative: { severe: "Large" } }];
  assertEquals(primaryValues(["ua"], labs, "severe", "M", seeded(3)).ua_ketones, "Large");
  assertEquals(primaryValues(["ua"], labs, "mild", "M", seeded(3)).ua_ketones, "Negative");
});

Deno.test("derived values follow the primaries", () => {
  const v = deriveValues({ na: 140, cl: 100, hco3: 12, bun: 28, cr: 1.4, glucose: 450, paco2: 25 }, 30, "M");
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
  const r = report("bmp", { na: 128, k: 4.0 }, "M");
  assert(r.abnormal);
  assert(r.text.includes("Sodium 128 mmol/L (L)"));
  assert(r.text.includes("Potassium 4 mmol/L") && !r.text.includes("Potassium 4 mmol/L ("));
});
