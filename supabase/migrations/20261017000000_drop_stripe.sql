-- Rounds sells only through the App Store now (Superwall's paywall, StoreKit purchases), so the
-- Stripe web checkout goes: its customer table, its subscription id column, and the rows it wrote.
-- The subscriptions table stays for App Store Server Notifications; rows remain service-role only.

drop table if exists private.stripe_customers;

delete from public.subscriptions where source = 'stripe';

alter table public.subscriptions drop column if exists stripe_subscription_id;

alter table public.subscriptions drop constraint if exists subscriptions_source_check;
alter table public.subscriptions add constraint subscriptions_source_check check (source = 'apple');
