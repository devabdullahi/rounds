# On-demand patient generation: quality, scalability, risk, availability

Scope: the "new patient" path, from tap (`AppState.admit`) to a saved case (`generate-case`), including
write-ahead (`private.ready_cases`), live profiles (`_shared/liveprofile.ts`), the writer and the fact
audit. Patient chat (`case-session`) appears only where it shares a limit with generation.

Evidence tags: **[M]** measured this session (2026-10-19), **[C]** read from code (file:line),
**[I]** inference or estimate, to be confirmed.

## Summary

- Tap-to-patient today is about **p50 10–12 s, p95 30–35 s** [I from M]. Write-ahead was meant to make
  it instant, but the live-profile write-ahead never finishes in production [M], and the post-start
  write-ahead picks from the whole catalog (`index.ts:101`, `waiting = false`), so about 2 in 3 of
  those jobs pick a condition with no stored profile and die [I: ~240 of 718 conditions stored].
- A live profile built inline (7 parallel DeepSeek calls, 20–25 s, +8–10 s for 1 in 3) is the main
  p95 driver, and it is avoidable: `pickProfile` ranks "not recent" above "has a stored profile"
  (`index.ts:142`), so once a student has seen a topic's stored conditions, they wait for a live one.
- One shared dollar cap (`usage.ts:36-48`) covers generation, chat, grading and voice. Case writing can
  spend it and then **chat and grading return 503 for every student**. The check-then-spend is not
  atomic, so a burst overshoots it.
- The UMLS check in the fact audit fans out with no limit (`factaudit.ts:61`): every planned item, at
  the same time, uncached, against a 20 req/s per-IP limit. That is the first external limit hit
  under load.
- Live profiles that pass the structural checks are saved and **served to every student while still
  in review "pending"** (`index.ts:138,158,175`), with unverified terms recorded only as advisory.
  DeepSeek Flash is prone to hallucination [M], so one wrong live profile reaches everyone.
- Accidental good behavior: when the budget is spent or DeepSeek is down, a stored-profile case falls
  back to `templateVoice` (no LLM, `index.ts:327-336`). That is the right last step, but nothing
  makes it deliberate, and the case it produces cannot be chatted with once the budget is gone.

## 1. Quality attribute scenarios

Priorities: H = drives architecture now, M = must hold by launch, L = monitor.

### QA-1 Tap-to-patient latency, normal load (H)
- Source/stimulus: a student taps "new patient" in a focus they have used before.
- Environment: normal load (≤ 20 concurrent generations), all providers healthy.
- Artifact: `AppState.admit` → `generate-case` → `claimReady` / `writeNow`.
- Response: open a unique case; use a ready case when one exists.
- Measure: **p50 ≤ 2 s, p95 ≤ 12 s, p99 ≤ 25 s**, nothing over 45 s (inside the 60 s client
  request timeout [I: supabase-swift default URLSession]). Ready-case hit rate ≥ 80% after the first case
  in a focus. Today: p50 ~10–12 s, p95 ~30–35 s, hit rate unknown (not logged per request).
- Measurement: the `case_generated` log line already carries `source`, `inline`, `total_ms`
  (`index.ts:218-221`). Add a `ready_hit` event in `claimReady` and a client-side tap→open timer.

### QA-2 First case in a never-seen topic (H)
- Source/stimulus: a new student picks Dermatology (15 conditions) right after onboarding.
- Environment: no ready case, `prepare` sent less than 10 s earlier.
- Artifact: `prepare` (`index.ts:85-88`) → `writeAhead`, then `admit`.
- Response: a stored-profile case, never a live build while the student waits.
- Measure: p95 ≤ 12 s. A live profile is built inline in 0% of taps when the focus has any stored
  profile (count of `source:"live", inline:true` per day = 0).

### QA-3 No repeat condition, no identical patient (H)
- Source/stimulus: a student starts case after case in one topic.
- Environment: any focus, including small ones (derm 15) and Mix.
- Artifact: `pickProfile` recent list (`index.ts:126-129`, last 15 across **all** foci), `planCase`.
- Response: no condition repeats until every case-suitable condition in the focus has been seen; once
  repeats start, the least recently seen condition comes first; no two cases share a fingerprint.
