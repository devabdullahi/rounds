import { assertEquals } from "jsr:@std/assert@1";
import { namedDiagnoses } from "./leak.ts";
import { partialAnswer, ReplyGate } from "./stream.ts";

/** Feeds a whole answer to a gate a few characters at a time, as the model would. */
function shownWhileStreaming(gate: ReplyGate, full: string, step = 3): string[] {
  const shown: string[] = [];
  for (let end = step; end < full.length + step; end += step) {
    const text = gate.update(full.slice(0, end));
    if (text !== null) shown.push(text);
  }
  return shown;
}

const answer = (fields: string, reply: string) => `{${fields},"reply":${JSON.stringify(reply)}}`;
const grounded = `"conduct":"clinical","fact_ids":["a1"],"seen_ids":[]`;

Deno.test("an unfinished answer gives its closed fields and the reply so far", () => {
  assertEquals(partialAnswer(`{"conduct":"clinical","fact_ids":["a1","a2"],"seen_ids":[],"reply":"It started la`), {
    conduct: "clinical", factIds: ["a1", "a2"], seenIds: [], reply: "It started la",
  });
  assertEquals(partialAnswer(`{"conduct":"clinical","fact_ids":["a1"`), { conduct: "clinical", factIds: undefined, seenIds: undefined });
});

Deno.test("escapes decode, and a half-written one waits", () => {
  assertEquals(partialAnswer(`{"reply":"She said \\"ow\\" and\\nleft`).reply, `She said "ow" and\nleft`);
  assertEquals(partialAnswer(`{"reply":"caf\\u00e9 and \\`).reply, "café and ");
  assertEquals(partialAnswer(`{"reply":"caf\\u00`).reply, "caf");
});

Deno.test("a grounded reply streams word by word, holding back the word being written", () => {
  const gate = new ReplyGate(["appendicitis"], new Set(["a1"]), new Set());
  const shown = shownWhileStreaming(gate, answer(grounded, "It started last night around my belly button."));
  assertEquals(shown.at(-1), "It started last night around my belly");
  // Each step only grows.
  for (let i = 1; i < shown.length; i++) assertEquals(shown[i].startsWith(shown[i - 1]), true);
});

Deno.test("a reply that needs the second check, or isn't clinical, never streams", () => {
  const facts = new Set(["a1"]);
  for (const fields of [
    `"conduct":"clinical","fact_ids":[],"seen_ids":[]`,
    `"conduct":"clinical","fact_ids":["zz"],"seen_ids":[]`,
    `"conduct":"off_topic","fact_ids":["a1"],"seen_ids":[]`,
  ]) {
    const gate = new ReplyGate([], facts, new Set());
    assertEquals(shownWhileStreaming(gate, answer(fields, "No, nothing like that, thank goodness.")), [], fields);
  }
});

Deno.test("a visible finding grounds a reply too", () => {
  const gate = new ReplyGate([], new Set(), new Set(["rash"]));
  const shown = shownWhileStreaming(gate, answer(`"conduct":"clinical","fact_ids":[],"seen_ids":["rash"]`, "It's on my left arm, about the size of a nickel."));
  assertEquals(shown.at(-1), "It's on my left arm, about the size of a");
});

Deno.test("the diagnosis name is never shown, even in part of the stream", () => {
  for (const name of ["appendicitis", "acute appendicitis", "MI"]) {
    const gate = new ReplyGate([name], new Set(["a1"]), new Set());
    const shown = shownWhileStreaming(gate, answer(grounded, `My doctor thinks it might be ${name} or something like that.`), 1);
    assertEquals(shown.length > 0, true, name);   // the words before the name still show
    for (const text of shown) assertEquals(namedDiagnoses(text, [name]), [], `${name}: ${text}`);
  }
});

Deno.test("script talk stops the stream", () => {
  const gate = new ReplyGate([], new Set(["a1"]), new Set());
  const shown = shownWhileStreaming(gate, answer(grounded, "Well, I haven't said what it is yet, doctor."), 1);
  for (const text of shown) assertEquals(text.includes("haven't said"), false, text);
});
