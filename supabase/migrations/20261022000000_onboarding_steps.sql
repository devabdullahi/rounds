-- Which onboarding pages each install reached, so the team can see where students leave the flow.
-- One row per install and page, written by the app the first time a page shows. Most of
-- onboarding runs before there's an account, so rows are keyed by a random id the app makes on
-- first launch (never the device's own identifiers) and anon may insert. Nothing else: no name,
-- no answers (those are in onboarding_answers), and the app never reads it back; the team reads
-- it with the service role.

create table public.onboarding_steps (
  install_id uuid not null,
  -- The page's name in the app (OnboardingPage), and its position in the flow.
  page text not null check (page ~ '^[a-zA-Z]{1,30}$'),
  step smallint not null check (step between 1 and 60),
  app_version text check (char_length(app_version) <= 40),
  reached_at timestamptz not null default now(),
  primary key (install_id, page)
);

alter table public.onboarding_steps enable row level security;

-- No user to check against (the install id is the app's own), so the policy allows any insert the
-- column checks pass; the primary key keeps one row per install and page.
create policy "onboarding_steps: insert" on public.onboarding_steps
  for insert to anon, authenticated with check (true);

revoke all on public.onboarding_steps from public, anon, authenticated;
grant insert (install_id, page, step, app_version) on public.onboarding_steps to anon, authenticated;
