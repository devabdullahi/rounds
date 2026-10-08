# Rounds

AI roleplay practice app for **US medical students**: the student interviews a fictional patient, examines, orders tests, commits to a diagnosis, and gets graded. Education only, never real patients, never medical advice.

| Folder | What |
|---|---|
| `Rounds - IOS/` | SwiftUI app, iOS 17+, XcodeGen (`project.yml` is the source of truth) |
| `supabase/` | Postgres schema + RLS (`migrations/`), `seed.sql`, edge functions (`functions/`) |

Current phase: **live backend, pre-launch.** The app talks to the cloud Supabase project (`mpyxaefnytviwnjuqtbu`, linked; `supabase/cloud.env` holds the DB password, git-ignored): accounts (email code, Apple, Google), cases and patient chat, grading, flashcards, profile photos. Edge functions are deployed with `supabase functions deploy <name>`, migrations with `supabase db push --linked`. Reference data (`Services/Reference/`) is still mock. Changes to cloud data, deploys and pushes affect the real project: say what you'll change first. Don't create new cloud projects or add keys unless asked.

## Commands

```bash
cd "Rounds - IOS"
xcodegen generate                       # after adding/removing files or editing project.yml
xcodebuild -project Rounds.xcodeproj -scheme Rounds \
  -destination 'platform=iOS Simulator,id=CD8A6302-939F-46CF-A8DA-5CB754FBF636' \
  -derivedDataPath build -quiet build
xcodebuild … test                        # same flags as build; runs RoundsTests (Swift Testing)
xcrun simctl launch booted com.abdul.rounds -screen <name>   # names listed in App/DebugLaunch.swift
supabase db reset                        # local DB from migrations + seed (needs Docker; optional)
supabase db push --linked -p "$SUPABASE_DB_PASSWORD"   # apply new migrations to the cloud
supabase functions deploy <name> --project-ref mpyxaefnytviwnjuqtbu
```

Never edit `Rounds.xcodeproj` by hand; change `project.yml` and regenerate.

## Workflow

1. **Design requests** ("create a design", "design flow"): build a claude.ai Design canvas artifact first. Implement in Swift only after the user picks or says build.
2. **Verify UI changes yourself**: build, launch with `-screen`, screenshot with `xcrun simctl io booted screenshot`, and look at it. Check light and dark mode when colors change. Say plainly what you could not verify (e.g. taps).
3. Build must pass with zero errors before you report done. SourceKit "cannot find X in scope" noise after adding files is not a build error; trust `xcodebuild`.
4. Keep changes scoped to the request. Ask before deleting files or rewriting a screen the user didn't mention.

## Separation of concerns

Each layer has one job. Dependencies point **down only**: View → State → Services → Backend. A lower layer never imports or knows about a higher one.

| Layer | Lives in | Owns | Must not |
|---|---|---|---|
| **View** | `Screens/`, `Components/` | Layout, styling, animation, reading state, forwarding user intent | Fetch data, call `SupabaseService`, hold business rules, format/grade/score, touch `UserDefaults` directly (use `@AppStorage` keys owned by the model type) |
| **State / domain** | `Model/` (`AppState`, `CaseSession`, `FocusSelection`) | App and screen state, business rules (matching, scoring display, case progress), plain value types | Import SwiftUI for layout, know about views, talk to the network directly |
| **Services** | `Services/` | Talking to Supabase, speech, persistence; mapping wire `Codable` DTOs ↔ domain types | Hold UI state, show alerts, decide what a screen looks like |
| **Backend** | `supabase/` | Truth and enforcement: schema, RLS, grading, patient replies, secrets | Trust the client; anything security-relevant is enforced here, never only in Swift |

Rules that follow from this:

- A screen gets data through its model, and the model gets it through a service **protocol** (`CaseRepository`, `PatientChat`…) with a live Supabase version and a mock version. Screens and previews run on the mock; swapping is one line where the model is created.
- Keep wire types (`CaseRow`, `AttemptRow`, snake_case `CodingKeys`) inside `Services/`. Domain types (`CaseData`, `Grade`) don't mirror database columns.
- Pure logic (matching, grading rules shown to the user, parsers) goes in free functions or value types with no SwiftUI, so it's testable without a simulator.
- Reusable visual pieces live in `Components/` and take plain values plus closures, never `AppState`.
- Backend split: **the DB** enforces who can read/write (RLS, grants, constraints). **Edge functions** hold privileged logic and third-party calls (LLM, grading). **The app** only displays and requests. Don't duplicate a server rule in Swift as the only check.
- When a file starts doing two of these jobs, split it before adding more.
- Outside medical data (conditions, drugs, MedlinePlus, authoring helpers) goes through the protocols in `Services/Reference/`, injected once via `@Environment(\.reference)` (`App/ReferenceEnvironment.swift`). Everything is mock today; a live client is a new type conforming to the same protocol, with caching.
- Known debt: `VoiceController` (speech is a service) sits in `Model/`, and some models import SwiftUI where `Observation` would do. Fix these when you're already editing those files; don't do it as a drive-by.

## SwiftUI architecture

- **MV first.** Views read `@Observable` models (`AppState`, `CaseSession`) via `@Environment` or `@State`. Add a per-screen view model only when a screen owns real async work or logic worth testing.
- Navigation is value-based: `NavigationStack(path:)` with `Hashable` step enums (`AuthStep`, `CaseStep`). Don't use string routes.
- One screen per file in `Screens/`; shared pieces in `Components/`; tokens in `Theme/Theme.swift`.
- Inside each layer, files sit in feature folders: `Screens/{Auth,Onboarding,Home,Case,Patients,Cards,Profile}`, `Model/{Account,Study,Case,Performance,Badges,Cards}`, `Components/{Buttons,Layout,Indicators,Icons,ECG,Onboarding,Focus,Badges,Case}`, `Services/{Auth,Cards,Cases,Reference}` (with `Errors/`, `Providers/`, `Protocols/`, `Models/`, `Mocks/` where they help), `App/Navigation`, and matching `RoundsTests/` folders. Put a new file in the folder of its feature; add a folder only when a feature has no home.
- Persist small user preferences with `@AppStorage` keys declared as `static let storageKey` on the owning type (see `StudyFocus`).

