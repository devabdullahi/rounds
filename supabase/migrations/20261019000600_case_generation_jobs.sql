create table private.case_generation_jobs (
  user_id    uuid not null references public.profiles (id) on delete cascade,
  focus      text not null,
  status     text not null default 'queued' check (status in ('queued', 'running', 'failed')),
  started_at timestamptz not null default now(),
  primary key (user_id, focus)
);

comment on table private.case_generation_jobs is
  'Tracks one background case generation per student and focus.';

revoke all on private.case_generation_jobs from public, anon, authenticated;
