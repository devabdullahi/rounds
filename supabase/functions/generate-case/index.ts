// generate-case: makes a new fictional patient for the calling student.
//
//   1. Verify the caller and take one case from their daily allowance.
//   2. Use the case written ahead for this student and focus, if one is waiting (instant). Otherwise
//      pick a validated condition profile that matches their study focus, and queue one new
//      condition in that focus for prepare-profile to write in the background (prefetch.ts). When
//      the focus has no profile at all yet, reply 202 "preparing" and the app asks again shortly.
//   3. Plan the patient in code (severity, age, sex, findings, vitals, lab values), and pick a
//      synthetic background record of the same sex and a close age (background.ts), if one fits.
//   4. Have the LLM write the person around that plan: door note, voice, facts, exam findings,
//      study reports, test prices. It never chooses numbers or the diagnosis.
//   5. Check the writing (structure, no diagnosis leaks). A leak is reworded field by field; other
//      problems get a full rewrite with the problems listed.
//   6. Save the public door note and menus, and the private script, results and rubric.
//   7. After replying, write the student's next case for this focus (private.ready_cases).
import { body, callerId, HttpError, json, serve } from "../_shared/http.ts";
import { sql } from "../_shared/db.ts";
import { completeJSON, currentModel } from "../_shared/llm.ts";
import { CASE_FIXER, CASE_WRITER, PROMPT_VERSION } from "../_shared/prompts.ts";
import { acceptedNames, type CasePlan, leakTerms, planCase, type Profile } from "../_shared/casegen.ts";
import { flag, type Patient, TESTS } from "../_shared/labs.ts";
import { type Focus, parseFocus } from "../_shared/focus.ts";
import { prepareNext } from "../_shared/prefetch.ts";
import { refundQuota, takeQuota } from "../_shared/quota.ts";
import { MAX_AGE_GAP, type PatientBackground, pickBackground } from "./background.ts";
import { bedCode } from "./bedcode.ts";
import { applyFixes, buildRubric, checkWriting, fixPrompt, leakSpots, neutralIds, type Writing, writerPrompt } from "./writer.ts";

/** Tries at writing one patient. A typical write takes ~30 s on GPT-6 Luna, so three stay inside the
 *  function's time limit; a reply that fails the checks is retried with the problems listed. */
const WRITE_ATTEMPTS = 3;

type Request = { focus?: string };

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
  const { focus: requested = "" } = await body<Request>(req);
  const focus = parseFocus(requested);

  // A new patient counts against the daily limit (refunded on failure), whether it's written now or
  // was written ahead. The quota comes first: a student over the limit mustn't start background
  // writing either.
  await takeQuota(userId, "case");
  let rows: CaseRows | null;
  try {
    try {
      await prepareNext(focus);
    } catch (error) {
      // Prefetch only speeds up later cases; it must not cost the student this one.
      console.error("prepare next before writing", error);
    }
    rows = await claimReady(userId, focus);
    if (!rows) {
      const picked = await pickProfile(focus);
      rows = picked ? await composeCase(picked, focus) : null;
    }
  } catch (error) {
    await refundQuota(userId, "case");
    throw error;
  }
  if (!rows) {
    await refundQuota(userId, "case");
    const queued = await prepareNext(focus);
    if (queued.inFlight) return json({ status: "preparing" }, 202);
    throw new HttpError(404, "no conditions available for this focus yet");
  }

  let caseId: string;
  try {
    caseId = await insertCase(userId, rows);
  } catch (error) {
    await refundQuota(userId, "case");
    throw error;
  }
  // Writing takes ~30 s; doing the next one now means the student's next start is instant.
  EdgeRuntime.waitUntil(writeAhead(userId, focus));
  return json({ case_id: caseId, model: currentModel("case") });
});

async function pickProfile(focus: Focus): Promise<Picked | null> {
  const rows = await sql<Picked[]>`
    select profile, clerkships, organ_systems,
      coalesce((select array(select jsonb_array_elements_text(c.terms -> 'snomed' -> 'synonyms'))
                from private.conditions c where c.slug = condition_profiles.slug), '{}') as synonyms
    from private.condition_profiles
    where validation = 'passed' and review <> 'rejected'
      and (${focus.kind !== "rotation"} or ${focus.value} = any(clerkships))
      and (${focus.kind !== "system"} or ${focus.value} = any(organ_systems))
    order by random() limit 1`;
  return rows[0] ?? null;
}

