-- Cases no longer have a test budget. Grading stopped penalizing spending and the app shows only a
-- running cost, so the column is unused. generate-case and the app stopped reading and writing it
-- first; apply this after deploying them.

alter table public.cases drop column budget;
