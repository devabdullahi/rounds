import { assert, assertEquals } from "jsr:@std/assert@1";
import { leakTerms, planCase, type Profile } from "../_shared/casegen.ts";
import { seeded } from "../_shared/labs.ts";
import { applyFixes, buildRubric, checkWriting, fixPrompt, leakSpots, neutralIds, type Writing, writerPrompt } from "./writer.ts";

const dir = new URL("../../../knowledge-base/profiles/", import.meta.url);
let profile: Profile | null = null;
for await (const entry of Deno.readDir(dir)) {
  if (!entry.name.endsWith(".json")) continue;
  const p = JSON.parse(await Deno.readTextFile(new URL(entry.name, dir)));
  if (p.generation.validation.status === "passed" && p.differential.some((d: { must_not_miss: boolean }) => d.must_not_miss)) {
    profile = p;
    break;
  }
}
if (!profile) throw new Error("no validated profile with a must-not-miss alternative in knowledge-base/profiles");
const plan = planCase(profile, seeded(1));
const terms = leakTerms(profile);
const mustNotMiss = profile.differential.find((d) => d.must_not_miss)!.name;

/** A writing that passes every check: the shape the model is asked for, with neutral text. */
function goodWriting(): Writing {
  return {
    patient: { name: "Dana Reyes", quote: "I don't feel right.", demeanor: "tired, uneasy", setting: "Walk-in, emergency department", complaint: "Adult with two days of feeling unwell." },
    persona: { voice: "plain, short answers", background: "Works at a hardware store.", fallback: "Sorry, I'm not sure what you mean." },
    facts: Array.from({ length: 10 }, (_, i) => ({
      id: `fact_${i}`, label: `topic ${i}`, reply: "It started a couple of days ago.",
      importance: i < 3 ? "essential" as const : i < 6 ? "important" as const : "optional" as const,
      screens_for: i === 0 ? mustNotMiss : null,
    })),
    suggested: [{ text: "When did it start?", fact: "fact_0" }],
    maneuvers: [
      { id: "look", title: "General appearance", finding: "Resting comfortably.", key: true },
      { id: "listen", title: "Listen to the heart", finding: "Regular rhythm.", key: false },
      { id: "feel", title: "Palpate the abdomen", finding: "Soft.", key: true },
    ],
    studies: plan.tests.filter((t) => t.kind === "study").map((t) => ({ test_id: t.id, result: "Unremarkable.", abnormal: false })),
    test_meta: plan.tests.map((t) => ({ test_id: t.id, detail: "Bloods · 4 min", cost: 30, turnaround_s: 5, delays_care_min: 0 })),
  };
}

Deno.test("a complete, neutral writing passes the checks", () => {
  assertEquals(checkWriting(goodWriting(), plan, terms), []);
});

Deno.test("naming the diagnosis anywhere the student sees is caught", () => {
  const w = goodWriting();
  w.facts[4] = { ...w.facts[4], reply: `My doctor thinks it's ${terms[0]}.` };
  assert(checkWriting(w, plan, terms).some((p) => p.startsWith("reveals the diagnosis")));
});

Deno.test("structural problems are each reported", () => {
  const w = goodWriting();
  w.facts = w.facts.slice(0, 5);
  w.facts.push({ ...w.facts[0] });                       // duplicate id
  w.suggested = [{ text: "Any fever?", fact: "missing" }];
  w.maneuvers = w.maneuvers.slice(0, 2);
  w.test_meta = w.test_meta.slice(1);
  const problems = checkWriting(w, plan, terms);
  for (const want of ["need at least 8 facts", "must be unique", "unknown fact missing", "need at least 3 maneuvers", `missing test_meta for ${plan.tests[0].id}`]) {
    assert(problems.some((p) => p.includes(want)), `expected "${want}" in ${JSON.stringify(problems)}`);
  }
});

Deno.test("out-of-range prices and waits are rejected", () => {
  const w = goodWriting();
  w.test_meta[0] = { ...w.test_meta[0], cost: -5 };
  assert(checkWriting(w, plan, terms).includes(`test_meta for ${plan.tests[0].id} out of range`));
});

Deno.test("neutral ids hide the writer's descriptive ones and keep links intact", () => {
  const w = neutralIds(goodWriting());
  assertEquals(w.facts.map((f) => f.id).slice(0, 2), ["f01", "f02"]);
  assertEquals(w.maneuvers.map((m) => m.id), ["x01", "x02", "x03"]);
  assertEquals(w.suggested[0].fact, "f01");
});

