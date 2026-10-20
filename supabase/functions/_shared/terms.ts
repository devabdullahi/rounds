// Terminology checks for generated profiles (port of tools/kb-generate/terminology.py): symptoms and
// exam findings must be SNOMED CT findings (UMLS API), risk medications RxNorm drugs (RxNav).
// Answers are cached in private.term_checks, so each term costs one lookup across all generations.
// Profiles get only a snomed_verified flag; no SNOMED content is stored in them.

import { sql } from "./db.ts";
import { baseTerm, findingItems } from "./profilegen.ts";

const UMLS = "https://uts-ws.nlm.nih.gov/rest";
const RXNAV = "https://rxnav.nlm.nih.gov/REST";
const FINDING_TAGS = ["(finding)", "(disorder)", "(observable entity)", "(morphologic abnormality)"];
// UMLS allows 20 requests a second per IP; a few terms at a time stays well under it.
const PARALLEL = 4;
/** One lookup may take this long; a hung terminology service must not hold the whole call. */
const LOOKUP_TIMEOUT_MS = 10_000;

/** checkTerms ran out of its time budget; answers so far are cached, so the next call resumes. */
export class TermsOutOfTime extends Error {
  constructor() {
    super("term checks ran out of time");
  }
}

// deno-lint-ignore no-explicit-any
type Json = any;
export type Check = { ok: boolean; suggestions: string[] };

export function umlsKey(): string {
  const key = Deno.env.get("UMLS_API_KEY");
  if (!key) throw new Error("UMLS_API_KEY is not set (supabase/functions/.env or supabase secrets set)");
  return key;
}

async function getJSON(url: string, params: Record<string, string | number>, missing: Json = null): Promise<Json> {
  const res = await fetch(`${url}?${new URLSearchParams(Object.entries(params).map(([k, v]) => [k, String(v)]))}`,
    { signal: AbortSignal.timeout(LOOKUP_TIMEOUT_MS) });
  if (res.status === 404 && missing !== null) return missing;
  if (!res.ok) throw new Error(`terminology lookup ${res.status} for ${url}`);
  return await res.json();
}

/** UMLS requests in flight from this instance. The fact audit used to start 40–80 lookups at once,
 *  and two cases together went past UMLS's 20 requests a second per IP. */
let inFlight = 0;
const waiting: (() => void)[] = [];

/** Runs `work` once fewer than PARALLEL UMLS requests are in flight. */
export async function throttled<T>(work: () => Promise<T>): Promise<T> {
  while (inFlight >= PARALLEL) await new Promise<void>((resolve) => waiting.push(resolve));
  inFlight++;
  try {
    return await work();
  } finally {
    inFlight--;
    waiting.shift()?.();
  }
}

function umls(path: string, params: Record<string, string | number>, missing: Json = null): Promise<Json> {
  return throttled(() => getJSON(`${UMLS}${path}`, { ...params, apiKey: umlsKey() }, missing));
}

/** Concepts already looked up by this instance: the same planned items ("Fever", "Nausea") come up in
 *  case after case. Kept small; a cold instance just asks again. */
const concepts = new Map<string, Promise<string | null>>();
const MAX_CACHED_CONCEPTS = 5000;

/** The UMLS concept (CUI) a term names, exact match first, then normalized; null when none. The
 *  fact audit compares a patient's words with the planned items this way. */
export function conceptOf(term: string): Promise<string | null> {
  const key = term.trim().toLowerCase();
  const known = concepts.get(key);
  if (known) return known;
  if (concepts.size >= MAX_CACHED_CONCEPTS) concepts.clear();
  // A failed lookup isn't kept, so the next case asks again.
  const lookup = lookUpConcept(term).catch((error) => {
    concepts.delete(key);
    throw error;
  });
  concepts.set(key, lookup);
  return lookup;
}

async function lookUpConcept(term: string): Promise<string | null> {
  for (const searchType of ["exact", "normalizedString"]) {
    const data = await umls("/search/current", { string: term, searchType, pageSize: 1 });
    const hit = data.result?.results?.[0];
    if (hit?.ui && hit.ui !== "NONE") return hit.ui;
  }
  return null;
}

/** True when SNOMED CT has the term as a finding or disorder (exact or normalized match). Uncached. */
export async function lookupSnomed(term: string): Promise<boolean> {
  for (const searchType of ["exact", "normalizedString"]) {
    const data = await umls("/search/current", { string: term, sabs: "SNOMEDCT_US", returnIdType: "code", searchType, pageSize: 5 });
    const hits = (data.result?.results ?? []).filter((r: Json) => r.ui && r.ui !== "NONE").slice(0, 3);
    for (const hit of hits) {
      const atoms = await umls(`/content/current/source/SNOMEDCT_US/${hit.ui}/atoms`, { language: "ENG", pageSize: 100 }, { result: [] });
      const fsn: string = (atoms.result ?? []).find((a: Json) => a.termType === "FN")?.name ?? "";
      if (FINDING_TAGS.some((t) => fsn.endsWith(t))) return true;
    }
  }
  return await viaUmls(term);
}

/** The term names a UMLS concept in any vocabulary (MeSH, MedDRA, …) that SNOMED CT also has as a
 *  finding or disorder: "Fecal incontinence" is SNOMED's "Incontinence of feces". Still a whole-name
 *  match on a real concept, so invented terms stay out. (Port of terminology.py's _via_umls.) */
