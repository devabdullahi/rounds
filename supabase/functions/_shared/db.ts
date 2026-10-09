// Direct Postgres connection (SUPABASE_DB_URL, the project's postgres role), so functions can reach
// the private schema without exposing it to the REST API. That role bypasses row-level security:
// every query that touches student data must filter by the verified caller itself.
import postgres from "postgres";

export const sql = postgres(Deno.env.get("SUPABASE_DB_URL")!, { prepare: false, max: 3 });
