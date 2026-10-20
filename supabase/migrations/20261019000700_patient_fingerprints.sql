-- Never the same patient twice for one student. Each case's patient gets a fingerprint (a hash of its
-- condition, severity, sex, age band and the symptoms it has), and a student can hold each fingerprint
-- once: generate-case redraws the plan before writing when one is taken, and this key backs that up if
-- two cases are written at the same moment. The hash says nothing about the condition on its own.

create table private.patient_fingerprints (
  user_id     uuid not null references public.profiles (id) on delete cascade,
  fingerprint text not null check (char_length(fingerprint) = 64),
  -- Kept when the student deletes the patient, so deleting one doesn't let it come back.
  case_id     text references public.cases (id) on delete set null,
  created_at  timestamptz not null default now(),
  primary key (user_id, fingerprint)
);

comment on table private.patient_fingerprints is
  'One row per patient a student was given, so no student gets an identical patient twice. Service role only.';

create index patient_fingerprints_case_idx on private.patient_fingerprints (case_id);

revoke all on private.patient_fingerprints from public, anon, authenticated;