async function viaUmls(term: string): Promise<boolean> {
  for (const searchType of ["exact", "normalizedString"]) {
    const data = await umls("/search/current", { string: term, searchType, pageSize: 3 });
    const hits = (data.result?.results ?? []).filter((r: Json) => r.ui && r.ui !== "NONE").slice(0, 3);
    for (const hit of hits) {
      const codes = await umls(`/content/current/CUI/${hit.ui}/atoms`, { sabs: "SNOMEDCT_US", pageSize: 5 }, { result: [] });
      for (const atom of codes.result ?? []) {
        const code = String(atom.code ?? "").split("/").pop();
        if (!code) continue;
        const atoms = await umls(`/content/current/source/SNOMEDCT_US/${code}/atoms`, { language: "ENG", pageSize: 100 }, { result: [] });
        const fsn: string = (atoms.result ?? []).find((a: Json) => a.termType === "FN")?.name ?? "";
        if (FINDING_TAGS.some((t) => fsn.endsWith(t))) return true;
      }
    }
  }
  return false;
}

/** SNOMED's own names for the concepts UMLS matches to a term, offered to the writer on a retry. */
async function snomedSuggestions(term: string): Promise<string[]> {
  const data = await umls("/search/current", { string: term, searchType: "words", pageSize: 3 });
  const out: string[] = [];
  for (const hit of (data.result?.results ?? []).filter((r: Json) => r.ui && r.ui !== "NONE")) {
    const names = await umls(`/content/current/CUI/${hit.ui}/atoms`, { sabs: "SNOMEDCT_US", ttys: "PT", pageSize: 3 }, { result: [] });
    for (const atom of names.result ?? []) if (!out.includes(atom.name)) out.push(atom.name);
  }
  return out.slice(0, 4);
}

async function cached(kind: "snomed" | "rxnorm", term: string, look: () => Promise<Check>): Promise<Check> {
  const key = term.toLowerCase();
  const rows = await sql<Check[]>`select ok, suggestions from private.term_checks where kind = ${kind} and term = ${key}`;
  if (rows.length) return rows[0];
  const check = await look();
  await sql`insert into private.term_checks (kind, term, ok, suggestions) values (${kind}, ${key}, ${check.ok}, ${check.suggestions})
    on conflict (kind, term) do nothing`;
  return check;
}

export function snomedCheck(term: string): Promise<Check> {
  return cached("snomed", term, async () => {
    const base = baseTerm(term);
    const ok = await lookupSnomed(term) || (base !== term && await lookupSnomed(base));
    return { ok, suggestions: ok ? [] : await snomedSuggestions(base || term) };
  });
}

/** True when RxNorm knows the drug name, exactly or by approximate match. Uncached. */
export async function lookupRxnorm(name: string): Promise<boolean> {
  const exact = await getJSON(`${RXNAV}/rxcui.json`, { name, search: 2 });
  if (exact.idGroup?.rxnormId?.length) return true;
  const approx = await getJSON(`${RXNAV}/approximateTerm.json`, { term: name, maxEntries: 1 });
  return Boolean(approx.approximateGroup?.candidate?.length);
}

export function rxnormCheck(name: string): Promise<Check> {
  return cached("rxnorm", name, async () => ({ ok: await lookupRxnorm(name), suggestions: [] }));
}

/** The cached lookups checkTerms uses; tests pass their own to stay off the database. */
export type TermCheckers = { snomed: (term: string) => Promise<Check>; rxnorm: (name: string) => Promise<Check> };

/** Runs `work` a few items at a time. Past `deadline` (ms since epoch) it starts no new batch and
 *  throws TermsOutOfTime instead. */
async function inBatches<T>(items: T[], work: (item: T) => Promise<void>, deadline?: number): Promise<void> {
  for (let i = 0; i < items.length; i += PARALLEL) {
    if (deadline !== undefined && Date.now() > deadline) throw new TermsOutOfTime();
    await Promise.all(items.slice(i, i + PARALLEL).map(work));
  }
}

/** Marks verified terms on a stage's output in place; returns errors for missing or unknown ones.
 *  With a `deadline`, throws TermsOutOfTime rather than run past it. */
export async function checkTerms(
  output: Json,
  checkers: TermCheckers = { snomed: snomedCheck, rxnorm: rxnormCheck },
  deadline?: number,
): Promise<string[]> {
  const errors: string[] = [];
  for (const section of ["presentation", "exam"] as const) {
    await inBatches(findingItems(section, output), async (item) => {
      const term = String(item.term ?? "").trim();
      const label = item.text ?? item.finding ?? "?";
      if (!term) {
        errors.push(`${section}: '${label}' has no term; add its standard clinical name`);
        return;
      }
      const check = await checkers.snomed(term);
      item.snomed_verified = check.ok;
      if (!check.ok) {
        const hint = check.suggestions.length
          ? `; SNOMED names close to it: ${check.suggestions.map((s) => `'${s}'`).join(", ")}`
          : "; use its standard clinical name";
        errors.push(`${section}: term '${term}' isn't a SNOMED CT finding${hint}`);
      }
    }, deadline);
  }
  await inBatches<string>(output.patient?.risk_medications ?? [], async (drug) => {
    if (!(await checkers.rxnorm(drug)).ok) errors.push(`patient.risk_medications: '${drug}' isn't an RxNorm drug; use the generic name`);
  }, deadline);
  return errors;
}
