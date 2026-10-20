// A condition profile built live for one case, from public medical APIs and the profile template,
// with nothing stored (the user's design, 2026-10-19: no saved profiles, only templates).
//
//   1. Fetch what the APIs know about the condition, all at once: MedlinePlus's summary, UMLS
//      definitions and SNOMED CT relationships (finding site, morphology, cause…), and the drugs
//      MED-RT says may treat it (RxClass). A source that fails or times out is just left out.
//   2. Fill the template (the profile schema's five sections, _shared/profilegen.ts) with the model,
//      every section at the same time, each grounded in those facts.
//   3. The caller runs the usual schema, rule and terminology checks before planning the patient.
//
// SNOMED CT names go only to the model, server side; they're never stored or sent to the app.

import { ingredients, labelCandidates, labelFacts, labelLines } from "./fdalabel.ts";
import { autoFix, labNormal, repair, ruleErrors, sectionErrors, sectionsOutput, STAGES, stagePrompt } from "./profilegen.ts";
import { type Level, levelRange, LEVELS, rangeLevel, VITAL_NORMALS } from "./levels.ts";
import { type Family, familiesOf, withFamilyNotes } from "./families.ts";
import { ageUnitErrors } from "./agecheck.ts";

// deno-lint-ignore no-explicit-any
type Json = any;

export type Facts = { summary: string; definitions: string[]; relations: string[]; treatments: string[]; labels?: string[] };

const TIMEOUT_MS = 6_000;
const UMLS = "https://uts-ws.nlm.nih.gov/rest";
/** SNOMED CT relationships that describe a disorder, in plain words for the model. */
const RELATIONS: Record<string, string> = {
  has_finding_site: "body site", has_associated_morphology: "tissue change", has_causative_agent: "cause",
  due_to: "due to", has_pathological_process: "process", associated_with: "associated with", has_clinical_course: "course",
  has_associated_finding: "associated finding", has_interpretation: "interpretation", occurs_after: "occurs after",
  has_manifestation: "manifestation", has_occurrence: "typical age",
};

async function getJSON(url: string): Promise<Json> {
  const res = await fetch(url, { signal: AbortSignal.timeout(TIMEOUT_MS) });
  if (!res.ok) throw new Error(`${res.status} ${url.split("?")[0]}`);
  return await res.json();
}

/** MedlinePlus's summary of the health topic whose title best matches the name, as plain text. */
export async function medlinePlusSummary(name: string): Promise<string> {
  const url = `https://wsearch.nlm.nih.gov/ws/query?db=healthTopics&rettype=brief&retmax=1&term=${encodeURIComponent(`title:${name}`)}`;
  const res = await fetch(url, { signal: AbortSignal.timeout(TIMEOUT_MS) });
  if (!res.ok) return "";
  const xml = await res.text();
  const summary = xml.match(/<content name="FullSummary">([\s\S]*?)<\/content>/)?.[1] ?? "";
  return decode(summary).replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim().slice(0, 4000);
}

function decode(text: string): string {
  return text.replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&amp;/g, "&");
}

/** UMLS definitions and SNOMED CT relationships for the condition's concept. */
export async function umlsFacts(name: string, key: string): Promise<{ definitions: string[]; relations: string[] }> {
  const q = (path: string, params: Record<string, string>) =>
    getJSON(`${UMLS}${path}?${new URLSearchParams({ ...params, apiKey: key })}`);
  const hit = (await q("/search/current", { string: name, searchType: "exact", pageSize: "1" })).result?.results?.[0];
  if (!hit?.ui || hit.ui === "NONE") return { definitions: [], relations: [] };
  const [defs, rels] = await Promise.all([
    q(`/content/current/CUI/${hit.ui}/definitions`, { pageSize: "10" }).catch(() => ({ result: [] })),
    q(`/content/current/CUI/${hit.ui}/relations`, { pageSize: "100", includeRelationLabels: "RO" }).catch(() => ({ result: [] })),
  ]);
  const definitions = (defs.result ?? [])
    .filter((d: Json) => ["MSH", "NCI", "MEDLINEPLUS", "CSP", "HPO"].includes(d.rootSource))
    .map((d: Json) => String(d.value).replace(/<[^>]+>/g, "").slice(0, 600)).slice(0, 3);
  const relations = (rels.result ?? [])
    .filter((r: Json) => r.rootSource === "SNOMEDCT_US" && RELATIONS[r.additionalRelationLabel])
    .map((r: Json) => `${RELATIONS[r.additionalRelationLabel]}: ${r.relatedIdName}`);
  return { definitions, relations: [...new Set<string>(relations)].slice(0, 25) };
}