- Measure: repeats before topic exhaustion = 0 (today's 15-case window spans foci, so a student
  alternating topics repeats a derm condition after about 8 derm cases [I]). Duplicate
  `(user, condition, age, sex, name, background_id)` = 0, enforced by a unique index, not a hope.

### QA-4 Medical accuracy (H)
- Source/stimulus: a case is written from a profile and voiced by DeepSeek Flash.
- Environment: normal, and also when the audit model or UMLS is unavailable.
- Artifact: skeleton (code), `checkWriting`, fact audit (`factaudit.ts`), profile checks.
- Response: every medical claim traces to the plan; a case built from an unreviewed profile is labeled.
- Measure: in a weekly sample of 50 cases reviewed by a clinician: 0 wrong diagnosis-defining facts,
  ≤ 2% facts flagged as unsupported. Audit coverage ≥ 99% of LLM-voiced cases (today the audit fails
  open, `index.ts:386-389`, and nothing counts how often). Unreviewed live profiles served to
  students other than the first one: 0 until review.

### QA-5 Cost per case and daily spend (M)
- Source/stimulus: 1,000 cases a day.
- Environment: steady state, write-ahead on.
- Artifact: `completeJSON` → `takeBudget`/`recordUsage` (`llm.ts:111,136`).
- Response: spend stays inside a case-generation budget separate from chat and grading.
- Measure: ≤ $0.01 per started case including write-ahead waste (today $0.007 stored, $0.03–0.04 live
  [M]; up to 4 `prepare` topics plus one post-start write per tap, `AppState.swift:231-245`).
  Write-ahead cases discarded unused (3-day expiry, `index.ts:75`) ≤ 20%.

### QA-6 Provider outage (H)
- Source/stimulus: DeepSeek returns 5xx or hangs for 30 minutes.
- Environment: peak evening use.
- Artifact: `completeJSON` task `case`/`template`; writer loop `index.ts:306-322`.
- Response: fall back to a second host of the same model, then to the template voice; still deliver.
- Measure: tap-to-patient success ≥ 99%, p95 ≤ 20 s during the outage. Today a hanging DeepSeek costs
  2 × 40 s writer timeouts (`index.ts:51`) before the template, past the client's timeout.

### QA-7 Budget exhaustion (H)
- Source/stimulus: today's spend reaches `LLM_DAILY_BUDGET_USD` at 21:00 UTC.
- Environment: students mid-case.
- Artifact: `takeBudget` (`usage.ts:36-48`), shared by every task.
- Response: generation degrades first (templates, ready cases); chat and grading keep a reserved share.
- Measure: students mid-case can finish and be graded 100% of the time; new cases still open (template
  voice) at ≥ 95% success; overshoot of the cap ≤ 5%.

### QA-8 Burst: 500 students start cases in the same 10 minutes (H)
- Source/stimulus: a class assigns Rounds; 500 taps in 10 min (~0.8/s, peaks 3/s), each also
  triggering a write-ahead and up to 4 prepares.
- Environment: cold ready-case table for most students.
- Artifact: edge workers, pooler, DeepSeek, OpenAI, UMLS, `private.llm_usage`.
- Response: every student gets a case; latency degrades gently, never by refusing.
- Measure: success ≥ 99%, p95 ≤ 20 s, 0 pooler "too many clients", 0 UMLS 429s that change a case,
  spend for the burst ≤ $10.

### QA-9 Background work completes (M)
- Source/stimulus: a write-ahead job starts after a case start.
- Environment: production edge runtime.
- Artifact: `queueGeneration` → `EdgeRuntime.waitUntil` (`index.ts:254-263`).
- Response: the job reaches `ready_cases` or a recorded failure; nothing stays `running`.
- Measure: ≥ 95% of jobs end within 60 s; 0 jobs `running` older than 3 min (today: live jobs never
  end [M]).

## 2. Scalability hotspots (ranked)

Workload assumed for estimates: QA-8 (500 starts in 10 min). Inline time 12 s (stored) / 25 s (live).
Concurrency ≈ arrival rate × duration, so ~10–25 inline generations plus the same number of
write-aheads in flight at once [I].

