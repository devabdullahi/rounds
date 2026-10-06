// Keeps profiles one step ahead of students. When a student starts or finishes a case in a topic,
// one condition in that topic that has no profile yet is queued, and prepare-profile writes it in
// the background, so the next case in the topic has a fresh condition ready.

import { sql } from "./db.ts";
import type { Focus } from "./focus.ts";

declare const EdgeRuntime: { waitUntil(promise: Promise<unknown>): void };

/** A job untouched this long is assumed dead (a call that hit the time limit) and is restarted. */
const STALE = "4 minutes";

export type Queued = { slug: string | null; inFlight: boolean };

/**
 * Queues the next condition for a focus. Returns the job to start (a new one, or one that stalled),
 * and whether the focus already has generation under way. At most one job runs per focus.
 */
export async function queueNext(focus: Focus): Promise<Queued> {
  const rotation = focus.kind === "rotation" ? focus.value : null;
  const system = focus.kind === "system" ? focus.value : null;

  const running = await sql<{ slug: string; stale: boolean }[]>`
    select j.slug, coalesce(j.locked_at, j.updated_at) < now() - ${STALE}::interval as stale
    from private.profile_jobs j join private.conditions c using (slug)
    where j.status in ('queued', 'running')
      and (${rotation}::text is null or ${rotation} = any(c.clerkships))
      and (${system}::text is null or ${system} = any(c.organ_systems))
    order by j.updated_at limit 1`;
  if (running.length) return { slug: running[0].stale ? running[0].slug : null, inFlight: true };

  // Most common conditions first, so early profiles are the ones students meet most.
  const added = await sql<{ slug: string }[]>`
    insert into private.profile_jobs (slug, requested_by)
    select c.slug, ${focus.stored} from private.conditions c
    where c.case_suitable
      and (${rotation}::text is null or ${rotation} = any(c.clerkships))
      and (${system}::text is null or ${system} = any(c.organ_systems))
      and not exists (select 1 from private.condition_profiles p where p.slug = c.slug)
      and not exists (select 1 from private.profile_jobs j where j.slug = c.slug)
    order by array_position(array['very_common', 'common', 'uncommon', 'rare'], c.commonness), random()
    limit 1
    on conflict (slug) do nothing
    returning slug`;
  return { slug: added[0]?.slug ?? null, inFlight: added.length > 0 };
}

/** Asks prepare-profile to advance a job. Returns once the request is accepted, not when it's done. */
export async function kick(slug: string): Promise<void> {
  try {
    const res = await fetch(`${Deno.env.get("SUPABASE_URL")}/functions/v1/prepare-profile`, {
      method: "POST",
      headers: { Authorization: `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")}`, "Content-Type": "application/json" },
      body: JSON.stringify({ slug }),
    });
    await res.body?.cancel();
    if (!res.ok) console.error("prepare-profile refused", slug, res.status);
  } catch (error) {
    // The next case start or grading restarts a stalled job, so a lost kick only costs time.
    console.error("prepare-profile unreachable", slug, error);
  }
}

/** Queues the next condition for a focus and starts it after the response is sent. */
export async function prepareNext(focus: Focus): Promise<Queued> {
  const queued = await queueNext(focus);
  if (queued.slug) EdgeRuntime.waitUntil(kick(queued.slug));
  return queued;
}
