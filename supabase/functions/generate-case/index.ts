// generate-case: makes a new fictional patient for the calling student.
//
//   1. Verify the caller.
//   2. Pick a validated condition profile that matches their study focus, and queue one new
//      condition in that focus for prepare-profile to write in the background (prefetch.ts). When
//      the focus has no profile at all yet, reply 202 "preparing" and the app asks again shortly.
//   3. Plan the patient in code (severity, age, sex, findings, vitals, lab values).
//   4. Have the LLM write the person around that plan: door note, voice, facts, exam findings,
//      study reports, test prices. It never chooses numbers or the diagnosis.
//   5. Check the writing (structure, no diagnosis leaks) and retry once with the problems.
//   6. Save the public door note and menus, and the private script, results and rubric.
import { body, callerId, HttpError, json, serve } from "../_shared/http.ts";
import { sql } from "../_shared/db.ts";
import { completeJSON, currentModel } from "../_shared/llm.ts";
import { CASE_WRITER, PROMPT_VERSION } from "../_shared/prompts.ts";
import { acceptedNames, caseBudget, type CasePlan, leakTerms, planCase, type Profile } from "../_shared/casegen.ts";
import { flag, type Patient, TESTS } from "../_shared/labs.ts";
import { type Focus, parseFocus } from "../_shared/focus.ts";
import { prepareNext } from "../_shared/prefetch.ts";
import { refundQuota, takeQuota } from "../_shared/quota.ts";
import { bedCode } from "./bedcode.ts";
import { buildRubric, checkWriting, neutralIds, type Writing, writerPrompt } from "./writer.ts";

type Request = { focus?: string };

serve(async (req) => {
  const userId = await callerId(req);
  const { focus: requested = "" } = await body<Request>(req);
  const focus = parseFocus(requested);

  const rows = await sql<{ profile: Profile; clerkships: string[]; organ_systems: string[]; synonyms: string[] }[]>`
    select profile, clerkships, organ_systems,
      coalesce((select array(select jsonb_array_elements_text(c.terms -> 'snomed' -> 'synonyms'))
                from private.conditions c where c.slug = condition_profiles.slug), '{}') as synonyms
    from private.condition_profiles
    where validation = 'passed' and review <> 'rejected'
      and (${focus.kind !== "rotation"} or ${focus.value} = any(clerkships))
      and (${focus.kind !== "system"} or ${focus.value} = any(organ_systems))
    order by random() limit 1`;
  if (rows.length === 0) {
    const queued = await prepareNext(focus);
    if (queued.inFlight) return json({ status: "preparing" }, 202);
    throw new HttpError(404, "no conditions available for this focus yet");
  }
  const { profile, clerkships, organ_systems: systems, synonyms } = rows[0];

  // A new patient costs a model call, so it counts against the daily limit (refunded on failure).
  // The quota comes first: a student over the limit mustn't start background profile writing either.
  await takeQuota(userId, "case");
  try {
    try {
      await prepareNext(focus);
    } catch (error) {
      // Prefetch only speeds up the next case; it must not cost the student this one.
      console.error("prepare next before writing", error);
    }
    return await writeCase(userId, profile, clerkships, systems, synonyms, focus);
  } catch (error) {
    await refundQuota(userId, "case");
    throw error;
  }
});

/** Plans the patient in code, has the model write them, checks the writing, and saves the case. */
async function writeCase(userId: string, profile: Profile, clerkships: string[], systems: string[], synonyms: string[], focus: Focus): Promise<Response> {
  // Clinical psychology is a focus like any rotation; its cases are written as a psychologist's intake.
  const psychology = focus.kind === "rotation" && focus.value === "clinicalPsychology";
  const dermatology = focus.kind === "rotation" && focus.value === "dermatology";
  const plan = planCase(profile, Math.random, { psychology, dermatology });
  const terms = leakTerms(profile);
  let user = writerPrompt(profile, plan);
  let writing: Writing | null = null;
  let problems: string[] = [];
  for (let attempt = 0; attempt < 2; attempt++) {
    try {
      writing = await completeJSON<Writing>(CASE_WRITER, user, 7000);
      problems = checkWriting(writing, plan, terms);
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

  const caseId = await save(userId, profile, clerkships, systems, synonyms, plan, neutralIds(writing), focus);
  return json({ case_id: caseId, model: currentModel() });
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

async function save(userId: string, profile: Profile, clerkships: string[], systems: string[], synonyms: string[], plan: CasePlan, w: Writing, focus: Focus): Promise<string> {
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
  const indicatedCost = tests.filter((t) => t.role === "indicated").reduce((s, t) => s + t.cost, 0);
  const budget = caseBudget(indicatedCost);

  for (let attempt = 0; attempt < 5; attempt++) {
    const id = bedCode();
    try {
      await sql.begin(async (tx) => {
        await tx`
          insert into public.cases (id, specialty, patient_name, age, sex, quote, complaint, vitals, budget, minutes,
            published, created_by, setting, demeanor, organ_system, clerkship, suggested, maneuvers, test_menu, key_history)
          values (${id}, ${profile.triage.primary_clerkship}, ${w.patient.name}, ${plan.age}, ${plan.sex},
            ${w.patient.quote}, ${w.patient.complaint}, ${tx.json(doorVitals(plan))}, ${budget}, 10,
            false, ${userId}, ${w.patient.setting}, ${w.patient.demeanor}, ${caseSystem(profile, systems, focus)},
            ${caseClerkship(profile, clerkships, focus)}, ${tx.json(w.suggested)},
            ${tx.json(w.maneuvers.map(({ id, title }) => ({ id, title })))},
            ${tx.json(tests.map(({ id, name, detail, cost, turnaround_s, delays_care_min }) =>
              ({ id, name, detail, cost, turnaround_s, delays_care_min })))},
            ${w.facts.filter((f) => f.importance !== "optional").length})`;
        await tx`
          insert into private.case_content (case_id, facts, exam, tests, answer_key, condition_slug, severity, persona, rubric, focus)
          values (${id}, ${tx.json(w.facts)}, ${tx.json(w.maneuvers)}, ${tx.json(tests)},
            ${tx.json({ diagnosis: profile.triage.name, accepted: acceptedNames(profile.teaching.accepted_names, synonyms) })},
            ${profile.slug}, ${plan.severity}, ${tx.json({ ...w.persona, name: w.patient.name, age: plan.age, sex: plan.sex, pregnant: plan.pregnant, model: currentModel(), prompt_version: PROMPT_VERSION })},
            ${tx.json(buildRubric(profile, plan, w, tests))}, ${focus.stored})`;
      });
      return id;
    } catch (error) {
      if ((error as { code?: string }).code !== "23505") throw error; // retry only on a bed-code collision
    }
  }
  throw new HttpError(500, "couldn't allocate a bed code");
}


