// prepare-profile: writes a condition profile on demand, one LLM attempt per call.
//
// Internal only: generate-case and case-session call it with the service role key (prefetch.ts),
// and it calls itself for each next step. A profile takes five stages; each stage gets a first
// attempt and, if checks fail, one retry with the errors. Saving after every attempt keeps each
// call under the edge runtime's time limit and lets a call that died be resumed.
//
//   1. Verify the caller is the service role.
//   2. Claim the job (queued, or running but stale), so two calls never work on it at once.
//   3. Run one stage attempt: prompt → model → repairs → schema, rule and SNOMED/RxNorm checks.
//   4. Save progress and start the next step; after the last stage, validate and store the profile
//      in private.condition_profiles (review "pending" until a clinician looks at it).

import { body, HttpError, json, serve } from "../_shared/http.ts";
import { sql } from "../_shared/db.ts";
import { completeJSON, currentModel } from "../_shared/llm.ts";
import {
  dropEmptyOptional, PROFILE_PROMPT_VERSION, repair, ruleErrors, ruleWarnings, sectionErrors, STAGES,
  stageOutput, stagePrompt, SYSTEM_PROMPT, termSummary, validate,
} from "../_shared/profilegen.ts";
import { checkTerms, umlsKey } from "../_shared/terms.ts";
import { kick } from "../_shared/prefetch.ts";

declare const EdgeRuntime: { waitUntil(promise: Promise<unknown>): void };

// deno-lint-ignore no-explicit-any
type Json = any;
type Job = { slug: string; token: string; stage: number; attempt: number; profile: Json; feedback: string[]; errors: string[]; repairs: string[]; outages: number };

/** Model or lookup outages tolerated before a job is given up; a later request can requeue it. */
const MAX_OUTAGES = 3;
const MAX_TOKENS = 8000;
const TEMPERATURE = 0.3;
/** A stage reply runs to 8,000 tokens, longer than the default model timeout allows; this still
 *  ends the call before the edge runtime's 150 s wall clock, so the job is saved as an outage. */
const TIMEOUT_MS = 140_000;

serve(async (req) => {
  const auth = req.headers.get("Authorization") ?? "";
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!key || auth !== `Bearer ${key}`) throw new HttpError(401, "internal function");
  const { slug } = await body<{ slug?: unknown }>(req);
  if (typeof slug !== "string" || !/^[a-z0-9-]{1,120}$/.test(slug)) throw new HttpError(400, "slug required");
  umlsKey(); // fail before claiming the job when the SNOMED check can't run

  EdgeRuntime.waitUntil(step(slug).catch((error) => console.error("prepare-profile", slug, error)));
  return json({ accepted: true }, 202);
});

async function step(slug: string): Promise<void> {
  // locked_at doubles as this call's ownership token (as text, to keep its microseconds). Every
  // later write requires it unchanged, so a call that ran past the stale limit and lost the job to
  // a restart can't overwrite the newer call's progress.
  const [job] = await sql<Job[]>`
    update private.profile_jobs set status = 'running', locked_at = clock_timestamp(), updated_at = now()
    where slug = ${slug} and (status = 'queued' or (status = 'running' and locked_at < now() - interval '4 minutes'))
    returning slug, locked_at::text as token, stage, attempt, profile, feedback, errors, repairs, outages`;
  if (!job) return; // done, failed, or another call has it
  const token = job.token;

  const [condition] = await sql<{ triage: Json; background: string }[]>`
    select triage, background from private.conditions where slug = ${slug}`;
  const profile: Json = Object.keys(job.profile).length ? job.profile : {
    schema_version: "0.2", slug, triage: condition.triage,
    generation: { stages: [], validation: { status: "pending" }, review: { status: "pending" } },
  };

  let output: Json;
  let errors: string[];
  let repairs: string[];
  try {
    ({ output, errors, repairs } = await attempt(job, condition, profile));
  } catch (error) {
    // The model or a terminology service couldn't be reached: says nothing about the condition.
    const outages = job.outages + 1;
    console.error("prepare-profile outage", slug, outages, (error as Error).message.slice(0, 200));
    await sql`update private.profile_jobs set status = ${outages >= MAX_OUTAGES ? "failed" : "queued"},
      outages = ${outages}, locked_at = null, updated_at = now() where slug = ${slug} and locked_at = ${token}::timestamptz`;
    return;
  }

  if (errors.length && job.attempt === 0) {
    const owned = await sql`update private.profile_jobs set status = 'queued', attempt = 1, feedback = ${errors},
      repairs = ${[...job.repairs, ...repairs]}, locked_at = null, updated_at = now()
      where slug = ${slug} and locked_at = ${token}::timestamptz returning slug`;
    if (owned.length) await kick(slug);
    return;
  }

  // Passed, or failed its retry: keep the output either way; validation decides at the end.
  Object.assign(profile, output);
  profile.generation.stages.push({
    stage: STAGES[job.stage].name, model: currentModel("profile"), prompt_version: PROFILE_PROMPT_VERSION, generated_at: new Date().toISOString(),
  });
  const next = job.stage + 1;
  const allErrors = [...job.errors, ...errors];
  const allRepairs = [...new Set([...job.repairs, ...repairs])];
  if (next < STAGES.length) {
    const owned = await sql`update private.profile_jobs set status = 'queued', stage = ${next}, attempt = 0, feedback = '{}',
      profile = ${sql.json(profile)}, errors = ${allErrors}, repairs = ${allRepairs}, locked_at = null, updated_at = now()
      where slug = ${slug} and locked_at = ${token}::timestamptz returning slug`;
    if (owned.length) await kick(slug);
    return;
  }
  await finish(slug, token, profile, allRepairs);
}

