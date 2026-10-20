import { assert, assertEquals } from "jsr:@std/assert@1";
import { LIVE_STAGES } from "./liveprofile.ts";
import { STAGES } from "./profilegen.ts";

Deno.test("the live template covers every stored section once, with the large stages split", () => {
  assertEquals(LIVE_STAGES.flatMap((s) => s.sections).sort(), STAGES.flatMap((s) => s.sections).sort());
  assertEquals(LIVE_STAGES.map((s) => s.sections), [
    ["patient", "presentation"], ["exam", "vitals"], ["labs", "ecg"], ["imaging", "workup"],
    ["differential"], ["course", "cancer"], ["teaching"],
  ]);
});

Deno.test("a split call's instructions, schema and example hold only its own sections", () => {
  for (const s of LIVE_STAGES.filter((x) => x.name === "diagnostics" || x.name === "differential_course")) {
    assertEquals(Object.keys(JSON.parse(s.schema).properties).sort(), [...s.sections].sort(), s.sections.join());
    assert(Object.keys(JSON.parse(s.example)).every((k) => s.sections.includes(k)), s.sections.join());
    const bullets = s.instructions.split("\n").flatMap((l) => l.match(/^- ([a-z_]+)/)?.[1] ?? []);
    assert(bullets.length > 0 && bullets.every((k) => s.sections.includes(k)), `${s.sections.join()}: ${bullets.join()}`);
  }
});

Deno.test("the labs half still asks for levels, not numbers", () => {
  const labs = LIVE_STAGES.find((s) => s.sections.includes("labs"))!;
  assert(labs.instructions.includes("levels"));
  assert(!("ranges" in JSON.parse(labs.schema).properties.labs.items.properties));
});
