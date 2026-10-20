// Who a subscription belongs to. Pure, so the rule is unit-tested without Apple or the database.
// Whether an account is paid up lives in _shared/plan.ts, shared with the functions that enforce it.

/**
 * The account a claim lands on. The account the app tagged the purchase with (appAccountToken) owns
 * it when that is a real account; otherwise the first account to claim it keeps it.
 */
export function ownerAfterClaim(
  existingOwner: string | null,
  caller: string,
  taggedAccount: string | null = null,
): { owner: string; takenByAnother: boolean } {
  const owner = taggedAccount ?? existingOwner;
  if (owner && owner !== caller) return { owner, takenByAnother: true };
  return { owner: caller, takenByAnother: false };
}
