// generate-case: makes a new fictional patient for the calling student.
//
//   1. Verify the caller and take one case from their daily allowance.
//   2. Use the case written ahead for this student and focus, if one is waiting (instant). Otherwise
//      pick a condition in their study focus. Stored first, live fallback: a validated stored profile
//      (private.condition_profiles) is used as is; a condition without one gets its profile built live
//      from public medical APIs and the profile template (_shared/liveprofile.ts), and a live profile
//      that passes its checks is saved for next time (review "pending"), so the catalog fills itself.
//      While a student waits, only conditions with a stored profile are picked when the focus has
//      any; writing ahead picks from the whole catalog, so variety grows. A live profile that still
//      fails its checks after its rewrites is dropped and another condition is tried.
//   3. Plan the patient in code (severity, age, sex, findings, vitals, lab values), and pick a
//      synthetic background record of the same sex and a close age (background.ts), if one fits.
//   4. Build the case's content in code (skeleton.ts): every history fact, present exam findings and
//      test prices; then fill in the rest from templates (template.ts): the door note, person, normal
//      exam results, study reports and one-tap questions. No model writes the case, so nothing in it
//      is invented; the patient model voices the facts when the student asks.
//   5. Check the writing (structure, no diagnosis leaks). A field that names the diagnosis is
//      reworded by the model, field by field.
//   6. Save the public door note and menus, and the private script, results and rubric.
//   7. Queue the student's next case for this focus after replying (private.ready_cases).
//
// `{focus, prepare: true}` only does step 7: the app sends it when a focus is chosen or the app
// opens, so the first case in a topic is usually written before the student asks for it.
import { body, callerId, HttpError, json, serve } from "../_shared/http.ts";
import { sql } from "../_shared/db.ts";
import { completeJSON, currentModel } from "../_shared/llm.ts";
import { CASE_FIXER, PROMPT_VERSION } from "../_shared/prompts.ts";
import { acceptedNames, type CasePlan, leakTerms, planCase, type Profile } from "../_shared/casegen.ts";
import { flag, type Patient, TESTS } from "../_shared/labs.ts";
import { type Focus, parseFocus } from "../_shared/focus.ts";
import { checkTerms, umlsKey } from "../_shared/terms.ts";
import { buildLiveProfile } from "../_shared/liveprofile.ts";
import { SYSTEM_PROMPT } from "../_shared/profilegen.ts";
// Daily patient limit off for now (2026-10-19, user request); restore these to turn it back on.
// import { refundQuota, takeQuota } from "../_shared/quota.ts";
import { MAX_AGE_GAP, type PatientBackground, pickBackground } from "./background.ts";
import { bedCode } from "./bedcode.ts";
import { applyFixes, assemble, buildRubric, checkWriting, fixPrompt, leakSpots, neutralIds, type Writing } from "./writer.ts";
import { buildSkeleton } from "./skeleton.ts";
import { templateVoice } from "./template.ts";

/** Bound slow provider calls so a stuck one can't keep a student waiting for the edge runtime's
 *  full request limit. */
const GENERATION_BUDGET_MS = 120_000;
const TEMPLATE_TIMEOUT_MS = 30_000;
const FIX_TIMEOUT_MS = 12_000;

function timeoutFor(deadline: number, maximum: number): number {
  const remaining = deadline - Date.now();
  if (remaining <= 0) throw new HttpError(504, "patient generation timed out; try again");
  return Math.min(remaining, maximum);
}

type GenerationStart = { status: "started"; token: string } | { status: "pending" } | { status: "failed" };

/** A validated profile for the focus, with the catalog data a case needs. */
type Picked = { profile: Profile; clerkships: string[]; organ_systems: string[]; synonyms: string[] };

/** Everything a case inserts except its owner and bed code: built once, kept as a ready case, and
 *  inserted when the student starts it. */
// deno-lint-ignore no-explicit-any
type CaseRows = { case: Record<string, any>; content: Record<string, any> };

declare const EdgeRuntime: { waitUntil(promise: Promise<unknown>): void };

/** A case written ahead and not started within this long is thrown away, so profiles that were
 *  fixed or rejected meanwhile don't reach students. */
const READY_FOR = "3 days";

serve(async (req) => {
  const userId = await callerId(req);
  const { focus: requested = "", polling: pollingInput, prepare } = await body<{ focus?: string; polling?: unknown; prepare?: unknown }>(req);
  const focus = parseFocus(requested);
  const polling = pollingInput === true;

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
  const rows = await claimReady(userId, focus);
  if (!rows) {
    const state = await startGeneration(userId, focus, polling);
    if (state.status === "failed") {
      throw new HttpError(503, "Couldn't prepare a patient just now. Tap to try again.");
    }
    if (state.status === "started") launchGeneration(userId, focus, state.token);
    return json({ status: "preparing" }, 202);
  }

  const caseId = await insertCase(userId, rows);
  // Queue the next case after this response; the next start can take it as soon as it's ready.
  queueGeneration(userId, focus);
  return json({ case_id: caseId, model: currentModel("case") });
});

