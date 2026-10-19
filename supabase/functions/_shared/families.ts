// Condition families: the one profile template, tuned to the kind of condition. A psychiatric
// patient gets a mental status exam instead of a cardiac exam, an injury leads with its mechanism and
// imaging, an infection asks about exposures. The model stops inventing filler for sections that
// don't fit, so profiles fail their checks less often and replies are shorter.
//
// A condition can be in several families (a child's pneumonia is pediatric and an infection); their
// notes are added to each template stage's instructions. Pure: chosen from the catalog's triage.

export type Family =
  | "psychiatric" | "infection" | "cancer" | "injury" | "poisoning" | "surgical_abdomen"
  | "pediatric" | "obstetric" | "skin" | "cardiac" | "neurologic";

type Triage = {
  kind?: string; category?: string; organ_systems?: readonly string[]; primary_clerkship?: string; is_cancer?: boolean;
};

const INFECTION = /infection|infectious|viral|bacterial|fungal|parasitic|sepsis|arboviral|exanthem|sexually transmitted|tuberculosis/;

/** The families a condition belongs to, from its triage. */
export function familiesOf(t: Triage): Family[] {
  const category = (t.category ?? "").toLowerCase();
  const systems = t.organ_systems ?? [];
  const families: Family[] = [];
  if (t.kind === "injury") families.push("injury");
  if (t.kind === "poisoning" || /poisoning|toxicity|overdose/.test(category)) families.push("poisoning");
  if (t.primary_clerkship === "psychiatry" || systems.includes("behavioral") || /substance use|psychiatric|anxiety|depressive|mood|eating disorder|personality/.test(category)) {
    families.push("psychiatric");
  }
  if (INFECTION.test(category)) families.push("infection");
  if (t.is_cancer || /malignan|cancer|carcinoma|lymphoma|leukemia/.test(category)) families.push("cancer");
  if (/surgical abdomen/.test(category)) families.push("surgical_abdomen");
  if (t.primary_clerkship === "pediatrics") families.push("pediatric");
  if (t.primary_clerkship === "obgyn" && /pregnan|obstetric|gestation|placent|labor|postpartum/.test(category)) families.push("obstetric");
  if (t.primary_clerkship === "dermatology") families.push("skin");
  if (systems.includes("cardiovascular")) families.push("cardiac");
  if (systems.includes("nervous") && !families.includes("psychiatric")) families.push("neurologic");
  return families;
}

/** Per family, extra instructions for the template stages it changes, keyed by stage name. */
const NOTES: Record<Family, Partial<Record<string, string>>> = {
  psychiatric: {
    exam_vitals: "exam.findings are mostly the mental status exam (appearance, behavior, speech, mood, affect, thought process, thought content including suicidal or homicidal ideation, perception, cognition, insight and judgment), plus only the physical signs this condition causes (intoxication or withdrawal signs, self-harm marks). Vitals stay normal unless intoxication, withdrawal or a medical complication changes them.",
    diagnostics: "labs only to exclude medical causes or to monitor (TSH, BMP, CBC, urine drug screen, drug levels); imaging is usually not indicated (put it in not_indicated if a student might reach for it); ecg only when QT-prolonging drugs, an eating disorder or intoxication makes it relevant.",
    teaching: "key_questions include safety (suicide, self-harm, harm to others) and, where they apply, standard screening tools (PHQ-9, GAD-7, AUDIT, CAGE).",
  },
  infection: {
    patient_presentation: "Cover exposures that matter for this infection: sick contacts, travel, animals or insects, food and water, sexual history, vaccination status, immune status, and the fever pattern.",
    diagnostics: "Include the tests that identify the organism (cultures with sensitivities, rapid antigen or PCR, serology) as relevant; imaging only to find a source or a complication.",
    differential_course: "differential includes non-infectious look-alikes, not only other organisms.",
  },
  cancer: {
    patient_presentation: "Include constitutional symptoms (weight loss, night sweats, fatigue) with their timeframe, risk exposures (smoking, occupation, family history) and screening history.",
    diagnostics: "Tissue diagnosis (biopsy) is confirmatory; include staging imaging; tumor markers only where they are used clinically for this cancer.",
  },
  injury: {
    patient_presentation: "Lead with the mechanism of injury, when it happened and what happened since; the rest of the history is brief.",
    exam_vitals: "Primary survey findings (airway, breathing, circulation, disability) where the injury affects them, then a focused exam of the injured region, including neurovascular status distal to a limb injury.",
    diagnostics: "Imaging leads the workup (x-ray, CT, FAST ultrasound as fits the injury); labs only as relevant (CBC, type and screen, coagulation); ecg only for chest trauma or electrical injury.",
  },
  poisoning: {
    patient_presentation: "Cover what was taken, how much, when, by what route, whether intentional, and any co-ingestants.",
    exam_vitals: "Describe the toxidrome: pupils, skin (dry, diaphoretic, flushed), mental status, bowel sounds, tremor or clonus.",
    diagnostics: "Include drug levels where they exist, acetaminophen and salicylate levels, BMP with anion gap and serum osmolality where relevant, and the ECG (QRS, QT).",
    teaching: "reasoning_points include the antidote or decontamination and contacting poison control.",
  },
  surgical_abdomen: {
    exam_vitals: "The abdominal exam carries the case: tenderness location, guarding, rebound, rigidity and the named signs that apply.",
    diagnostics: "Imaging decides the diagnosis (ultrasound or CT as fits); labs support it (CBC, BMP, lipase, LFTs, lactate, pregnancy test in people who can be pregnant); ecg only for a cardiac look-alike.",
  },
  pediatric: {
    patient_presentation: "The patient is a child: the history comes mostly from a parent or caregiver; include birth history, growth, development, feeding and vaccination where they matter.",
    exam_vitals: "Describe vital sign levels relative to normal for the child's age.",
  },
  obstetric: {
    patient_presentation: "Include gestational age, gravidity and parity, prenatal care, and prior pregnancy complications.",
    diagnostics: "Include the pregnancy-specific tests (hCG, obstetric ultrasound, Rh type, urinalysis) as relevant.",
  },
  skin: {
    exam_vitals: "Describe lesions by morphology: primary lesion, color, size, distribution, configuration and secondary changes.",
    diagnostics: "Workup is bedside or tissue-based (KOH prep, dermoscopy, biopsy, cultures) as fits; imaging usually not indicated; ecg only if relevant.",
  },
  cardiac: {
    diagnostics: "ecg is relevant: give its findings.",
  },
  neurologic: {
    exam_vitals: "The neurologic exam localizes the lesion: mental status, cranial nerves, motor, sensory, reflexes, coordination and gait as relevant.",
  },
};

/** The instructions for one template stage with the families' notes added. */
export function withFamilyNotes(instructions: string, stageName: string, families: Family[]): string {
  const notes = families.map((f) => NOTES[f][stageName]).filter((n): n is string => !!n);
  return notes.length ? `${instructions}\n- For this kind of condition: ${notes.join(" ")}` : instructions;
}
