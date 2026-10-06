import { assert, assertEquals } from "jsr:@std/assert@1";
import { cardFacts, missFacts } from "./cardfacts.ts";
import { type Profile } from "./casegen.ts";

const dir = new URL("../../../knowledge-base/profiles/", import.meta.url);
const profiles: Profile[] = [];
for await (const entry of Deno.readDir(dir)) {
  if (!entry.name.endsWith(".json")) continue;
  const p = JSON.parse(await Deno.readTextFile(new URL(entry.name, dir)));
  if (p.generation.validation.status === "passed") profiles.push(p);
}

Deno.test("every passing profile yields card facts tagged with its slug", () => {
  for (const p of profiles) {
    const set = cardFacts(p);
    assertEquals(set.source, p.slug);
    assert(set.facts.length >= 3, `${p.slug} has only ${set.facts.length} facts`);
  }
});

Deno.test("missed red flags become their own fact set", () => {
  assertEquals(missFacts([]), null);
  const set = missFacts([{ flag: "Ectopic pregnancy", why: "Any patient who could be pregnant." }])!;
  assertEquals(set.source, "missed");
  assert(set.facts[0].includes("Ectopic pregnancy"));
});
