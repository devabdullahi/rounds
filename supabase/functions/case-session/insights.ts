// What the student sees about the condition once a case is graded: a short teaching summary, the
// differential the profile lists (and which of those the student named), and the student's own
// alternatives the profile didn't list. Built only at submit, so nothing reaches the app while the
// case is open. Pure, so it's tested with a fixture shaped like a real profile.
import { diagnosisCandidates, matchesDiagnosis, words } from "./grade.ts";

type Frequency = "almost_always" | "common" | "sometimes" | "rare";
type Item = { text: string; frequency?: Frequency };

/** The parts of a condition profile (private.condition_profiles.profile) these insights read. Every
 *  part is optional: older profiles may lack some, and a missing part just leaves its list empty. */
export type InsightProfile = {
  teaching?: { reasoning_points?: string[] };
  presentation?: { chief_complaints?: Item[]; ros?: { positives?: Item[] }[] };
  patient?: { risk_factors?: { text: string; strength?: string }[] };
  differential?: {
    name: string;
    slug?: string;
    must_not_miss?: boolean;
    why_considered?: string;
    discriminators?: Record<string, string[] | undefined>;
  }[];
};

export type Insights = {
  about: { summary_points: string[]; symptoms: string[]; risk_factors: string[] };
  differential: { name: string; must_not_miss: boolean; why: string; tell_apart: string[]; in_yours: boolean }[];
  your_extras: string[];
};

const MAX = { summary: 4, symptoms: 6, riskFactors: 5, differential: 5, tellApart: 2, extras: 5 };
const FREQUENCY_RANK: Record<string, number> = { almost_always: 0, common: 1, sometimes: 2, rare: 3 };
const STRENGTH_RANK: Record<string, number> = { strong: 0, moderate: 1, weak: 2 };
/** Discriminator groups in the order a student meets them: what the patient says, then the exam, then results. */
const DISCRIMINATOR_ORDER = ["history", "exam", "labs", "imaging", "ecg"];
// Words that don't make two symptoms different ("I have pressure in my chest" = "Chest pressure").
const STOPWORDS = new Set(["i", "my", "me", "a", "an", "the", "is", "am", "are", "have", "has", "feel", "feels", "feeling", "in", "of", "and", "or", "it", "to", "like"]);
// Too vague on their own to name one alternative.
const GENERIC = new Set(["pain", "disease", "disorder", "syndrome", "infection", "failure", "acute", "chronic", "injury", "cancer", "tumor", "attack"]);

/** Builds the insights from the condition's profile, the student's submitted differential, and the
 *  case's correct names (diagnosis plus accepted), which are never counted as an extra. */
export function conditionInsights(profile: InsightProfile, studentDifferential: string[], answerNames: string[]): Insights {
  const items = profile.differential ?? [];
  const named = studentDifferential.map((entry) => ({ entry, candidates: diagnosisCandidates(entry) }));
  const matched = new Set<string>();
  const differential = items
    .map((d, index) => ({ d, index }))
    .sort((a, b) => Number(!!b.d.must_not_miss) - Number(!!a.d.must_not_miss) || a.index - b.index)
    .slice(0, MAX.differential)
    .map(({ d }) => {
      const hits = named.filter((n) => n.candidates.some((c) => namesItem(c, d)));
      hits.forEach((h) => matched.add(h.entry));
      return {
        name: d.name, must_not_miss: !!d.must_not_miss, why: d.why_considered ?? "",
        tell_apart: tellApart(d.discriminators ?? {}), in_yours: hits.length > 0,
      };
    });
  // An entry counts as listed when it names any of the profile's alternatives, not only the five shown.
  for (const n of named) if (items.some((d) => n.candidates.some((c) => namesItem(c, d)))) matched.add(n.entry);

  const answers = answerNames.map(words).filter(Boolean);
  const extras = named.filter((n) =>
    n.candidates.length > 0 && !matched.has(n.entry) && !matchesDiagnosis(n.entry, answerNames) &&
    !n.candidates.some((c) => answers.some((a) => sameName(c, a)))
  ).map((n) => n.entry.trim());

  return {
    about: {
      summary_points: (profile.teaching?.reasoning_points ?? []).slice(0, MAX.summary),
      symptoms: symptoms(profile),
      risk_factors: [...(profile.patient?.risk_factors ?? [])]
        .map((r, index) => ({ r, index }))
        .sort((a, b) => rank(STRENGTH_RANK, a.r.strength) - rank(STRENGTH_RANK, b.r.strength) || a.index - b.index)
        .slice(0, MAX.riskFactors).map(({ r }) => r.text),
    },
    differential,
    your_extras: [...new Set(extras)].slice(0, MAX.extras),
  };
}