Deno.test("the rubric weighs essential facts double and keeps only key maneuvers", () => {
  const w = neutralIds(goodWriting());
  const tests = plan.tests.map((t) => ({ id: t.id, name: t.name, role: t.role, why: t.why ?? null }));
  const r = buildRubric(profile!, plan, w, tests);
  assertEquals(r.diagnosis, profile!.triage.name);
  assertEquals(r.key_facts.length, 6);
  assertEquals(r.key_facts.filter((f) => f.weight === 2).length, 3);
  assertEquals(r.key_maneuvers.map((m) => m.id), ["x01", "x03"]);
  assertEquals(r.red_flags, [{ fact: "f01", flag: mustNotMiss, why: r.red_flags[0].why }]);
  assert(r.red_flags[0].why.length > 0);
  assertEquals(r.indicated_tests.map((t) => t.id), tests.filter((t) => t.role === "indicated").map((t) => t.id));
  assert(r.must_not_miss.includes(mustNotMiss));
});

Deno.test("coding wording from a synthetic record is caught, in replies and the persona", () => {
  const w = goodWriting();
  w.facts[5] = { ...w.facts[5], reply: "I'm allergic to Peanut (substance)." };
  w.persona = { ...w.persona, background: "Has Chronic sinusitis (disorder)." };
  const problem = checkWriting(w, plan, terms).find((p) => p.startsWith("uses coding wording"));
  assert(problem?.includes("(substance)") && problem.includes("(disorder)"), problem);
});

Deno.test("a background goes to the writer cleaned, and only when there is one", () => {
  assert(!writerPrompt(profile!, plan).includes("Patient background (synthetic record)"));
  const prompt = writerPrompt(profile!, plan, {
    id: "x", age: plan.age, sex: plan.sex, marital: "M", conditions: ["Hypertension (disorder)"],
    medications: [{ name: "lisinopril 10 MG Oral Tablet" }], allergies: ["Peanut (substance)"], smoking: "Ex-smoker", social: [],
  });
  assert(prompt.includes("Patient background (synthetic record)"));
  assert(prompt.includes("lisinopril 10 MG Oral Tablet") && prompt.includes('"Peanut"'));
  assert(!prompt.includes("Peanut (substance)") &&!prompt.includes("Hypertension (disorder)"));
});

Deno.test("a leak names the field it's in, so the retry can fix it", () => {
  const w = goodWriting();
  w.facts[4] = { ...w.facts[4], reply: `I think it's ${terms[0]} again.` };
  const problem = checkWriting(w, plan, terms).find((p) => p.startsWith("reveals the diagnosis")) ?? "";
  assert(problem.includes(`fact ${w.facts[4].id} reply`), problem);
  assert(!problem.includes("patient quote"), problem);
});

Deno.test("leak spots name each field that reveals the diagnosis", () => {
  const w = goodWriting();
  w.facts[2].reply = `The doctor said it might be ${terms[0]}.`;
  w.maneuvers[0].finding = `Classic for ${terms[0]}`;
  const { leaked, where } = leakSpots(w, terms);
  assert(leaked.length > 0);
  assertEquals(where, [`fact ${w.facts[2].id} reply`, `maneuver ${w.maneuvers[0].id} finding`]);
});

Deno.test("the fix prompt carries only the leaking lines and the names to avoid", () => {
  const w = goodWriting();
  w.patient.quote = `I think it's ${terms[0]}.`;
  const prompt = fixPrompt(w, ["patient quote"], [terms[0]]);
  assert(prompt.includes(JSON.stringify(terms[0])));
  assert(prompt.includes(`"where":"patient quote"`));
  assert(!prompt.includes(w.facts[0].reply));
});

Deno.test("fixes land in the field they name; unknown, blank or bad fixes are ignored", () => {
  const w = goodWriting();
  const fixed = applyFixes(w, [
    { where: "patient quote", text: "My side hurts." },
    { where: `fact ${w.facts[1].id} reply`, text: "Since Tuesday." },
    { where: "suggested question 1", text: "When did it start?" },
    { where: `maneuver ${w.maneuvers[0].id} finding`, text: "Tender to touch." },
    { where: "fact nope reply", text: "ignored" },
    { where: "patient complaint", text: "   " },
    { where: "patient demeanor", text: 7 as unknown as string },
  ]);
  assertEquals(fixed.patient.quote, "My side hurts.");
  assertEquals(fixed.facts[1].reply, "Since Tuesday.");
  assertEquals(fixed.suggested[0].text, "When did it start?");
  assertEquals(fixed.maneuvers[0].finding, "Tender to touch.");
  assertEquals(fixed.patient.complaint, w.patient.complaint);
  assertEquals(fixed.patient.demeanor, w.patient.demeanor);
  assertEquals(w.patient.quote, "I don't feel right.", "the original is untouched");
});

Deno.test("a leak fixed by rewording passes the checks again", () => {
  const w = goodWriting();
  w.facts[0].reply = `My sister had ${terms[0]} too.`;
  assert(checkWriting(w, plan, terms).some((p) => p.startsWith("reveals the diagnosis")));
  const { where } = leakSpots(w, terms);
  assertEquals(checkWriting(applyFixes(w, where.map((at) => ({ where: at, text: "My sister had something similar." }))), plan, terms), []);
});
