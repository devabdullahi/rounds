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

import { autoFix, labNormal, repair, ruleErrors, sectionErrors, STAGES, stageOutput, stagePrompt } from "./profilegen.ts";
import { type Level, levelRange, LEVELS, rangeLevel, VITAL_NORMALS } from "./levels.ts";

// deno-lint-ignore no-explicit-any
type Json = any;

export type Facts = { summary: string; definitions: string[]; relations: string[]; treatments: string[] };

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
  const [summary, umls, drugs] = await Promise.all([
    medlinePlusSummary(name).catch(() => ""),
    umlsFacts(name, umlsKey).catch(() => ({ definitions: [], relations: [] })),
    treatments(name).catch(() => [] as string[]),
  ]);
  return { summary, definitions: umls.definitions, relations: umls.relations, treatments: drugs };
}

/** The facts as the template's background: sourced, so the model can lean on them. */
export function groundingText(facts: Facts, catalogBackground = ""): string {
  const parts = [
    facts.summary && `MedlinePlus summary: ${facts.summary}`,
    !facts.summary && catalogBackground && `Background: ${catalogBackground}`,
    facts.definitions.length && `Definitions (UMLS): ${facts.definitions.join(" | ")}`,
    facts.relations.length && `SNOMED CT relationships: ${facts.relations.join("; ")}`,
    facts.treatments.length && `Drugs that may treat it (MED-RT): ${facts.treatments.join(", ")}`,
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

/** Fills every template section at once, each grounded in the same facts and the condition's
 *  triage. Returns the profile and which sections came back incomplete. */
export async function fillTemplate(
  slug: string, triage: Json, grounding: string,
  complete: (system: string, user: string) => Promise<Json>, system: string,
): Promise<{ profile: Json; missing: string[] }> {
  const base: Json = { schema_version: "0.2", slug, triage };
  const replies = await Promise.all(STAGES.map((_, stage) =>
    complete(system, stagePrompt(stage, triage.name, grounding, base, [], levelStage(stage))).catch(() => ({}))
  ));
  const profile: Json = { ...base };
  const missing: string[] = [];
  replies.forEach((reply, stage) => {
    const { output, missing: m } = stageOutput(stage, reply);
    Object.assign(profile, output);
    missing.push(...m);
  });
  return { profile, missing };
}

/** Which template section an error belongs to, from its prefix ("labs[3] k.severe: …" → labs). */
function stageOf(error: string): number {
  const section = error.match(/^([a-z_]+)/)?.[1] ?? "";
  return STAGES.findIndex((s) => s.sections.includes(section));
}

/** The profile's problems by template section: blocking ones (structure, medical rules) and
 *  terminology ones (a term that isn't an exact SNOMED CT or RxNorm name). Terms only advise, like
 *  stored profiles' allowance for unverified terms: standard phrases such as "scrotal erythema"
 *  aren't exact SNOMED names, and rejecting on them threw good profiles away. */
async function problemsByStage(profile: Json, missing: string[], termErrors: (output: Json) => Promise<string[]>) {
  const blocking = new Map<number, string[]>();
  const terms = new Map<number, string[]>();
  const add = (map: Map<number, string[]>, stage: number, error: string) => { if (stage >= 0) map.set(stage, [...(map.get(stage) ?? []), error]); };
  for (const m of missing) add(blocking, stageOf(m.replace(/^missing section /, "")), m);
  for (const [stage, s] of STAGES.entries()) {
    for (const section of s.sections) if (section in profile) for (const e of sectionErrors(section, profile[section])) add(blocking, stage, e);
  }
  if (blocking.size === 0) for (const e of ruleErrors(profile)) add(blocking, stageOf(e), e);
  const found = await Promise.all(STAGES.map((s) => termErrors(Object.fromEntries(s.sections.filter((k) => k in profile).map((k) => [k, profile[k]])))));
  found.forEach((errors, stage) => errors.forEach((e) => add(terms, stage, e)));
  return { blocking, terms };
}

/** A profile for one case, built live: facts from the APIs, the template filled at once, then
 *  checked; sections with problems are rewritten once with them listed. Returns the problems that
 *  remain, so the caller can try another condition rather than plan from a flawed profile. */
export async function buildLiveProfile(
  slug: string, triage: Json, catalogBackground: string,
  deps: { umlsKey: string; system: string; complete: (system: string, user: string) => Promise<Json>; termErrors: (output: Json) => Promise<string[]> },
): Promise<{ profile: Json; problems: string[]; facts: Facts }> {
  const facts = await fetchFacts(triage.name, deps.umlsKey);
  const grounding = groundingText(facts, catalogBackground);
  const { profile, missing } = await fillTemplate(slug, triage, grounding, deps.complete, deps.system);
  expandLevels(profile);
  repair(profile);
  // Mechanical rule errors are fixed in code, so most profiles skip the rewrite round (~10 s).
  autoFix(profile);
  let { blocking, terms } = await problemsByStage(profile, missing, deps.termErrors);
  // Only sections with blocking problems are rewritten; their term notes ride along as feedback.
  if (blocking.size) {
    const base: Json = { schema_version: "0.2", slug, triage };
    await Promise.all([...blocking.entries()].map(async ([stage, errors]) => {
      const reply = await deps.complete(deps.system, stagePrompt(stage, triage.name, grounding, base, [...errors, ...(terms.get(stage) ?? [])], levelStage(stage)))
        .catch(() => ({}));
      Object.assign(profile, stageOutput(stage, reply).output);
    }));
    expandLevels(profile);
    repair(profile);
    autoFix(profile);
    ({ blocking, terms } = await problemsByStage(profile, [], deps.termErrors));
  }
  const unverified = [...terms.values()].flat();
  profile.generation = {
    stages: [], live: true, review: { status: "pending" },
    validation: { status: blocking.size ? "failed" : "passed", review_issues: unverified },
  };
  return { profile, problems: [...blocking.values()].flat(), facts };
}
