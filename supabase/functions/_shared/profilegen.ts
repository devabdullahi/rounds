// Condition profile generation, the pure parts: prompts, the schema checker, mechanical repairs and
// the rule checks. A port of tools/kb-generate (generate.py, checks.py), which stays the source of
// truth: prompts, schema and example come from profilegen_assets.json, exported by
// tools/kb-generate/load_conditions.py. No I/O here, so it's tested without a database or model.

import assets from "./profilegen_assets.json" with { type: "json" };
import ranges from "./reference_ranges.json" with { type: "json" };
import labDirections from "./lab_directions.json" with { type: "json" };

// deno-lint-ignore no-explicit-any
type Json = any;
type Schema = Record<string, Json>;

export const PROFILE_PROMPT_VERSION: string = assets.prompt_version;
export const SYSTEM_PROMPT: string = assets.system;
export const STAGES: { name: string; sections: string[]; instructions: string; schema: string; example: string }[] = assets.stages;
const SCHEMA: Schema = assets.schema;
const OPTIONAL = new Set<string>(assets.optional_sections);
const REQUIRED: string[] = assets.required_sections;
export const MAX_UNVERIFIED: number = assets.max_unverified;

type Test = { id: string; name: string; derived?: boolean; abnormal?: string[]; low?: number; high?: number;
  female?: number[]; male?: number[]; critical_low?: number; critical_high?: number };
const TESTS: Record<string, Test> = Object.fromEntries(
  (ranges.panels as { tests: Test[] }[]).flatMap((p) => p.tests).map((t) => [t.id, t]),
);
const PANELS = new Set((ranges.panels as { id: string }[]).map((p) => p.id));
/** Hand-written condition slug → {test id: expected direction} for high-yield pairs (see its "about"). */
const DIRECTIONS: Record<string, Record<string, string>> = labDirections.conditions;

// MARK: - Prompt

/** The user message for one stage attempt; a retry appends the previous attempt's errors. */
export function stagePrompt(stage: number, name: string, background: string, profile: Json, feedback: string[]): string {
  const s = STAGES[stage];
  const previous = Object.fromEntries(
    Object.entries(profile).filter(([k]) => !["generation", "schema_version", "slug"].includes(k)),
  );
  const values: Record<string, string> = {
    name,
    instructions: s.instructions,
    keys: s.sections.join(", "),
    schema: s.schema,
    example: s.example,
    background,
    extra: s.name === "diagnostics" ? assets.reference_table : "",
    previous: JSON.stringify(previous),
  };
  // Named slots only: the templates contain JSON braces.
  let text: string = assets.stage_template;
  for (const [key, value] of Object.entries(values)) text = text.replaceAll(`{${key}}`, value);
  if (feedback.length) {
    text += "\n\nYour previous reply had these problems. Fix them and reply with the full JSON again:\n- " +
      feedback.slice(0, 30).join("\n- ");
  }
  return text;
}

/** Keeps only the stage's sections from a reply, and lists sections it left out. */
export function stageOutput(stage: number, reply: Json): { output: Json; missing: string[] } {
  const output: Json = {};
  for (const s of STAGES[stage].sections) if (reply && s in reply) output[s] = reply[s];
  const missing = STAGES[stage].sections.filter((s) => !(s in output) && !OPTIONAL.has(s)).map((s) => `missing section ${s}`);
  return { output, missing };
}

/** Drops optional sections the writer returned empty, as generate.py does before saving. */
export function dropEmptyOptional(profile: Json): void {
  for (const s of OPTIONAL) {
    const v = profile[s];
    if (v && typeof v === "object" && (Object.keys(v).length === 0 || (Array.isArray(v.findings) && v.findings.length === 0 && Object.keys(v).length === 1))) {
      delete profile[s];
    }
  }
}

// MARK: - Schema

