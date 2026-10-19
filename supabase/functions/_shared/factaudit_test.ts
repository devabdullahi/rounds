import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { auditPrompt, auditProblems, candidateFlags, confirmWithUmls, fixRequest, parseClaims } from "./factaudit.ts";

const items = { present: ["Abdominal pain", "Vomiting"], absent: ["Fever"], background: ["Hypertension"] };

Deno.test("the prompt numbers present, absent and background items in one list", () => {
  const prompt = auditPrompt(items, [{ id: "f1", reply: "It hurts." }]);
  assertStringIncludes(prompt, '{"n":2,"text":"Fever"}');
  assertStringIncludes(prompt, '{"id":"f1","text":"It hurts."}');
});

Deno.test("malformed claims are dropped and out-of-range items read as none", () => {
  const claims = parseClaims({ claims: [{ fact: "f1", claim: "pain", item: 0 }, { fact: "f2", claim: "rash", item: 99 }, { claim: "x" }] }, 4);
  assertEquals(claims.map((c) => [c.fact, c.item]), [["f1", 0], ["f2", null]]);
});

Deno.test("unplanned claims and absent symptoms stated as present are flagged; denials are not", () => {
  const flags = candidateFlags([
    { fact: "f1", claim: "belly pain", item: 0, negated: false },
    { fact: "f2", claim: "fever", item: 2, negated: true },
    { fact: "f3", claim: "fever since yesterday", item: 2, negated: false },
    { fact: "f4", claim: "blood in stool", item: null, negated: false },
  ], items);
  assertEquals(flags.map((f) => [f.fact, f.kind]), [["f3", "contradicts"], ["f4", "invented"]]);
  assertEquals(auditProblems(flags).length, 2);
});

Deno.test("UMLS clears a claim that is a planned item under another name, and keeps the rest", async () => {
  const concepts: Record<string, string> = { "Abdominal pain": "C1", "Vomiting": "C2", "Hypertension": "C3", "throwing up": "C2", "blood in stool": "C9" };
  const flags = [
    { fact: "f1", claim: "throwing up", kind: "invented" as const },
    { fact: "f2", claim: "blood in stool", kind: "invented" as const },
    { fact: "f3", claim: "fever", kind: "contradicts" as const },
  ];
  const kept = await confirmWithUmls(flags, items, (t) => Promise.resolve(concepts[t] ?? null));
  assertEquals(kept.map((f) => f.fact), ["f2", "f3"]);
});

Deno.test("the fix request lists each flagged line once, with what to remove and what to deny", () => {
  const request = fixRequest([
    { fact: "f3", claim: "fever since yesterday", kind: "contradicts" },
    { fact: "f4", claim: "blood in stool", kind: "invented" },
    { fact: "f4", claim: "night sweats", kind: "invented" },
  ], [{ id: "f3", reply: "I've had a fever since yesterday." }, { id: "f4", reply: "Some blood in my stool and night sweats." }]);
  assertStringIncludes(request, '"where":"fact f4 reply"');
  assertStringIncludes(request, '"remove":["blood in stool","night sweats"]');
  assertStringIncludes(request, '"deny":["fever since yesterday"]');
});
