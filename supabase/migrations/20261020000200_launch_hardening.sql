-- Launch hardening from the reliability and security reviews (2026-10-20).

-- Resume and submit look up a student's unsubmitted attempt at one case.
create index if not exists attempts_open_by_case_idx
  on public.attempts (user_id, case_id) where submitted_at is null;

-- Every model call added to one row per (day, task, model), so under load every call waited on that
-- row's lock. Spread them over 16 rows; the budget check and any report sum across them anyway.
alter table private.llm_usage add column shard smallint not null default 0 check (shard between 0 and 15);
alter table private.llm_usage drop constraint llm_usage_pkey;
alter table private.llm_usage add primary key (day, task, model, shard);

create or replace function private.record_llm_usage(
  what text, model_name text, hit bigint, miss bigint, out_tokens bigint, reasoning_tokens bigint, cost numeric
)
returns void
language sql
volatile
set search_path = ''
as $$
  insert into private.llm_usage as u (day, task, model, shard, calls, cache_hit, cache_miss, output, reasoning, cost_usd)
  values ((now() at time zone 'utc')::date, what, model_name, floor(random() * 16)::smallint, 1, hit, miss, out_tokens, reasoning_tokens, cost)
  on conflict (day, task, model, shard) do update set
    calls = u.calls + 1,
    cache_hit = u.cache_hit + excluded.cache_hit,
    cache_miss = u.cache_miss + excluded.cache_miss,
    output = u.output + excluded.output,
    reasoning = u.reasoning + excluded.reasoning,
    cost_usd = u.cost_usd + excluded.cost_usd;
$$;

revoke all on function private.record_llm_usage(text, text, bigint, bigint, bigint, bigint, numeric) from public, anon, authenticated;