/** Takes the student's case written ahead for this focus, if there is a fresh one. */
async function claimReady(userId: string, focus: Focus): Promise<CaseRows | null> {
  const [row] = await sql<{ rows: CaseRows; fresh: boolean }[]>`
    delete from private.ready_cases where user_id = ${userId} and focus = ${focus.stored}
    returning rows, created_at > now() - ${READY_FOR}::interval as fresh`;
  return row?.fresh ? row.rows : null;
}

/** Writes the student's next case for this focus in the background, unless one is already waiting.
 *  Failures only cost the speed-up, so they're logged, never raised. */
async function writeAhead(userId: string, focus: Focus): Promise<void> {
  try {
    const [{ waiting }] = await sql<{ waiting: boolean }[]>`
      select exists(select 1 from private.ready_cases where user_id = ${userId} and focus = ${focus.stored}) as waiting`;
    if (waiting) return;
    const picked = await pickProfile(focus);
    if (!picked) return;
    const rows = await composeCase(picked, focus);
    await sql`insert into private.ready_cases (user_id, focus, rows) values (${userId}, ${focus.stored}, ${sql.json(rows)})
      on conflict (user_id, focus) do nothing`;
  } catch (error) {
    console.error("generate-case: writing ahead failed", error);
  }
}

/** Plans the patient in code, has the model write them and checks the writing. */
async function composeCase({ profile, clerkships, organ_systems: systems, synonyms }: Picked, focus: Focus): Promise<CaseRows> {
  // Clinical psychology is a focus like any rotation; its cases are written as a psychologist's intake.
  const psychology = focus.kind === "rotation" && focus.value === "clinicalPsychology";
  const dermatology = focus.kind === "rotation" && focus.value === "dermatology";
  // A heart case: filed under cardiology or the cardiovascular system, or made for either focus.
  const cardiac = clerkships.includes("cardiology") || systems.includes("cardiovascular") ||
    (focus.kind === "rotation" && focus.value === "cardiology") || (focus.kind === "system" && focus.value === "cardiovascular");
  const plan = planCase(profile, Math.random, { psychology, dermatology, cardiac });
  const terms = leakTerms(profile);
  const background = await findBackground(plan, [profile.triage.name, ...acceptedNames(profile.teaching.accepted_names, synonyms)]);
  let user = writerPrompt(profile, plan, background);
  let writing: Writing | null = null;
  let problems: string[] = [];
  for (let attempt = 0; attempt < WRITE_ATTEMPTS; attempt++) {
    try {
      writing = await completeJSON<Writing>(CASE_WRITER, user, 7000, { task: "case" });
      problems = checkWriting(writing, plan, terms);
      if (problems.length) {
        writing = await fixLeaks(writing, terms);
        problems = checkWriting(writing, plan, terms);
      }
    } catch (error) {
      problems = [`reply unusable: ${(error as Error).message.slice(0, 200)}`];
    }
    if (problems.length === 0) break;
    user += `\n\nYour previous reply had these problems. Fix them and reply with the full JSON again:\n- ${problems.join("\n- ")}`;
  }
  if (!writing || problems.length > 0) {
    console.error("generate-case: writing failed", profile.slug, problems);
    throw new HttpError(502, "the patient couldn't be written; try again");
  }
  return buildRows(profile, clerkships, systems, synonyms, plan, neutralIds(writing), focus, background?.id ?? null);
}

/** Rewords only the fields that named the diagnosis. Leaks are the usual reason a writing fails, and
 *  this takes 2–3 s where a full rewrite takes 15–20 s. Returns the writing unchanged if it can't. */
async function fixLeaks(w: Writing, terms: string[]): Promise<Writing> {
  const { leaked, where } = leakSpots(w, terms);
  if (!leaked.length) return w;
  try {
    const reply = await completeJSON<{ fixes?: { where: string; text: string }[] }>(CASE_FIXER, fixPrompt(w, where, leaked), 1500, { task: "case" });
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
          insert into private.case_content (case_id, facts, exam, tests, answer_key, condition_slug, severity, persona, rubric, focus, background_id)
          values (${id}, ${tx.json(k.facts)}, ${tx.json(k.exam)}, ${tx.json(k.tests)}, ${tx.json(k.answer_key)},
            ${k.condition_slug}, ${k.severity}, ${tx.json(k.persona)}, ${tx.json(k.rubric)}, ${k.focus}, ${k.background_id})`;
      });
      return id;
    } catch (error) {
      if ((error as { code?: string }).code !== "23505") throw error; // retry only on a bed-code collision
    }
  }
  throw new HttpError(500, "couldn't allocate a bed code");
}


