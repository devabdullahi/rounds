-- Live voice: the student talks with the patient over OpenAI's Realtime API (WebRTC).
--
-- case-session's voice_session hands the app's SDP offer to OpenAI with the patient's session config
-- (the API key never reaches the device) and records the call here. Each call is one 'realtime'
-- unit of the daily allowance and lasts at most a few minutes: the app ends it at the deadline,
-- and the server hangs up any call of this student's that's past it (on their next voice request)
-- or still open when they start another. Rows are service-role only.

alter table private.usage drop constraint usage_kind_check;
alter table private.usage add constraint usage_kind_check check (kind in ('case', 'question', 'cards', 'grade', 'voice', 'realtime'));

create table private.voice_calls (
  -- OpenAI's call id, from the Location header of POST /v1/realtime/calls.
  call_id    text primary key,
  user_id    uuid not null references auth.users (id) on delete cascade,
  attempt_id uuid not null references public.attempts (id) on delete cascade,
  started_at timestamptz not null default now(),
  ends_at    timestamptz not null,
  ended_at   timestamptz
);

create index voice_calls_user_open on private.voice_calls (user_id) where ended_at is null;
create index voice_calls_attempt on private.voice_calls (attempt_id);

alter table private.voice_calls enable row level security;
revoke all on private.voice_calls from public, anon, authenticated;