/** One stage attempt. Throws only when the model or a lookup service is unreachable. */
async function attempt(job: Job, condition: { triage: Json; background: string }, profile: Json) {
  const user = stagePrompt(job.stage, condition.triage.name, condition.background, profile, job.feedback);
  let reply: Json;
  try {
    reply = await completeJSON<Json>(SYSTEM_PROMPT, user, MAX_TOKENS, { task: "profile", temperature: TEMPERATURE, timeoutMs: TIMEOUT_MS });
  } catch (error) {
    if (error instanceof SyntaxError) return { output: {}, errors: [`reply unusable: ${error.message}`], repairs: [] };
    throw error;
  }
  const { output, missing } = stageOutput(job.stage, reply);
  const repairs = repair(output);
  let errors = [...missing, ...Object.entries(output).flatMap(([s, v]) => sectionErrors(s, v))];
  if (!errors.length) {
    // Only errors this stage introduces count; earlier failures are already recorded.
    const baseline = new Set(ruleErrors(profile));
    errors = ruleErrors({ ...profile, ...output }).filter((e) => !baseline.has(e));
  }
  errors.push(...await checkTerms(output));
  return { output, errors, repairs };
}

async function finish(slug: string, token: string, profile: Json, repairs: string[]): Promise<void> {
  dropEmptyOptional(profile);
  repairs = [...repairs, ...repair(profile)];
  const terms = termSummary(profile);
  const errors = [...new Set([...validate(profile), ...terms.errors])].sort();
  const known = new Set<string>((await sql<{ slug: string }[]>`select slug from private.condition_profiles`).map((r) => r.slug));
  known.add(slug);
  const status = errors.length ? "failed" : "passed";
  profile.generation.validation = {
    status,
    rule_errors: errors,
    review_issues: [...repairs.map((r) => `auto-repaired: ${r}`), ...terms.notes, ...ruleWarnings(profile, known)],
  };
  const t = profile.triage;
  // Study topics come from the catalog: triage rotations plus tagged specialties (tag_specialties.py).
  const [catalog] = await sql<{ clerkships: string[]; organ_systems: string[] }[]>`
    select clerkships, organ_systems from private.conditions where slug = ${slug}`;
  // Body systems too: the catalog's re-filing (tag_systems.py) beats triage's ten-system pick.
  const systems = catalog?.organ_systems?.length ? catalog.organ_systems : t.organ_systems ?? [];
  const clerkships = [...new Set([t.primary_clerkship, ...(t.secondary_clerkships ?? []), ...(catalog?.clerkships ?? [])])];
  const saved = await sql.begin(async (tx) => {
    // Release the job first: if another call took it over, this one saves nothing.
    const owned = await tx`update private.profile_jobs set status = ${status === "passed" ? "done" : "failed"}, profile = ${tx.json(profile)},
      locked_at = null, updated_at = now() where slug = ${slug} and locked_at = ${token}::timestamptz returning slug`;
    if (!owned.length) return false;
    // A rewritten profile is new content: it goes back to review and takes the catalog's current topics.
    await tx`
      insert into private.condition_profiles (slug, name, primary_clerkship, clerkships, organ_systems, validation, review, profile)
      values (${slug}, ${t.name}, ${t.primary_clerkship}, ${clerkships}, ${systems}, ${status}, 'pending', ${tx.json(profile)})
      on conflict (slug) do update set name = excluded.name, primary_clerkship = excluded.primary_clerkship,
        clerkships = excluded.clerkships, organ_systems = excluded.organ_systems, validation = excluded.validation,
        review = 'pending', profile = excluded.profile, updated_at = now()`;
    return true;
  });
  if (!saved) {
    console.log("prepare-profile lost the job before saving", slug);
    return;
  }
  console.log("prepare-profile finished", slug, status, errors.slice(0, 5));
}
