import { assert, assertEquals, assertNotEquals } from "jsr:@std/assert@1";
import { naturalDenial, naturalRefusal, talksAboutScript } from "./refusal.ts";

Deno.test("replies about the script are caught; ordinary refusals aren't", () => {
  for (const [reply, meta] of [
    ["I don't know. I haven't said exactly what I use.", true],
    ["I don't know. I haven't told you what it is.", true],
    ["That's not in my notes.", true],
    ["I haven't noticed anything like that.", false],
    ["I'd rather not say right now.", false],
    ["I never told my wife about it.", false],
  ] as const) {
    assertEquals(talksAboutScript(reply), meta, reply);
  }
});

Deno.test("a stand-in refusal never repeats the patient's last reply", () => {
  for (let i = 0; i < 20; i++) {
    const first = naturalRefusal(undefined, () => i / 20);
    assertNotEquals(naturalRefusal(first, () => i / 20), first);
  }
  assert(naturalRefusal(undefined, () => 0.99).length > 0);
});

Deno.test("a slipped-in medical detail becomes a plain no, never the last reply again", () => {
  const first = naturalDenial(undefined, () => 0);
  assert(/^No|^Not that/.test(first));
  for (let i = 0; i < 4; i++) assertNotEquals(naturalDenial(first, () => i / 4), first);
});
