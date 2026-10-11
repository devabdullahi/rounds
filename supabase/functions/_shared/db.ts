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
export const sql = postgres(Deno.env.get("DB_POOLER_URL") ?? Deno.env.get("SUPABASE_DB_URL")!, { prepare: false, max: 1, idle_timeout: 2 });
