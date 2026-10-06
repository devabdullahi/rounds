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
type Job = { slug: string; stage: number; attempt: number; profile: Json; feedback: string[]; errors: string[]; repairs: string[]; outages: number };

/** Model or lookup outages tolerated before a job is given up; a later request can requeue it. */
const MAX_OUTAGES = 3;
const MAX_TOKENS = 8000;
const TEMPERATURE = 0.3;

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
  const [job] = await sql<Job[]>`
    update private.profile_jobs set status = 'running', locked_at = now(), updated_at = now()
    where slug = ${slug} and (status = 'queued' or (status = 'running' and locked_at < now() - interval '4 minutes'))
    returning slug, stage, attempt, profile, feedback, errors, repairs, outages`;
  if (!job) return; // done, failed, or another call has it

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
      outages = ${outages}, locked_at = null, updated_at = now() where slug = ${slug}`;
    return;
  }

  if (errors.length && job.attempt === 0) {
    await sql`update private.profile_jobs set status = 'queued', attempt = 1, feedback = ${errors},
      repairs = ${[...job.repairs, ...repairs]}, locked_at = null, updated_at = now() where slug = ${slug}`;
    await kick(slug);
    return;
  }

  // Passed, or failed its retry: keep the output either way; validation decides at the end.
  Object.assign(profile, output);
  profile.generation.stages.push({
    stage: STAGES[job.stage].name, model: currentModel(), prompt_version: PROFILE_PROMPT_VERSION, generated_at: new Date().toISOString(),
  });
  const next = job.stage + 1;
  const allErrors = [...job.errors, ...errors];
  const allRepairs = [...job.repairs, ...repairs];
  if (next < STAGES.length) {
    await sql`update private.profile_jobs set status = 'queued', stage = ${next}, attempt = 0, feedback = '{}',
      profile = ${sql.json(profile)}, errors = ${allErrors}, repairs = ${allRepairs}, locked_at = null, updated_at = now()
      where slug = ${slug}`;
    await kick(slug);
    return;
  }
  await finish(slug, profile, allRepairs);
}

/** One stage attempt. Throws only when the model or a lookup service is unreachable. */
async function attempt(job: Job, condition: { triage: Json; background: string }, profile: Json) {
  const user = stagePrompt(job.stage, condition.triage.name, condition.background, profile, job.feedback);
  let reply: Json;
  try {
    reply = await completeJSON<Json>(SYSTEM_PROMPT, user, MAX_TOKENS, TEMPERATURE);
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

async function finish(slug: string, profile: Json, repairs: string[]): Promise<void> {
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
  const clerkships = [...new Set([t.primary_clerkship, ...(t.secondary_clerkships ?? [])])];
  await sql.begin(async (tx) => {
    await tx`
      insert into private.condition_profiles (slug, name, primary_clerkship, clerkships, organ_systems, validation, review, profile)
      values (${slug}, ${t.name}, ${t.primary_clerkship}, ${clerkships}, ${t.organ_systems ?? []}, ${status}, 'pending', ${tx.json(profile)})
      on conflict (slug) do update set validation = excluded.validation, profile = excluded.profile, updated_at = now()`;
    await tx`update private.profile_jobs set status = ${status === "passed" ? "done" : "failed"}, profile = ${tx.json(profile)},
      locked_at = null, updated_at = now() where slug = ${slug}`;
  });
  console.log("prepare-profile finished", slug, status, errors.slice(0, 5));
}
