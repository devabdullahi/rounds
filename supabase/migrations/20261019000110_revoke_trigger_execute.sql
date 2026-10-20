-- handle_new_user runs only as the auth.users insert trigger, which doesn't need EXECUTE on the
-- caller's side. Postgres grants EXECUTE to public by default, which put the function on the REST
-- API as /rpc/handle_new_user for anon and signed-in users. Nobody should call it directly.
revoke execute on function public.handle_new_user() from public, anon, authenticated;