/** Live profile attempts per case: a condition whose profile still fails its checks is swapped. */
const LIVE_TRIES = 2;

type Condition = {
  slug: string; triage: Profile["triage"]; background: string | null; clerkships: string[]; organ_systems: string[]; synonyms: string[];
  /** The condition's validated stored profile, when it has one. */
  stored: Profile | null;
};

/** Where a case's profile came from, for the timing log. */
type Source = "stored" | "live";

/** A condition in the focus with its profile: stored when it has a validated one, else built live
 *  (and saved when it passes). `waiting`: a student is waiting, so a condition with a stored profile
 *  is preferred whenever the focus has one. Null when the focus has no condition, or none built
 *  cleanly within LIVE_TRIES. */
async function pickProfile(focus: Focus, deadline: number, waiting: boolean): Promise<(Picked & { source: Source }) | null> {
  const tried: string[] = [];
  for (let attempt = 0; attempt < LIVE_TRIES; attempt++) {
    if (Date.now() >= deadline) break;
    const [c] = await sql<Condition[]>`
      select c.slug, c.triage, c.background, c.clerkships, c.organ_systems,
        coalesce(array(select jsonb_array_elements_text(c.terms -> 'snomed' -> 'synonyms')), '{}') as synonyms,
        p.profile as stored
      from private.conditions c
      left join private.condition_profiles p on p.slug = c.slug and p.validation = 'passed' and p.review <> 'rejected'
      where c.case_suitable and c.triage is not null and not (c.slug = any(${tried}::text[]))
        and (${focus.kind !== "rotation"} or ${focus.value} = any(c.clerkships))
        and (${focus.kind !== "system"} or ${focus.value} = any(c.organ_systems))
      order by (${waiting} and p.profile is not null) desc, random() limit 1`;
    if (!c) return null;
    tried.push(c.slug);
    const topics = { clerkships: c.clerkships, organ_systems: c.organ_systems, synonyms: c.synonyms };
    if (c.stored) return { profile: c.stored, ...topics, source: "stored" };
    const { profile, problems } = await buildLiveProfile(c.slug, c.triage, c.background ?? "", {
      umlsKey: umlsKey(),
      system: SYSTEM_PROMPT,
      complete: (system, user) => completeJSON(system, user, 8000, {
        task: "template", temperature: 0.3, timeoutMs: timeoutFor(deadline, TEMPLATE_TIMEOUT_MS),
      }),
      // Time-boxed: terms it can't check in time are left unverified rather than holding the case.
      termErrors: (output) => checkTerms(output, undefined, Math.min(Date.now() + 8000, deadline)).catch(() => []),
    });
    if (Date.now() >= deadline) throw new HttpError(504, "patient generation timed out; try again");
    if (problems.length === 0) {
      await saveProfile(c, profile as Profile);
      return { profile: profile as Profile, ...topics, source: "live" };
    }
    console.warn("generate-case: live profile failed its checks", c.slug, problems.slice(0, 5));
  }
  return null;
}

/** Keeps a live profile that passed its checks, so the condition's next case starts from it. It
 *  goes to clinician review like any new profile. Never replaces a stored one (prepare-profile and
 *  reviewers own those), and a failed save only costs the head start. */
async function saveProfile(c: Condition, profile: Profile): Promise<void> {
  const t = profile.triage;
  // deno-lint-ignore no-explicit-any
  const json = sql.json(profile as any);
  await sql`
    insert into private.condition_profiles (slug, name, primary_clerkship, clerkships, organ_systems, validation, review, profile)
    values (${c.slug}, ${t.name}, ${t.primary_clerkship}, ${c.clerkships}, ${c.organ_systems}, 'passed', 'pending', ${json})
    on conflict (slug) do nothing`.catch((error) => console.error("generate-case: saving the live profile failed", c.slug, error));
}

/** Takes the student's case written ahead for this focus, if there is a fresh one. */
async function claimReady(userId: string, focus: Focus): Promise<CaseRows | null> {
  const [row] = await sql<{ rows: CaseRows; fresh: boolean }[]>`
    delete from private.ready_cases where user_id = ${userId} and focus = ${focus.stored}
    returning rows, created_at > now() - ${READY_FOR}::interval as fresh`;
  return row?.fresh ? row.rows : null;
}

