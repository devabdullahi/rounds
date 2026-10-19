-- Live calls end on time even when the app never reports back.
--
-- Until now an overdue call was hung up only on its own student's next voice request, so a client
-- that went quiet could keep a call open until OpenAI's own session limit while the daily cap
-- counted five minutes. A pg_cron job now calls voice-sweep each minute, which hangs up every call
-- past its deadline and settles its cost. voice_turn also counts the exchanges each call logs, so
-- one call id can't log an unbounded number of them.
--
-- voice-sweep accepts only the service role key, read with the project URL from the same Vault
-- secrets as the core profile batch (20261018000100_core_profile_batch). Until both are in Vault
-- the job does nothing.

alter table private.voice_calls add column turns integer not null default 0;

-- Overdue open calls: what the sweeper looks for each minute.
create index voice_calls_overdue on private.voice_calls (ends_at) where ended_at is null;

-- Asks voice-sweep to hang up overdue calls, only when there is one. Returns whether it asked.
create function private.sweep_voice_calls()
returns boolean
language plpgsql
volatile
set search_path = ''
as $$
declare
  url text;
  key text;
begin
  if not exists (select 1 from private.voice_calls where ended_at is null and ends_at < now()) then
    return false;
  end if;

  select decrypted_secret into url from vault.decrypted_secrets where name = 'project_url';
  select decrypted_secret into key from vault.decrypted_secrets where name = 'service_role_key';
  if url is null or key is null then
    raise notice 'sweep_voice_calls: add project_url and service_role_key to Vault';
    return false;
  end if;

  perform net.http_post(
    url := url || '/functions/v1/voice-sweep',
    headers := jsonb_build_object('Authorization', 'Bearer ' || key, 'Content-Type', 'application/json'),
    body := '{}'::jsonb
  );
  return true;
end;
$$;

revoke all on function private.sweep_voice_calls() from public, anon, authenticated;

select cron.schedule('voice-call-sweeper', '* * * * *', $cron$select private.sweep_voice_calls()$cron$);
