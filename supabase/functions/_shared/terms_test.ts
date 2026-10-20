// Terminology lookups against a fake fetch: no network, no database (checkTerms gets its checkers).
import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
import { type Check, checkTerms, lookupRxnorm, lookupSnomed, TermsOutOfTime } from "./terms.ts";

type Route = (url: URL) => Response | undefined;

/** Replaces fetch for one test; unmatched URLs fail loudly so a test never reaches the network. */
async function withFetch(route: Route, work: (calls: URL[]) => Promise<void>): Promise<void> {
  const real = globalThis.fetch;
  const calls: URL[] = [];
  globalThis.fetch = ((input: string | URL | Request) => {
    const url = new URL(input instanceof Request ? input.url : String(input));
    calls.push(url);
    const res = route(url);
    return Promise.resolve(res ?? new Response(`unexpected ${url}`, { status: 599 }));
  }) as typeof fetch;
  Deno.env.set("UMLS_API_KEY", "test-key");
  try {
    await work(calls);
  } finally {
    globalThis.fetch = real;
  }
}

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status });
const search = (...uis: string[]) => json({ result: { results: uis.map((ui) => ({ ui })) } });
const atoms = (...names: string[]) => json({ result: names.map((name) => ({ termType: "FN", name })) });

Deno.test("a SNOMED finding is found by exact search", async () => {
  await withFetch((url) => {
    if (url.pathname.endsWith("/search/current")) return search("25064002");
    if (url.pathname.endsWith("/SNOMEDCT_US/25064002/atoms")) return atoms("Headache (finding)");
  }, async (calls) => {
    assertEquals(await lookupSnomed("Headache"), true);
    assertEquals(calls[0].searchParams.get("apiKey"), "test-key");
    assertEquals(calls[0].searchParams.get("searchType"), "exact");
  });
});

Deno.test("a SNOMED concept that isn't a finding doesn't count", async () => {
  await withFetch((url) => {
    if (url.pathname.endsWith("/search/current")) return url.searchParams.get("sabs") ? search("1") : search();
    if (url.pathname.endsWith("/SNOMEDCT_US/1/atoms")) return atoms("Stethoscope (physical object)");
  }, async () => {
    assertEquals(await lookupSnomed("Stethoscope"), false);
  });
});

Deno.test("a term known under another vocabulary is found through UMLS", async () => {
  await withFetch((url) => {
    if (url.pathname.endsWith("/search/current")) return url.searchParams.get("sabs") ? search() : search("C0015732");
    if (url.pathname.endsWith("/CUI/C0015732/atoms")) return json({ result: [{ code: "https://x/SNOMEDCT_US/72042002" }] });
    if (url.pathname.endsWith("/SNOMEDCT_US/72042002/atoms")) return atoms("Incontinence of feces (finding)");
  }, async () => {
    assertEquals(await lookupSnomed("Fecal incontinence"), true);
  });
});

Deno.test("missing atoms read as no match, other errors throw as outages", async () => {
  await withFetch((url) => {
    if (url.pathname.endsWith("/search/current")) return url.searchParams.get("sabs") ? search("9") : search();
    if (url.pathname.endsWith("/atoms")) return new Response("", { status: 404 });
  }, async () => {
    assertEquals(await lookupSnomed("Whatever"), false);
  });
  await withFetch(() => new Response("down", { status: 503 }), async () => {
    await assertRejects(() => lookupSnomed("Headache"), Error, "terminology lookup 503");
  });
});

Deno.test("RxNorm accepts exact names, then approximate ones", async () => {
  await withFetch((url) => {
    if (url.pathname.endsWith("/rxcui.json")) return json({ idGroup: url.searchParams.get("name") === "lisinopril" ? { rxnormId: ["29046"] } : {} });
    if (url.pathname.endsWith("/approximateTerm.json")) {
      return json({ approximateGroup: url.searchParams.get("term") === "lisinoprill" ? { candidate: [{ rxcui: "29046" }] } : {} });
    }
  }, async (calls) => {
    assertEquals(await lookupRxnorm("lisinopril"), true);
    assertEquals(calls.length, 1);
    assertEquals(await lookupRxnorm("lisinoprill"), true);
    assertEquals(await lookupRxnorm("notadrug"), false);
  });
});

Deno.test("checkTerms marks verified terms and explains the rest", async () => {
  const snomed = (term: string): Promise<Check> =>
    Promise.resolve(term === "Headache" ? { ok: true, suggestions: [] } : { ok: false, suggestions: term === "Head pain thing" ? ["Headache"] : [] });
  const rxnorm = (name: string): Promise<Check> => Promise.resolve({ ok: name === "ibuprofen", suggestions: [] });
  const output = {
    presentation: { chief_complaints: [{ text: "my head hurts", term: "Headache" }, { text: "pressure", term: "Head pain thing" }] },
    exam: { findings: [{ finding: "looks unwell" }] },
    patient: { risk_medications: ["ibuprofen", "made-up-ol"] },
  };
  const errors = await checkTerms(output, { snomed, rxnorm });
  assertEquals((output.presentation.chief_complaints[0] as Record<string, unknown>).snomed_verified, true);
  assert(errors.includes("presentation: term 'Head pain thing' isn't a SNOMED CT finding; SNOMED names close to it: 'Headache'"));
  assert(errors.includes("exam: 'looks unwell' has no term; add its standard clinical name"));
  assert(errors.includes("patient.risk_medications: 'made-up-ol' isn't an RxNorm drug; use the generic name"));
  assertEquals(errors.length, 3);
});

Deno.test("checkTerms stops at its deadline instead of running past it", async () => {
  const output = { presentation: { chief_complaints: [{ text: "my belly hurts", term: "Abdominal pain" }] }, exam: {}, patient: {} };
  const ok = () => Promise.resolve({ ok: true, suggestions: [] });
  await assertRejects(() => checkTerms(output, { snomed: ok, rxnorm: ok }, Date.now() - 1), TermsOutOfTime);
});
