// The patient's own medical story beyond today's illness, built in code like the rest of the case:
// how long each condition has been there, what they take for it and what their doctor has told
// them, allergies with what happened, and whether anyone has seen them for this problem yet. The
// writer only words it, so every detail a patient says is one the case planned (and the fact audit
// can check). Pure, so it's unit-tested.

/** What a typical patient with a common chronic condition takes and has been told, at usual
 *  US starting doses. A condition without an entry still gets its age; no medicine is invented. */
type Care = { said: string; medication?: string; note: string };

const CARE: [RegExp, Care][] = [
  [/hypertension|high blood pressure/i, { said: "high blood pressure", medication: "lisinopril 10 mg once a day", note: "Their primary care doctor checks it every few months and says it's mostly under control." }],
  [/prediabetes/i, { said: "borderline blood sugar", note: "A checkup found it; the doctor told them to cut back on sweets and walk more." }],
  [/diabetes/i, { said: "type 2 diabetes", medication: "metformin 500 mg twice a day with meals", note: "Their last A1c was about 7, and the doctor would like it a little lower." }],
  [/hyperlipidemia|high cholesterol|hypercholesterol/i, { said: "high cholesterol", medication: "atorvastatin 20 mg at night", note: "It showed up on routine bloodwork." }],
  [/coronary|ischemic heart/i, { said: "heart disease", medication: "aspirin 81 mg once a day", note: "A cardiologist sees them once a year." }],
  [/atrial fibrillation/i, { said: "an irregular heartbeat (atrial fibrillation)", medication: "apixaban 5 mg twice a day", note: "A cardiologist follows it and told them never to skip the blood thinner." }],
  [/asthma/i, { said: "asthma", medication: "an albuterol inhaler as needed", note: "They use it a couple of times a month, more in the winter." }],
  [/chronic obstructive|copd|emphysema/i, { said: "COPD", medication: "a tiotropium inhaler once a day and albuterol as needed", note: "A lung doctor sees them once a year." }],
  [/hypothyroid/i, { said: "an underactive thyroid", medication: "levothyroxine 50 mcg every morning", note: "The doctor checks a thyroid blood test once a year." }],
  [/reflux|gerd|heartburn/i, { said: "acid reflux", medication: "omeprazole 20 mg before breakfast", note: "The heartburn is mostly under control on it." }],
  [/depress/i, { said: "depression", medication: "sertraline 50 mg once a day", note: "Their primary care doctor started it, and their mood is better than it was." }],
  [/anxiety/i, { said: "anxiety", medication: "sertraline 50 mg once a day", note: "Their primary care doctor started it a while back." }],
  [/osteoarthritis|arthritis/i, { said: "arthritis in their joints", medication: "acetaminophen 500 mg as needed", note: "The doctor told them it's wear and tear." }],
  [/back pain/i, { said: "on-and-off back pain", medication: "ibuprofen 400 mg as needed", note: "Physical therapy helped a few years ago." }],
  [/allergic rhinitis|hay fever|seasonal allerg/i, { said: "seasonal allergies", medication: "cetirizine 10 mg once a day in the spring", note: "It's worse when the pollen is high." }],
  [/gout/i, { said: "gout", medication: "allopurinol 100 mg once a day", note: "They haven't had a flare in over a year." }],
  [/osteoporosis/i, { said: "thin bones (osteoporosis)", medication: "alendronate 70 mg once a week", note: "A bone scan found it." }],
  [/anemia/i, { said: "low iron", medication: "ferrous sulfate 325 mg once a day", note: "Their doctor checks their blood count now and then." }],
  [/sleep apnea/i, { said: "sleep apnea", note: "They use a CPAP machine most nights." }],
  [/chronic kidney/i, { said: "kidney disease", note: "A kidney doctor keeps an eye on their kidney blood tests." }],
  [/obes|body mass index 3/i, { said: "being overweight", note: "Their doctor has talked with them about losing weight." }],
];

