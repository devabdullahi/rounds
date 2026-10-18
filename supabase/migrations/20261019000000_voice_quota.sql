-- Voice mode counts against a daily allowance.
--
-- case-session's speak (the patient's reply as OpenAI speech) and transcribe (the student's
-- recorded turn as text) each call a paid audio model. The edge function takes a 'voice' unit
-- before each and gives it back if the call fails, like the other kinds (_shared/quota.ts).

alter table private.usage drop constraint usage_kind_check;
alter table private.usage add constraint usage_kind_check check (kind in ('case', 'question', 'cards', 'grade', 'voice'));
