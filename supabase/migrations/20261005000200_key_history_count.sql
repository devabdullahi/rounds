-- How many key history topics a case has, so the interview's coverage meter can show its total
-- before the first question. A count only; which topics they are stays private.
alter table public.cases add column key_history integer not null default 0;
