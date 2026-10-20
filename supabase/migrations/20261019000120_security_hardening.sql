-- Hardening from the security audit.

-- Purchase claims ask Apple each time, so they count against a daily allowance like model calls.
alter table private.usage drop constraint usage_kind_check;
alter table private.usage add constraint usage_kind_check check (kind in ('case', 'question', 'cards', 'grade', 'voice', 'claim'));

-- Flashcard topic and source had no size limit, so one account could fill storage with a few huge
-- rows. Generated topics are cut to 40 characters and sources are profile slugs.
alter table public.flashcards add constraint flashcards_topic_length  check (char_length(topic) <= 80)   not valid;
alter table public.flashcards add constraint flashcards_source_length check (char_length(source) <= 120) not valid;
alter table public.flashcards validate constraint flashcards_topic_length;
alter table public.flashcards validate constraint flashcards_source_length;

-- Students edit a card's text and look, never its owner, source or creation time.
revoke update on public.flashcards from authenticated;
grant update (deck, topic, front, back, color) on public.flashcards to authenticated;

-- A cap on cards per student, far above real use, so a scripted account can't add rows without end.
create function private.cap_flashcards()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.user_id is not null
     and (select count(*) from public.flashcards where user_id = new.user_id) >= 5000 then
    raise exception 'card limit reached' using errcode = '54000';
  end if;
  return new;
end;
$$;

revoke execute on function private.cap_flashcards() from public, anon, authenticated;

create trigger flashcards_cap
  before insert on public.flashcards
  for each row execute function private.cap_flashcards();

-- A review must be of a card the student can see: a built-in card or one of their own.
drop policy "reviews: add own" on public.flashcard_reviews;
create policy "reviews: add own" on public.flashcard_reviews for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.flashcards f
      where f.id = card_id and (f.user_id is null or f.user_id = (select auth.uid()))
    )
  );