/** Drugs MED-RT says may treat the condition (RxClass), by name. */
export async function treatments(name: string): Promise<string[]> {
  const RX = "https://rxnav.nlm.nih.gov/REST/rxclass";
  const found = await getJSON(`${RX}/class/byName.json?className=${encodeURIComponent(name)}&classTypes=DISEASE`);
  const classId = found.rxclassMinConceptList?.rxclassMinConcept?.[0]?.classId;
  if (!classId) return [];
  const members = await getJSON(`${RX}/classMembers.json?classId=${classId}&relaSource=MEDRT&rela=may_treat`);
  const names = (members.drugMemberGroup?.drugMember ?? []).map((m: Json) => String(m.minConcept?.name ?? "").toLowerCase());
  return [...new Set(names.filter(Boolean))].slice(0, 20) as string[];
}

/** Everything the APIs say, fetched at once; each source that fails is left empty. */
export async function fetchFacts(name: string, umlsKey: string): Promise<Facts> {
  // Drugs come from two places: the labels that name the condition (openFDA's count, the usual
  // choices first) and RxClass. The labels are then read for both, right after, alongside the rest.
  const drugsAndLabels = Promise.all([labelCandidates(name).catch(() => [] as string[]), treatments(name).catch(() => [] as string[])])
    .then(async ([fromLabels, fromRxClass]) => {
      const drugs = ingredients([...fromLabels, ...fromRxClass]);
      return { drugs, labels: labelLines(await labelFacts(drugs, [name]).catch(() => [])) };
    });
  const [summary, umls, { drugs, labels }] = await Promise.all([
    medlinePlusSummary(name).catch(() => ""),
    umlsFacts(name, umlsKey).catch(() => ({ definitions: [], relations: [] })),
    drugsAndLabels,
  ]);
  return { summary, definitions: umls.definitions, relations: umls.relations, treatments: drugs.slice(0, 20), labels };
}

/** The facts as the template's background: sourced, so the model can lean on them. */
export function groundingText(facts: Facts, catalogBackground = ""): string {
  const parts = [
    facts.summary && `MedlinePlus summary: ${facts.summary}`,
    !facts.summary && catalogBackground && `Background: ${catalogBackground}`,
    facts.definitions.length && `Definitions (UMLS): ${facts.definitions.join(" | ")}`,
    facts.relations.length && `SNOMED CT relationships: ${facts.relations.join("; ")}`,
    facts.treatments.length && `Drugs that may treat it (MED-RT): ${facts.treatments.join(", ")}`,
    facts.labels?.length && `FDA drug labels (openFDA):\n- ${facts.labels.join("\n- ")}`,
  ].filter(Boolean);
  return `${parts.join("\n")}\nUse these retrieved facts. Where they're silent, use established clinical knowledge and standard US practice; never contradict them.`;
}

// MARK: - Levels instead of numbers

