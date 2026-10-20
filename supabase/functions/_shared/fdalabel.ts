// openFDA drug labels (https://open.fda.gov/apis/drug/label/): for the drugs RxClass says may treat a
// condition, what the FDA label says about this condition. Whether it's an approved use, the dose
// line the label gives for it, the route, and the boxed warning's headline, so a profile's treatment
// and medicine details are grounded in the label instead of recall. The parsing is pure and tested;
// the fetch is one request per drug, in parallel, and any failure just leaves that drug out.
//
// Env: OPENFDA_API_KEY is optional. Without it openFDA allows 1,000 requests a day per IP address;
// with it, 120,000.

// deno-lint-ignore no-explicit-any
type Json = Record<string, any>;

const API = "https://api.fda.gov/drug/label.json";
const TIMEOUT_MS = 6_000;
/** Drugs looked up per condition (in parallel), and labels kept after ranking: RxClass lists
 *  hospital-only drugs first as often as not, so it takes a wider net to find the usual oral ones. */
export const MAX_LOOKUPS = 15;
export const MAX_LABELS = 6;
/** Characters of label text kept around the condition's mention in the dosing section. */
const DOSE_WINDOW = 180;

/** Salt, hydrate and form words RxClass keeps on separate entries ("moxifloxacin hydrochloride
 *  monohydrate"); the ingredient is what a label is filed under. */
const SALT = /\b(hydrochloride|hydrobromide|monohydrate|hemihydrate|dihydrate|trihydrate|anhydrous|sulfate|sodium|potassium|calcium|lactate|tosylate|mesylate|maleate|acetate|citrate|phosphate|succinate|tartrate|fumarate|besylate|disodium|magnesium|medoxomil|kamedoxomil|axetil|cilexetil|mofetil|pivoxil)\b/gi;

/** Form words that labels add to the generic name ("ciprofloxacin tablets", "ciprofloxacin hcl"). */
const FORM = /\b(tablets?|capsules?|hcl|oral|solution|suspension|extended-release|delayed-release|er|xr|sr|usp)\b/gi;

/** Edits between two short names, to catch typos in label names ("ciprofolxacin"). */
function distance(a: string, b: string): number {
  const row = Array.from({ length: b.length + 1 }, (_, j) => j);
  for (let i = 1; i <= a.length; i++) {
    let prev = row[0]++;
    for (let j = 1; j <= b.length; j++) {
      const here = row[j];
      row[j] = Math.min(row[j] + 1, row[j - 1] + 1, prev + (a[i - 1] === b[j - 1] ? 0 : 1));
      prev = here;
    }
  }
  return row[b.length];
}

/** Drug names as unique ingredients, first-seen order kept: salts, forms and typos of a name seen
 *  earlier collapse into it. */
export function ingredients(names: string[]): string[] {
  const out: string[] = [];
  for (const raw of names) {
    const name = raw.toLowerCase().replace(SALT, " ").replace(FORM, " ").replace(/[^a-z0-9 ,-]+/g, " ")
      .replace(/\s+/g, " ").replace(/^[\s,]+|[\s,]+$/g, "").trim();
    if (!name || out.some((seen) => seen === name || (name.length >= 8 && distance(seen, name) <= 2))) continue;
    out.push(name);
  }
  return out;
}

export type LabelFact = {
  drug: string;
  routes: string[];
  /** The label's indications mention the condition (or one of its names). */
  indicated: boolean;
  /** The dosing text around the condition's mention, when the label has one. */
  dose: string | null;
  /** The boxed warning's headline, when there is one. */
  boxed: string | null;
};

const clean = (s: string) => s.replace(/\s+/g, " ").trim();

/** Wording that names a condition to rule it out ("is not indicated for the treatment of
 *  pyelonephritis"), in the stretch of text just before the mention. */
const RULED_OUT = /\bnot\b[^.]{0,80}$|\b(?:excluding|except)\b[^.]{0,40}$/;

/** Whether the indications name the term as a use, not only to exclude it. */
export function mentionsAsUse(indications: string, term: string): boolean {
  for (let at = indications.indexOf(term); at >= 0; at = indications.indexOf(term, at + 1)) {
    if (!RULED_OUT.test(indications.slice(Math.max(0, at - 100), at))) return true;
  }
  return false;
}

