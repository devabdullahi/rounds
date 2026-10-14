-- Cases written ahead, so starting a case is instant.
--
-- Writing a patient takes 15–20 s. After each case start, generate-case writes the student's next
-- case for the same focus in the background and keeps it here; the next start takes it and saves it
-- as a normal case. At most one waits per student and focus. The rows hold the private script,
-- results and answer key, so this table is service role only, like private.case_content.

create table private.ready_cases (
  user_id    uuid not null references public.profiles (id) on delete cascade,
  focus      text not null,                  -- Focus.stored: "", "rotation:surgery", "system:renal"
  rows       jsonb not null,                 -- the public.cases and private.case_content values, minus id and owner
  created_at timestamptz not null default now(),
  primary key (user_id, focus)
);

comment on table private.ready_cases is 'One case written ahead per student and focus, taken on the next case start. Service role only.';

revoke all on private.ready_cases from public, anon, authenticated;
