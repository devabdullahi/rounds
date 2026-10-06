-- Generated flashcards record which condition profile they were written from, so a card can show
-- its source and a reviewer can trace it. Hand-written cards leave it null.
alter table public.flashcards add column source text;

comment on column public.flashcards.source is 'Condition profile slug a generated card was written from; null for hand-written cards.';

-- "Clear all" and deck switching filter by owner and deck.
create index flashcards_user_deck_idx on public.flashcards (user_id, deck);
