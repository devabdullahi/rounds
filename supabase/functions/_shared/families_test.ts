import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { type Family, familiesOf, withFamilyNotes } from "./families.ts";

Deno.test("families come from the triage", () => {
  for (const [triage, families] of [
    [{ kind: "disease", category: "anxiety disorder", organ_systems: ["behavioral"], primary_clerkship: "psychiatry" }, ["psychiatric"]],
    [{ kind: "disease", category: "viral infection", organ_systems: ["respiratory"], primary_clerkship: "pediatrics" }, ["infection", "pediatric"]],
    [{ kind: "injury", category: "fracture", organ_systems: ["musculoskeletal"], primary_clerkship: "emergency" }, ["injury"]],
    [{ kind: "disease", category: "gastrointestinal malignancy", organ_systems: ["gastrointestinal"], is_cancer: true }, ["cancer"]],
    [{ kind: "disease", category: "acute surgical abdomen", organ_systems: ["gastrointestinal"], primary_clerkship: "surgery" }, ["surgical_abdomen"]],
    [{ kind: "disease", category: "ischemic heart disease", organ_systems: ["cardiovascular"] }, ["cardiac"]],
    [{ kind: "disease", category: "cerebrovascular disease", organ_systems: ["nervous", "cardiovascular"] }, ["cardiac", "neurologic"]],
    [{ kind: "disease", category: "substance use disorder", organ_systems: ["nervous", "behavioral"] }, ["psychiatric"]],
    [{ kind: "disease", category: "vitamin deficiency", organ_systems: ["blood"] }, []],
  ] as const) {
    assertEquals(familiesOf(triage), [...families] as Family[], triage.category);
  }
});

Deno.test("a stage gets the notes of every family it belongs to, and is unchanged without any", () => {
  const notes = withFamilyNotes("Describe the exam.", "exam_vitals", ["psychiatric", "pediatric"]);
  assertStringIncludes(notes, "mental status exam");
  assertStringIncludes(notes, "normal for the child's age");
  assertEquals(withFamilyNotes("Describe the exam.", "teaching", ["skin"]), "Describe the exam.");
  assertEquals(withFamilyNotes("Describe the exam.", "exam_vitals", []), "Describe the exam.");
});
