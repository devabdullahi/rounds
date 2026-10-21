// The human parts of a case, filled in from templates: no model call. Code already built every fact,
// exam result and test (skeleton.ts); this words them and adds the door note, the person and the
// one-tap questions. The patient model voices each fact in character when the student asks
// (case-session ask), so the facts only need to say the right thing plainly here, and nothing can be
// invented because every word comes from the plan.
// Pure, so the rules are unit-tested.
import type { CasePlan, Profile } from "../_shared/casegen.ts";
import { backgroundForWriter, type PatientBackground } from "./background.ts";
import { diagnosisWords, plain, type Skeleton } from "./skeleton.ts";
import { patientName } from "../_shared/names.ts";
import type { Voice } from "./writer.ts";

const DEMEANOR: Record<string, string> = {
  mild: "Comfortable, talking easily",
  moderate: "Uncomfortable but conversant",
  severe: "In obvious distress",
  critical: "Ill-appearing, struggling to talk",
};

const SETTING: Record<string, string> = {
  emergency: "Walk-in, emergency department",
  urgent_care: "Walk-in, urgent care",
  clinic: "Scheduled visit, primary care clinic",
  pediatric_clinic: "Scheduled visit, pediatric clinic",
  outpatient: "Scheduled visit, primary care clinic",
  labor_delivery: "Admitted, labor and delivery",
  psychiatric: "Admitted, inpatient psychiatric unit",
  inpatient: "Admitted, medical ward",
  icu: "Transferred, intensive care unit",
};

/** One-tap questions for the facts a strong history opens with, keyed by the skeleton's labels. */
const QUESTIONS: [label: string, question: string][] = [
  ["Onset", "When did this start?"],
  ["Location", "Where exactly do you feel it?"],
  ["Character", "What does it feel like?"],
  ["Course", "Has it changed since it started?"],
  ["What changes it", "Does anything make it better or worse?"],
  ["Past medical history", "Do you have any medical conditions?"],
  ["Medications", "Do you take any medications?"],
  ["Social history", "Do you smoke, drink or use any drugs?"],
];

const pick = <T>(list: T[], rng: () => number): T => list[Math.floor(rng() * list.length) % list.length];
const sentence = (text: string) => {
  const t = text.trim().replace(/[.;\s]+$/, "");
  return t ? `${t[0].toUpperCase()}${t.slice(1)}.` : "";
};
/** "Murphy sign", "Babinski reflex": an eponym keeps its capital. */
const EPONYM = /^[A-Z][a-z]+(?:'s)? (sign|test|maneuver|reflex|triad|nodes?|spots?|lines?)\b/;

/** Lowercases a leading capital of each "; "-separated item, leaving acronyms ("ECG", "RUQ") alone. */
const lower = (text: string) => text.split("; ").map((t) => EPONYM.test(t) ? t : t.replace(/^[A-Z](?![A-Z])/, (c) => c.toLowerCase())).join("; ");

/** A fact's clinical content as a plain first-person line for the patient model to voice. */
export function factReply(content: string): string {
  const c = content.trim();
  let m: RegExpMatchArray | null;
  if ((m = c.match(/^Also has (.+?)\.?$/))) return `Also ${lower(m[1])}.`;
  if ((m = c.match(/^Has (.+?)\.?$/))) return `Yes, ${lower(m[1])}.`;
  if ((m = c.match(/^Denies: (.+?)\.?$/))) return `No ${lower(m[1]).replace(/; /g, ", no ")}.`;
  if (c === "Takes no regular medications.") return "I don't take any regular medications.";
  if ((m = c.match(/^Takes (.+?)\.?$/))) return `I take ${m[1]}.`;
  if (c === "No known drug allergies.") return "No allergies that I know of.";
  if ((m = c.match(/^Allergic to (.+?)\.?$/))) return `I'm allergic to ${m[1]}.`;
  // History of present illness: "onset: sudden. duration: 2 days" → its values.
  if (/^[a-z_]+: /.test(c)) return c.split(/\.\s+(?=[a-z_]+: )/).map((part) => sentence(part.replace(/^[a-z_]+: /, ""))).join(" ");
  return sentence(c);
}

/** How far along a pregnant patient is: weeks the profile mentions for this condition, else none. */
export function gestationalWeeks(profile: Profile): number | null {
  const text = JSON.stringify(profile.presentation) + JSON.stringify(profile.course ?? {});
  const range = text.match(/(\d{1,2})\s*(?:-|–|to)\s*(\d{1,2})\s*weeks/);
  if (range) return Math.round((Number(range[1]) + Number(range[2])) / 2);
  const single = text.match(/(?:after|beyond|past|at|about)\s+(\d{1,2})\s*weeks/);
  return single ? Number(single[1]) : null;
}

/** A study's report from its planned findings: findings that name the diagnosis are left out, and a
 *  "normal" finding is dropped when abnormal ones were planned alongside it. */
export function studyReport(findings: string[], banned: string[]): string[] {
  const clean = findings.map((f) => f.replace(/\s*\([^)]*\)/g, "").trim()).filter((f) => f && !banned.some((w) => f.toLowerCase().includes(w)));
  const abnormal = clean.filter((f) => !/^(usually |often |typically )?normal\b/i.test(f));
  return (abnormal.length ? abnormal : []).map(sentence).filter(Boolean);
}