| # | Hotspot | Evidence | Estimated limit | Mitigation |
|---|---|---|---|---|
| 1 | **Shared daily dollar cap** spent by generation, then 503 for chat/grading for everyone; check-then-spend race | `usage.ts:36-48` (read sum, compare, no reservation); `llm.ts:111`; one cap for all tasks | 500 starts × (1 inline + 1 write-ahead) × $0.035 live ≈ **$35 > $25 default cap**. 50 in-flight calls can overshoot by ~$2 | Per-task budgets (case ≤ 40%, chat+grade reserved); reserve-then-settle in one SQL statement; cap write-ahead spend first |
| 2 | **UMLS fan-out in the fact audit**: every allowed item and every invented claim at once, uncached, 2 searches each | `factaudit.ts:61` (`Promise.all` over all items); `terms.ts:48-55` uncached; limit 20 req/s per IP (`terms.ts:12`) | ~40 items → 40–80 requests per case; **2 cases at once already exceed 20 req/s** from a shared egress IP [I]. A failed lookup keeps the flag → extra fixer calls | Cache `conceptOf` in `private.term_checks`; only look up claims plus the items the model matched; limit to 4 in flight; precompute CUIs of profile items when a profile is stored |
| 3 | **Live profile inline** on the waiting path | `index.ts:142` ranks recent above stored; `index.ts:147-155` 7 calls (`liveprofile.ts:275`), `TEMPLATE_TIMEOUT_MS` 30 s, `LIVE_TRIES` 2 | 20–25 s, 30–35 s with a rewrite, ~60 s when the first condition fails. DeepSeek official ~176 tok/s [M] | Never build live inline when a stored profile exists in the focus: reuse the least-recent stored condition with a new plan instead. Live builds move to a durable batch |
| 4 | **Write-ahead on `waitUntil`**: live jobs never finish; post-start job picks from the whole catalog | `index.ts:101,254-263`; `waiting = false` → no stored preference (`index.ts:142`); stale after 3 min (`index.ts:196`) | ~2/3 of write-aheads wasted [I]; ready-hit rate ≈ 1/3 at best; tokens spent on jobs that die | Write-ahead uses stored profiles only (`waiting = true` always); or run the work inside the `prepare` request itself rather than after the response |
| 5 | **One Postgres connection per worker, ~2 round trips per LLM call plus term-cache reads** | `db.ts:14` `max: 1`; `usage.ts:39,54`; `terms.ts:105-108` per term; `index.ts:126-142` | A live build makes ~7–14 LLM calls (28 queries) plus ~50 term-cache reads, serialized on one connection. At ~5–15 ms through the pooler: 0.5–1 s added [I]. Pooler 200 clients is fine at 50 workers | Batch term-cache reads (`where term = any(...)`); record usage once per request; keep `max:1` |
| 6 | **DeepSeek throughput and rate limiting** | `llm.ts:46-50` all writing on one provider; no retry/backoff (`llm.ts:133`) | 50 concurrent writes × ~4k tokens: the official API throttles dynamically ("server busy") [I]; Baseten serves the same model at ~700 tok/s [M] | Second host of the same model as a hot standby; Baseten primary for inline, official API for background |
| 7 | **Client timeout vs server budget** | `GENERATION_BUDGET_MS` 120 s (`index.ts:49`); the client sets no timeout (`SupabaseClient+Functions.swift:9-11`) | Server keeps working after the client gives up at ~60 s [I]; the case appears in the ward later, the student retries and pays twice | Server deadline 45 s for inline; anything longer becomes a ready case and the app is told "almost ready" |
| 8 | **Background row scan** | `index.ts:428-431` returns every same-sex row within ±7 years | Grows linearly with the Synthea load; 10k rows → ~1.4k rows per case over the wire [I] | `order by random() limit 20` in SQL |
| 9 | **Small topics run out** | 15 derm conditions; recent window 15 across all foci (`index.ts:106,129`) | A derm student repeats after 8–15 cases; ~49 umbrella topics give vague cases [M] | Per-focus history; least-recently-seen ordering; exclude umbrella topics from case-suitable |

Not hotspots: the 2 s CPU limit (work is I/O; largest CPU work is JSON checks on a ~30 KB profile [I]),
the bed-code allocation (`index.ts:511-533`, retries on collision), and the `cases_created_by_idx`
recent-condition query.

## 3. Risk register

L/I = likelihood/impact, 1–5. Severity = L × I.