/** Claims the one background generation slot for this student and focus. The token is the slot's
 *  started_at as text, and is only ever compared as text: passed back as a parameter cast to
 *  timestamptz, the client turned it into a JS Date and dropped the microseconds, so no job ever
 *  matched its own slot and every case written in the background was thrown away. */
async function startGeneration(userId: string, focus: Focus, polling: boolean): Promise<GenerationStart> {
  return await sql.begin(async (tx) => {
    await tx`insert into private.case_generation_jobs (user_id, focus) values (${userId}, ${focus.stored})
      on conflict (user_id, focus) do nothing`;
    const [job] = await tx<{ status: "queued" | "running" | "failed"; stale: boolean }[]>`
      select status, started_at < now() - interval '3 minutes' as stale
      from private.case_generation_jobs where user_id = ${userId} and focus = ${focus.stored}
      for update`;
    if (!job) throw new Error("generation job disappeared before it could start");
    if (job.status === "failed" && polling) return { status: "failed" };
    if (job.status === "running" && !job.stale) return { status: "pending" };
    const [started] = await tx<{ token: string }[]>`
      update private.case_generation_jobs set status = 'running', started_at = clock_timestamp()
      where user_id = ${userId} and focus = ${focus.stored}
      returning started_at::text as token`;
    return { status: "started", token: started.token };
  });
}

/** Writes the next case in the background, then makes it available to the next poll. */
async function writeAhead(userId: string, focus: Focus, token: string, studentWaiting: boolean): Promise<void> {
  const started = Date.now();
  try {
    const [{ waiting }] = await sql<{ waiting: boolean }[]>`
      select exists(select 1 from private.ready_cases where user_id = ${userId} and focus = ${focus.stored}) as waiting`;
    if (waiting) {
      await finishGeneration(userId, focus, token, null);
      return;
    }
    const deadline = Date.now() + GENERATION_BUDGET_MS;
    const picked = await pickProfile(focus, deadline, studentWaiting);
    if (!picked) throw new Error("no suitable condition could be prepared");
    const profiled = Date.now();
    const rows = await composeCase(picked, focus, deadline);
    await finishGeneration(userId, focus, token, rows);
    // One line per case, for the timing dashboard: where the profile came from and where time went.
    console.log(JSON.stringify({
      event: "case_generated", focus: focus.stored, slug: picked.profile.slug, source: picked.source, waiting: studentWaiting,
      profile_ms: profiled - started, compose_ms: Date.now() - profiled, total_ms: Date.now() - started,
    }));
  } catch (error) {
    console.error("generate-case: writing ahead failed", error);
    await finishGeneration(userId, focus, token, null, true);
  }
}

function launchGeneration(userId: string, focus: Focus, token: string): void {
  EdgeRuntime.waitUntil(writeAhead(userId, focus, token, true).catch((error) => {
    console.error("generate-case: background generation failed", error);
  }));
}

/** Writes the focus's next case in the background. `waiting`: a student may tap soon (the head
 *  start on Home), so a stored profile is preferred, as when they're already waiting. */
function queueGeneration(userId: string, focus: Focus, waiting = false): void {
  EdgeRuntime.waitUntil((async () => {
    try {
      const generation = await startGeneration(userId, focus, false);
      if (generation.status === "started") await writeAhead(userId, focus, generation.token, waiting);
    } catch (error) {
      console.error("generate-case: unable to queue next case", error);
    }
  })());
}

async function finishGeneration(
  userId: string, focus: Focus, token: string, rows: CaseRows | null, failed = false,
): Promise<void> {
  await sql.begin(async (tx) => {
    const owned = await tx<{ user_id: string }[]>`
      select user_id from private.case_generation_jobs
      where user_id = ${userId} and focus = ${focus.stored} and started_at::text = ${token}
      for update`;
    if (!owned.length) return;
    if (rows) {
      await tx`insert into private.ready_cases (user_id, focus, rows)
        values (${userId}, ${focus.stored}, ${tx.json(rows)}) on conflict (user_id, focus) do nothing`;
    }
    if (failed) {
      await tx`update private.case_generation_jobs set status = 'failed'
        where user_id = ${userId} and focus = ${focus.stored} and started_at::text = ${token}`;
    } else {
      await tx`delete from private.case_generation_jobs where user_id = ${userId} and focus = ${focus.stored}`;
    }
  });
}

