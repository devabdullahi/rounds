// Every database read and write generate-case makes: the catalog and its profiles, the student's
// history, cases written ahead and their job slots, and saving a case. The other modules stay pure
// or talk only to models.
import { sql } from "../_shared/db.ts";
import { HttpError } from "../_shared/http.ts";
import { FREE_CASES_USED } from "../_shared/plan.ts";
import type { CasePlan, Profile } from "../_shared/casegen.ts";
import { type Focus, settingTags } from "../_shared/focus.ts";
import { MAX_AGE_GAP, type PatientBackground, pickBackground } from "./background.ts";
import { bedCode } from "./bedcode.ts";
import type { CaseRows, Condition, GenerationStart, History } from "./types.ts";

/** A case written ahead and not started within this long is thrown away, so profiles that were
 *  fixed or rejected meanwhile don't reach students. */
const READY_FOR = "3 days";

/** The next condition for this student and focus (and care setting, if one is picked), never one in `tried`. Conditions they've never
 *  had come first, so nothing repeats until the topic is used up; after that, the ones they had
 *  longest ago (by day, then chance, so one condition that keeps failing can't block every tap).
 *  Among equals, a condition with a stored profile wins when a student is waiting, then chance.
 *  Skipped: a condition already waiting for them as a written-ahead case, or being written for them
 *  by a background job right now. History counts deleted patients too (their fingerprints stay). */
export async function nextCondition(userId: string, focus: Focus, tried: string[], waiting: boolean): Promise<Condition | null> {
  const [c] = await sql<Condition[]>`
    with had as (
      select cc.condition_slug as slug, cs.created_at as at
      from public.cases cs join private.case_content cc on cc.case_id = cs.id
      where cs.created_by = ${userId} and cc.condition_slug is not null
      union all
      select condition_slug, created_at from private.patient_fingerprints
      where user_id = ${userId} and condition_slug is not null
    ), seen as (
      select slug, max(at) as last from had group by slug
    ), ahead as (
      select rows -> 'content' ->> 'condition_slug' as slug from private.ready_cases where user_id = ${userId}
      union all
      select slug from private.case_generation_jobs
      where user_id = ${userId} and status = 'running' and started_at > now() - interval '3 minutes'
    )
    select c.slug, c.triage, c.background, c.clerkships, c.organ_systems,
      coalesce(array(select jsonb_array_elements_text(c.terms -> 'snomed' -> 'synonyms')), '{}') as synonyms,
      p.profile as stored
    from private.conditions c
    left join private.condition_profiles p on p.slug = c.slug and p.validation = 'passed' and p.review <> 'rejected'
    left join seen s on s.slug = c.slug
    where c.case_suitable and c.triage is not null and not (c.slug = any(${tried}::text[]))
      and c.slug not in (select slug from ahead where slug is not null)
      and (${focus.kind !== "rotation"} or ${focus.value} = any(c.clerkships))
      and (${focus.kind !== "system"} or ${focus.value} = any(c.organ_systems))
      and (${!focus.setting} or exists (
        select 1 from jsonb_array_elements_text(c.triage -> 'settings') t where t = any(${settingTags(focus.setting)}::text[])))
    order by (s.slug is not null) asc, date_trunc('day', s.last) asc nulls first, (${waiting} and p.profile is not null) desc, random()
    limit 1`;
  return c ?? null;
}

/** The student's patients so far: fingerprints and names, so the next one is never the same. */
export async function studentHistory(userId: string): Promise<History> {
  const [fingerprints, names] = await Promise.all([
    sql<{ fingerprint: string }[]>`select fingerprint from private.patient_fingerprints where user_id = ${userId}`,
    sql<{ name: string }[]>`select patient_name as name from public.cases where created_by = ${userId}`,
  ]);
  return { fingerprints: new Set(fingerprints.map((r) => r.fingerprint)), names: new Set(names.map((r) => r.name)) };
}

/** Keeps a live profile that passed its checks, so the condition's next case starts from it. It
 *  goes to review like any new profile, and replaces a stored one only when `replace` says the
 *  stored one failed its checks. A failed save fails the case: its content points at this row. */
export async function saveProfile(c: Condition, profile: Profile, replace = false): Promise<void> {
  const t = profile.triage;
  // deno-lint-ignore no-explicit-any
  const json = sql.json(profile as any);
  try {
    await sql`
      insert into private.condition_profiles (slug, name, primary_clerkship, clerkships, organ_systems, validation, review, profile)
      values (${c.slug}, ${t.name}, ${t.primary_clerkship}, ${c.clerkships}, ${c.organ_systems}, 'passed', 'pending', ${json})
      on conflict (slug) do update set profile = excluded.profile, name = excluded.name, validation = 'passed',
        review = 'pending', updated_at = now()
      where ${replace}`;
  } catch (error) {
    console.error("generate-case: saving the live profile failed", c.slug, error);
    throw new HttpError(503, "Couldn't prepare a patient just now. Tap to try again.");
  }
}

