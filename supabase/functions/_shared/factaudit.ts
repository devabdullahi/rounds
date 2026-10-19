// The fact audit: after a case is written, every medical claim in the patient's facts must come
// from what the writer was given. All of it is asked live, nothing is built ahead:
//   1. A fast model (task "check") lists each fact's medical claims and the planned item each one
//      matches: a present symptom, an absent one, or a background/risk item; or none.
//   2. Code flags two mistakes: a claim matching nothing (invented) and an absent symptom stated as
//      present (contradicts). Denials ("no fever") are fine.
//   3. Each invented claim is confirmed with the UMLS API: if it names the same concept (CUI) as a
//      planned item ("throwing up" is vomiting), the model only missed the match and it isn't
//      flagged. Only what survives goes back to the writer as a problem.
// The prompt building and the decisions are pure, so they're unit-tested; the calls are injected.

export type PlanItems = { present: string[]; absent: string[]; background: string[] };
export type Claim = { fact: string; claim: string; item: number | null; negated: boolean };
export type Flag = { fact: string; claim: string; kind: "invented" | "contradicts" };

/** The planned items as one numbered list, so the model can point at them by number. */
export function numbered(items: PlanItems): { kind: "present" | "absent" | "background"; text: string }[] {
  return [
    ...items.present.map((text) => ({ kind: "present" as const, text })),
    ...items.absent.map((text) => ({ kind: "absent" as const, text })),
    ...items.background.map((text) => ({ kind: "background" as const, text })),
  ];
}

export function auditPrompt(items: PlanItems, facts: { id: string; reply: string }[]): string {
  return `Planned items: ${JSON.stringify(numbered(items).map((i, n) => ({ n, text: i.text })))}
Facts: ${JSON.stringify(facts.map((f) => ({ id: f.id, text: f.reply })))}`;
}

/** The model's claims, kept only when well formed. */
export function parseClaims(reply: unknown, itemCount: number): Claim[] {
  const claims = (reply as { claims?: unknown })?.claims;
  if (!Array.isArray(claims)) return [];
  return claims.flatMap((c) => {
    if (typeof c?.fact !== "string" || typeof c?.claim !== "string") return [];
    const item = Number.isInteger(c.item) && c.item >= 0 && c.item < itemCount ? c.item as number : null;
    return [{ fact: c.fact, claim: c.claim, item, negated: c.negated === true }];
  });
}

/** Claims that bring in something unplanned, or state an absent symptom as present. */
export function candidateFlags(claims: Claim[], items: PlanItems): Flag[] {
  const list = numbered(items);
  return claims.flatMap((c): Flag[] => {
    if (c.negated) return [];
    if (c.item === null) return [{ fact: c.fact, claim: c.claim, kind: "invented" }];
    return list[c.item].kind === "absent" ? [{ fact: c.fact, claim: c.claim, kind: "contradicts" }] : [];
  });
}

/** Drops invented flags whose claim is, by UMLS concept, one of the allowed planned items.
 *  `conceptOf` is the live UMLS lookup; a lookup that fails keeps the flag. */
export async function confirmWithUmls(flags: Flag[], items: PlanItems, conceptOf: (term: string) => Promise<string | null>): Promise<Flag[]> {
  const invented = flags.filter((f) => f.kind === "invented");
  if (!invented.length) return flags;
  const allowedTexts = [...items.present, ...items.background];
  const lookup = (t: string) => conceptOf(t).catch(() => null);
  const [allowed, claimed] = await Promise.all([Promise.all(allowedTexts.map(lookup)), Promise.all(invented.map((f) => lookup(f.claim)))]);
  const planned = new Set(allowed.filter((c): c is string => !!c));
  return flags.filter((f) => f.kind !== "invented" || !planned.has(claimed[invented.indexOf(f)] ?? "-"));
}

/** The flags as problems for the writer's retry. */
export function auditProblems(flags: Flag[]): string[] {
  return flags.map((f) => f.kind === "contradicts"
    ? `fact ${f.fact} says the patient has "${f.claim}", but the plan lists it as ABSENT: the patient must deny it or not mention it`
    : `fact ${f.fact} claims "${f.claim}", which isn't in the planned symptoms, risk factors or background: remove it and use only what the plan gives`);
}

/** The flagged facts as lines for the fact fixer, each with the claims to remove or deny. */
export function fixRequest(flags: Flag[], facts: { id: string; reply: string }[]): string {
  const byFact = new Map<string, Flag[]>();
  for (const f of flags) byFact.set(f.fact, [...(byFact.get(f.fact) ?? []), f]);
  const lines = [...byFact.entries()].flatMap(([id, fl]) => {
    const fact = facts.find((x) => x.id === id);
    return fact ? [{
      where: `fact ${id} reply`, text: fact.reply,
      remove: fl.filter((f) => f.kind === "invented").map((f) => f.claim),
      deny: fl.filter((f) => f.kind === "contradicts").map((f) => f.claim),
    }] : [];
  });
  return `Lines to correct: ${JSON.stringify(lines)}`;
}
