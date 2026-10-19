import { assert, assertEquals } from "jsr:@std/assert@1";
import { birthDecade, patientName } from "./names.ts";

Deno.test("first names come from the decade the patient was born in, within the data's range", () => {
  assertEquals(birthDecade(70, 2026), 1950);
  assertEquals(birthDecade(9, 2026), 2000);   // past the data's last decade: its newest names
  assertEquals(birthDecade(105, 2026), 1920);
});

Deno.test("names have a first and last part and vary from case to case", () => {
  const seen = new Set<string>();
  for (let i = 0; i < 200; i++) {
    const name = patientName(i % 2 ? "F" : "M", 20 + (i % 60), Math.random);
    assertEquals(name.split(" ").length >= 2, true, name);
    seen.add(name);
  }
  assert(seen.size > 190, `only ${seen.size} different names in 200`);
});

Deno.test("an older woman gets a name of her generation", () => {
  const name = patientName("F", 75, () => 0, 2026);  // the 1950s' most common first name
  assert(name.startsWith("Mary "), name);
});
