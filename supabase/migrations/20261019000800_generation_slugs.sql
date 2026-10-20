-- Two gaps in "no repeats" found by the edge-case probe:
-- 1. A background job and a tap could pick the same condition at the same moment, because the job's
--    pick wasn't visible until its case was finished. The job now records its condition as soon as
--    it picks, and a tap skips it.
-- 2. Deleting a patient made its condition "never had" again, because history came from public.cases.
--    Each fingerprint now keeps its condition, so history survives a deletion.

alter table private.case_generation_jobs add column slug text;

comment on column private.case_generation_jobs.slug is
  'The condition this running job picked, so a case written at the same moment picks another.';

alter table private.patient_fingerprints add column condition_slug text;

update private.patient_fingerprints f set condition_slug = cc.condition_slug
from private.case_content cc where cc.case_id = f.case_id and f.condition_slug is null;

create index patient_fingerprints_user_slug_idx on private.patient_fingerprints (user_id, condition_slug);

comment on column private.patient_fingerprints.condition_slug is
  'The patient''s condition, kept after the case is deleted so the condition still counts as had.';
