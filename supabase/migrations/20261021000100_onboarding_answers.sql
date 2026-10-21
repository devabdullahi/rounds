-- What each student picked in onboarding, kept for product research (which years, exams and
-- struggles students come with). One row per account, written once by the app when onboarding
-- ends. The app never reads it back: students may insert their own row and nothing else; the
-- team reads it with the service role. No name or other personal details, only the picks.

create table public.onboarding_answers (
  user_id uuid primary key references auth.users (id) on delete cascade,
  school_year text,
  study_goal text,
  study_focus text,
  care_setting text,
  struggles text[] not null default '{}',
  -- The mini-quiz: the option index picked (0-3) and whether it was the red flag.
  red_flag_pick smallint check (red_flag_pick between 0 and 3),
  red_flag_correct boolean,
  voice_mode boolean,
  exam_by_default boolean,
  time_limit_minutes smallint check (time_limit_minutes between 0 and 120),
  daily_goal smallint check (daily_goal between 1 and 10),
  reminder text,
  app_version text check (char_length(app_version) <= 40),
  answered_at timestamptz not null default now(),
  -- Short picks only: these are enum raw values, never free text.
  constraint onboarding_answers_short check (
    coalesce(char_length(school_year), 0) <= 40 and coalesce(char_length(study_goal), 0) <= 40 and
    coalesce(char_length(study_focus), 0) <= 80 and coalesce(char_length(care_setting), 0) <= 40 and
    coalesce(char_length(reminder), 0) <= 40 and cardinality(struggles) <= 10)
);

alter table public.onboarding_answers enable row level security;

-- user_id is the primary key, so the policy column is already indexed.
create policy "onboarding_answers: insert own" on public.onboarding_answers
  for insert to authenticated with check ((select auth.uid()) = user_id);

revoke all on public.onboarding_answers from public, anon, authenticated;
grant insert (user_id, school_year, study_goal, study_focus, care_setting, struggles, red_flag_pick,
  red_flag_correct, voice_mode, exam_by_default, time_limit_minutes, daily_goal, reminder, app_version)
  on public.onboarding_answers to authenticated;
