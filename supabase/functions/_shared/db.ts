// Direct Postgres connection with the function's own database role, so the private schema stays
// unexposed to the REST API. Every query that touches student data filters by the verified caller.
import postgres from "postgres";

export const sql = postgres(Deno.env.get("SUPABASE_DB_URL")!, { prepare: false, max: 3 });