/** The JSON Schema subset condition_profile.schema.json uses. */
export function schemaErrors(value: Json, schema: Schema, path = "$"): string[] {
  if (schema.$ref) schema = SCHEMA.$defs[String(schema.$ref).split("/").pop()!];
  const errors: string[] = [];
  const expected = schema.type;
  if (expected && !hasType(value, expected)) return [`${path}: expected ${expected}`];
  if ("const" in schema && JSON.stringify(value) !== JSON.stringify(schema.const)) errors.push(`${path}: must be ${JSON.stringify(schema.const)}`);
  if (schema.enum && !schema.enum.some((e: Json) => JSON.stringify(e) === JSON.stringify(value))) {
    errors.push(`${path}: ${JSON.stringify(value)} not in ${JSON.stringify(schema.enum)}`);
  }
  if (typeof value === "string") {
    if (schema.pattern && !new RegExp(schema.pattern).test(value)) errors.push(`${path}: ${JSON.stringify(value)} doesn't match ${schema.pattern}`);
    if (schema.maxLength !== undefined && value.length > schema.maxLength) errors.push(`${path}: longer than ${schema.maxLength}`);
  }
  if (typeof value === "number") {
    if (schema.minimum !== undefined && value < schema.minimum) errors.push(`${path}: below ${schema.minimum}`);
    if (schema.maximum !== undefined && value > schema.maximum) errors.push(`${path}: above ${schema.maximum}`);
  }
  if (isObject(value)) {
    const props = schema.properties ?? {};
    for (const key of schema.required ?? []) if (!(key in value)) errors.push(`${path}: missing ${key}`);
    for (const [key, item] of Object.entries(value)) {
      if (key in props) errors.push(...schemaErrors(item, props[key], `${path}.${key}`));
      else if (schema.additionalProperties === false) errors.push(`${path}: unexpected key ${key}`);
      else if (isObject(schema.additionalProperties)) errors.push(...schemaErrors(item, schema.additionalProperties, `${path}.${key}`));
    }
  }
  if (Array.isArray(value)) {
    if (value.length < (schema.minItems ?? 0)) errors.push(`${path}: needs at least ${schema.minItems} items`);
    if (schema.items) value.forEach((item, i) => errors.push(...schemaErrors(item, schema.items, `${path}[${i}]`)));
  }
  return errors;
}

export function sectionErrors(section: string, value: Json): string[] {
  return schemaErrors(value, SCHEMA.properties[section], `$.${section}`);
}

