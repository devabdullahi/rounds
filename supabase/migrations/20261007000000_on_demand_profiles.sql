-- Condition profiles generated on demand.
--
-- The condition catalog (every triaged condition, with its source text) lives in private, and a
-- profile is written only when students need it: generate-case serves an existing profile and
-- queues one new condition in the same topic, and case-session queues another on grading. The
-- edge function prepare-profile works through a job one LLM attempt per call, so no call outlives
-- the edge runtime's time limit. Everything here is service role only.

-- ───────────────────────────── catalog ─────────────────────────────

create table private.conditions (
  slug              text primary key,
  condition_id      text not null,                -- source id ("mplus-1234", "ct-4925")
  name              text not null,
  case_suitable     boolean not null,
  commonness        text not null default 'rare' check (commonness in ('very_common', 'common', 'uncommon', 'rare')),
  primary_clerkship text not null,
  clerkships        text[] not null,              -- primary + secondary, for study-focus matching
  organ_systems     text[] not null,
  triage            jsonb not null,
  background        text not null default '',     -- public-domain source text handed to the writer
  updated_at        timestamptz not null default now()
);

comment on table private.conditions is 'Triaged condition catalog (tools/kb-generate/load_conditions.py). Names diagnoses: service role only.';

create index conditions_clerkships_idx on private.conditions using gin (clerkships);
create index conditions_organ_systems_idx on private.conditions using gin (organ_systems);

-- ───────────────────────────── generation jobs ─────────────────────────────

-- One job per condition (slug is the key), so two students asking at once never generate twice.
create table private.profile_jobs (
  slug        text primary key references private.conditions (slug) on delete cascade,
  status      text not null default 'queued' check (status in ('queued', 'running', 'done', 'failed')),
  stage       integer not null default 0,           -- index into the stage list
  attempt     integer not null default 0,           -- attempt within the stage (0 or 1)
  profile     jsonb not null default '{}'::jsonb,   -- sections written so far
  feedback    text[] not null default '{}',         -- the last attempt's errors, sent back on the retry
  errors      text[] not null default '{}',         -- stage errors kept for the reviewer
  repairs     text[] not null default '{}',
  outages     integer not null default 0,           -- model unreachable; retried, then given up
  locked_at   timestamptz,                          -- set while a call works on it
  requested_by text,                                -- focus that queued it, for logs
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

comment on table private.profile_jobs is 'On-demand profile generation, advanced by the prepare-profile edge function.';

create index profile_jobs_status_idx on private.profile_jobs (status) where status in ('queued', 'running');

-- ───────────────────────────── terminology cache ─────────────────────────────

-- SNOMED CT (via UMLS) and RxNorm answers, so each term costs one lookup across all generations.
-- Holds only yes/no and suggested names for the writer's retry, never SNOMED content in profiles.
create table private.term_checks (
  kind        text not null check (kind in ('snomed', 'rxnorm')),
  term        text not null,                         -- lowercased
  ok          boolean not null,
  suggestions text[] not null default '{}',
  checked_at  timestamptz not null default now(),
  primary key (kind, term)
);

comment on table private.term_checks is 'Cached terminology lookups for profile checks. Service role only.';

-- ───────────────────────────── cases remember their focus ─────────────────────────────

-- Grading queues the next condition for the topic the student was practicing.
alter table private.case_content add column focus text not null default '';

-- ───────────────────────────── topic availability ─────────────────────────────

-- Topics now count every case-suitable condition, since a profile is written when first needed.
create or replace function public.topic_counts()
returns table (kind text, topic text, conditions integer)
language sql
stable
security definer
set search_path = ''
as $$
  select 'rotation', c, count(*)::integer
  from private.conditions p, unnest(p.clerkships) c
  where p.case_suitable
  group by c
  union all
  select 'system', s, count(*)::integer
  from private.conditions p, unnest(p.organ_systems) s
  where p.case_suitable
  group by s;
$$;

revoke execute on function public.topic_counts() from public, anon;
grant execute on function public.topic_counts() to authenticated;
