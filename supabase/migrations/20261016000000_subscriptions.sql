-- Paid access. Rounds has no free tier: a student uses the app while they hold an active plan,
-- bought in the app (App Store) or on the web (Stripe Checkout, US storefront only).
--
-- Rows are written only by edge functions with the service role: stripe-webhook today, App Store
-- Server Notifications later. Students can read their own row, nothing else, and can't write.

create table public.subscriptions (
  user_id uuid primary key references auth.users (id) on delete cascade,
  source text not null check (source in ('stripe', 'apple')),
  -- The provider's status: trialing, active, past_due, canceled, unpaid, incomplete…
  status text not null,
  plan text not null check (plan in ('weekly', 'monthly', 'yearly')),
  current_period_end timestamptz not null,
  cancel_at_period_end boolean not null default false,
  stripe_subscription_id text unique,
  updated_at timestamptz not null default now()
);

alter table public.subscriptions enable row level security;

create policy "subscriptions: read own" on public.subscriptions
  for select to authenticated using ((select auth.uid()) = user_id);

revoke all on public.subscriptions from anon, authenticated;
grant select on public.subscriptions to authenticated;

-- Stripe customer per student, so repeat checkouts and the billing portal use one customer.
create table private.stripe_customers (
  user_id uuid primary key references auth.users (id) on delete cascade,
  customer_id text not null unique,
  created_at timestamptz not null default now()
);

revoke all on private.stripe_customers from public, anon, authenticated;
