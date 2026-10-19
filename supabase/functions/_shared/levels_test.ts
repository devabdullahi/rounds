import { assert, assertEquals } from "jsr:@std/assert@1";
import { levelRange, rangeLevel, VITAL_NORMALS } from "./levels.ts";
import { expandLevels } from "./liveprofile.ts";
import { labNormal } from "./profilegen.ts";

Deno.test("vital levels: heart rate by multiples of normal, fever and hypoxia by fixed bands", () => {
  assertEquals(levelRange("high", VITAL_NORMALS.hr, "vital", "hr"), { min: 110, max: 130 });
  assertEquals(levelRange("high", VITAL_NORMALS.temp, "vital", "temp"), { min: 100.4, max: 102.2 });
  assertEquals(levelRange("markedly_low", VITAL_NORMALS.spo2, "vital", "spo2"), { min: 82, max: 88 });
  assertEquals(levelRange("normal", VITAL_NORMALS.rr, "vital", "rr"), { min: 12, max: 20 });
});

Deno.test("DKA's signature numbers come out of the levels", () => {
  const glucose = levelRange("severely_high", labNormal("glucose")!, "lab", "glucose")!;
  assert(glucose.min >= 250, `severe DKA glucose starts at ${glucose.min}`);
  const bicarb = levelRange("markedly_low", labNormal("hco3")!, "lab", "hco3")!;
  assert(bicarb.max < 18, `markedly low bicarbonate tops out at ${bicarb.max}`);
});

Deno.test("a range reads back as the level it came from", () => {
  for (const level of ["slightly_high", "high", "markedly_high", "low"] as const) {
    assertEquals(rangeLevel(levelRange(level, [60, 100], "vital")!, [60, 100], "vital"), level);
  }
});

Deno.test("expandLevels turns the model's levels into ranges and drops what can't apply", () => {
  // deno-lint-ignore no-explicit-any
  const profile: any = {
    vitals: { hr: { mild: "slightly_high", severe: "markedly_high" }, temp: { severe: "nonsense" } },
    labs: [{ test_id: "wbc", levels: { moderate: "high" }, frequency: "common", importance: "important" }],
  };
  expandLevels(profile);
  assertEquals(profile.vitals.hr, { mild: { min: 100, max: 110 }, severe: { min: 130, max: 160 } });
  assertEquals(profile.vitals.temp, {});
  const wbc = profile.labs[0];
  assert(wbc.ranges.moderate.min > labNormal("wbc")![1]!);
  assert(!("levels" in wbc));
});
