-- Token use and cost of every model call, per day, task and model.
--
-- Edge functions add each call here (functions/_shared/usage.ts) and check today's total against a
-- project-wide cap (LLM_DAILY_BUDGET_USD) before calling the model. The per-student allowances in
-- private.usage limit one account; this cap limits the whole bill. Cost is estimated at the
-- provider's peak price. Days are UTC. Service role only.

create table private.llm_usage (
  day        date not null,
  task       text not null,                     -- patient, check, case, grade, cards, profile
  model      text not null,                     -- provider/model
  calls      integer not null default 0 check (calls >= 0),
  cache_hit  bigint not null default 0,         -- prompt tokens served from the provider's cache
  cache_miss bigint not null default 0,
  output     bigint not null default 0,         -- includes reasoning tokens
  reasoning  bigint not null default 0,
  cost_usd   numeric(12, 6) not null default 0,
  primary key (day, task, model)
);

comment on table private.llm_usage is 'Daily model token use and estimated cost per task, for monitoring and the daily spending cap.';

create function private.record_llm_usage(
  what text, model_name text, hit bigint, miss bigint, out_tokens bigint, reasoning_tokens bigint, cost numeric
)
returns void
language sql
volatile
set search_path = ''
as $$
  insert into private.llm_usage as u (day, task, model, calls, cache_hit, cache_miss, output, reasoning, cost_usd)
  values ((now() at time zone 'utc')::date, what, model_name, 1, hit, miss, out_tokens, reasoning_tokens, cost)
  on conflict (day, task, model) do update set
    calls = u.calls + 1,
    cache_hit = u.cache_hit + excluded.cache_hit,
    cache_miss = u.cache_miss + excluded.cache_miss,
    output = u.output + excluded.output,
    reasoning = u.reasoning + excluded.reasoning,
    cost_usd = u.cost_usd + excluded.cost_usd;
$$;

-- Today's estimated spend across every task and model.
create function private.llm_spend_today()
returns numeric
language sql
stable
set search_path = ''
as $$
  select coalesce(sum(cost_usd), 0) from private.llm_usage where day = (now() at time zone 'utc')::date;
$$;

revoke all on private.llm_usage from public, anon, authenticated;
revoke all on function private.record_llm_usage(text, text, bigint, bigint, bigint, bigint, numeric) from public, anon, authenticated;
revoke all on function private.llm_spend_today() from public, anon, authenticated;
