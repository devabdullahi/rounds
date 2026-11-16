# Security policy

Palpo is a practice app for medical students. It uses fictional patients only and never stores real patient data, but it does hold student accounts, subscriptions and study history, so security reports are welcome.

## Reporting a vulnerability

Please report privately through GitHub: **Security → Report a vulnerability** on this repository ([direct link](https://github.com/devabdullahi/rounds/security/advisories/new)).

Don't open a public issue or pull request for a security problem.

A useful report includes:

- what is affected (iOS app, backend API or edge function, database access rules, website)
- steps to reproduce, or a proof of concept
- what an attacker could do with it

## What to expect

- Acknowledgement within 3 business days.
- An initial assessment within 10 business days.
- Updates as the fix progresses, and credit in the advisory once it's fixed, if you'd like it.

## Scope

In scope:

- The Palpo iOS app (the latest App Store version)
- The backend in `supabase/`: edge functions, database schema and row-level security
- The website at tryroundsapp.com

Out of scope:

- Third-party services we depend on (Supabase, Apple, Google, OpenAI, Superwall, Cloudflare); report those to the vendor
- Findings that need a jailbroken device or physical access to an unlocked phone
- Denial of service, spam, and automated scanner output without a demonstrated impact
- Missing best-practice headers or settings with no exploitable impact

## Testing rules

- Use only accounts you own. Don't access, change or delete other people's data.
- Don't run load tests or anything that degrades the service for others.
- Don't use social engineering against users or the team.
- Stop and report as soon as you've confirmed an issue.

Good-faith research that follows these rules won't lead to any action against you.

## Supported versions

Only the latest App Store release and the current backend are supported. Fixes ship there; older app versions aren't patched.