const SEVERITIES = ["mild", "moderate", "severe", "critical"];
const LEVEL_SCHEMA = {
  type: "object", additionalProperties: false,
  description: "Per severity, how far from normal: a level, never a number. Code turns levels into values from the reference ranges.",
  properties: Object.fromEntries(SEVERITIES.map((s) => [s, { enum: [...LEVELS] }])),
};
const VITALS_LINE = "- vitals: for each vital that changes, per severity (mild, moderate, severe, critical), a level: normal, slightly_high, high, markedly_high, severely_high, slightly_low, low, markedly_low or severely_low. Never numbers: code computes them. Omit a severity or a vital when it stays normal.";
const LABS_LINE = "- labs: only tests that are abnormal or decisive, with test ids from the reference table below. For numeric tests give \"levels\": per severity, one of normal, slightly_high, high, markedly_high, severely_high, slightly_low, low, markedly_low, severely_low (never numbers: code computes them from the reference ranges). Omit severities where the test is normal. Never list derived tests (marked derived); code computes them. For qualitative tests use the \"qualitative\" map with values from that test's abnormal list.";

// deno-lint-ignore no-explicit-any
const toLevels = (ranges: any, normal: [number | null, number | null] | null, kind: "vital" | "lab", id: string) =>
  Object.fromEntries(Object.entries(ranges ?? {}).map(([sev, r]) => [sev, normal ? rangeLevel(r as { min: number; max: number }, normal, kind, id) : "normal"]));

/** The vitals-and-exam and diagnostics sections reworded to ask for levels: their instructions,
 *  schema and example (converted from the template's own ranges, so it shows the same patient). */
function levelStage(stage: number): { instructions: string; schema: string; example: string } | undefined {
  const s = STAGES[stage];
  const schema = JSON.parse(s.schema);
  const example = JSON.parse(s.example);
  if (s.sections.includes("vitals")) {
    schema.properties.vitals.properties = Object.fromEntries(Object.keys(VITAL_NORMALS).map((v) => [v, LEVEL_SCHEMA]));
    schema.properties.vitals.description = "Per vital, per severity: how far from normal, as a level. Code picks the patient's value.";
    example.vitals = Object.fromEntries(Object.entries(example.vitals ?? {}).map(([v, r]) => [v, toLevels(r, VITAL_NORMALS[v] ?? null, "vital", v)]));
    return { instructions: s.instructions.replace(/^- vitals:.*$/m, VITALS_LINE), schema: JSON.stringify(schema), example: JSON.stringify(example) };
  }
  if (s.sections.includes("labs")) {
    const item = schema.properties.labs.items;
    delete item.properties.ranges;
    item.properties.levels = LEVEL_SCHEMA;
    // deno-lint-ignore no-explicit-any
    example.labs = (example.labs ?? []).map(({ ranges, ...lab }: any) => (ranges ? { ...lab, levels: toLevels(ranges, labNormal(lab.test_id), "lab", lab.test_id) } : lab));
    return { instructions: s.instructions.replace(/^- labs:.*$/m, LABS_LINE), schema: JSON.stringify(schema), example: JSON.stringify(example) };
  }
  return undefined;
}

// MARK: - Live stages

/** The template's two largest stages, each about 2,000 tokens and 10–12 s, split into parallel
 *  calls of about half the size. No check ties one half to the other. */
const SPLITS: Record<string, string[][]> = {
  diagnostics: [["labs", "ecg"], ["imaging", "workup"]],
  differential_course: [["differential"], ["course", "cancer"]],
};

/** One call that fills part of the template: the stored stage it comes from, cut to its sections. */
type LiveStage = { base: number; name: string; sections: string[]; instructions: string; schema: string; example: string };

/** A stage's instructions, schema and example cut to some of its sections. */
function cut(stage: { instructions: string; schema: string; example: string }, sections: string[]) {
  const keep = (line: string) => {
    const key = line.match(/^- ([a-z_]+)/)?.[1];
    return !key || sections.includes(key);
  };
  const schema = JSON.parse(stage.schema);
  schema.properties = Object.fromEntries(Object.entries(schema.properties).filter(([k]) => sections.includes(k)));
  if (Array.isArray(schema.required)) schema.required = schema.required.filter((k: string) => sections.includes(k));
  const example = Object.fromEntries(Object.entries(JSON.parse(stage.example)).filter(([k]) => sections.includes(k)));
  return { instructions: stage.instructions.split("\n").filter(keep).join("\n"), schema: JSON.stringify(schema), example: JSON.stringify(example) };
}

