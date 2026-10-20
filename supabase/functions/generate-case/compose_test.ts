import { assert, assertRejects } from "jsr:@std/assert@1";
import { freshPlan, NoNewPatient } from "./compose.ts";
import type { Profile } from "../_shared/casegen.ts";

const profile = JSON.parse(Deno.readTextFileSync(new URL("../../../knowledge-base/profiles/migraine.json", import.meta.url))) as Profile;
const names = new Set<string>();

Deno.test("a student with no patients of this condition gets a fresh plan", async () => {
  const { print } = await freshPlan(profile, {}, { fingerprints: new Set(), names });
  assert(print.length === 64);
});

Deno.test("a condition the student has used up says so, so the writer moves to another", async () => {
  // Every plan is one they've had.
  const all = { has: () => true } as unknown as Set<string>;
  const error = await assertRejects(() => freshPlan(profile, {}, { fingerprints: all, names }), NoNewPatient);
  assert(error.slug === profile.slug);
});
