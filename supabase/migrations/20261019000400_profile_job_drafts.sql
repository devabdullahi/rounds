-- Profile stages in two calls, so each fits the edge runtime's time limit.
--
-- A stage was one prepare-profile call: the model writes the sections (about 40 s on GPT-6.1 Sol),
-- then every new symptom and exam term is checked against SNOMED CT and RxNorm (several UMLS
-- requests per uncached term). Together they ran past the worker's limit: since 2026-10-09 each job
-- was dropped about 75 s in, after the model had answered but before anything was saved, and no
-- profile was finished. Now the model's reply is saved here as a draft and the call ends; the next
-- call (kicked at once) runs the term checks on the draft and advances the job. Term answers are
-- cached (private.term_checks), so a check phase that runs out of time resumes where it stopped.

alter table private.profile_jobs add column draft jsonb;

comment on column private.profile_jobs.draft is
  'This stage''s model reply awaiting its term checks: {output, errors, repairs}. Null between stages.';