| ID | Risk | Trigger | Impact | L | I | Sev | Early signals | Mitigation | Experiment / evidence |
|---|---|---|---|---|---|---|---|---|---|
| R1 | Generation spends the shared budget; whole app returns 503 | Class burst, live-heavy mix, write-ahead waste, a retry loop | All students blocked from chat, grading, cards until 00:00 UTC | 4 | 5 | **20** | `llm_spend_today()` above 50% before 18:00 UTC; `task='template'` share of spend rising | Per-task caps with chat/grade reserve; atomic reserve; alert at 50/80% | Replay 500 starts against a stub provider with real `costUSD`; check overshoot |
| R2 | Unreviewed live profile with a hallucinated fact served to many students | DeepSeek invents a lab pattern or drug that passes the structural checks | Students learn wrong medicine; credibility and legal exposure | 3 | 5 | **15** | Profiles with `review='pending'` and non-empty `review_issues` used by more than one user | Serve pending live profiles only to the student who triggered them (or not at all); clinician queue; Sol re-check before promotion | Sample 30 saved live profiles against stored ones; count factual errors |
| R3 | Inline live builds keep p95 at 30 s+ | Students outgrow the stored conditions in their focus | Abandoned taps; "slow" reviews | 5 | 3 | **15** | `case_generated` with `source:live, inline:true` > 5% | Stored-only inline; least-recent stored reuse; batch-fill profiles off-peak | A/B the ordering at `index.ts:142` and compare p95 |
| R4 | Write-ahead never helps | `waitUntil` work killed after the response; live picks | Every tap waits inline; tokens wasted | 5 | 3 | **15** | `case_generation_jobs` rows `running` > 3 min; low `ready_hit` | Stored-only write-ahead; do the work inside the `prepare` request; or pg_cron + pgmq worker once Vault secrets exist | Count job outcomes per day for one week |
| R5 | UMLS 429/timeouts under load | ≥ 2 concurrent audits; NLM maintenance | Audit flags kept → extra fixer calls (cost, +2–3 s) or audit skipped | 4 | 3 | **12** | `fact audit failed` / UMLS 429 in logs | Cache, bound concurrency, precompute CUIs | Load test 10 concurrent `auditCase` calls |
| R6 | Fact audit fails open silently | OpenAI Luna outage or timeout (`CHECK_TIMEOUT_MS` 10 s) | Unaudited DeepSeek text reaches students | 3 | 4 | **12** | Ratio of `fact audit failed` to cases | Count and mark `audited:false` in `case_content`; past a threshold, use the template voice instead | Fault-inject a Luna 500 and inspect the case |
| R7 | DeepSeek outage or throttling | Provider incident; China-region routing issue | Writer: 2 × up to 40 s before template; live profiles impossible | 3 | 4 | **12** | Rising `reply unusable` and `writer failed, using templates` logs | Second host (Baseten) for the same model; cut writer timeout to ~15 s with one fast retry on the other host | Point `LLM_MODEL_CASE` at the standby in staging and time it |
| R8 | Repeats and near-identical patients | Small topics; 15-case window across foci; no fingerprint | Students notice repeats; perceived low content depth | 4 | 3 | **12** | Same condition twice in a student's last 10 cases in one focus | Per-focus history; unique fingerprint; vary severity/age band on reuse | Query `case_content` for repeat rate per user |
| R9 | Scheduled jobs inert (no Vault secrets) | Migrations assume secrets that were never added | Profile batch never fills the catalog; voice sweeper idle (5 h billed once [M]) | 5 | 3 | **15** | `cron.job_run_details` returns but no `net.http` request leaves | Add the two Vault secrets (a cloud change: confirm first); alert when a cron job has no effect for 24 h | Check `profile_jobs` progress after one night |
| R10 | Client gives up before the server finishes | 120 s server budget vs ~60 s client | Duplicate cases and spend; confusing ward | 3 | 2 | 6 | Cases created after the client's error | 45 s server deadline; idempotency key per tap | Measure with a slow stub provider |
| R11 | Budget check fails open on DB error | Pooler hiccup (`usage.ts:40-42`) | Spend not capped during the outage | 2 | 3 | 6 | `llm budget check failed` logs | Fail closed for background tasks, open only for in-case chat | n/a |
| R12 | Daily case quota disabled | `index.ts:36-37,93` commented out | One account or script can drive spend toward R1 | 3 | 4 | **12** | Any user > 30 cases a day | Restore the quota before launch; per-user write-ahead limits | Query per-user case counts |