/** Every call the live template makes, in parallel: the stored stages, levels instead of numbers,
 *  with the large ones split. */
export const LIVE_STAGES: LiveStage[] = STAGES.flatMap((s, base) => {
  const full = levelStage(base) ?? { instructions: s.instructions, schema: s.schema, example: s.example };
  const groups = SPLITS[s.name] ?? [s.sections];
  return groups.map((sections) => ({ base, name: s.name, sections, ...(groups.length > 1 ? cut(full, sections) : full) }));
});

/** The prompt for one live call, with the condition families' notes. */
function livePrompt(stage: number, triage: Json, grounding: string, base: Json, feedback: string[], families: Family[]): string {
  const s = LIVE_STAGES[stage];
  return stagePrompt(s.base, triage.name, grounding, base, feedback, {
    instructions: withFamilyNotes(s.instructions, s.name, families), schema: s.schema, example: s.example, sections: s.sections,
  });
}

/** Turns the model's levels back into the ranges planCase draws from. A level that can't apply to
 *  a test (no upper limit to be "high" against) is dropped. */
export function expandLevels(profile: Json): void {
  for (const [vital, bySeverity] of Object.entries<Json>(profile.vitals ?? {})) {
    const normal = VITAL_NORMALS[vital];
    for (const [severity, level] of Object.entries<Json>(bySeverity ?? {})) {
      if (typeof level !== "string") continue;
      const range = normal && LEVELS.includes(level as Level) ? levelRange(level as Level, normal, "vital", vital) : null;
      if (range) bySeverity[severity] = range;
      else delete bySeverity[severity];
    }
  }
  for (const lab of profile.labs ?? []) {
    if (!lab?.levels) continue;
    const normal = labNormal(lab.test_id);
    lab.ranges = {};
    for (const [severity, level] of Object.entries<Json>(lab.levels)) {
      const range = normal && LEVELS.includes(level as Level) ? levelRange(level as Level, normal, "lab", lab.test_id) : null;
      if (range) lab.ranges[severity] = range;
    }
    delete lab.levels;
  }
}

/** Which template section an error belongs to, from its prefix ("labs[3] k.severe: …" → labs). */
function stageOf(error: string): number {
  const section = error.match(/^\$?\.?([a-z_]+)/)?.[1] ?? "";
  return LIVE_STAGES.findIndex((s) => s.sections.includes(section));
}

/** Fixes in code that change nothing a check cares about but used to cost a rewrite round (~8 s):
 *  - the template's own example shows a condition without ECG findings as "ecg": {}, which the
 *    schema rejects for missing "findings"; both mean "no ECG findings".
 *  - a name listed twice in accepted_names. */
