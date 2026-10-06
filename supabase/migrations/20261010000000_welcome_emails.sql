-- One welcome email per student.
--
-- The app asks send-welcome to email a new student once they finish onboarding. The function
-- claims this row first (insert ... on conflict do nothing), so a repeated or replayed request
-- never sends a second email. Service role only: students never read or write it.

create table private.welcome_emails (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  sent_at timestamptz not null default now()
);

comment on table private.welcome_emails is 'Who has been sent the welcome email (send-welcome edge function).';

revoke all on private.welcome_emails from public, anon, authenticated;
