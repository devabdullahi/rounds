-- What the public medical APIs (MedlinePlus, RxNav, openFDA, UMLS) said about a condition, kept a
-- day. NLM's terms ask callers to cache results 12–24 hours, and a live profile build for the same
-- condition then skips a dozen or more requests. The UMLS part holds SNOMED CT relations, so like
-- private.term_checks it stays in the private schema, never in git or a client response.
create table private.api_cache (
  key        text primary key,                       -- e.g. "facts:pyelonephritis"
  body       jsonb not null,
  fetched_at timestamptz not null default now()
);

comment on table private.api_cache is 'Public medical API answers cached for a day (NLM asks for 12-24 h). Service role only.';

revoke all on private.api_cache from public, anon, authenticated;
