# 03 · Structure of on-demand patient generation

Scope: `supabase/functions/generate-case/`, `_shared/` (generation modules), `prepare-profile/`,
`case-session/` (as a consumer), related migrations, and the iOS call sites. Read-only review,
2026-10-19, branch `more-conditions`. Skills applied: component-boundary-reviewer,
layered-architecture-designer, monolith-vs-modular-monolith-reviewer, service-decomposition-advisor.

## Summary

- The *pure* generation pieces are already well cut: `casegen.ts` (plan), `skeleton.ts` (content),
  `writer.ts` / `template.ts` (voice), `factaudit.ts` (audit decisions), `profilegen.ts` (schema and
  rules) are I/O-free and unit-tested. That is the asset to protect.
- The problem is `generate-case/index.ts` (534 lines): it is the HTTP handler, the condition
  selector, the live-profile orchestrator, the profile store writer, the per-student job queue, the
  writer/repair loop, the audit runner, the row builder and the case store, all in one file and all
  talking to `sql` directly. Every planned change (pool, refill, no-repeat, narrower topics) lands
  in this one file.
- Two profile builders exist with different shapes (`liveprofile.ts` parallel-in-request vs
  `prepare-profile` staged job chain), and both rely on `EdgeRuntime.waitUntil`, which the planned
  design says dies in production.
- Verdict: **modular monolith inside the edge functions**, not more services. Extract modules
  within `generate-case/` and `_shared/`, then add **one** cron-driven worker function
  (`refill-pool`) that reuses the same modules. Fold the profile batch into the existing
  `prepare-profile` + `profile_jobs` + pg_cron path rather than a new service.

## 1. Component map (as built)

Evidence = file:line in `supabase/functions/` unless noted.

