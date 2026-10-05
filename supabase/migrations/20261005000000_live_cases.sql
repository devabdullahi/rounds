-- Live, model-generated cases.
--
-- Condition profiles (the generated knowledge base) live in private and are read only by edge
-- functions. generate-case turns a profile into a fictional patient for one student; case-session
-- runs the encounter and grades it. The app reads only the public door note and menus.

-- ───────────────────────────── profiles (knowledge) ─────────────────────────────

create table private.condition_profiles (
  slug              text primary key,
  name              text not null,
  primary_clerkship text not null,
  clerkships        text[] not null,          -- primary + secondary, for study-focus matching
  organ_systems     text[] not null,
  validation        text not null check (validation in ('passed', 'failed', 'pending')),
  review            text not null default 'pending' check (review in ('pending', 'approved', 'changes_requested', 'rejected')),
  profile           jsonb not null,
  updated_at        timestamptz not null default now()
);

comment on table private.condition_profiles is 'Generated condition knowledge (knowledge-base/profiles). Names diagnoses: service role only.';

-- ───────────────────────────── cases: generated per student ─────────────────────────────

alter table public.cases
  add column created_by    uuid references public.profiles (id) on delete cascade,
  add column setting       text not null default '',
  add column demeanor      text not null default '',
  add column organ_system  text,
  add column clerkship     text,
  add column task          text not null default 'Take a focused history, examine, order investigations, and give a working diagnosis with a plan.',
  add column suggested     jsonb not null default '[]'::jsonb,  -- [{text, fact}] one-tap questions
  add column maneuvers     jsonb not null default '[]'::jsonb,  -- [{id, title}] exam menu, no findings
  add column test_menu     jsonb not null default '[]'::jsonb;  -- [{id, name, detail, cost, turnaround_s}], no results

comment on column public.cases.created_by is 'Student the case was generated for; null for shared published cases.';

create index cases_created_by_idx on public.cases (created_by, created_at desc);

-- Students see shared published cases plus the ones generated for them. Rows are written only by
-- generate-case (service role), so there are no insert/update policies.
drop policy "cases: read published" on public.cases;
create policy "cases: read published or own" on public.cases for select to authenticated
  using (published or (select auth.uid()) = created_by);

alter table private.case_content
  add column condition_slug text references private.condition_profiles (slug),
  add column severity       text check (severity in ('mild', 'moderate', 'severe', 'critical')),
  add column persona        jsonb not null default '{}'::jsonb,  -- voice, demeanor, background for the patient LLM
  add column rubric         jsonb not null default '{}'::jsonb;  -- grading weights derived from the profile

-- ───────────────────────────── attempts: written by case-session ─────────────────────────────

-- case-session records every action and the submission with the service role, after checking the
-- caller owns the attempt. Students keep read access to their own attempts only.
revoke update on public.attempts from authenticated;
drop policy "attempts: update own until submitted" on public.attempts;
drop policy "attempts: start own" on public.attempts;
revoke insert on public.attempts from authenticated;
