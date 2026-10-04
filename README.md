# Rounds

A clinical-reasoning trainer for medical students: take a simulated patient's history, examine, order tests, commit to a diagnosis and get graded feedback. For education and practice only — fictional patients, not medical advice.

| Folder | What it is |
| --- | --- |
| `Rounds - IOS/` | SwiftUI iOS app (XcodeGen project: run `xcodegen generate` then open `Rounds.xcodeproj`) |
| `supabase/` | Supabase backend: database schema + row-level security (`migrations/`), sample data (`seed.sql`), server functions for the patient and grading (`functions/`, stubs). Not connected to the app yet. |

## Backend (Supabase)

- **Run locally:** start Docker, then `supabase start` and `supabase db reset` (applies the schema and seed).
- **Connect the app later:** copy `Rounds - IOS/Config/Secrets.example.xcconfig` to `Secrets.xcconfig` (git-ignored) and fill in the project URL and anon key.
- **Answers stay server-side:** patient scripts and answer keys live in the `private` schema, which the app can't read; only server functions use them.
