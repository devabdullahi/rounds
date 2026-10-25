-- Per-minute burst limits replace the daily allowances (2026-10-25: every student is a paying
-- customer, with no daily limits). A student's actions are counted per UTC minute, far above what
-- anyone does by hand, so only a script or a stuck retry loop ever reaches the cap. Atomic, like
-- take_quota: two requests at once can't both slip past. Service role only.

create table private.burst (
  user_id uuid not null references public.profiles (id) on delete cascade,
  minute  timestamptz not null,
  kind    text not null check (kind in ('case', 'question', 'cards', 'grade')),
  used    integer not null default 0 check (used >= 0),
  primary key (user_id, minute, kind)
);

comment on table private.burst is 'Per-student counts of model-backed actions in the current minute, for the burst guard in edge functions.';

-- Takes one unit of this minute's allowance. True when it was available, false at the cap. Clears
-- the student's earlier minutes as it goes, so the table only ever holds the current one.
create function private.take_burst(uid uuid, what text, cap integer)
returns boolean
language plpgsql
volatile
set search_path = ''
as $$
declare
  now_minute timestamptz := date_trunc('minute', now());
  taken integer;
begin
  delete from private.burst where user_id = uid and minute < now_minute;
  insert into private.burst as b (user_id, minute, kind, used)
  values (uid, now_minute, what, 1)
  on conflict (user_id, minute, kind) do update set used = b.used + 1
    where b.used < cap
  returning b.used into taken;
  return taken is not null and taken <= cap;
end;
$$;

-- Gives back a unit taken for an action that then failed (a no-op once the minute has passed).
create function private.refund_burst(uid uuid, what text)
returns void
language sql
volatile
set search_path = ''
as $$
  update private.burst set used = used - 1
  where user_id = uid and minute = date_trunc('minute', now()) and kind = what and used > 0;
$$;

revoke all on private.burst from public, anon, authenticated;
revoke all on function private.take_burst(uuid, text, integer) from public, anon, authenticated;
revoke all on function private.refund_burst(uuid, text) from public, anon, authenticated;
