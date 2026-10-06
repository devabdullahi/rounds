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
import { type CasePlan, leakTerms, planCase, type Profile } from "../_shared/casegen.ts";
import { flag, type Patient, TESTS } from "../_shared/labs.ts";
import { type Focus, parseFocus } from "../_shared/focus.ts";
import { prepareNext } from "../_shared/prefetch.ts";
import { buildRubric, checkWriting, neutralIds, type Writing, writerPrompt } from "./writer.ts";

type Request = { focus?: string };

serve(async (req) => {
  const userId = await callerId(req);
  const { focus: requested = "" } = await body<Request>(req);
  const focus = parseFocus(requested);

  const rows = await sql<{ profile: Profile }[]>`
    select profile from private.condition_profiles
    where validation = 'passed' and review <> 'rejected'
      and (${focus.kind !== "rotation"} or ${focus.value} = any(clerkships))
      and (${focus.kind !== "system"} or ${focus.value} = any(organ_systems))
    order by random() limit 1`;
  const queued = await prepareNext(focus);
  if (rows.length === 0) {
    if (queued.inFlight) return json({ status: "preparing" }, 202);
    throw new HttpError(404, "no conditions available for this focus yet");
  }
  const profile = rows[0].profile;

  const plan = planCase(profile, Math.random);
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

  const caseId = await save(userId, profile, plan, neutralIds(writing), focus);
  return json({ case_id: caseId, model: currentModel() });
});

function bedCode(): string {
  const letters = "ABCDEFGHJKLMNPRSTUVWXYZ";
  return letters[Math.floor(Math.random() * letters.length)] + String(Math.floor(Math.random() * 90) + 10);
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

async function save(userId: string, profile: Profile, plan: CasePlan, w: Writing, focus: Focus): Promise<string> {
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
  const budget = Math.max(200, Math.ceil((indicatedCost * 1.5) / 50) * 50);

  for (let attempt = 0; attempt < 5; attempt++) {
    const id = bedCode();
    try {
      await sql.begin(async (tx) => {
        await tx`
          insert into public.cases (id, specialty, patient_name, age, sex, quote, complaint, vitals, budget, minutes,
            published, created_by, setting, demeanor, organ_system, clerkship, suggested, maneuvers, test_menu, key_history)
          values (${id}, ${profile.triage.primary_clerkship}, ${w.patient.name}, ${plan.age}, ${plan.sex},
            ${w.patient.quote}, ${w.patient.complaint}, ${tx.json(doorVitals(plan))}, ${budget}, 10,
            false, ${userId}, ${w.patient.setting}, ${w.patient.demeanor}, ${profile.triage.organ_systems[0]},
            ${profile.triage.primary_clerkship}, ${tx.json(w.suggested)},
            ${tx.json(w.maneuvers.map(({ id, title }) => ({ id, title })))},
            ${tx.json(tests.map(({ id, name, detail, cost, turnaround_s, delays_care_min }) =>
              ({ id, name, detail, cost, turnaround_s, delays_care_min })))},
            ${w.facts.filter((f) => f.importance !== "optional").length})`;
        await tx`
          insert into private.case_content (case_id, facts, exam, tests, answer_key, condition_slug, severity, persona, rubric, focus)
          values (${id}, ${tx.json(w.facts)}, ${tx.json(w.maneuvers)}, ${tx.json(tests)},
            ${tx.json({ diagnosis: profile.triage.name, accepted: profile.teaching.accepted_names })},
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


