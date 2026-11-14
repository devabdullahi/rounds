import { assertEquals } from "jsr:@std/assert@1";
import { chooseScan, isChestXray, type ScanAsset, scanFinding, type ScanFinding, sideHint } from "./scans.ts";

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

for (
  const [findings, want] of [
    [[], "normal"],
    [["Right lower lobe consolidation"], "opacity"],
    [["Small left pleural effusion", "Consolidation"], "effusion"],
    [["Kerley B lines"], "edema"],
    [["Widened mediastinum"], null],
  ] as [string[], ScanFinding | null][]
) {
  Deno.test(`scanFinding: ${JSON.stringify(findings)}`, () => assertEquals(scanFinding(findings), want));
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
const want = { finding: "opacity" as const, side: "left" as const, age: 50, sex: "female" as const };
const first = () => 0;

Deno.test("chooseScan requires the same sex", () => {
  assertEquals(chooseScan([asset("m", { sex: "male" })], want, new Set(), first), null);
});

Deno.test("chooseScan never matches a child to adult assets", () => {
  assertEquals(chooseScan([asset("a", { age: 20 })], { ...want, age: 10 }, new Set(), first), null);
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