## 4. Availability and degradation review

### Critical journey and its dependencies

Tap → Supabase Auth (`http.ts:39`) → edge `generate-case` → pooler/Postgres → DeepSeek (writer,
live template) → OpenAI Luna (audit) → UMLS/MedlinePlus/RxNav (live facts, terms, audit) → insert.
Single points of failure with no alternative: **Postgres/pooler, Supabase Auth, the edge runtime**
(platform-level; accept and monitor). Everything else should be optional for the tap.

### What fails, what happens today, what should happen

| Failure | Current behavior (evidence) | Recommended behavior |
|---|---|---|
| DeepSeek 5xx (fast) | Writer fails twice → `templateVoice` (`index.ts:327-336`); case delivered, plainer. Live profile fails → 503 (`index.ts:215`) | Same model on the standby host first; template voice second; never live inline |
| DeepSeek hangs | Up to 40 s per writer attempt × 2 (`index.ts:51,309`), then template; total past the client timeout | Writer timeout ~15 s, then standby host, then template; total inline ≤ 45 s |
| OpenAI Luna down | Audit skipped silently (`index.ts:386-389`); case shipped unaudited. Chat itself fails | Mark `audited:false`; above 5% skipped in an hour, voice from the template. The app should say the patient can't talk right now instead of failing on each question |
| UMLS/MedlinePlus/RxNav down | Live facts empty (`liveprofile.ts:84-88`), model writes from memory (hallucination risk); audit lookups keep flags | No live profiles without grounding (refuse to save one with empty facts); audit uses cached CUIs |
| Daily budget reached | `takeBudget` 503 inside each call; stored cases fall to templates (works by accident); live → 503; chat/grade 503 | Per-task budgets: generation stops writing ahead first, then voices from templates; chat/grade keep a reserve so started cases can finish |
| Background worker killed | Job `running` until 3 min stale (`index.ts:196,201`); no ready case | Stored-only write-ahead (sub-second [M]); durable queue once cron is live |
| Pooler/Postgres down | Total outage (auth, quota, cases) | Platform SPOF: status banner in the app, no retry storms (client backoff) |
| Topic has no stored profile | Live inline 20–60 s, or 503 if two conditions fail | Answer with the closest stored condition in the same clerkship/system and tell the app "new conditions for this topic are being added" |

### Recommended fallback chain for one tap

1. **Ready case** for this student and focus (`claimReady`): ~0.3–1 s.
2. **Stored profile, least-recently-seen condition, writer on the primary host** with a 15 s timeout,
   audit on Luna: ~10–12 s today, ~4–6 s on the faster host [I: 700 vs 176 tok/s].
3. **Same, writer on the standby host** (same model, so prompts and checks don't change).
4. **Stored profile + `templateVoice`**, no LLM: < 1 s, correct but plain. Used too when the
   generation budget is spent.
5. **Stored profile from the nearest topic** (same clerkship or system) when the focus has none, with a
   note in the app. Live profiles are never built while a student waits; they are built by the
   batch, grounded, and promoted to students only after review.
6. Only if all of the above fail: 503 with a retry hint, and no quota charged.

Recovery: write-ahead refills the ready slot after every start; a profile batch (pg_cron once the
Vault secrets exist) closes the gap between 240 stored and 718 suitable conditions, which removes
step 5 for most topics.

## Evidence vs assumptions

- Measured: latencies, provider speeds, costs, background failure, cron inertness, catalog sizes.
- From code: every file:line above (branch `more-conditions`, 2026-10-19).
- Assumed: client timeout ~60 s (supabase-swift default, not set in the app); UMLS 20 req/s applies to
  a shared edge egress IP; DeepSeek throttling under ~50 concurrent writes; pooler latency 5–15 ms;
  ready-hit rate (no metric exists). Each has an experiment in the risk register.

## Recommended next steps

1. `adr-writer`: "No live profile while a student waits" and "per-task LLM budgets".
2. `runtime-view-writer`: the fallback chain above as a sequence with timeouts.
3. Instrument first (ready-hit, audit-skipped, per-task spend) so the scenario measures can be checked.
