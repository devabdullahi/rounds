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

// deno-lint-ignore no-explicit-any
type Json = any;
type Check = { ok: boolean; suggestions: string[] };

export function umlsKey(): string {
  const key = Deno.env.get("UMLS_API_KEY");
  if (!key) throw new Error("UMLS_API_KEY is not set (supabase/functions/.env or supabase secrets set)");
  return key;
}

async function getJSON(url: string, params: Record<string, string | number>, missing: Json = null): Promise<Json> {
  const res = await fetch(`${url}?${new URLSearchParams(Object.entries(params).map(([k, v]) => [k, String(v)]))}`);
  if (res.status === 404 && missing !== null) return missing;
  if (!res.ok) throw new Error(`terminology lookup ${res.status} for ${url}`);
  return await res.json();
}

function umls(path: string, params: Record<string, string | number>, missing: Json = null): Promise<Json> {
  return getJSON(`${UMLS}${path}`, { ...params, apiKey: umlsKey() }, missing);
}

async function lookupSnomed(term: string): Promise<boolean> {
  for (const searchType of ["exact", "normalizedString"]) {
    const data = await umls("/search/current", { string: term, sabs: "SNOMEDCT_US", returnIdType: "code", searchType, pageSize: 5 });
    const hits = (data.result?.results ?? []).filter((r: Json) => r.ui && r.ui !== "NONE").slice(0, 3);
    for (const hit of hits) {
      const atoms = await umls(`/content/current/source/SNOMEDCT_US/${hit.ui}/atoms`, { language: "ENG", pageSize: 100 }, { result: [] });
      const fsn: string = (atoms.result ?? []).find((a: Json) => a.termType === "FN")?.name ?? "";
      if (FINDING_TAGS.some((t) => fsn.endsWith(t))) return true;
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

export function rxnormCheck(name: string): Promise<Check> {
  return cached("rxnorm", name, async () => {
    const exact = await getJSON(`${RXNAV}/rxcui.json`, { name, search: 2 });
    if (exact.idGroup?.rxnormId?.length) return { ok: true, suggestions: [] };
    const approx = await getJSON(`${RXNAV}/approximateTerm.json`, { term: name, maxEntries: 1 });
    return { ok: Boolean(approx.approximateGroup?.candidate?.length), suggestions: [] };
  });
}

async function inBatches<T>(items: T[], work: (item: T) => Promise<void>): Promise<void> {
  for (let i = 0; i < items.length; i += PARALLEL) await Promise.all(items.slice(i, i + PARALLEL).map(work));
}

/** Marks verified terms on a stage's output in place; returns errors for missing or unknown ones. */
export async function checkTerms(output: Json): Promise<string[]> {
  const errors: string[] = [];
  for (const section of ["presentation", "exam"] as const) {
    await inBatches(findingItems(section, output), async (item) => {
      const term = String(item.term ?? "").trim();
      const label = item.text ?? item.finding ?? "?";
      if (!term) {
        errors.push(`${section}: '${label}' has no term; add its standard clinical name`);
        return;
      }
      const check = await snomedCheck(term);
      item.snomed_verified = check.ok;
      if (!check.ok) {
        const hint = check.suggestions.length
          ? `; SNOMED names close to it: ${check.suggestions.map((s) => `'${s}'`).join(", ")}`
          : "; use its standard clinical name";
        errors.push(`${section}: term '${term}' isn't a SNOMED CT finding${hint}`);
      }
    });
  }
  await inBatches<string>(output.patient?.risk_medications ?? [], async (drug) => {
    if (!(await rxnormCheck(drug)).ok) errors.push(`patient.risk_medications: '${drug}' isn't an RxNorm drug; use the generic name`);
  });
  return errors;
}
