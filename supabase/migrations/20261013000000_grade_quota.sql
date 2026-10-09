-- Grading counts against a daily allowance too.
--
-- Every case-session submit makes a grading model call, and a student could otherwise restart a
-- case and resubmit without limit. The edge function takes a 'grade' unit before grading and gives
-- it back if grading fails, like the other kinds (_shared/quota.ts).

alter table private.usage drop constraint usage_kind_check;
alter table private.usage add constraint usage_kind_check check (kind in ('case', 'question', 'cards', 'grade'));
