// Postgres as the project's postgres role, so functions can reach the private schema without exposing
// it to the REST API. That role bypasses row-level security: every query that touches student data
// must filter by the verified caller itself.
//
// Through the connection pooler (DB_POOLER_URL, transaction mode) when it's set: every function
// instance opening its own direct connections ran the database out of slots at about 15 busy
// instances (a load test of 100 students at once failed 91% with "too many clients"). Transaction
// mode can't keep prepared statements, hence prepare: false. SUPABASE_DB_URL (direct) is the fallback
// for local runs.
import postgres from "postgres";

// One connection per instance: the pooler takes 200 clients, and the platform runs many instances side
// by side under load, so three each overflowed it. Requests are short; one connection is plenty.
const base = postgres(Deno.env.get("DB_POOLER_URL") ?? Deno.env.get("SUPABASE_DB_URL")!, { prepare: false, max: 1, idle_timeout: 2 });

/** Waits before each retry when the pooler is full, with jitter so instances don't retry together. */
const RETRY_DELAYS_MS = [100, 300, 900];

/** Whether a query failed because the pooler had no room for another client. The query never ran,
 *  so trying it again is safe. Seen under load as "(EMAXCONN) max client connections reached". */
export function poolFull(error: unknown): boolean {
  const e = error as { code?: string; message?: string } | null;
  return e?.code === "EMAXCONN" || /max client connections|too many clients|remaining connection slots/i.test(e?.message ?? "");
}

/** Runs `run`, retrying a few times while the pooler is full. */
export async function retryWhenFull<T>(run: () => Promise<T>, wait = (ms: number) => new Promise((r) => setTimeout(r, ms))): Promise<T> {
  for (let attempt = 0; ; attempt++) {
    try {
      return await run();
    } catch (error) {
      if (!poolFull(error) || attempt >= RETRY_DELAYS_MS.length) throw error;
      await wait(RETRY_DELAYS_MS[attempt] * (0.5 + Math.random()));
    }
  }
}

/** `sql` as everywhere else uses it, but a whole query (a tagged template) is retried while the
 *  pooler is full. Helper calls (`sql(rows)`, `sql.json`, `sql.begin`) pass through unchanged. */
export const sql = new Proxy(base, {
  apply(target, thisArg, args) {
    const template = Array.isArray(args[0]) && "raw" in (args[0] as object);
    if (!template) return Reflect.apply(target, thisArg, args);
    return retryWhenFull(() => Reflect.apply(target, thisArg, args) as Promise<unknown>);
  },
}) as typeof base;