| Component | Responsibility | Inputs / outputs | Owns data | Depends on | Notes |
|---|---|---|---|---|---|
| `generate-case` handler (`index.ts:77-103`) | Auth, parse focus, prepare vs admit, claim-or-write, insert, queue next | JWT + `{focus, prepare}` → `{case_id}` | none | everything below | 6 jobs in 27 lines; quota commented out (`:36-37`, `:93`) |
| Condition selection (`index.ts:124-142`) | Pick a condition in focus, avoid last 15, prefer stored profile | userId, focus → `Condition` | reads `private.conditions`, `condition_profiles`, `cases`, `case_content` | `sql` | Recency = last 15 of *this student's* cases, not "topic exhausted" |
| Live profile orchestration (`index.ts:147-161`) | Build profile in request, retry another condition | slug, triage → `Profile` | — | `liveprofile.ts`, `llm.ts`, `terms.ts`, `profilegen.SYSTEM_PROMPT` | **Two jobs:** selection loop and profile building interleaved in one function |
| Profile store write (`index.ts:169-177`) | Save live profile as `passed/pending` | `Condition`, `Profile` | writes `private.condition_profiles` | `sql` | Swallows errors, but `case_content.condition_slug` FKs `condition_profiles(slug)` (`migrations/20261005000000_live_cases.sql:47`), so a failed save surfaces later as a 500 in `insertCase` |
| Per-student write-ahead queue (`index.ts:180-285`) | `ready_cases` claim, `case_generation_jobs` slot/token, `writeAhead`, `queueGeneration` | userId, focus → `CaseRows` | `private.ready_cases`, `private.case_generation_jobs` | `EdgeRuntime.waitUntil` (`:71`, `:255`) | Background work the planned design says dies in prod; `polling`/`failed` branch (`:200`) is dead since `queueGeneration` always passes `false` |
| Case composer (`index.ts:288-342`) | Plan → background → skeleton → name → write loop → leak fix → audit → template fallback | `Picked`, focus, deadline → `CaseRows` | — | `casegen`, `skeleton`, `writer`, `template`, `names`, `background`, `llm`, `prompts` | **Two jobs:** domain decisions (psychology/derm/cardiac flags `:292-296`) mixed with retry/timeout policy |
| Audit + repairs (`index.ts:347-422`) | Plan items, LLM fact audit, UMLS confirm, fact fixer, leak fixer | `Writing` → `Writing` | — | `factaudit`, `terms.conceptOf`, `llm`, `prompts` | Belongs with the verifier, not the handler |
| Background lookup (`index.ts:426-437`) | Query Synthea rows, pick one | plan → `PatientBackground?` | reads `private.patient_backgrounds` | `background.ts` | Fine; I/O half of `background.ts` |
| Row builder (`index.ts:442-508`) | Filing (clerkship/system), door vitals, public vs private split, rubric | plan + writing → `CaseRows` | — | `labs`, `writer.buildRubric`, `llm.currentModel` | Pure but lives in the I/O file, so untested; `currentModel` couples rows to LLM config |
| Case store (`index.ts:511-534`) | Insert `public.cases` + `private.case_content` under a bed code | userId, `CaseRows` → id | `public.cases`, `private.case_content` | `bedcode.ts`, `sql` | Owner is set here; an unowned pool case needs this split |
| `_shared/liveprofile.ts` (308) | Fetch MedlinePlus/UMLS/RxClass facts, fill template in parallel, rewrite, validate | slug, triage → `{profile, problems}` | none (header `:1-3` says "nothing stored", contradicted by `index.ts:169`) | `profilegen`, `levels`, `families`, injected `complete`/`termErrors` | Good: I/O injected. Network fetches (`:32-90`) and pipeline in one file |
| `prepare-profile/index.ts` (204) | Staged, resumable profile job (2 calls per stage) | service role + `{slug}` → 202 | `private.profile_jobs`, writes `condition_profiles` | `profilegen`, `terms`, `llm`, `prefetch.kick` | Self-chains via `waitUntil` + HTTP (`:56`, `kick`); hand-rolled key compare (`:49-51`) instead of `internal.requireServiceRole` |
| `_shared/prefetch.ts` (87) | Queue next profile per focus, `kick` | focus → slug | `profile_jobs` | `sql`, `fetch` | `queueNext`/`prepareNext` have **no callers** (only `kick` is used, by prepare-profile); prepare-profile header (`:3`) is stale |
| pg_cron `advance_profile_batch` (`migrations/20261018000100_core_profile_batch.sql:287-344`) | Start ≤3 batch jobs every 2 min under a $10/day cap | `profile_jobs where requested_by='core-batch'` | — | Vault secrets, `pg_net` | The only scheduler-driven generation today; pattern to reuse |
| `_shared/llm.ts`, `usage.ts`, `quota.ts`, `db.ts` | Model calls with per-task model, cost recording, global daily cap, per-user quota, pooled connection | — | `llm_usage`, `usage` | — | Cross-cutting infrastructure; sound. `db.ts` max 1 connection per instance |
| `_shared/terms.ts` | SNOMED/RxNorm checks with DB cache, UMLS concept lookups | terms → checks | `private.term_checks` | `profilegen`, `sql`, UMLS | Mixes cache store and HTTP client; acceptable |
| `case-session/index.ts` (596) | Patient chat, voice, exam, orders, grading, insights | attempt → replies/grade | `attempts`, reads `case_content` | `prompts`, `grade`, `insights` | Consumer only: reads `case_content.profile` with fallback to `condition_profiles` (`:549-551`). Must keep working unchanged for pooled cases |
| iOS `AppState.admit` / `prepareAhead` (`Rounds/Model/AppState.swift:197-251`) | Admit with `.preparing` polling loop up to 8 min; fire `prepare` for ≤4 topics | focus → bed | — | `CaseService.admit/prepare` | Server never returns `preparing` any more; polling loop is dead weight but harmless |
| iOS `LiveCaseService` (`Services/Cases/LiveCaseService.swift:61-70`) | `generate-case` invoke | DTOs | — | Supabase SDK | Boundary is clean: the app knows nothing about pools or profiles |

### Boundary findings (priority)

1. **High: `index.ts` is the integration point for every future change.** Pool claim, refill,
   no-repeat, topic narrowing and profile sourcing all need to edit the same 534 lines. Split before
   adding the pool.
2. **High: background work rides on `waitUntil`.** `queueGeneration` (`index.ts:254`) and
   `prepare-profile` (`:56`) both do the long part after the response. The pool design replaces the
   first; the second needs the same cron-driven treatment for the 480-profile batch.
3. **Medium: profile building has two pipelines and two owners of `condition_profiles` writes**
   (`index.ts:174`, `prepare-profile` `finish`). Validation status means slightly different things in
   each (`liveprofile` marks `generation.live`). Pick one builder for stored profiles.
4. **Medium: hidden FK coupling.** Case store depends on the profile store having succeeded, yet the
   profile save is fire-and-forget (`index.ts:176`). Make the save a precondition or drop the FK
   in favour of `case_content.profile` (which already holds the profile).
5. **Medium: selection rules are SQL inside a loop** (`index.ts:133-142`), so "no repeat until
   exhausted" and "no identical fingerprint" have no testable home.
