// Picking the next condition for a student and getting its profile: the stored one when it has a
// validated profile, else one built live (and saved when it passes its checks).
import { HttpError } from "../_shared/http.ts";
import { completeJSON } from "../_shared/llm.ts";
import { takeBudget } from "../_shared/usage.ts";
import type { Profile } from "../_shared/casegen.ts";
import type { Focus } from "../_shared/focus.ts";
import { checkTerms, umlsKey } from "../_shared/terms.ts";
import { buildLiveProfile } from "../_shared/liveprofile.ts";
import { SYSTEM_PROMPT } from "../_shared/profilegen.ts";
import { agesUsable } from "../_shared/agecheck.ts";
import { vitalErrors } from "../_shared/vitalcheck.ts";
import { timeoutFor } from "./compose.ts";
import { nextCondition, saveProfile } from "./stores.ts";
import type { Picked, Source } from "./types.ts";

/** Live profile builds per case: a condition whose profile still fails its checks is swapped. */
const LIVE_TRIES = 2;
/** Conditions looked at per case, counting stored profiles skipped for impossible ages. */
const MAX_PICKS = 6;
const TEMPLATE_TIMEOUT_MS = 30_000;

/** Where the pick comes from: `waiting` when a student is waiting (stored profiles first among
 *  conditions they've never had), `tried` to skip conditions already tried for this case, and
 *  `onPick` to record the condition the moment it's chosen (a background job does, so a case
 *  written meanwhile picks another). */
export type PickOptions = { waiting: boolean; tried?: string[]; onPick?: (slug: string) => Promise<void> };

/** The student's next condition in the focus with its profile (see nextCondition for the order).
 *  Null when the focus has no usable condition, or none built cleanly within LIVE_TRIES. */
export async function pickProfile(userId: string, focus: Focus, deadline: number, opts: PickOptions): Promise<(Picked & { source: Source }) | null> {
  const tried = [...(opts.tried ?? [])];
  let builds = 0;
  for (let pick = 0; pick < MAX_PICKS && builds < LIVE_TRIES; pick++) {
    if (Date.now() >= deadline) break;
    const c = await nextCondition(userId, focus, tried, opts.waiting);
    if (!c) return null;
    tried.push(c.slug);
    // A stored profile written with ages in months would plan a six-year-old with an infant disease.
    if (c.stored && !agesUsable(c.stored)) {
      console.warn("generate-case: stored profile has impossible ages, skipped", c.slug);
      continue;
    }
    // A stored profile whose vitals plan impossible values (a newborn's own numbers, shifted for
    // their age a second time) is rebuilt live, where vitals are written against adult normals,
    // and the rebuild replaces it.
    const broken = c.stored ? vitalErrors(c.stored) : [];
    if (broken.length) console.warn("generate-case: stored profile has impossible vitals, rebuilding", c.slug, broken.slice(0, 3));
    await opts.onPick?.(c.slug);
    const topics = { clerkships: c.clerkships, organ_systems: c.organ_systems, synonyms: c.synonyms };
    if (c.stored && !broken.length) return { profile: c.stored, ...topics, source: "stored" };
    // Out of content budget: say so now, rather than build a profile whose calls are all refused.
    await takeBudget("template");
    builds++;
    const { profile, problems } = await buildLiveProfile(c.slug, c.triage, c.background ?? "", {
      umlsKey: umlsKey(),
      system: SYSTEM_PROMPT,
      complete: (system, user) => completeJSON(system, user, 8000, {
        task: "template", temperature: 0.3, timeoutMs: timeoutFor(deadline, TEMPLATE_TIMEOUT_MS),
      }),
      // Time-boxed: terms it can't check in time are left unverified rather than holding the case.
      termErrors: (output) => checkTerms(output, undefined, Math.min(Date.now() + 8000, deadline)).catch(() => []),
    });
    if (problems.length === 0) {
      // Saved even when time ran out, so the next tap doesn't build it again.
      await saveProfile(c, profile as Profile, broken.length > 0);
      if (Date.now() >= deadline) throw new HttpError(504, "patient generation timed out; try again");
      return { profile: profile as Profile, ...topics, source: "live" };
    }
    if (Date.now() >= deadline) throw new HttpError(504, "patient generation timed out; try again");
    console.warn("generate-case: live profile failed its checks", c.slug, problems.slice(0, 5));
  }
  return null;
}
