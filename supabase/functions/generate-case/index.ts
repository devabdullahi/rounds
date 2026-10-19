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
// `{focus, prepare: true}` only does step 7: the app sends it when a focus is chosen or the app
// opens, so the first case in a topic is usually written before the student asks for it.
import { body, callerId, HttpError, json, serve } from "../_shared/http.ts";
import { currentModel } from "../_shared/llm.ts";
import { type Focus, parseFocus } from "../_shared/focus.ts";
// Daily patient limit off for now (2026-10-19, user request); restore these to turn it back on.
// import { refundQuota, takeQuota } from "../_shared/quota.ts";
import { composeCase } from "./compose.ts";
import { pickProfile } from "./pick.ts";
import { claimReady, finishGeneration, hasReady, insertCase, startGeneration, studentHistory } from "./stores.ts";
import type { CaseRows } from "./types.ts";

/** Background writing may take this long. */
const GENERATION_BUDGET_MS = 120_000;
/** A student waiting gets an answer within this. The app gives up after 60 s, and a case written
 *  after that is never seen: the student taps again and gets a duplicate. */
const INLINE_BUDGET_MS = 50_000;

declare const EdgeRuntime: { waitUntil(promise: Promise<unknown>): void };

serve(async (req) => {
  const userId = await callerId(req);
  // `polling` is still sent by app builds that waited on background jobs; it no longer changes anything.
  const { focus: requested = "", prepare } = await body<{ focus?: string; polling?: unknown; prepare?: unknown }>(req);
  const focus = parseFocus(requested);

  // Prepare only: write this focus's next case ahead, before the student asks for it, so even the
  // first patient in a topic opens instantly. Bounded by one job and one ready case per focus.
  if (prepare === true) {
    queueGeneration(userId, focus, true);
    return json({ status: "preparing" }, 202);
  }

  // A new patient counts against the daily limit (refunded on failure), whether it's written now or
  // was written ahead. The quota comes first: a student over the limit mustn't start background
  // writing either.
  // await takeQuota(userId, "case");
  // No case waiting: write one now, in this request. A student never waits on a background job,
  // which could die with its worker; writing ahead is only a head start.
  const rows = await claimReady(userId, focus) ?? await writeNow(userId, focus);

  const caseId = await insertCase(userId, rows);
  // Queue the next case after this response; the next start can take it as soon as it's ready.
  queueGeneration(userId, focus);
  return json({ case_id: caseId, model: currentModel("case") });
});

/** One line per case, for the timing dashboard: where the profile came from and where time went. */
function logGenerated(focus: Focus, slug: string, source: string, waiting: boolean, inline: boolean, started: number, profiled: number) {
  console.log(JSON.stringify({
    event: "case_generated", focus: focus.stored, slug, source, waiting, inline,
    profile_ms: profiled - started, compose_ms: Date.now() - profiled, total_ms: Date.now() - started,
  }));
}

/** A case written while the student waits: a stored profile when the focus has one. */
async function writeNow(userId: string, focus: Focus): Promise<CaseRows> {
  const started = Date.now();
  const deadline = started + INLINE_BUDGET_MS;
  const [picked, history] = await Promise.all([pickProfile(userId, focus, deadline, true), studentHistory(userId)]);
  if (!picked) throw new HttpError(503, "Couldn't prepare a patient just now. Tap to try again.");
  const profiled = Date.now();
  const rows = await composeCase(picked, focus, deadline, history);
  logGenerated(focus, picked.profile.slug, picked.source, true, true, started, profiled);
  return rows;
}

/** Writes the next case in the background, then keeps it for the student's next start. */
async function writeAhead(userId: string, focus: Focus, token: string, studentWaiting: boolean): Promise<void> {
  const started = Date.now();
  try {
    if (await hasReady(userId, focus)) {
      await finishGeneration(userId, focus, token, null);
      return;
    }
    const deadline = Date.now() + GENERATION_BUDGET_MS;
    const [picked, history] = await Promise.all([pickProfile(userId, focus, deadline, studentWaiting), studentHistory(userId)]);
    if (!picked) throw new Error("no suitable condition could be prepared");
    const profiled = Date.now();
    const rows = await composeCase(picked, focus, deadline, history);
    await finishGeneration(userId, focus, token, rows);
    logGenerated(focus, picked.profile.slug, picked.source, studentWaiting, false, started, profiled);
  } catch (error) {
    console.error("generate-case: writing ahead failed", error);
    await finishGeneration(userId, focus, token, null, true);
  }
}

/** Writes the focus's next case in the background. `waiting`: a student may tap soon (the head
 *  start on Home), so a stored profile is preferred, as when they're already waiting. */
function queueGeneration(userId: string, focus: Focus, waiting = false): void {
  EdgeRuntime.waitUntil((async () => {
    try {
      const generation = await startGeneration(userId, focus);
      if (generation.status === "started") await writeAhead(userId, focus, generation.token, waiting);
    } catch (error) {
      console.error("generate-case: unable to queue next case", error);
    }
  })());
}