6. **Low: dead code.** `prefetch.queueNext/prepareNext`, the `polling`/`failed` path, the iOS
   `.preparing` loop, commented quota calls. Remove when the pool lands, not before.

## 2. Proposed layering for the backend side of generation

Same rule as CLAUDE.md, applied inside the backend: dependencies point **down only**.

```
 Entry points      generate-case (HTTP, student)   refill-pool (cron)   prepare-profile (cron/internal)
                         │                               │                     │
 Use cases         admit · prepare           refillTopic          buildStoredProfile
                         │                               │                     │
 Domain (pure)     selection rules · patient planner · writer/voice · verifier rules · row builder · fingerprint
                         │                               │                     │
 Stores / adapters case store · pool store · profile store · catalog store · LLM · terms/UMLS · medical APIs
```

| Module (proposed file) | Layer | Owns | Must not |
|---|---|---|---|
| `generate-case/index.ts` | Entry | Auth (`callerId`), input parsing, HTTP status mapping | Contain SQL, pick conditions, call the LLM |
| `refill-pool/index.ts` (new) | Entry | `requireServiceRole`, batch size, time budget per invocation | Hold business rules; serve students |
| `prepare-profile/index.ts` | Entry | `requireServiceRole`, one step of a profile job | Self-chain via `waitUntil` once cron drives it |
| `generation/admit.ts` | Use case | Claim from pool → else write now → insert owned case; record exposure | Know prompt text or SQL shape |
| `generation/refill.ts` | Use case | For one topic: pick condition, compose case, verify, store unowned | Assign an owner; wait on a student |
| `generation/compose.ts` | Use case | Plan → skeleton → voice → verify → repair → template fallback, with deadlines | Read/write tables except through stores |
| `selection.ts` (pure) | Domain | No-repeat ordering: exclude conditions the student saw in this topic until exhausted; prefer stored profiles; topic membership | Do I/O; know about pools or HTTP |
| `casegen.ts`, `skeleton.ts`, `names.ts`, `background.ts` pick | Domain (planner) | Severity, demographics, findings, values; **patient fingerprint** (slug + severity + sex + age band + key findings hash) | Call the LLM; read the DB |
| `writer.ts`, `template.ts`, `prompts.ts` | Domain (voice) | Prompts in, `Writing` out | Choose medicine; decide retries |
| `verify.ts` (from `index.ts:347-422` + `writer.checkWriting` + `factaudit.ts`) | Domain + adapter seam | Structure, leak, invented-fact checks; fix requests | Silently pass a case that failed structure/leak checks |
| `rows.ts` (from `index.ts:442-508`) | Domain | Public/private split, filing, door vitals, rubric | Set `created_by` or bed code |
| `stores/cases.ts` | Store | Insert owned case; bed codes; transaction | Decide what a case contains |
| `stores/pool.ts` | Store | `claim(topic, userId, excludeSlugs, excludeFingerprints)` with `for update skip locked`; `put(topic, rows, fingerprint)`; depth per topic | Generate content |
| `stores/profiles.ts` | Store | Read validated profile; single writer for `condition_profiles` | Run model calls |
| `stores/catalog.ts` | Store | Conditions per topic (after narrowing), exposure history per student | Ordering policy (that is `selection.ts`) |
| `llm.ts`, `usage.ts`, `quota.ts`, `terms.ts`, `db.ts` | Infrastructure | As today | Import any generation module |

**Rules**

- Allowed direction: entry → use case → domain; use case → stores/adapters. Domain never imports
  `db.ts`, `llm.ts` or `fetch`; I/O is injected as functions (the `liveprofile.buildLiveProfile`
  `deps` pattern already does this, copy it).
- Forbidden shortcuts: entry points running `sql` directly; domain modules reading `Deno.env`;
  `rows.ts` calling `currentModel` (pass the model name in); any module other than
  `stores/profiles.ts` writing `condition_profiles`; any client-facing path reading `pool`.
- Security stays in the DB: pool table in `private`, service role only, same as `ready_cases`; a
  claimed pool row becomes an owned `public.cases` row in one transaction, so RLS on `cases`
  (`created_by`) is unchanged and `case-session` needs no edits.
- Cross-cutting: deadlines (`timeoutFor`) passed as a `Budget` value into use cases; logging via one
  `logEvent` helper so the `case_generated` timing line is identical from admit and refill;
  cost cap enforced in `llm.ts` (`takeBudget`) for both paths, plus a lower refill cap like
  `advance_profile_batch(…, daily_cap_usd)` so students keep headroom.

