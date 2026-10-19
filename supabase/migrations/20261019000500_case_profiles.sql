-- Each case keeps the condition profile it was built from.
--
-- Profiles are now built live for every new patient, from public medical APIs and the profile
-- template (_shared/liveprofile.ts), and aren't stored for reuse. Grading insights, the debrief and
-- mistake flashcards still need the profile a case was planned from, so it's kept with that case
-- only. Older cases have none and fall back to private.condition_profiles.

alter table private.case_content add column profile jsonb;
