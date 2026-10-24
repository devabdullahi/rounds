-- The free case is decided from a record deleting patients can't reset. Before this, "graded" came
-- from public.attempts and "written" from public.cases, and delete_patients() removes both, so a
-- student could delete their patients and get the free case back as often as they liked.
--
-- "Written" now also counts private.patient_fingerprints, which survive deletion already. "Graded"
-- comes from this table: case-session's submit adds the student's row in the same transaction that
-- grades their first attempt.

create table private.first_submissions (
  user_id      uuid primary key references public.profiles (id) on delete cascade,
  submitted_at timestamptz not null default now()
);

comment on table private.first_submissions is
  'When each student first submitted a case. Survives delete_patients(), so the free case can''t be reset. Service role only.';

revoke all on private.first_submissions from public, anon, authenticated;

-- Students who have already submitted keep their place.
insert into private.first_submissions (user_id, submitted_at)
select user_id, min(submitted_at)
from public.attempts
where submitted_at is not null
group by user_id
on conflict (user_id) do nothing;