## 3. Monolith vs modular monolith (edge functions)

Facts: one developer; Supabase edge functions (150 s wall clock, `waitUntil` unreliable for long
work per the planned design); shared Postgres; ~7.7k lines of TS across functions; generation and
chat change together often (prompt versions, profile shape read by `case-session`).

| Option | Gains | Costs |
|---|---|---|
| A. Keep `index.ts` as is, add pool code | Fastest first diff | Every change touches a 600+ line file; pool and write-now drift; untestable selection |
| **B. Modular monolith: modules within `generate-case/` + `_shared/generation/`, plus one cron worker entry point** | Same code for admit, write-now and refill; pure modules testable; one deploy unit per entry point; no new infra | Needs discipline on import direction (no tooling enforces it; use a test that greps imports) |
| C. Split into planner / writer / verifier functions calling each other over HTTP | Independent deploys | Each hop adds cold start + auth + JSON of the full profile; 150 s budget per hop but compose already fits one call; partial-failure handling across hops; more secrets plumbing. No team or scaling pressure justifies it |
| D. External worker (queue + container) | No time limit | New platform, new keys, new bill; against "don't add infra unless asked" |

**Verdict: B.** `generate-case` stays one function with modules; the pool refill is a *second entry
point* (`refill-pool`) over the same modules, not a separate service with its own logic. Edge-function
boundaries should follow **trigger and auth** (student JWT vs service-role cron), not pipeline stages.

## 4. Service decomposition: pool/refill worker and profile batch builder

### Pool / refill worker

- **Cohesion:** high. "Keep each topic at depth N with verified, unowned cases" is one job; it uses
  compose + verify + pool store, nothing student-specific except the global no-fingerprint rule.
- **Coupling:** shares *code* with `generate-case` (compose, selection, rows), shares *data* via
  `private.case_pool` (new) and `condition_profiles`. Keep the coupling at the module level, never
  HTTP between the two functions.
- **Data ownership:** `refill-pool` is the only writer of pool rows; `generate-case` is the only
  claimer (delete … returning, `skip locked`). Fingerprints live on the pool row and on
  `case_content` (new column, unique index) so "never identical" is a DB constraint, not a hope.
  Per-student exposure ("no condition repeats until the topic is exhausted") is read from
  `cases`+`case_content` (`created_by`, `condition_slug`, `focus`), needing an index on
  `case_content (condition_slug)` joined from `cases_created_by_idx`; no new table required at first.
- **Trigger:** pg_cron → `pg_net.http_post` → `refill-pool`, the same Vault pattern as
  `advance_profile_batch` and `sweep_voice_calls`. Each invocation does a bounded batch (e.g.
  1–3 cases, stop at ~100 s) and returns; **no `waitUntil`**. Overlapping runs are safe because each
  picks a topic with `for update skip locked` on a per-topic row (or an advisory lock).
- **Operational cost on Supabase:** cron every 1–2 min ≈ 720–1,440 invocations/day (well inside
  edge quotas); LLM spend dominates — cap refill with its own daily USD limit below `usage.ts`'s
  global cap; DB pooler connections: one per instance, so cap concurrent refill invocations (≤3).
  Pool rows hold full profiles (~tens of KB); depth × topics (e.g. 3 × ~120) is small.
- **Anti-split warning:** do not make a separate "writer" or "verifier" function; do not keep the
  per-student `ready_cases` write-ahead alongside the pool long-term (two queues, two freshness
  rules). Keep `ready_cases` only until the pool is proven, then drop it and `case_generation_jobs`
  in a migration.

### Profile batch builder (~480 profiles)

- **Recommendation:** not a new service. Reuse `prepare-profile` + `private.profile_jobs` +
  `advance_profile_batch` (already: queue by `requested_by`, ≤N running, daily USD cap). Insert the
  480 slugs as a new batch label in a migration.
- **Change needed:** `prepare-profile` currently self-chains through `waitUntil` + `kick`. Make each
  cron tick drive steps: the scheduler calls `prepare-profile` per runnable job, the function runs
  one step *inside the request* (fits: stage write ≤140 s, term checks 45 s budget), saves, returns.
  The stale-lock logic (`locked_at` token) already makes this safe to retry.