/** A synthetic background for the planned patient, or null when none fits or the table can't be
 *  read: a background only adds texture, so it never stops a case from being written. */
export async function findBackground(plan: CasePlan, diagnosisNames: string[]): Promise<PatientBackground | null> {
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

/** Takes the student's case written ahead for this focus, if there is a fresh one. */
export async function claimReady(userId: string, focus: Focus): Promise<CaseRows | null> {
  const [row] = await sql<{ rows: CaseRows; fresh: boolean }[]>`
    delete from private.ready_cases where user_id = ${userId} and focus = ${focus.stored}
    returning rows, created_at > now() - ${READY_FOR}::interval as fresh`;
  return row?.fresh ? row.rows : null;
}

/** Whether a case for this student and focus is already written and waiting. */
export async function hasReady(userId: string, focus: Focus): Promise<boolean> {
  const [{ waiting }] = await sql<{ waiting: boolean }[]>`
    select exists(select 1 from private.ready_cases where user_id = ${userId} and focus = ${focus.stored}) as waiting`;
  return waiting;
}

/** Claims the one background generation slot for this student and focus. The token is the slot's
 *  started_at as text, and is only ever compared as text: passed back as a parameter cast to
 *  timestamptz, the client turned it into a JS Date and dropped the microseconds, so no job ever
 *  matched its own slot and every case written in the background was thrown away. */
export async function startGeneration(userId: string, focus: Focus): Promise<GenerationStart> {
  return await sql.begin(async (tx) => {
    await tx`insert into private.case_generation_jobs (user_id, focus) values (${userId}, ${focus.stored})
      on conflict (user_id, focus) do nothing`;
    const [job] = await tx<{ status: "queued" | "running" | "failed"; stale: boolean }[]>`
      select status, started_at < now() - interval '3 minutes' as stale
      from private.case_generation_jobs where user_id = ${userId} and focus = ${focus.stored}
      for update`;
    if (!job) throw new Error("generation job disappeared before it could start");
    if (job.status === "running" && !job.stale) return { status: "pending" };
    const [started] = await tx<{ token: string }[]>`
      update private.case_generation_jobs set status = 'running', started_at = clock_timestamp()
      where user_id = ${userId} and focus = ${focus.stored}
      returning started_at::text as token`;
    return { status: "started", token: started.token };
  });
}

/** Marks the condition a running job picked, so a case written for the student meanwhile skips it. */
export async function recordJobPick(userId: string, focus: Focus, token: string, slug: string): Promise<void> {
  await sql`update private.case_generation_jobs set slug = ${slug}
    where user_id = ${userId} and focus = ${focus.stored} and started_at::text = ${token}`;
}

/** Releases the slot, keeping the written case (if any) for the student's next start. */
export async function finishGeneration(
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

/** Saves a case for the student under a fresh bed code, with its fingerprint. The fingerprint's key
 *  turns down an identical patient written for the same student at the same moment. */
export async function insertCase(userId: string, { case: c, content: k, fingerprint }: CaseRows, freeLimit?: number): Promise<string> {
  for (let attempt = 0; attempt < 5; attempt++) {
    const id = bedCode();
    try {
      await sql.begin(async (tx) => {
        // A free case: one save at a time per student, and none past the limit (plan.ts FREE_CASES).
        if (freeLimit !== undefined) {
          await tx`select pg_advisory_xact_lock(hashtextextended(${userId}, 0))`;
          const [{ written }] = await tx<{ written: number }[]>`
            select greatest((select count(*)::int from public.cases where created_by = ${userId}),
                            (select count(*)::int from private.patient_fingerprints where user_id = ${userId})) as written`;
          if (written >= freeLimit) throw new HttpError(402, FREE_CASES_USED);
        }
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
        if (fingerprint) {
          await tx`insert into private.patient_fingerprints (user_id, fingerprint, case_id, condition_slug)
            values (${userId}, ${fingerprint}, ${id}, ${k.condition_slug})`;
        }
      });
      return id;
    } catch (error) {
      const e = error as { code?: string; constraint_name?: string };
      if (e.code === "23505" && e.constraint_name === "patient_fingerprints_pkey") {
        throw new HttpError(409, "That patient was just written for you. Tap to get another.");
      }
      if (e.code !== "23505") throw error; // retry only on a bed-code collision
    }
  }
  throw new HttpError(500, "couldn't allocate a bed code");
}
