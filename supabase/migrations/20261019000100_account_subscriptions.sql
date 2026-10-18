-- Subscriptions belong to the Rounds account that bought them, not to the iPhone.
--
-- StoreKit answers "does this Apple ID have a plan?", so every Rounds account signed in on a paying
-- phone got in for free. The subscription edge function now asks Apple about each purchase (App Store
-- Server API) and records which account owns it: the first account to claim an original transaction
-- keeps it, and any other account is refused. Access follows the account to any device.
--
-- Rows are written only by the edge function with the service role; students may read their own.
--
-- Replaces the Stripe-era table (20261016000000, one row per student, never written for the App
-- Store and empty when this ran): ownership is now per Apple subscription, keyed by its original
-- transaction id.

drop table public.subscriptions;

create table public.subscriptions (
  -- Apple's id for the whole subscription, the same across renewals.
  original_transaction_id text primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  product_id text not null,
  expires_at timestamptz not null,
  -- 'Production' or 'Sandbox' (TestFlight), as Apple reports it.
  environment text not null,
  -- Refunded or revoked by Apple: never entitles again.
  revoked boolean not null default false,
  updated_at timestamptz not null default now()
);

create index subscriptions_user_idx on public.subscriptions (user_id);

alter table public.subscriptions enable row level security;

create policy "subscriptions: read own" on public.subscriptions
  for select to authenticated using ((select auth.uid()) = user_id);

revoke all on public.subscriptions from anon, authenticated;
grant select on public.subscriptions to authenticated;