/** Plans the patient in code, has the model write them and checks the writing. */
async function composeCase(
  { profile, clerkships, organ_systems: systems, synonyms }: Picked, focus: Focus, deadline: number,
): Promise<CaseRows> {
  // Clinical psychology is a focus like any rotation; its cases are written as a psychologist's intake.
  const psychology = focus.kind === "rotation" && focus.value === "clinicalPsychology";
  const dermatology = focus.kind === "rotation" && focus.value === "dermatology";
  // A heart case: filed under cardiology or the cardiovascular system, or made for either focus.
  const cardiac = clerkships.includes("cardiology") || systems.includes("cardiovascular") ||
    (focus.kind === "rotation" && focus.value === "cardiology") || (focus.kind === "system" && focus.value === "cardiovascular");
  const plan = planCase(profile, Math.random, { psychology, dermatology, cardiac });
  const terms = leakTerms(profile);
  const background = await findBackground(plan, [profile.triage.name, ...acceptedNames(profile.teaching.accepted_names, synonyms)]);
  const skeleton = buildSkeleton(profile, plan, background, Math.random);
  let writing: Writing = assemble(skeleton, templateVoice(profile, plan, skeleton, background, Math.random));
  let problems = checkWriting(writing, plan, terms);
  if (problems.length) {
    writing = await fixLeaks(writing, terms, deadline);
    problems = checkWriting(writing, plan, terms);
  }
  if (problems.length > 0) {
    console.error("generate-case: writing failed", profile.slug, problems);
    throw new HttpError(502, "the patient couldn't be written; try again");
  }
  return buildRows(profile, clerkships, systems, synonyms, plan, neutralIds(writing), focus, background?.id ?? null);
}

/** Rewords only the fields that named the diagnosis. Leaks are the usual reason a writing fails, and
 *  this takes 2–3 s where a full rewrite takes 15–20 s. Returns the writing unchanged if it can't. */
async function fixLeaks(w: Writing, terms: string[], deadline: number): Promise<Writing> {
  const { leaked, where } = leakSpots(w, terms);
  if (!leaked.length) return w;
  try {
    const reply = await completeJSON<{ fixes?: { where: string; text: string }[] }>(CASE_FIXER, fixPrompt(w, where, leaked), 1500, {
      task: "case", timeoutMs: timeoutFor(deadline, FIX_TIMEOUT_MS),
    });
    return applyFixes(w, Array.isArray(reply.fixes) ? reply.fixes : []);
  } catch (error) {
    console.error("generate-case: leak fix failed", (error as Error).message.slice(0, 200));
    return w;
  }

}

/** A synthetic background for the planned patient, or null when none fits or the table can't be
 *  read: a background only adds texture, so it never stops a case from being written. */
async function findBackground(plan: CasePlan, diagnosisNames: string[]): Promise<PatientBackground | null> {
  try {
    const rows = await sql<PatientBackground[]>`
      select id, age, sex, marital, conditions, medications, allergies, smoking, social
      from private.patient_backgrounds
      where sex = ${plan.sex} and age between ${plan.age - MAX_AGE_GAP} and ${plan.age + MAX_AGE_GAP}`;
    return pickBackground(rows, plan, diagnosisNames, Math.random);
  } catch (error) {
    console.error("generate-case: background lookup failed", error);
    return null;
  }
}

/** The specialty a case files under: the one the student picked, when the condition belongs to it
 *  (a depression case made for Clinical psychology is a psychology case; a heart failure case made
 *  for Cardiology is a cardiology case), else the condition's own primary rotation. */
function caseClerkship(profile: Profile, topics: string[], focus: Focus): string {
  return focus.kind === "rotation" && topics.includes(focus.value) ? focus.value : profile.triage.primary_clerkship;
}

/** The body system a case files under: the one the student picked when the condition is in it, else
 *  the condition's first (from the catalog's re-filing, falling back to triage's). */
function caseSystem(profile: Profile, systems: string[], focus: Focus): string {
  if (focus.kind === "system" && systems.includes(focus.value)) return focus.value;
  return systems[0] ?? profile.triage.organ_systems[0];
}

const VITAL_LABELS: Record<string, string> = { hr: "HR", sbp: "BP", rr: "RR", spo2: "SpO₂", temp: "Temp" };

/** Door-note vitals with an abnormal flag from this patient's normal ranges (age, pregnancy);
 *  the app turns the flag into a color. */