- **One builder for stored profiles:** stored profiles come only from `prepare-profile` (staged,
  resumable, full validation). `liveprofile.ts` stays as the emergency in-request fallback for a
  topic with zero stored profiles and should **not** write `condition_profiles` (or writes through
  `stores/profiles.ts` with the same validation the batch uses). Once the batch completes, the live
  path should almost never run.
- **Cost/ops:** 480 × 5 stages × 2 calls ≈ 4,800 invocations, spread over days by the cap; the
  batch is one-off, so a migration-seeded queue plus the existing cron is cheaper than any new
  component. Clinician review state (`review = 'pending'`) is unchanged.
- **Ordering dependency:** topic narrowing (d) must land before the batch and before pool depth is
  set, because both key on topic membership (`clerkships`, `organ_systems`).

## 5. Refactor sequence (each step shippable, behaviour-preserving until step 6)

1. **Extract pure modules from `index.ts`, no behaviour change.** Move `buildRows`, `doorVitals`,
   `caseClerkship`, `caseSystem` → `generate-case/rows.ts`; `planItems` → `verify.ts`; pass the model
   name in. Add Deno tests for rows (filing rules, vitals flags). Deploy `generate-case`.
2. **Extract `compose.ts` and `verify.ts`.** `composeCase`, `auditCase`, `fixUnsupported`,
   `fixLeaks`, `timeoutFor` move out; LLM and background lookup injected as `deps`. Test the
   template-fallback and leak-fix paths with fake `complete`. Deploy.
3. **Extract stores.** `stores/cases.ts` (`insertCase`, with `ownerId` optional for later),
   `stores/profiles.ts` (`saveProfile`, made awaited and failing loudly so the FK can't surprise),
   `stores/catalog.ts` (condition query, recent history). `index.ts` becomes ~80 lines. Deploy.
4. **Add `selection.ts` with the no-repeat rule, behind the existing query.** Pure function over
   `(candidates, seenInTopic, hasStoredProfile)`; migration adds index for exposure lookup.
   Ship it for write-now first; this alone delivers (c) part one. Add a `fingerprint` column on
   `case_content` + unique index (nullable for old rows); compute it in the planner; retry plan on
   conflict. Delivers (c) part two.
5. **Narrow umbrella topics (d)** as a catalog migration plus `tools/kb-generate` re-tag; verify
   topic counts (`topic_counts` migration) before and after.
6. **Profile batch (b):** migration queues the ~480 slugs under a batch label; change
   `prepare-profile` to step-per-request driven by `advance_profile_batch` (no `waitUntil`/`kick`);
   switch to `internal.requireServiceRole`. Remove dead `prefetch.queueNext/prepareNext`.
7. **Pool (a):** migration for `private.case_pool` (service role only, topic, rows, fingerprint,
   created_at, index on topic) and a cron job; new `refill-pool` entry point over `compose` +
   `selection` + `stores/pool.ts`; `admit` claims pool → else write-now. Keep `ready_cases` as a
   second fallback for one release; log claim-hit rate.
8. **Retire per-student write-ahead:** stop `queueGeneration`/`prepare`, return 202 no-op for old app
   builds, drop `ready_cases` and `case_generation_jobs` in a later migration; remove the iOS
   `.preparing` polling loop and `prepareAhead` (app release), and the commented quota lines
   (decide: restore `takeQuota` around claim or delete).

## Evidence vs assumptions

- **Evidence:** line references above; FK `case_content.condition_slug → condition_profiles(slug)`;
  no callers of `prefetch.queueNext/prepareNext`; `requested_by='core-batch'` cron pattern exists.
- **Assumptions:** `waitUntil` dying for long jobs is taken from the planned design, not verified
  here. Pool depth, refill cadence and cost figures are estimates. That `ready_cases` can be dropped
  depends on pool hit rate in practice.
- **Unknowns:** how often the live-profile fallback still runs after the batch; whether
  `case-session` or flashcards rely on `condition_profiles` rows for live-built cases beyond the
  `coalesce` at `case-session/index.ts:550`.

## Risks or tradeoffs

- Modules without enforcement drift back into `index.ts`; add an import-direction test.
- A shared pool means two students may get the same condition quickly; fingerprint uniqueness
  avoids identical patients but not same-condition overlap across students (acceptable).
- Pool cases are written before a profile might be rejected; keep the 3-day freshness rule
  (`READY_FOR`) on pool rows and purge on profile rejection.

## Recommended next skill

`runtime-view-writer` for the claim/refill/fallback sequence and its failure paths, then
`adr-writer` to record "modular monolith + cron worker; one stored-profile builder".
