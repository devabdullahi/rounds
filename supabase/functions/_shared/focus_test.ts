import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { parseFocus, settingTags } from "./focus.ts";

Deno.test("a care setting is part of the stored focus, so written-ahead cases stay in their setting", () => {
  const cases: [focus: string, setting: unknown, stored: string][] = [
    ["", "", ""],
    ["", "clinic", "@clinic"],
    ["rotation:surgery", "", "rotation:surgery"],
    ["rotation:surgery", "hospital", "rotation:surgery@hospital"],
    ["system:renal", "clinic", "system:renal@clinic"],
  ];
  for (const [focus, setting, stored] of cases) assertEquals(parseFocus(focus, setting).stored, stored);
  assertEquals(parseFocus("system:renal", "clinic").setting, "clinic");
  assertEquals(parseFocus("system:renal").setting, "");
});

Deno.test("an unknown care setting is refused", () => {
  for (const setting of ["office", "Clinic", 1, null]) assertThrows(() => parseFocus("", setting));
});

Deno.test("clinic and hospital draw from separate setting tags", () => {
  assertEquals(settingTags(""), []);
  assertEquals(settingTags("clinic").filter((t) => settingTags("hospital").includes(t)), []);
  assertEquals(settingTags("clinic").includes("pediatric_clinic"), true);
  assertEquals(settingTags("hospital").includes("icu"), true);
});
