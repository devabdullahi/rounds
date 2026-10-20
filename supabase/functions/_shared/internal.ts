// The check for functions only our own backend calls (pg_cron jobs, other functions): the bearer
// token must be the service role key. Those functions run with verify_jwt off, so this is their gate.

import { HttpError } from "./http.ts";

/** Equal strings, compared in time that doesn't depend on where they first differ. */
export function sameSecret(given: string, expected: string): boolean {
  const a = new TextEncoder().encode(given);
  const b = new TextEncoder().encode(expected);
  let diff = a.length ^ b.length;
  for (let i = 0; i < b.length; i++) diff |= (a[i] ?? 0) ^ b[i];
  return diff === 0;
}

/** Throws 401 unless the request carries the service role key. */
export function requireServiceRole(req: Request): void {
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const auth = req.headers.get("Authorization") ?? "";
  if (!key || !sameSecret(auth, `Bearer ${key}`)) throw new HttpError(401, "internal function");
}