function rank(table: Record<string, number>, key: string | undefined): number {
  return table[key ?? ""] ?? Object.keys(table).length;
}

/** Chief complaints and frequent review-of-systems positives, most frequent first, near-duplicates dropped. */
function symptoms(profile: InsightProfile): string[] {
  const complaints = (profile.presentation?.chief_complaints ?? []).map((c, index) => ({ ...c, order: index }));
  const ros = (profile.presentation?.ros ?? []).flatMap((s) => s.positives ?? [])
    .filter((p) => p.frequency === "almost_always" || p.frequency === "common")
    .map((p, index) => ({ ...p, order: complaints.length + index }));
  const ordered = [...complaints, ...ros].sort((a, b) =>
    rank(FREQUENCY_RANK, a.frequency) - rank(FREQUENCY_RANK, b.frequency) || a.order - b.order);
  const kept: { text: string; tokens: Set<string> }[] = [];
  for (const s of ordered) {
    const tokens = new Set(words(s.text).split(" ").filter((w) => w && !STOPWORDS.has(w)));
    if (tokens.size === 0 || kept.some((k) => subset(tokens, k.tokens) || subset(k.tokens, tokens))) continue;
    kept.push({ text: s.text, tokens });
    if (kept.length === MAX.symptoms) break;
  }
  return kept.map((k) => k.text);
}

function subset(a: Set<string>, b: Set<string>): boolean {
  return [...a].every((w) => b.has(w));
}

/** Up to two ways to tell this alternative apart: one from each group in order (history first), then more. */
function tellApart(discriminators: Record<string, string[] | undefined>): string[] {
  const groups = [...DISCRIMINATOR_ORDER, ...Object.keys(discriminators).filter((k) => !DISCRIMINATOR_ORDER.includes(k))]
    .map((k) => (discriminators[k] ?? []).filter((s) => typeof s === "string" && s.trim()));
  const out: string[] = [];
  for (let i = 0; out.length < MAX.tellApart && groups.some((g) => i < g.length); i++) {
    for (const g of groups) if (i < g.length && out.length < MAX.tellApart) out.push(g[i]);
  }
  return out;
}

/** The names an alternative goes by: its name, its slug in words, and any parenthesized short form
 *  ("Pulmonary embolism (PE)" also goes by "pe" and "pulmonary embolism"). */
function aliases(d: { name: string; slug?: string }): string[] {
  const inner = [...d.name.matchAll(/\(([^)]*)\)/g)].map((m) => m[1]);
  return [d.name, d.name.replace(/\([^)]*\)/g, " "), ...inner, d.slug ?? ""].map(words).filter(Boolean);
}

/** True when one normalized candidate from the student names this alternative. */
function namesItem(candidate: string, d: { name: string; slug?: string }): boolean {
  return aliases(d).some((alias) => sameName(candidate, alias));
}

/** Whole-word containment either way: "aortic dissection type a" names "Aortic dissection", and
 *  "dissection" names it too. A partial name must be 4+ letters and not a generic word ("pain",
 *  "disease"), so a vague entry can't claim every alternative that contains it. */
function sameName(candidate: string, name: string): boolean {
  if (` ${candidate} `.includes(` ${name} `)) return true;
  return candidate.length >= 4 && !GENERIC.has(candidate) && ` ${name} `.includes(` ${candidate} `);
}
