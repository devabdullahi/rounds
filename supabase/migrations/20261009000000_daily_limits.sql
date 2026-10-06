-- Daily limits on the actions that cost a model call.
--
-- Every new case, patient question and flashcard deck calls the LLM, so each student gets a daily
-- allowance per kind. Counting happens here, atomically: two requests at once can't both slip past
-- the cap. Edge functions take one unit before the model call and give it back if the call fails.
-- Days are UTC. Service role only: students never read or write their counters.

create table private.usage (
  user_id uuid not null references public.profiles (id) on delete cascade,
  day     date not null,
  kind    text not null check (kind in ('case', 'question', 'cards')),
  used    integer not null default 0 check (used >= 0),
  primary key (user_id, day, kind)
);

comment on table private.usage is 'Per-student daily counts of model-backed actions, for the limits in edge functions.';

-- Takes one unit of today's allowance. True when it was available (and is now used), false at the cap.
create function private.take_quota(uid uuid, what text, cap integer)
returns boolean
language plpgsql
volatile
set search_path = ''
as $$
declare
  taken integer;
begin
  insert into private.usage as u (user_id, day, kind, used)
  values (uid, (now() at time zone 'utc')::date, what, 1)
  on conflict (user_id, day, kind) do update set used = u.used + 1
    where u.used < cap
  returning u.used into taken;
  return taken is not null and taken <= cap;
end;
$$;

-- Gives back a unit taken for an action that then failed.
create function private.refund_quota(uid uuid, what text)
returns void
language sql
volatile
set search_path = ''
as $$
  update private.usage set used = used - 1
  where user_id = uid and day = (now() at time zone 'utc')::date and kind = what and used > 0;
$$;

revoke all on function private.take_quota(uuid, text, integer) from public, anon, authenticated;
revoke all on function private.refund_quota(uuid, text) from public, anon, authenticated;
