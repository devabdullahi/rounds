// Who a subscription belongs to and whether an account is paid up. Pure, so the rules that decide
// access are unit-tested without Apple or the database.

export type Row = { user_id: string; expires_at: Date; revoked: boolean };

/** The account a claim lands on: the first account to claim a subscription keeps it. */
export function ownerAfterClaim(existingOwner: string | null, caller: string): { owner: string; takenByAnother: boolean } {
  if (existingOwner && existingOwner !== caller) return { owner: existingOwner, takenByAnother: true };
  return { owner: caller, takenByAnother: false };
}

/** Paid up: some subscription of the account runs past now and wasn't refunded. */
export function entitled(rows: Row[], now: Date = new Date()): boolean {
  return rows.some((r) => !r.revoked && r.expires_at.getTime() > now.getTime());
}

/** The lapsed subscription worth asking Apple about again (it may have renewed): the latest one. */
export function toRecheck(rows: (Row & { original_transaction_id: string })[]): string | null {
  const live = rows.filter((r) => !r.revoked).sort((a, b) => b.expires_at.getTime() - a.expires_at.getTime());
  return live[0]?.original_transaction_id ?? null;
}
