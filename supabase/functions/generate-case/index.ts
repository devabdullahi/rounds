// generate-case: makes a new fictional patient for the calling student.
//
//   1. Verify the caller and take one case from their daily allowance.
//   2. Use the case written ahead for this student and focus, if one is waiting (instant). Otherwise
//      pick a condition in their study focus. Stored first, live fallback: a validated stored profile
//      (private.condition_profiles) is used as is; a condition without one gets its profile built live
//      from public medical APIs and the profile template (_shared/liveprofile.ts), and a live profile
//      that passes its checks is saved for next time (review "pending"), so the catalog fills itself.
//      A condition the student has never had comes first, so nothing repeats until the topic is used
//      up (then the one they had longest ago); among those, a stored profile wins while a student
//      waits (pick.ts, stores.ts nextCondition). A live profile that still fails its checks after its
//      rewrites is dropped and another condition is tried.
//   3. Plan the patient in code (severity, age, sex, findings, vitals, lab values), never one the
//      student already has (fingerprint.ts), and pick a synthetic background record of the same sex
//      and a close age (background.ts), if one fits. compose.ts runs steps 3–5.
//   4. Build the case's content in code (skeleton.ts): every history fact, present exam findings and
//      test prices. The LLM only voices it: each fact in the patient's words, the door note and
//      persona, normal exam results and study reports. It never chooses the medicine. If the writer
//      fails, the case is filled from templates instead (template.ts), plainer but correct.
//   5. Check the writing (structure, no diagnosis leaks, no invented facts: _shared/factaudit.ts). A
//      leak is reworded field by field; other problems get a rewrite with the problems listed.
//   6. Save the public door note and menus, and the private script, results and rubric.
//   7. Queue the student's next case for this focus after replying (private.ready_cases).
//
// `setting` ("clinic" / "hospital", optional) narrows step 2 to conditions seen there and sets the
// encounter there (setting.ts). `{focus, prepare: true}` only does step 7: the app sends it when a
// focus is chosen or the app opens, so the first case in a topic is usually written before the student asks for it.
import { body, callerId, HttpError, json, serve } from "../_shared/http.ts";
import { currentModel } from "../_shared/llm.ts";
import { type Focus, parseFocus } from "../_shared/focus.ts";
import { requirePlan } from "../_shared/plan.ts";
import { refundQuota, takeQuota } from "../_shared/quota.ts";
import { BudgetExceeded } from "../_shared/usage.ts";
import { aiOnlyCase, aiOnlyUser } from "./aionly.ts";
import { BACKGROUND_WRITER_MS, composeCase, NoNewPatient } from "./compose.ts";
import { pickProfile } from "./pick.ts";
import { claimReady, finishGeneration, hasReady, insertCase, recordJobPick, startGeneration, studentHistory } from "./stores.ts";
import type { CaseRows } from "./types.ts";

/** Background writing may take this long. */
const GENERATION_BUDGET_MS = 120_000;
/** Everything one request starts, background work included, ends by then: the edge runtime stops
 *  a worker at 150 s, and a job killed mid-write stays "running" for minutes. */
const INVOCATION_BUDGET_MS = 140_000;
/** Time a tap needs left to try a second condition after the first failed. */
const RETRY_MIN_MS = 25_000;
/** Used-up conditions skipped for one patient before giving up. Each skip costs only a database
 *  pick (no model call), and a topic rarely has more than a few nearly exhausted conditions. */
const MAX_USED_UP = 6;
const USED_UP_MESSAGE = "You've had nearly every patient this topic can make. Try another topic, or mix it up.";
/** A student waiting gets an answer within this. The app gives up after 60 s, and a case written
 *  after that is never seen: the student taps again and gets a duplicate. */
const INLINE_BUDGET_MS = 50_000;

declare const EdgeRuntime: { waitUntil(promise: Promise<unknown>): void };

serve(async (req) => {
  const invoked = Date.now();
  const userId = await callerId(req);
  await requirePlan(userId);
  // `polling` is still sent by app builds that waited on background jobs; it no longer changes anything.
  const { focus: requested = "", setting = "", prepare } =
    await body<{ focus?: string; setting?: unknown; polling?: unknown; prepare?: unknown }>(req);
  const focus = parseFocus(requested, setting);

  // Prepare only: write this focus's next case ahead, before the student asks for it, so even the
  // first patient in a topic opens instantly. Bounded by one job and one ready case per focus.
  if (prepare === true) {
    queueGeneration(userId, focus, invoked, true);
    return json({ status: "preparing" }, 202);
  }

  // A new patient counts against the daily limit (refunded on failure), whether it's written now or
  // was written ahead. The quota comes first: a student over the limit mustn't start background
  // writing either.
  // One account mustn't use up the shared content budget for everyone (LIMIT_CASES_PER_DAY, 10 by
  // default; launch blocker from the security review, 2026-10-20).
  await takeQuota(userId, "case");
  // No case waiting: write one now, in this request. A student never waits on a background job,
  // which could die with its worker; writing ahead is only a head start.
  let caseId: string;
  try {
    let rows = await claimReady(userId, focus);
    try {
      caseId = await insertCase(userId, rows ?? (rows = await writeNow(userId, focus)));
    } catch (error) {
      // A case written ahead can turn out identical to one written for this student since (409):
      // write a fresh one instead of losing the tap.
      if (!(error instanceof HttpError && error.status === 409)) throw error;
      caseId = await insertCase(userId, await writeNow(userId, focus));
    }
  } catch (error) {
    // No patient came of it: the tap doesn't count against the day.
    await refundQuota(userId, "case").catch(() => {});
    throw error;
  }
  // Queue the next case after this response; the next start can take it as soon as it's ready.
  queueGeneration(userId, focus, invoked);
  return json({ case_id: caseId, model: currentModel("case") });
});