/** What one label says about the condition. `names` are the condition's names and synonyms. */
export function readLabel(drug: string, label: Json, names: string[]): LabelFact {
  const text = (field: string) => clean(((label[field] as string[] | undefined) ?? []).join(" "));
  const indications = text("indications_and_usage").toLowerCase();
  const dosing = text("dosage_and_administration");
  const terms = names.map((n) => n.toLowerCase()).filter((n) => n.length >= 4);
  const indicated = terms.some((t) => mentionsAsUse(indications, t));
  let dose: string | null = null;
  for (const t of terms) {
    const at = dosing.toLowerCase().indexOf(t);
    if (at >= 0) {
      dose = dosing.slice(at, at + DOSE_WINDOW).replace(/\s\S*$/, "");
      break;
    }
  }
  const warning = text("boxed_warning");
  // The headline is the all-capitals run at the start; the text after it starts in normal case.
  const headline = warning.replace(/^(?:BOXED WARNING SECTION\s*)?(?:WARNINGS?:?\s*)?/i, "").match(/^[^a-z]+?(?=\s+[A-Z][a-z]|$)/)?.[0] ?? "";
  // A warning without a capitals headline gives its first sentence instead.
  const lead = clean(headline).replace(/[\s,;:]+$/, "");
  const boxed = !warning ? null
    : lead.length >= 8 ? lead.slice(0, 140)
    : clean(warning.replace(/^(?:BOXED WARNING SECTION\s*)?(?:WARNINGS?:?\s*)?/i, "")).split(/(?<=\.)\s/)[0].slice(0, 140);
  const routes = ((label.openfda?.route as string[] | undefined) ?? []).map((r) => r.toLowerCase());
  return { drug, routes, indicated, dose, boxed: boxed || null };
}

/** Oral drugs whose labels name the condition in their indications, most labels first: generics
 *  common enough to have many manufacturers' labels come first, which puts the usual choices
 *  ahead of rare ones (openFDA's count). Mentions that rule the condition out are caught later,
 *  when each label is read. */
export async function labelCandidates(name: string, apiKey = Deno.env.get("OPENFDA_API_KEY") ?? ""): Promise<string[]> {
  const key = apiKey ? `&api_key=${encodeURIComponent(apiKey)}` : "";
  const search = encodeURIComponent(`indications_and_usage:"${name}" AND openfda.route:"ORAL"`);
  const res = await fetch(`${API}?search=${search}&count=openfda.generic_name.exact&limit=30${key}`, { signal: AbortSignal.timeout(TIMEOUT_MS) });
  if (!res.ok) return [];
  return ingredients(((await res.json()).results ?? []).map((r: Json) => String(r.term ?? "")))
    // Combination products ("acetaminophen, aspirin, caffeine") aren't one drug a profile can name.
    .filter((d) => !d.includes(","));
}

/** Labels for the condition's drugs (in the order given, most likely first), ranked: approved for
 *  this condition and dosed for it first, then oral. */
export async function labelFacts(drugs: string[], names: string[], apiKey = Deno.env.get("OPENFDA_API_KEY") ?? ""): Promise<LabelFact[]> {
  const key = apiKey ? `&api_key=${encodeURIComponent(apiKey)}` : "";
  const first = async (search: string): Promise<Json | null> => {
    // Newest label first, so its dosing is the current one.
    const res = await fetch(`${API}?search=${encodeURIComponent(search)}&sort=effective_time:desc&limit=1${key}`, { signal: AbortSignal.timeout(TIMEOUT_MS) });
    return res.ok ? (await res.json()).results?.[0] ?? null : null;
  };
  // The oral label first: a drug's first hit is as likely to be its ear drops or IV form.
  const one = async (drug: string): Promise<LabelFact | null> => {
    try {
      const label = await first(`openfda.generic_name:"${drug}" AND openfda.route:"ORAL"`) ?? await first(`openfda.generic_name:"${drug}"`);
      return label ? readLabel(drug, label, names) : null;
    } catch {
      return null;
    }
  };
  const found = (await Promise.all(ingredients(drugs).slice(0, MAX_LOOKUPS).map(one))).filter((f): f is LabelFact => !!f);
  // Stable sort: within a rank, the order given (most labels first) stands.
  const rank = (f: LabelFact) => (f.indicated ? 0 : 4) + (f.dose ? 0 : 2) + (f.routes.includes("oral") ? 0 : 1);
  return found.sort((a, b) => rank(a) - rank(b)).slice(0, MAX_LABELS);
}

/** The labels as grounding lines for the profile writer. */
export function labelLines(facts: LabelFact[]): string[] {
  return facts.map((f) => [
    `${f.drug} (${f.routes.join(", ") || "route not listed"})`,
    f.indicated ? "label lists this condition" : "label doesn't name this condition",
    f.dose && `dosing text: "${f.dose}"`,
    f.boxed && `boxed warning: ${f.boxed}`,
  ].filter(Boolean).join("; "));
}
