-- Length limits on text students write directly through the API.
--
-- Display names and flashcards are written by the app with the student's own token (column grants
-- and RLS), so nothing upstream bounds their size. The limits sit well above what the screens and
-- generate-cards allow (deck 40, generated card sides 400) and only stop abuse. Each constraint is
-- added NOT VALID and then validated as its own step: if an existing row is over a limit, the
-- VALIDATE names the constraint it broke and the whole migration rolls back, changing nothing.

-- Names from Apple or Google sign-up are cut to fit, so an unusually long one can't block sign-up.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, name)
  values (new.id, left(coalesce(new.raw_user_meta_data ->> 'name', ''), 80));
  return new;
end;
$$;

alter table public.profiles   add constraint profiles_name_length   check (char_length(name) <= 80)    not valid;
alter table public.flashcards add constraint flashcards_deck_length check (char_length(deck) <= 40)    not valid;
alter table public.flashcards add constraint flashcards_front_length check (char_length(front) <= 2000) not valid;
alter table public.flashcards add constraint flashcards_back_length check (char_length(back) <= 2000)  not valid;

alter table public.profiles   validate constraint profiles_name_length;
alter table public.flashcards validate constraint flashcards_deck_length;
alter table public.flashcards validate constraint flashcards_front_length;
alter table public.flashcards validate constraint flashcards_back_length;