/** One line per case, for the timing dashboard: where the profile came from and where time went. */
function logGenerated(focus: Focus, slug: string, source: string, waiting: boolean, inline: boolean, started: number, profiled: number) {
  console.log(JSON.stringify({
    event: "case_generated", focus: focus.stored, slug, source, waiting, inline,
    profile_ms: profiled - started, compose_ms: Date.now() - profiled, total_ms: Date.now() - started,
  }));
}

/** A case written while the student waits: a stored profile when the focus has one. If writing the
 *  first condition fails, another is tried while there's time, so one bad profile can't fail every tap. */
async function writeNow(userId: string, focus: Focus): Promise<CaseRows> {
  const started = Date.now();
  const deadline = started + INLINE_BUDGET_MS;
  const history = await studentHistory(userId);
  // The AI-only experiment: listed accounts get a case the model invents whole (aionly.ts).
  if (await aiOnlyUser(userId)) return await aiOnlyCase(userId, focus, history, deadline);
  const tried: string[] = [];
  let failed = false;   // one writing failure may move on to another condition, not more
  let usedUp = 0;
  for (;;) {
    const picked = await pickProfile(userId, focus, deadline, { waiting: true, tried });
    if (!picked) throw new HttpError(503, usedUp ? USED_UP_MESSAGE : "Couldn't prepare a patient just now. Tap to try again.");
    const profiled = Date.now();
    try {
      const rows = await composeCase(picked, focus, deadline, history);
      logGenerated(focus, picked.profile.slug, picked.source, true, true, started, profiled);
      return rows;
    } catch (error) {
      tried.push(picked.profile.slug);
      // A condition the student has used up: the next one in the topic, at no cost.
      if (error instanceof NoNewPatient && ++usedUp < MAX_USED_UP) continue;
      if (error instanceof NoNewPatient) throw new HttpError(503, USED_UP_MESSAGE);
      if (error instanceof BudgetExceeded || deadline - Date.now() < RETRY_MIN_MS || failed) throw error;
      console.warn("generate-case: writing failed, trying another condition", picked.profile.slug, (error as Error).message.slice(0, 120));
      failed = true;
    }
  }
}

/** Writes the next case in the background, then keeps it for the student's next start. */
async function writeAhead(userId: string, focus: Focus, token: string, studentWaiting: boolean, invoked: number): Promise<void> {
  const started = Date.now();
  try {
    if (await hasReady(userId, focus)) {
      await finishGeneration(userId, focus, token, null);
      return;
    }
    const deadline = Math.min(Date.now() + GENERATION_BUDGET_MS, invoked + INVOCATION_BUDGET_MS);
    const history = await studentHistory(userId);
    if (await aiOnlyUser(userId)) {
      await finishGeneration(userId, focus, token, await aiOnlyCase(userId, focus, history, deadline));
      return;
    }
    const tried: string[] = [];
    // A condition the student has used up is skipped for the next one in the topic.
    for (let usedUp = 0; ; usedUp++) {
      const picked = await pickProfile(userId, focus, deadline, {
        waiting: studentWaiting, tried, onPick: (slug) => recordJobPick(userId, focus, token, slug),
      });
      if (!picked) throw new Error(usedUp ? "every condition tried was used up for this student" : "no suitable condition could be prepared");
      const profiled = Date.now();
      try {
        const rows = await composeCase(picked, focus, deadline, history, BACKGROUND_WRITER_MS);
        await finishGeneration(userId, focus, token, rows);
        logGenerated(focus, picked.profile.slug, picked.source, studentWaiting, false, started, profiled);
        return;
      } catch (error) {
        if (!(error instanceof NoNewPatient) || usedUp + 1 >= MAX_USED_UP) throw error;
        tried.push(picked.profile.slug);
      }
    }
  } catch (error) {
    console.error("generate-case: writing ahead failed", error);
    await finishGeneration(userId, focus, token, null, true);
  }
}

/** Writes the focus's next case in the background. `waiting`: a student may tap soon (the head
 *  start on Home), so a stored profile is preferred, as when they're already waiting. */
function queueGeneration(userId: string, focus: Focus, invoked: number, waiting = false): void {
  EdgeRuntime.waitUntil((async () => {
    try {
      const generation = await startGeneration(userId, focus);
      if (generation.status === "started") await writeAhead(userId, focus, generation.token, waiting, invoked);
    } catch (error) {
      console.error("generate-case: unable to queue next case", error);
    }
  })());
}