/** What happened with each common allergy, so "what happens?" has an answer. */
const REACTION: [RegExp, string][] = [
  [/penicillin|amoxicillin/i, "broke out in hives"],
  [/sulfa|sulfonamide/i, "got a rash"],
  [/peanut|tree nut|shellfish|fish/i, "their lips and throat swelled up"],
  [/latex/i, "got an itchy rash"],
  [/aspirin|ibuprofen|nsaid/i, "got wheezy"],
  [/codeine|morphine/i, "threw up"],
  [/pollen|grass|dust|mold|dander|cat|dog/i, "get sneezy and itchy eyes"],
  [/bee|wasp|insect/i, "swelled up a lot"],
  [/egg|milk|wheat|soy/i, "got a stomachache and hives"],
];

export type HistoryFact = { label: string; content: string; importance: "important" | "optional" };

/** An allergy as a patient says it: "Penicillin V" → "penicillin" (drop the drug's letter variant). */
function allergen(raw: string): string {
  return raw.replace(/\s+[a-z]$/i, "").toLowerCase();
}

/** Lowercase first letter, for a condition name dropped into a sentence. */
const lower = (s: string) => s.charAt(0).toLowerCase() + s.slice(1);

/** A condition as a revealed-fact chip: "an irregular heartbeat (atrial fibrillation)" → "Irregular heartbeat". */
function chipLabel(said: string): string {
  const bare = said.replace(/\s*\(.*\)$/, "").replace(/^(an?|the|on-and-off) /, "");
  return bare.charAt(0).toUpperCase() + bare.slice(1);
}

/** The care entry for a condition, if it's a common one. */
export function careFor(condition: string): Care | null {
  return CARE.find(([test]) => test.test(condition))?.[1] ?? null;
}

/**
 * The patient's past history as facts: a summary of their conditions with how long each has been
 * there, one fact per known condition with its medicine and what the doctor said, their medicines
 * (the record's own when it has some, else the usual one for each condition), allergies with the
 * reaction, and whether anyone has looked at today's problem yet.
 */
export function historyFacts(
  conditions: string[], recordMedications: string[], allergies: string[], rng: () => number,
): HistoryFact[] {
  const facts: HistoryFact[] = [];
  const seen = new Set<string>();
  const known = conditions.map((c) => ({ raw: c, care: careFor(c) })).filter(({ raw, care }) => {
    const key = care?.said ?? raw.toLowerCase();
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
  // Years since diagnosis, fixed per condition for this patient so a repeat question agrees.
  const years = known.map(() => 2 + Math.floor(rng() * 12));

  if (known.length) {
    const parts = known.map(({ raw, care }, i) => `${care?.said ?? lower(raw)} (for about ${years[i]} years)`);
    facts.push({ label: "Past medical history", content: `Has ${parts.join(", ")}.`, importance: "important" });
  } else {
    facts.push({ label: "Past medical history", content: "No significant past medical history; healthy until now.", importance: "important" });
  }

  const fromRecord = recordMedications.length > 0;
  for (const [i, { care }] of known.entries()) {
    if (!care) continue;
    const takes = !fromRecord && care.medication ? ` Takes ${care.medication} for it.` : "";
    facts.push({
      label: chipLabel(care.said),
      content: `Diagnosed with ${care.said} about ${years[i]} years ago.${takes} ${care.note}`,
      importance: "optional",
    });
  }

  const medications = fromRecord
    ? recordMedications
    : [...new Set(known.map(({ care }) => care?.medication).filter((m): m is string => !!m))];
  facts.push({
    label: "Medications",
    content: medications.length ? `Takes ${medications.join("; ")}. Takes them as prescribed.` : "Takes no regular medications, prescription or over the counter.",
    importance: "important",
  });

  facts.push({
    label: "Allergies",
    content: allergies.length
      ? allergies.map((a) => `Allergic to ${allergen(a)}: ${REACTION.find(([test]) => test.test(a))?.[1] ?? "had a bad reaction once"}.`).join(" ")
      : "No known drug allergies.",
    importance: "optional",
  });
  return facts;
}

/** Whether anyone has seen them for today's problem: one plain, safe story per case. */
export function priorCare(rng: () => number): HistoryFact {
  const stories = [
    "Hasn't seen a doctor about this yet; came in because it isn't getting better.",
    "Called their primary care office this morning, and the nurse told them to get checked today.",
    "Mentioned it to a family member, who talked them into coming in. No one has examined them for it yet.",
  ];
  return { label: "Care so far", content: stories[Math.floor(rng() * stories.length) % stories.length], importance: "optional" };
}
