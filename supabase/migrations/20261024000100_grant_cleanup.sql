-- Security test follow-ups (2026-10-24).
--
-- 1. onboarding_steps: anon may insert (onboarding runs before there's an account), and the install
--    id is the app's own, so nothing stopped a script with the public key from filling the table.
--    A trigger now caps rows per install and across the project per minute. The app ignores a
--    refused step (it's analytics), so a real student never notices.
-- 2. Supabase's default grants gave anon every privilege on the original tables and authenticated
--    insert/delete on tables only the server writes. RLS kept them closed; this removes them, so a
--    future permissive policy can't open them by accident.
-- 3. Flashcard inserts were table-wide, so a client could set `source` or `created_at` on its own
--    cards. Inserts are now limited to the columns the app sends.

-- 1. onboarding_steps caps

-- Generous for real use: an onboarding run logs about 20 pages, and 1200 steps a minute is about
-- 60 students starting at once.
create function private.cap_onboarding_steps() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if (select count(*) from public.onboarding_steps where install_id = new.install_id) >= 40 then
    raise exception 'too many steps for this install' using errcode = '54000';
  end if;
  if (select count(*) from public.onboarding_steps where reached_at > now() - interval '1 minute') >= 1200 then
    raise exception 'too many onboarding steps right now' using errcode = '54000';
  end if;
  return new;
end $$;

revoke all on function private.cap_onboarding_steps() from public, anon, authenticated;

create index onboarding_steps_reached_idx on public.onboarding_steps (reached_at);

create trigger onboarding_steps_cap before insert on public.onboarding_steps
  for each row execute function private.cap_onboarding_steps();

-- 2. Leftover default grants

revoke all on public.profiles, public.cases, public.attempts, public.flashcards, public.flashcard_reviews from anon;
revoke insert, delete, truncate, references, trigger on public.profiles, public.cases, public.attempts from authenticated;

-- 3. Flashcard inserts: only what the app writes (LiveCardService's NewCardRow).

revoke insert on public.flashcards from authenticated;
grant insert (user_id, deck, topic, front, back, color) on public.flashcards to authenticated;
