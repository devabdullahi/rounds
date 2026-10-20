// MedlinePlus for a condition: the health topic's summary, found by code first. MedlinePlus Connect
// (https://medlineplus.gov/medlineplus-connect/web-service/) takes an ICD-10-CM code and returns the
// topics written for it; the codes come from the NIH Clinical Tables conditions list. When no code
// gives a topic that fits the name, the MedlinePlus search API is tried by name, and a hit counts
// only when its title fits too. Every request names the app (`tool`, `email`), as NLM asks. Pure
// matching and parsing are tested; any failed request just gives an empty summary.

const TIMEOUT_MS = 6_000;
const CONNECT = "https://connect.medlineplus.gov/service";
const SEARCH = "https://wsearch.nlm.nih.gov/ws/query";
const CONDITIONS = "https://clinicaltables.nlm.nih.gov/api/conditions/v3/search";
/** HL7 code system id for ICD-10-CM, which Connect's mainSearchCriteria.v.cs takes. */
const ICD10CM = "2.16.840.1.113883.6.90";
/** Codes tried per condition (in parallel). */
const MAX_CODES = 3;

/** NLM asks callers to identify themselves on every request. */
function identity(): string {
  const email = Deno.env.get("AUTH_SENDER_EMAIL") ?? "";
  return `&tool=rounds${email ? `&email=${encodeURIComponent(email)}` : ""}`;
}

async function get(url: string): Promise<Response | null> {
  try {
    const res = await fetch(url, { signal: AbortSignal.timeout(TIMEOUT_MS) });
    return res.ok ? res : null;
  } catch {
    return null;
  }
}

export type Topic = { title: string; url: string; summary: string; medlineplus: boolean };

/** HTML entities and tags out, whitespace collapsed. */
export function plainText(html: string): string {
  return html.replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&amp;/g, "&")
    .replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim();
}

/** Words that carry meaning in a condition name ("acute", "disease" and the like don't). */
const FILLER = new Set(["acute", "chronic", "disease", "diseases", "disorder", "disorders", "syndrome", "syndromes",
  "infection", "infections", "condition", "conditions", "the", "and", "with", "type"]);
function keywords(text: string): string[] {
  return text.toLowerCase().split(/[^a-z0-9]+/).filter((w) => w.length >= 4 && !FILLER.has(w));
}

/** Whether a topic's title is about the condition: it shares a meaningful word with the name (or
 *  one of its other names), allowing for the word's endings ("kidney" in "kidneys"). */
export function fits(title: string, names: string[]): boolean {
  const titleWords = keywords(title);
  return names.flatMap(keywords).some((w) => titleWords.some((t) => t.startsWith(w.slice(0, 6)) || w.startsWith(t.slice(0, 6))));
}

/** Connect's JSON feed as topics. */
export function connectTopics(feed: { feed?: { entry?: unknown[] } }): Topic[] {
  return (feed.feed?.entry ?? []).map((e) => {
    const entry = e as { title?: { _value?: string }; link?: { href?: string }[]; summary?: { _value?: string } };
    const url = entry.link?.[0]?.href ?? "";
    return { title: entry.title?._value ?? "", url, summary: plainText(entry.summary?._value ?? ""), medlineplus: url.includes("medlineplus.gov") };
  }).filter((t) => t.title && t.summary);
}

/** The condition's ICD-10-CM codes from Clinical Tables: those of its best matching entries. */
export async function icd10Codes(name: string): Promise<string[]> {
  const res = await get(`${CONDITIONS}?terms=${encodeURIComponent(name)}&ef=icd10cm_codes&maxList=${MAX_CODES}`);
  if (!res) return [];
  const body = await res.json() as [number, string[], { icd10cm_codes?: string[] }];
  return [...new Set((body[2]?.icd10cm_codes ?? []).flatMap((c) => c.split(/[,\s]+/)).filter(Boolean))].slice(0, MAX_CODES);
}

/** Topics MedlinePlus Connect lists for the codes, in code order, without repeats. */
async function topicsForCodes(codes: string[]): Promise<Topic[]> {
  const lists = await Promise.all(codes.map(async (code) => {
    const res = await get(`${CONNECT}?mainSearchCriteria.v.cs=${ICD10CM}&mainSearchCriteria.v.c=${encodeURIComponent(code)}` +
      `&knowledgeResponseType=application/json&informationRecipient.languageCode.c=en${identity()}`);
    return res ? connectTopics(await res.json()) : [];
  }));
  const seen = new Set<string>();
  return lists.flat().filter((t) => !seen.has(t.url) && seen.add(t.url));
}

/** The search API by name: the first of a few hits whose title fits. */
async function searchByName(names: string[]): Promise<Topic | null> {
  const res = await get(`${SEARCH}?db=healthTopics&rettype=brief&retmax=3&term=${encodeURIComponent(names[0])}${identity()}`);
  if (!res) return null;
  for (const doc of (await res.text()).split("<document").slice(1)) {
    const title = plainText(doc.match(/<content name="title">([\s\S]*?)<\/content>/)?.[1] ?? "");
    const summary = plainText(doc.match(/<content name="FullSummary">([\s\S]*?)<\/content>/)?.[1] ?? "");
    if (title && summary && fits(title, names)) return { title, url: doc.match(/url="([^"]+)"/)?.[1] ?? "", summary, medlineplus: true };
  }
  return null;
}

/** Of the topics found by code, the one to use: one whose title fits the name, a MedlinePlus page
 *  before a partner's (NIDDK and others write shorter overviews); else none. */
export function pickTopic(topics: Topic[], names: string[]): Topic | null {
  const fitting = topics.filter((t) => fits(t.title, names));
  return fitting.find((t) => t.medlineplus) ?? fitting[0] ?? null;
}

/**
 * The condition's MedlinePlus summary, as plain text. A topic that fits by code wins; partner
 * overviews that also fit are added after it as one line each. Empty when nothing fits.
 */
export async function medlinePlusSummary(name: string, otherNames: string[] = []): Promise<string> {
  const names = [name, ...otherNames];
  const topics = await topicsForCodes(await icd10Codes(name));
  const byCode = pickTopic(topics, names);
  // A partner's short overview is a fallback: MedlinePlus's own page, found by name, says more.
  const main = byCode?.medlineplus ? byCode : (await searchByName(names)) ?? byCode;
  if (!main) return "";
  const extras = topics.filter((t) => t !== main && !t.medlineplus && fits(t.title, names)).map((t) => `${t.title}: ${t.summary}`);
  return [`${main.title}: ${main.summary}`, ...extras].join(" ").slice(0, 4000);
}
