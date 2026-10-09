-- Synthetic patient backgrounds (Synthea): who a generated patient is before today's illness.
-- One row per synthetic person: chronic conditions, current medications ([{rxcui, name}]),
-- allergies, smoking status and social circumstances. generate-case picks one with the case's sex
-- and closest age and has the writer voice it in plain words.
--
-- Everything is synthetic, so no real patient data. Condition, allergy and social wording is SNOMED CT
-- (licensed, UMLS Affiliate License): it lives only here and in knowledge-base/licensed/, loaded with
-- tools/synthea/load_backgrounds.py, never in git, seed files or client responses.
create table private.patient_backgrounds (
  id          text primary key,
  age         integer not null check (age >= 0),
  sex         text not null check (sex in ('F', 'M')),
  marital     text,           -- Synthea code: M, S, D, W, or null
  conditions  jsonb not null default '[]',
  medications jsonb not null default '[]',
  allergies   jsonb not null default '[]',
  smoking     text,
  social      jsonb not null default '[]'
);

create index patient_backgrounds_sex_age_idx on private.patient_backgrounds (sex, age);

comment on table private.patient_backgrounds is 'Synthetic (Synthea) patient backgrounds for generated cases. SNOMED CT wording; service role only.';

revoke all on private.patient_backgrounds from public, anon, authenticated;

-- Which background a generated case was written from, for tracing a case back to its record.
-- No foreign key: reloading the backgrounds must not touch existing cases.
alter table private.case_content add column background_id text;
