import { assertEquals } from "jsr:@std/assert@1";
import { backgroundForWriter, type PatientBackground, pickBackground } from "./background.ts";

function row(id: string, age: number, sex: string, conditions: string[] = []): PatientBackground {
  return { id, age, sex, marital: "M", conditions, medications: [], allergies: [], smoking: "Never smoked tobacco", social: [] };
}

const rows = [
  row("f50", 50, "F"), row("m48", 48, "M"), row("m53", 53, "M"), row("m47", 47, "M"),
  row("m60", 60, "M"), row("m50mi", 50, "M", ["Hyperlipidemia", "Acute ST segment elevation myocardial infarction (disorder)"]),
  row("m49preg", 49, "M", ["Normal pregnancy"]),
];
const mi = ["Myocardial infarction", "Heart attack", "STEMI"];
const man50 = { age: 50, sex: "M" as const, pregnant: false };
const first = () => 0;
const last = () => 0.999;

Deno.test("picks the same sex at the closest age, at random among ties", () => {
  // m48 is 2 years off; m47 and m53 are 3; m50mi is skipped for naming the diagnosis.
  assertEquals(pickBackground(rows, man50, mi, first)?.id, "m48");
  const tied = [row("a", 45, "F"), row("b", 55, "F"), row("c", 40, "F")];
  const woman50 = { age: 50, sex: "F" as const, pregnant: false };
  assertEquals(pickBackground(tied, woman50, mi, first)?.id, "a");
  assertEquals(pickBackground(tied, woman50, mi, last)?.id, "b");
});

Deno.test("nothing within seven years, or of the same sex, gives null", () => {
  assertEquals(pickBackground([row("old", 58, "M")], man50, mi, first), null);
  assertEquals(pickBackground([row("f", 50, "F")], man50, mi, first), null);
  assertEquals(pickBackground([row("edge", 57, "M")], man50, mi, first)?.id, "edge");
  assertEquals(pickBackground([], man50, mi, first), null);
});

Deno.test("skips a background whose conditions name the diagnosis", () => {
  const onlyMi = [row("m50mi", 50, "M", ["Acute ST segment elevation myocardial infarction (disorder)"]), row("m55", 55, "M", ["Hyperlipidemia"])];
  assertEquals(pickBackground(onlyMi, man50, mi, first)?.id, "m55");
  // A background condition that is part of the diagnosis's name gives it away too.
  const anemia = [row("an", 50, "M", ["Anemia"]), row("ok", 52, "M", ["Hypertension"])];
  assertEquals(pickBackground(anemia, man50, ["Iron deficiency anemia"], first)?.id, "ok");
});

Deno.test("skips pregnancies unless the patient is pregnant", () => {
  const preg = [row("p", 30, "F", ["Normal pregnancy"]), row("q", 33, "F")];
  assertEquals(pickBackground(preg, { age: 30, sex: "F", pregnant: false }, mi, first)?.id, "q");
  assertEquals(pickBackground(preg, { age: 30, sex: "F", pregnant: true }, mi, first)?.id, "p");
});

Deno.test("writer input drops SNOMED tags and the allergic-disposition marker", () => {
  const b: PatientBackground = {
    id: "x", age: 45, sex: "F", marital: "W", conditions: ["Chronic sinusitis (disorder)", "Body mass index 30+ - obesity"],
    medications: [{ rxcui: "311372", name: "Loratadine 10 MG Oral Tablet" }],
    allergies: ["Allergic disposition", "Peanut (substance)", "Mold (organism)"], smoking: "Ex-smoker", social: ["Full-time employment (finding)"],
  };
  assertEquals(backgroundForWriter(b), {
    chronic_conditions: ["Chronic sinusitis", "Body mass index 30+ - obesity"],
    current_medications: ["Loratadine 10 MG Oral Tablet"],
    allergies: ["Peanut", "Mold"], smoking: "Ex-smoker", marital_status: "widowed", social: ["Full-time employment"],
  });
});