function isObject(v: Json): v is Record<string, Json> {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

function hasType(v: Json, type: string): boolean {
  switch (type) {
    case "object": return isObject(v);
    case "array": return Array.isArray(v);
    case "string": return typeof v === "string";
    case "boolean": return typeof v === "boolean";
    case "integer": return Number.isInteger(v);
    case "number": return typeof v === "number";
    default: return true;
  }
}

// MARK: - Repair

const WORKUP_GROUPS = ["initial", "confirmatory", "supporting", "not_indicated"] as const;
const LOOKS_LIKE_ID = /^[a-z0-9_]+$/;

/** Our test id for a model-made id like "troponin", when exactly one test name contains its words. */
function matchTest(token: string): string | null {
  const words = token.replaceAll("_", " ").replaceAll("-", " ").split(/\s+/).filter(Boolean);
  const hits = Object.values(TESTS).filter((t) => !t.derived && words.every((w) => t.name.toLowerCase().includes(w)));
  return hits.length === 1 ? hits[0].id : null;
}

/** "fungal_culture" → "Fungal culture"; short tokens read as abbreviations ("ecg" → "ECG"). */
function plainName(token: string): string {
  const text = token.replaceAll("_", " ");
  return text.length <= 4 ? text.toUpperCase() : text[0].toUpperCase() + text.slice(1);
}

/**
 * Fixes mechanical slips in place and returns notes for the reviewer: model-made test ids become
 * our id or a plain name, labs with unknown ids are dropped, and a test listed in several workup
 * groups is kept once (see keepOne). Never invents content. Notes come back without repeats.
 */
export function repair(profile: Json): string[] {
  const notes: string[] = [];
  const workup = profile.workup ?? {};
  for (const group of WORKUP_GROUPS) {
    for (const ref of workup[group] ?? []) {
      const name = ref.test;
      if (LOOKS_LIKE_ID.test(name) && !(name in TESTS) && !PANELS.has(name)) {
        ref.test = matchTest(name) ?? plainName(name);
        notes.push(`workup: renamed '${name}' to '${ref.test}'`);
      }
    }
  }

  if (Array.isArray(profile.labs)) {
    const kept = [];
    for (const lab of profile.labs) {
      const id = lab?.test_id;
      if (!(id in TESTS)) {
        const match = matchTest(id ?? "");
        if (!match) {
          notes.push(`labs: dropped '${id}' (not in the reference table)`);
          continue;
        }
        notes.push(`labs: mapped '${id}' to '${match}'`);
        lab.test_id = match;
      }
      if (TESTS[lab.test_id].derived) {
        notes.push(`labs: dropped derived '${lab.test_id}'`);
        continue;
      }
      kept.push(lab);
    }
    profile.labs = kept;
  }

  const ecg = profile.ecg;
  if (isObject(ecg) && Array.isArray(ecg.findings)) {
    const extra = Object.keys(ecg).filter((k) => k !== "findings");
    for (const k of extra) delete ecg[k];
    if (extra.length) notes.push(`ecg: dropped extra keys ${extra.join(", ")} (findings carry their own leads)`);
  }

  const seen = new Map<string, [string, Json][]>();
  for (const group of WORKUP_GROUPS) {
    for (const ref of workup[group] ?? []) {
      const key = workupKey(String(ref.test));
      seen.set(key, [...(seen.get(key) ?? []), [group, ref]]);
    }
  }
  for (const entries of seen.values()) if (entries.length > 1) notes.push(keepOne(workup, entries));
  return [...new Set(notes)];
}

/** "Chest X-ray", "chest x ray" and "CHEST X-RAY" are one test: lowercase, punctuation as spaces. */
export function workupKey(name: string): string {
  return name.toLowerCase().replace(/[^a-z0-9]+/g, " ").trim().split(/\s+/).filter(Boolean).join(" ");
}

/**
 * Keeps a test listed in several workup groups once and says what happened. An order beats
 * not_indicated: "not indicated" plus an order is either a conditional order (one of them has
 * only_if, which the kept entry carries) or the model contradicting itself, which a reviewer
 * should look at. Among orders the earliest group wins (initial, confirmatory, supporting).
 */
function keepOne(workup: Json, entries: [string, Json][]): string {
  const ordered = entries.filter(([g]) => g !== "not_indicated");
  const skipped = entries.filter(([g]) => g === "not_indicated").map(([, r]) => r);
  const [group, kept] = (ordered.length ? ordered : entries)[0];
  // Identity: duplicates are often equal objects.
  for (const [g, r] of entries) if (r !== kept) workup[g] = workup[g].filter((x: Json) => x !== r);
  const note = `workup: '${kept.test}' was in ${entries.map(([g]) => g).join(", ")}; kept ${group}`;
  if (!ordered.length || !skipped.length) return note;
  const condition = skipped.find((r) => r.only_if)?.only_if;
  if (condition && !kept.only_if) kept.only_if = condition;
  if (kept.only_if) return `${note} as a conditional order (only if ${kept.only_if})`;
  return `${note}; also listed as not indicated, so the model contradicted itself: check whether to order it`;
}

// MARK: - Rules

/** Checks that need reference data. Every error here blocks the profile. */
export function ruleErrors(profile: Json): string[] {
  const errors: string[] = [];
  (profile.labs ?? []).forEach((lab: Json, i: number) => {
    const where = `labs[${i}] ${lab?.test_id}`;
    const test = TESTS[lab?.test_id];
    if (!test) {
      errors.push(`${where}: unknown test id`);
      return;
    }
    if (test.derived) errors.push(`${where}: derived test; code computes it, don't list it`);
    for (const [severity, result] of Object.entries(lab.qualitative ?? {})) {
      const allowed = test.abnormal ?? [];
      if (!allowed.includes(result as string)) errors.push(`${where}.${severity}: '${result}' not in ${allowed.join(", ")}`);
    }
    for (const [severity, r] of Object.entries<Json>(lab.ranges ?? {})) {
      if (r.min > r.max) errors.push(`${where}.${severity}: min above max`);
      if (test.critical_low != null && r.max < test.critical_low * 0.5) errors.push(`${where}.${severity}: implausibly low`);
      if (test.critical_high != null && r.min > test.critical_high * 3) errors.push(`${where}.${severity}: implausibly high`);
    }
  });

  for (const [severity, r] of Object.entries<Json>(profile.vitals?.temp ?? {})) {
    if (!(r.min >= 90 && r.min <= 110 && r.max >= 90 && r.max <= 110)) errors.push(`vitals.temp.${severity}: must be °F`);
  }
  for (const [vital, byseverity] of Object.entries<Json>(profile.vitals ?? {})) {
    for (const [severity, r] of Object.entries<Json>(byseverity ?? {})) {
      if (r.min > r.max) errors.push(`vitals.${vital}.${severity}: min above max`);
    }
  }

  for (const group of WORKUP_GROUPS) {
    for (const ref of profile.workup?.[group] ?? []) {
      const name = ref.test;
      if (LOOKS_LIKE_ID.test(name) && !(name in TESTS) && !PANELS.has(name)) {
        errors.push(`workup.${group}: unknown test id '${name}'; use a listed id or the test's plain name`);
      }
      if (name === "vitals") errors.push(`workup.${group}: vital signs aren't an orderable test`);
    }
  }

  // A test sits in one group; a conditional order is one entry with only_if, never also not_indicated.
  const groups = new Map<string, string[]>();
  for (const group of WORKUP_GROUPS) {
    for (const ref of profile.workup?.[group] ?? []) {
      const key = workupKey(String(ref.test));
      groups.set(key, [...(groups.get(key) ?? []), group]);
    }
  }
  for (const [name, found] of groups) {
    if (found.length > 1) errors.push(`workup: '${name}' appears in ${found.join(", ")}; list it once (use only_if for a conditional order)`);
  }

  if (profile.labs?.length && profile.teaching && !(profile.differential ?? []).some((d: Json) => d.must_not_miss)) {
    errors.push("differential: no must-not-miss alternative; every case should have one to rule out");
  }
  errors.push(...ageErrors(profile), ...duplicateErrors(profile), ...emptyStringErrors(profile), ...snomedIdErrors(profile));
  errors.push(...directionErrors(profile));
  return errors;
}

const MAX_AGE = 120;
/** Newborn and infant conditions: an age over 2 means the model wrote days, weeks or months. */
const INFANT = /neonat|newborn|infant/;
const MAX_INFANT_AGE = 2;

/** Ages are whole years; days or months written as years show up as impossible numbers. */
export function ageErrors(profile: Json): string[] {
  const age = profile.patient?.age ?? {};
  const errors = Object.entries<Json>(age)
    .filter(([, v]) => typeof v === "number" && v > MAX_AGE)
    .map(([k]) => `patient.age.${k}: over ${MAX_AGE}; ages are in years`);
  const name = `${profile.slug ?? ""} ${profile.triage?.name ?? ""}`.toLowerCase();
  const key = "possible_max" in age ? "possible_max" : "typical_max";
  const oldest = age[key];
  if (INFANT.test(name) && typeof oldest === "number" && oldest > MAX_INFANT_AGE && oldest <= MAX_AGE) {
    errors.push(`patient.age.${key}: over ${MAX_INFANT_AGE} for a newborn or infant condition; ages are in years`);
  }
  return errors;
}

/** A list item's identity: two labs with one test_id, or two findings with one id, are the same item. */
const ITEM_KEYS = ["test_id", "id", "slug", "text"];

/** [path, value] for the generated content: everything but the pipeline's own bookkeeping. */
function content(profile: Json): [string, Json][] {
  return Object.entries<Json>(profile ?? {}).filter(([k]) => k !== "generation").map(([k, v]) => [`$.${k}`, v]);
}

/** Every [path, value] inside value, depth first, in document order. */
function* walk(path: string, value: Json): Generator<[string, Json]> {
  yield [path, value];
  if (Array.isArray(value)) for (let i = 0; i < value.length; i++) yield* walk(`${path}[${i}]`, value[i]);
  else if (isObject(value)) for (const [k, v] of Object.entries(value)) yield* walk(`${path}.${k}`, v);
}

/** The same string twice in a list, or two list items with the same id, test_id, slug or text. */
export function duplicateErrors(profile: Json): string[] {
  const errors: string[] = [];
  for (const [top, section] of content(profile)) {
    for (const [path, value] of walk(top, section)) {
      if (!Array.isArray(value)) continue;
      const seen = new Set<string>();
      for (const item of value) {
        let field: string | undefined;
        let text: string;
        if (typeof item === "string") {
          field = "";
          text = item;
        } else if (isObject(item)) {
          field = ITEM_KEYS.find((k) => typeof item[k] === "string");
          if (field === undefined) continue;
          text = item[field];
        } else continue;
        const marker = `${field}\u0000${text.trim().toLowerCase()}`;
        if (seen.has(marker)) errors.push(`${path}: duplicate ${field ? field + " " : ""}'${text}'`);
        seen.add(marker);
      }
    }
  }
  return errors;
}

export function emptyStringErrors(profile: Json): string[] {
  const errors: string[] = [];
  for (const [top, section] of content(profile)) {
    for (const [path, value] of walk(top, section)) if (typeof value === "string" && !value.trim()) errors.push(`${path}: empty string`);
  }
  return errors;
}

/** SNOMED CT content is licensed: profiles carry snomed_verified flags, never concept ids. */
export function snomedIdErrors(profile: Json): string[] {
  const errors: string[] = [];
  for (const [path, value] of walk("$", profile)) {
    if (isObject(value) && "snomed_id" in value) errors.push(`${path}.snomed_id: SNOMED CT ids are licensed content; keep only snomed_verified`);
  }
  return errors;
}

const SEVERITIES = ["mild", "moderate", "severe", "critical"];

/** Labs that move the wrong way with severity, for the hand-written pairs in lab_directions.json. */
export function directionErrors(profile: Json): string[] {
  const errors: string[] = [];
  const expected = DIRECTIONS[profile.slug] ?? {};
  for (const lab of profile.labs ?? []) {
    const direction = expected[lab?.test_id];
    const test = TESTS[lab?.test_id];
    if (!direction || !test || !lab.ranges || !Object.keys(lab.ranges).length) continue;
    const [low, high] = normalInterval(test);
    const where = `labs ${lab.test_id}`;
    const present: [string, Json][] = SEVERITIES.filter((s) => s in lab.ranges).map((s) => [s, lab.ranges[s]]);
    if (direction === "up" || direction === "down") {
      const rising = direction === "up";
      const mids = present.map(([s, r]): [string, number] => [s, (r.min + r.max) / 2]);
      for (let i = 1; i < mids.length; i++) {
        const [before, a] = mids[i - 1];
        const [after, b] = mids[i];
        if (rising ? b < a : b > a) {
          errors.push(`${where}: should ${rising ? "rise" : "fall"} with severity, but ${after} is ${rising ? "lower" : "higher"} than ${before}`);
        }
      }
      const [top, mid] = mids[mids.length - 1];
      const bound = rising ? high : low;
      if (bound != null && (rising ? mid <= bound : mid >= bound)) {
        errors.push(`${where}.${top}: should be ${rising ? "above" : "below"} normal at the worst listed severity`);
      }
    }
    for (const [s, r] of present) {
      if (direction === "normal_or_up" && low != null && r.max < low) errors.push(`${where}.${s}: should be normal or high, not low`);
      if (direction === "normal_or_down" && high != null && r.min > high) errors.push(`${where}.${s}: should be normal or low, not high`);
    }
  }
  return errors;
}

/** Widest normal interval across sexes, so direction checks don't depend on the patient. */
function normalInterval(t: Test): [number | null, number | null] {
  const lows = [t.low, t.female?.[0], t.male?.[0]].filter((v): v is number => v != null);
  const highs = [t.high, t.female?.[1], t.male?.[1]].filter((v): v is number => v != null);
  return [lows.length ? Math.min(...lows) : null, highs.length ? Math.max(...highs) : null];
}

/** Worth a reviewer's look but don't block. */
export function ruleWarnings(profile: Json, knownSlugs: Set<string>): string[] {
  const warnings: string[] = [];
  for (const lab of profile.labs ?? []) {
    const test = TESTS[lab.test_id];
    if (!test || !lab.ranges) continue;
    const [low, high] = normalInterval(test);
    const directions = new Set<string>();
    for (const r of Object.values<Json>(lab.ranges)) {
      if (high != null && r.min > high) directions.add("high");
      if (low != null && r.max < low) directions.add("low");
    }
    if (directions.size > 1) warnings.push(`labs ${lab.test_id}: both high and low across severities`);
  }
  for (const d of profile.differential ?? []) {
    if (d.slug && !knownSlugs.has(d.slug)) warnings.push(`differential ${d.slug}: no profile yet`);
  }
  return warnings;
}

/** Whole-profile validation, judged on the saved content. */
export function validate(profile: Json): string[] {
  const missing = REQUIRED.filter((s) => !(s in profile)).map((s) => `missing section ${s}`);
  return [...missing, ...schemaErrors(profile, SCHEMA), ...ruleErrors(profile)];
}

// MARK: - Terminology items

/** The items that carry a SNOMED term, by section. */
export function findingItems(section: "presentation" | "exam", output: Json): Json[] {
  if (section === "presentation") {
    const p = output.presentation ?? {};
    return [...(p.chief_complaints ?? []), ...(p.hpi?.associated_symptoms ?? []), ...(p.ros ?? []).flatMap((r: Json) => r.positives ?? [])];
  }
  return [...(output.exam?.findings ?? [])];
}

/** "Crackles absent", "No rebound tenderness": the finding inside is the part to look up. */
export function baseTerm(term: string): string {
  return term.replace(/^(?:no|absent|absence of|without)\s+|\s+(?:absent|normal|not present)$/i, "").trim();
}

/** Errors and review notes from the verified flags on a finished profile (terminology.term_summary). */
export function termSummary(profile: Json): { errors: string[]; notes: string[] } {
  const errors: string[] = [];
  const notes: string[] = [];
  for (const section of ["presentation", "exam"] as const) {
    const items = findingItems(section, profile);
    if (!items.length) continue;
    if (!items.some((i) => "term" in i)) {
      notes.push(`${section}: older format without SNOMED terms`);
      continue;
    }
    const unverified = items.filter((i) => !i.snomed_verified).map((i) => i.term || "(none)");
    if (unverified.length / items.length > MAX_UNVERIFIED) errors.push(`${section}: ${unverified.length} of ${items.length} terms aren't SNOMED CT findings`);
    notes.push(...unverified.map((t) => `${section}: term '${t}' not found in SNOMED CT`));
  }
  return { errors, notes };
}
