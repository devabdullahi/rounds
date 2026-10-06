-- Students can remove patients from their history.
--
-- Cases are written only by generate-case, and attempts reference cases without cascading, so a
-- client-side delete would need two statements and new policies. One function instead deletes the
-- caller's own generated cases and every attempt on them, atomically. Shared published cases
-- (created_by null) are never touched, and ratings already earned stay as they are.

create function public.delete_patients(case_ids text[] default null)
returns integer
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  removed integer;
begin
  if uid is null then
    raise exception 'not signed in' using errcode = '42501';
  end if;

  -- Generated cases are visible only to their creator, so every attempt on them is the caller's.
  delete from public.attempts a
  using public.cases c
  where a.case_id = c.id
    and c.created_by = uid
    and (case_ids is null or c.id = any (case_ids));

  -- private.case_content goes with the case (on delete cascade).
  delete from public.cases c
  where c.created_by = uid
    and (case_ids is null or c.id = any (case_ids));
  get diagnostics removed = row_count;
  return removed;
end;
$$;

comment on function public.delete_patients(text[]) is
  'Deletes the caller''s own generated patients (all of them when case_ids is null) with their attempts. Returns how many.';

revoke execute on function public.delete_patients(text[]) from public, anon;
grant execute on function public.delete_patients(text[]) to authenticated;