export function normalize(part: Json): void {
  if (part.ecg && typeof part.ecg === "object" && !Array.isArray(part.ecg) && !("findings" in part.ecg)) part.ecg = { ...part.ecg, findings: [] };
  const names = part.teaching?.accepted_names;
  if (Array.isArray(names)) {
    const seen = new Set<string>();
    part.teaching.accepted_names = names.filter((n) => {
      const key = typeof n === "string" ? n.trim().toLowerCase() : n;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
  }
}

/** One live call's sections, made usable and checked: levels turned into ranges, mechanical
 *  mistakes fixed in code (each touches only its own section), then the section's structure and
 *  terminology checked. Blocking problems are structure; term notes only advise (standard phrases
 *  such as "scrotal erythema" aren't exact SNOMED names, and rejecting on them threw good profiles
 *  away). */
type StageResult = { output: Json; blocking: string[]; terms: string[] };

async function fillStage(
  stage: number, prompt: (feedback: string[]) => string, base: Json,
  deps: { system: string; complete: (system: string, user: string) => Promise<Json>; termErrors: (output: Json) => Promise<string[]> },
): Promise<StageResult> {
  const { sections } = LIVE_STAGES[stage];
  const attempt = async (feedback: string[]): Promise<StageResult> => {
    const reply = await deps.complete(deps.system, prompt(feedback)).catch(() => ({}));
    const { output: raw, missing } = sectionsOutput(sections, reply);
    const part: Json = { ...base, ...raw };
    normalize(part);
    expandLevels(part);
    repair(part);
    autoFix(part);
    const output = Object.fromEntries(sections.filter((k) => k in raw).map((k) => [k, part[k]]));
    const blocking = [...missing, ...sections.filter((k) => k in output).flatMap((k) => sectionErrors(k, output[k]))];
    return { output, blocking, terms: await deps.termErrors(output) };
  };
  const first = await attempt([]);
  // Rewritten straight away, while slower sections are still being written: a separate round
  // after every section returned used to add ~10 s.
  return first.blocking.length ? await attempt([...first.blocking, ...first.terms]) : first;
}

/** A profile for one case, built live: facts from the APIs, then every template section written at
 *  once, each fixed, checked and (once) rewritten with its problems as soon as it arrives. Rules
 *  across sections are checked when all are in, and the sections they flag rewritten once more.
 *  Returns the problems that remain, so the caller can try another condition rather than plan from
 *  a flawed profile. */
export async function buildLiveProfile(
  slug: string, triage: Json, catalogBackground: string,
  deps: { umlsKey: string; system: string; complete: (system: string, user: string) => Promise<Json>; termErrors: (output: Json) => Promise<string[]> },
): Promise<{ profile: Json; problems: string[]; facts: Facts }> {
  const facts = await fetchFacts(triage.name, deps.umlsKey);
  const grounding = groundingText(facts, catalogBackground);
  const base: Json = { schema_version: "0.2", slug, triage };
  const families = familiesOf(triage);
  const prompt = (stage: number) => (feedback: string[]) => livePrompt(stage, triage, grounding, base, feedback, families);
  const results = await Promise.all(LIVE_STAGES.map((_, stage) => fillStage(stage, prompt(stage), base, deps)));

  const profile: Json = { ...base, ...Object.assign({}, ...results.map((r) => r.output)) };
  let blocking = results.flatMap((r) => r.blocking);
  if (blocking.length === 0) {
    const byStage = new Map<number, string[]>();
    for (const e of [...ruleErrors(profile), ...ageUnitErrors(profile)]) byStage.set(stageOf(e), [...(byStage.get(stageOf(e)) ?? []), e]);
    byStage.delete(-1);
    if (byStage.size) {
      await Promise.all([...byStage.entries()].map(async ([stage, errors]) => {
        const reply = await deps.complete(deps.system, prompt(stage)([...errors, ...results[stage].terms])).catch(() => ({}));
        const { output } = sectionsOutput(LIVE_STAGES[stage].sections, reply);
        const part: Json = { ...base, ...output };
        normalize(part);
        expandLevels(part);
        repair(part);
        autoFix(part);
        for (const k of Object.keys(output)) profile[k] = part[k];
      }));
      blocking = LIVE_STAGES.flatMap((s) => {
        const { output, missing } = sectionsOutput(s.sections, profile);
        return [...missing, ...Object.keys(output).flatMap((k) => sectionErrors(k, output[k]))];
      });
      // As before, a rule error no section owns can't be rewritten, so it doesn't block.
      if (blocking.length === 0) blocking = [...ruleErrors(profile), ...ageUnitErrors(profile)].filter((e) => stageOf(e) >= 0);
    }
  }
  const unverified = results.flatMap((r) => r.terms);
  profile.generation = {
    stages: [], live: true, review: { status: "pending" },
    validation: { status: blocking.length ? "failed" : "passed", review_issues: unverified },
  };
  return { profile, problems: blocking, facts };
}
