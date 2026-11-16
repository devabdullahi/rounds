-- Denied-path test for private.scan_assets and the private `scans` bucket.
-- Run against a reset local database: psql "$LOCAL_DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/scan_assets_rls.sql
-- Fails (non-zero exit) if the app roles can read the table or the bucket's objects.

insert into storage.objects (bucket_id, name) values ('scans', 'rls-test.jpg');

do $$ begin
  if not exists (select 1 from storage.buckets where id = 'scans' and not public) then
    raise exception 'scans bucket missing or public';
  end if;
end $$;

-- anon and authenticated: the table must be unreadable.
set role anon;
do $$ begin
  perform 1 from private.scan_assets;
  raise exception 'anon read private.scan_assets';
exception when insufficient_privilege then null;
end $$;
reset role;

set role authenticated;
do $$ begin
  perform 1 from private.scan_assets;
  raise exception 'authenticated read private.scan_assets';
exception when insufficient_privilege then null;
end $$;

-- ...and the bucket's objects must be invisible (no Storage policies).
do $$ begin
  if exists (select 1 from storage.objects where bucket_id = 'scans') then
    raise exception 'authenticated can see scans objects';
  end if;
end $$;
reset role;

set role anon;
do $$ begin
  if exists (select 1 from storage.objects where bucket_id = 'scans') then
    raise exception 'anon can see scans objects';
  end if;
end $$;
reset role;

-- Edge functions read the table over SUPABASE_DB_URL (the postgres role), not as service_role,
-- which has no usage on schema private.
do $$ begin
  perform 1 from private.scan_assets;
end $$;

delete from storage.objects where bucket_id = 'scans' and name = 'rls-test.jpg';
select 'scan_assets_rls: PASS' as result;
