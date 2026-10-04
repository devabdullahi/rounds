-- Rounds: initial schema
-- Students practise on fictional patients. Nothing here stores real patient data.
--
-- Security model
--   * Public case info (door note, vitals, quote) is readable by any signed-in user.
--   * The case "script" (history facts, exam findings, test results) and the answer key live in
--     private.case_content, which the app can never read. Server functions (service role) use it
--     to voice the patient and grade attempts, so answers never travel to the device.
--   * Attempts belong to their student. The student can record actions, but only the grading
--     function can write a score.

create schema if not exists private;

-- ───────────────────────────── profiles ─────────────────────────────

create table public.profiles (
  id              uuid primary key references auth.users (id) on delete cascade,
  name            text not null default '',
  training_level  text check (training_level in ('ms12', 'ms3', 'ms4')),  -- US medical students only
  rating          integer not null default 1200,
  streak          integer not null default 0,
  created_at      timestamptz not null default now()
);

comment on table public.profiles is 'One row per student. Rating and streak are written by server functions only.';

-- Create a profile automatically when someone signs up.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'name', ''));
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ───────────────────────────── cases ─────────────────────────────

create table public.cases (
  id            text primary key,                  -- bed code, e.g. 'B4'
  specialty     text not null,                     -- Cardiology, Respiratory, ...
  patient_name  text not null,
  age           integer not null check (age between 0 and 120),
  sex           text not null check (sex in ('F', 'M', 'X')),
  quote         text not null,                     -- "My chest has been hurting..."
  complaint     text not null,                     -- door-note summary
  vitals        jsonb not null,                    -- {"hr": 104, "bp": "148/92", ...}
  budget        integer not null default 600,
  minutes       integer not null default 10,
  published     boolean not null default false,
  created_at    timestamptz not null default now()
);

comment on table public.cases is 'What the student sees before entering the room. No answers here.';

create table private.case_content (
  case_id     text primary key references public.cases (id) on delete cascade,
  facts       jsonb not null,   -- [{id, label, keywords[], reply, red_flag, key_history}]
  exam        jsonb not null,   -- [{id, title, finding, red_flag}]
  tests       jsonb not null,   -- [{id, name, cost, turnaround_s, result, abnormal, delays_care_min}]
  answer_key  jsonb not null,   -- {diagnosis, accepted[], plan_keywords[], red_flags[], differential[]}
  reviewed_by text,             -- clinician who signed off this version
  reviewed_at timestamptz,
  version     integer not null default 1
);

comment on table private.case_content is 'Patient script and answer key. Service role only; never exposed to the app.';

-- ───────────────────────────── attempts ─────────────────────────────

create table public.attempts (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  case_id             text not null references public.cases (id),
  exam_mode           boolean not null default false,
  time_limit_minutes  integer check (time_limit_minutes is null or time_limit_minutes between 1 and 120),
  started_at          timestamptz not null default now(),
  transcript          jsonb not null default '[]'::jsonb,  -- questions and patient replies
  revealed_facts      text[] not null default '{}',
  examined            text[] not null default '{}',
  ordered_tests       jsonb not null default '[]'::jsonb,  -- [{id, at}]
  diagnosis           text,
  differential        text[] not null default '{}',
  plan                text,
  submitted_at        timestamptz,
  score               integer check (score between 0 and 100),
  grade               jsonb                                 -- verdict, feedback, misses, rating delta
);

create index attempts_user_idx on public.attempts (user_id, started_at desc);
create index attempts_case_idx on public.attempts (case_id);

comment on column public.attempts.score is 'Written by the grade-attempt function only.';

-- ───────────────────────────── flashcards ─────────────────────────────

create table public.flashcards (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid references public.profiles (id) on delete cascade,  -- null = built-in deck
  deck        text not null default 'My cards',
  topic       text not null default '',
  front       text not null,
  back        text not null,
  color       text not null default 'standard'
                check (color in ('standard', 'teal', 'blue', 'purple', 'pink', 'red', 'yellow')),
  created_at  timestamptz not null default now()
);

create index flashcards_user_idx on public.flashcards (user_id);

create table public.flashcard_reviews (
  id           bigint generated always as identity primary key,
  user_id      uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  card_id      uuid not null references public.flashcards (id) on delete cascade,
  knew_it      boolean not null,
  reviewed_at  timestamptz not null default now()
);

create index flashcard_reviews_user_idx on public.flashcard_reviews (user_id, reviewed_at desc);

-- ───────────────────────────── row-level security ─────────────────────────────

alter table public.profiles          enable row level security;
alter table public.cases             enable row level security;
alter table public.attempts          enable row level security;
alter table public.flashcards        enable row level security;
alter table public.flashcard_reviews enable row level security;

-- The app (anon/authenticated roles) has no access to the private schema at all.
revoke all on schema private from anon, authenticated;
revoke all on all tables in schema private from anon, authenticated;

-- profiles: read and edit only your own; rating/streak are server-written.
create policy "profiles: read own"   on public.profiles for select to authenticated using ((select auth.uid()) = id);
create policy "profiles: update own" on public.profiles for update to authenticated
  using ((select auth.uid()) = id) with check ((select auth.uid()) = id);
revoke update on public.profiles from authenticated;
grant update (name, training_level) on public.profiles to authenticated;

-- cases: any signed-in student can browse published cases.
create policy "cases: read published" on public.cases for select to authenticated using (published);

-- attempts: your own only. Students may record actions until they submit; never the score.
create policy "attempts: read own"   on public.attempts for select to authenticated using ((select auth.uid()) = user_id);
create policy "attempts: start own"  on public.attempts for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "attempts: update own until submitted" on public.attempts for update to authenticated
  using ((select auth.uid()) = user_id and submitted_at is null)
  with check ((select auth.uid()) = user_id);
revoke update on public.attempts from authenticated;
grant update (transcript, revealed_facts, examined, ordered_tests, diagnosis, differential, plan, submitted_at)
  on public.attempts to authenticated;

-- flashcards: built-in decks are readable by all students; your own cards are fully yours.
create policy "flashcards: read built-in and own" on public.flashcards for select to authenticated
  using (user_id is null or (select auth.uid()) = user_id);
create policy "flashcards: add own"    on public.flashcards for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "flashcards: edit own"   on public.flashcards for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "flashcards: delete own" on public.flashcards for delete to authenticated using ((select auth.uid()) = user_id);

create policy "reviews: read own" on public.flashcard_reviews for select to authenticated using ((select auth.uid()) = user_id);
create policy "reviews: add own"  on public.flashcard_reviews for insert to authenticated with check ((select auth.uid()) = user_id);

-- ───────────────────────────── views ─────────────────────────────

-- "Worth a second visit": the student's latest graded attempt per case that missed red flags.
create view public.revisits
with (security_invoker = true) as
select distinct on (a.case_id)
  a.case_id,
  a.score,
  a.grade -> 'missed_red_flags' as misses,
  a.submitted_at
from public.attempts a
where a.submitted_at is not null
  and jsonb_array_length(coalesce(a.grade -> 'missed_red_flags', '[]'::jsonb)) > 0
order by a.case_id, a.submitted_at desc;