function doorVitals(plan: CasePlan) {
  const v = plan.vitals as Record<string, number>;
  const patient: Patient = { sex: plan.sex, age: plan.age, pregnant: plan.pregnant };
  const off = (id: string) => !!flag(TESTS.get(id)!, v[id], patient);
  const out = [
    { id: "hr", value: `${v.hr}`, abnormal: off("hr") },
    { id: "sbp", value: `${v.sbp}/${v.dbp}`, abnormal: off("sbp") || off("dbp") },
    { id: "spo2", value: `${v.spo2}%`, abnormal: off("spo2") },
    { id: "rr", value: `${v.rr}`, abnormal: off("rr") },
    { id: "temp", value: `${v.temp.toFixed(1)}°F`, abnormal: off("temp") },
  ];
  return out.map((x) => ({ ...x, label: VITAL_LABELS[x.id] }));
}

/** The rows a case saves: the door note and menus the student sees, and the private script, results
 *  and rubric. */
function buildRows(profile: Profile, clerkships: string[], systems: string[], synonyms: string[], plan: CasePlan, w: Writing, focus: Focus, backgroundId: string | null): CaseRows {
  const meta = new Map(w.test_meta.map((m) => [m.test_id, m]));
  const reports = new Map(w.studies.map((s) => [s.test_id, s]));
  const tests = plan.tests.map((t) => {
    const m = meta.get(t.id)!;
    const study = reports.get(t.id);
    return {
      id: t.id, name: t.name, detail: m.detail, cost: m.cost, turnaround_s: m.turnaround_s,
      delays_care_min: m.delays_care_min ?? 0,
      result: t.kind === "lab" ? t.result : study!.result,
      abnormal: t.kind === "lab" ? t.abnormal : study!.abnormal,
      role: t.role, why: t.why ?? null,
    };
  });

  return {
    case: {
      specialty: profile.triage.primary_clerkship, patient_name: w.patient.name, age: plan.age, sex: plan.sex,
      quote: w.patient.quote, complaint: w.patient.complaint, vitals: doorVitals(plan), minutes: 10,
      setting: w.patient.setting, demeanor: w.patient.demeanor, organ_system: caseSystem(profile, systems, focus),
      clerkship: caseClerkship(profile, clerkships, focus), suggested: w.suggested,
      maneuvers: w.maneuvers.map(({ id, title }) => ({ id, title })),
      test_menu: tests.map(({ id, name, detail, cost, turnaround_s, delays_care_min }) => ({ id, name, detail, cost, turnaround_s, delays_care_min })),
      key_history: w.facts.filter((f) => f.importance !== "optional").length,
    },
    content: {
      facts: w.facts, exam: w.maneuvers, tests,
      answer_key: { diagnosis: profile.triage.name, accepted: acceptedNames(profile.teaching.accepted_names, synonyms) },
      condition_slug: profile.slug, severity: plan.severity,
      persona: { ...w.persona, name: w.patient.name, age: plan.age, sex: plan.sex, pregnant: plan.pregnant, model: currentModel("case"), prompt_version: PROMPT_VERSION },
      rubric: buildRubric(profile, plan, w, tests), focus: focus.stored, background_id: backgroundId,
      // The live profile this case was planned from: grading insights and mistake cards read it.
      profile,
    },
  };
}

/** Saves a case for the student under a fresh bed code. */
async function insertCase(userId: string, { case: c, content: k }: CaseRows): Promise<string> {
  for (let attempt = 0; attempt < 5; attempt++) {
    const id = bedCode();
    try {
      await sql.begin(async (tx) => {
        await tx`
          insert into public.cases (id, specialty, patient_name, age, sex, quote, complaint, vitals, minutes,
            published, created_by, setting, demeanor, organ_system, clerkship, suggested, maneuvers, test_menu, key_history)
          values (${id}, ${c.specialty}, ${c.patient_name}, ${c.age}, ${c.sex}, ${c.quote}, ${c.complaint}, ${tx.json(c.vitals)}, ${c.minutes},
            false, ${userId}, ${c.setting}, ${c.demeanor}, ${c.organ_system}, ${c.clerkship}, ${tx.json(c.suggested)},
            ${tx.json(c.maneuvers)}, ${tx.json(c.test_menu)}, ${c.key_history})`;
        await tx`
          insert into private.case_content (case_id, facts, exam, tests, answer_key, condition_slug, severity, persona, rubric, focus, background_id, profile)
          values (${id}, ${tx.json(k.facts)}, ${tx.json(k.exam)}, ${tx.json(k.tests)}, ${tx.json(k.answer_key)},
            ${k.condition_slug}, ${k.severity}, ${tx.json(k.persona)}, ${tx.json(k.rubric)}, ${k.focus}, ${k.background_id},
            ${k.profile ? tx.json(k.profile) : null})`;
      });
      return id;
    } catch (error) {
      if ((error as { code?: string }).code !== "23505") throw error; // retry only on a bed-code collision
    }
  }
  throw new HttpError(500, "couldn't allocate a bed code");
}