/** A normal report for a study with no planned findings, in the wording its kind of test uses. */
export function normalReport(name: string, psychology: boolean): string {
  const n = name.toLowerCase();
  if (psychology) return "Score within the normal range.";
  if (/\b(ecg|ekg|electrocardiogram)\b/.test(n)) return "Normal sinus rhythm. No acute ST-segment or T-wave changes.";
  if (/culture|pcr|antigen|swab|serolog|rapid|naat|smear/.test(n)) return "Negative.";
  if (/biopsy|cytolog|patholog/.test(n)) return "No diagnostic abnormality.";
  if (/x-?ray|radiograph|\bct\b|tomograph|\bmri\b|ultrasound|sonograph|echo|doppler|scan|angiogra/.test(n)) return "No acute abnormality.";
  return "Within normal limits.";
}

/** A positive report for a test that finds the condition, when no writer worded it. It doesn't name
 *  the organism (the template has no safe source for it) but never reads negative. */
export function positiveReport(name: string): string {
  const n = name.toLowerCase();
  if (/culture/.test(n)) return "Growth of a pathogenic organism. Identification and susceptibilities to follow.";
  if (/serolog|antibod|titer|\big[gm]\b|monospot/.test(n)) return "Positive.";
  return "Detected.";
}

/** The person: an age- and sex-appropriate word for them. */
function who(plan: CasePlan): string {
  if (plan.age < 18) return plan.sex === "F" ? "girl" : "boy";
  return plan.sex === "F" ? "woman" : "man";
}

/** Everything a written case needs beyond the skeleton, filled in from templates. */
export function templateVoice(profile: Profile, plan: CasePlan, skeleton: Skeleton, background: PatientBackground | null, rng: () => number): Voice {
  const complaints = profile.presentation.chief_complaints;
  const banned = diagnosisWords(profile);
  const safe = (t: string | undefined) => t && !banned.some((w) => t.toLowerCase().includes(w)) ? t : undefined;
  const chief = complaints[0] as { text: string; term?: string } | undefined;
  const duration = String(profile.presentation.hpi.duration ?? "").split(/[;,(.]/)[0].trim();
  const spans = /\d|minute|hour|day|week|month|year/i.test(duration) && duration.split(" ").length <= 5 && safe(duration);
  // The clinical term ("Rhinorrhea"); the patient's own words ("my nose is runny") don't fit a triage note.
  const firstPerson = (t?: string) => t && /\b(i|i'm|i've|my|me)\b/i.test(t) ? undefined : t;
  const complaintText = lower(safe(chief?.term) ?? safe(firstPerson(chief?.text)) ?? "feeling unwell");
  const doorNote = `${plan.age}-year-old ${who(plan)}${plan.pregnant ? ", pregnant," : ""} with ${complaintText}${spans ? ` for ${lower(duration)}` : ""}.`;

  const record = background ? backgroundForWriter(background) : null;
  const life = [record?.marital_status, ...(record?.social ?? []).slice(0, 2)].filter(Boolean).join("; ");
  const voice = plan.age < 13 ? "A young child with a parent who answers most questions, in plain words"
    : plan.age < 18 ? "A teenager; short answers in everyday words"
    : plan.age >= 65 ? "An older adult; unhurried, plain everyday words"
    : "Plain everyday words; answers what is asked";
  const unwell = plan.severity === "severe" || plan.severity === "critical";

  const weeks = plan.pregnant ? gestationalWeeks(profile) : null;
  const facts: Voice["facts"] = Object.fromEntries(skeleton.facts.map((f) => [f.id, {
    label: f.label,
    reply: f.label === "Pregnancy" ? (weeks ? `I'm pregnant, about ${weeks} weeks along.` : "Yes, I'm pregnant.") : factReply(f.content),
  }]));

  const byLabel = new Map(skeleton.facts.map((f) => [f.label, f.id]));
  const firstSymptom = skeleton.facts.find((f) => f.content.startsWith("Has "));
  const suggested = [
    ...QUESTIONS.filter(([label]) => byLabel.has(label)).map(([label, text]) => ({ text, fact: byLabel.get(label)! })),
    ...(firstSymptom ? [{ text: "Have you noticed anything else?", fact: firstSymptom.id }] : []),
  ].slice(0, 8);

  const examById = new Map(plan.exam.map((f, i) => [`x${i + 1}`, f as { finding: string; term?: string }]));
  const normals = Object.fromEntries(skeleton.maneuvers.filter((m) => m.finding === null).map((m) => {
    const f = examById.get(m.id);
    const said = f ? plain(f.term ?? f.finding, banned) : "";
    return [m.id, said ? sentence(`No ${lower(said)}`) : "Normal."];
  }));

  const studies = plan.tests.filter((t) => t.kind === "study").map((t) => {
    const found = studyReport(t.findings ?? [], banned);
    if (!found.length && t.positive) return { test_id: t.id, result: positiveReport(t.name), abnormal: true };
    return { test_id: t.id, result: found.length ? found.join(" ") : normalReport(t.name, plan.psychology), abnormal: found.length > 0 };
  });

  return {
    patient: {
      name: patientName(plan.sex, plan.age, rng),
      quote: pick(complaints.map((c) => c.text).filter((t) => safe(t)), rng) ?? "I haven't been feeling well.",
      demeanor: DEMEANOR[plan.severity] ?? DEMEANOR.moderate,
      setting: plan.psychology ? "Referral, outpatient psychology clinic"
        : plan.dermatology ? "Scheduled visit, dermatology clinic"
        : SETTING[profile.triage.settings[0]] ?? SETTING.clinic,
      complaint: doorNote,
    },
    persona: {
      voice: unwell ? `${voice}; short answers because they feel very unwell` : voice,
      background: life ? sentence(life) : "Lives locally with family.",
      fallback: "Sorry, I'm not sure what you mean.",
    },
    facts,
    normals,
    studies,
    suggested,
  };
}