## Concurrency (Swift 6 rules, even in Swift 5 mode)

- UI-owned `@Observable` classes are `@MainActor`. Model structs sent across tasks are `Sendable`.
- Use `async/await` and `.task {}` (auto-cancels) instead of `DispatchQueue` or Combine. Check `Task.isCancelled` in loops.
- Shared mutable state off the main thread goes in an `actor`, not locks.
- Don't flip `SWIFT_VERSION` to 6 as a drive-by; that is its own task, module by module.

## Design system (follow exactly)

- **Colors:** only `Theme.*` tokens; every token is adaptive light/dark. **Never orange.** Warnings, streaks and destructive actions use red (`Theme.wrong` / `Theme.warn`). Light-mode accent is green, dark is blue.
- Text must meet 4.5:1 contrast (3:1 at 24pt+); check new color pairs with the better-colors skill.
- **Icons:** Phosphor (regular) SVGs in `Assets.xcassets/Icons/`, accessed through the `IconGlyph` enum and `AppIcon` view. Add new ones from `@phosphor-icons/core`. No SF Symbols except the Apple logo on Sign in with Apple.
- **Buttons:** `PrimaryButtonStyle` (glass over a vivid gradient, white text). Use non-interactive glass (`interactive: false` / `reactive: false`) inside swipeable cards and on filter chips, because interactive glass swells and flares white when held.
- Signed-out screens (welcome, sign up, log in, onboarding) are always light mode.
- Touch targets ≥ 44pt. Every icon-only button gets `accessibilityLabel`. Honor Reduce Motion (no loops, no springs, final state).

## Animation

Multi-step animations start with a storyboard comment block and named constants (interface-craft style):

```swift
/* ANIMATION STORYBOARD · Screen
 *    0ms   trace draws (1400ms)
 *  300ms   headline rises, y 12 → 0 */
private enum TIMING { static let headline = 0.30 }
```

Prefer springs. Drive sequences with stage state from one `.task`, and continuous motion with `TimelineView(.animation(paused:))`. Keep `repeatForever` for simple pulses like `GlowDot`, since it can't be paused or synced and stutters when state changes mid-loop.

## Supabase backend

- **RLS on every table** in `public`. Policies use `(select auth.uid())`, not bare `auth.uid()`, and every policy column is indexed.
- Answers, patient scripts and rubrics live in the `private` schema; `anon`/`authenticated` must never be granted access. Grading writes (`score`, `grade`, `rating`) happen only in edge functions with the service role.
- Restrict client writes with column grants (`grant update (col, …)`), not just policies.
- **Schema changes = a new timestamped file in `supabase/migrations/`.** Never edit an applied migration. Keep `seed.sql` fictional.
- **Edge functions** (Deno/TypeScript): verify the caller's JWT → authorize the specific row → validate input → then do the one privileged action. Test the denied paths (401/404) before the happy path.
- Secrets (`ANTHROPIC_API_KEY`, service role key) only via `supabase secrets set` and `Deno.env.get`. The app ships only the URL and anon/publishable key, from git-ignored `Config/Secrets.xcconfig`.
- The patient LLM sees only the facts it may reveal, never the diagnosis or answer key. A second check rejects replies that add facts or hint at the answer.
- iOS client: `SupabaseService.client` (nil until configured). Decode rows into `Codable` structs; let the SDK keep the session in the keychain.

## Content and legal

- Cases are original writing about fictional patients. Never copy question-bank items (UWorld, NBME, USMLE, AMBOSS), textbook wording, or "NCLEX"/"USMLE" branding. Facts are fine; wording must be ours.
- US terms and units: CBC/BMP, mg/dL, °F, ACC/AHA guidelines, acetaminophen. Tag every case with one `Clerkship` and one `OrganSystem`; students browse by these topics, never by training year.
- Never store or request real patient data.

## Testing

- New logic (grading, `FocusSelection`, parsers) gets Swift Testing tests (`@Test`, `#expect`; `#require` only for preconditions). Use parameterized tests for input tables. Tests live in `RoundsTests/` and must pass before you report done.
- For SQL/RLS, test both allowed and denied access as `authenticated` (PGlite or `supabase db reset` plus queries).

## Code hygiene

- Match the surrounding code: doc comments on types and non-obvious properties, explaining *why*. No commented-out code, no `print` left behind, no force unwraps outside previews and debug code.
- Debug-only code goes inside `#if DEBUG` (see `DebugLaunch`). Add a `-screen` name for every new screen or state you build.
- **One shared type per Swift file**, named after it (struct, class, enum, actor or protocol): anything other files use, including wire DTOs, test doubles and test suites. A `private` helper used only by that file may stay in it. Extensions of the file's type may stay. Some older files still hold several shared types; don't add to them.
- Small, focused files; extract a component once it's used twice.
- No new dependencies without asking.

## Git

- Work on a branch, open a PR with summary + testing notes (including what wasn't verified), merge when asked.
- **Never add Claude/AI attribution** (no `Co-Authored-By`, no "Generated with" lines) to commits or PRs.
- Never commit `build/`, `.env`, `Secrets.xcconfig`, `reports/`, `research_notes/`, or `.agents/`.
