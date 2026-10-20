// Who a subscription belongs to. Pure, so the rule is unit-tested without Apple or the database.
// Whether an account is paid up lives in _shared/plan.ts, shared with the functions that enforce it.
//
// The policy (chosen 2026-10-20): a plan stays with the account that has it until that account's
// student asks to move it, or it lapses. Another account on the same Apple ID is told whose plan it
// is and may move it to themselves ("transfer"); an expired or refunded plan is free for whoever
// claims next. Once our record exists it decides: the purchase's tag (appAccountToken) only places a
// plan the first time, so switching tiers inside the group never moves it silently.

export type ClaimDecision = { kind: "own" } | { kind: "taken"; owner: string };

/**
 * Where a claim lands. `rowOwner`: the account our record has, if any. `taggedAccount`: the real
 * account the purchase was tagged with, if any. `current`: Apple says the plan is paid up now (not
 * expired, refunded or revoked); a lapsed plan blocks nobody.
 */
export function decideClaim(input: { caller: string; rowOwner: string | null; taggedAccount: string | null; current: boolean }): ClaimDecision {
  const holder = input.rowOwner ?? input.taggedAccount;
  if (holder && holder !== input.caller && input.current) return { kind: "taken", owner: holder };
  return { kind: "own" };
}
