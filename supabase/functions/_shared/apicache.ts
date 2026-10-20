// A day's cache for what the public medical APIs answered (private.api_cache). NLM's terms ask for
// 12–24 hours of caching; it also spares the rate limits when one condition is built twice. A
// database error never blocks the lookup: the answer is just fetched again.
import { sql } from "./db.ts";

export const CACHE_HOURS = 24;

/** The cached answer for `key` if it's fresh, else `load()`'s, stored for next time. An empty
 *  answer (`isEmpty`) isn't stored, so a source that was down is asked again next time. */
export async function cachedFor<T>(key: string, load: () => Promise<T>, isEmpty: (value: T) => boolean = () => false): Promise<T> {
  try {
    const [row] = await sql<{ body: T }[]>`
      select body from private.api_cache where key = ${key} and fetched_at > now() - make_interval(hours => ${CACHE_HOURS})`;
    if (row) return row.body;
  } catch (error) {
    console.warn("api cache read failed", (error as Error).message);
  }
  const value = await load();
  if (!isEmpty(value)) {
    try {
      await sql`insert into private.api_cache (key, body) values (${key}, ${sql.json(value as never)})
                on conflict (key) do update set body = excluded.body, fetched_at = now()`;
    } catch (error) {
      console.warn("api cache write failed", (error as Error).message);
    }
  }
  return value;
}
