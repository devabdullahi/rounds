// Picking the next condition for a student and getting its profile: the stored one when it has a
// validated profile, else one built live (and saved when it passes its checks).
import { HttpError } from "../_shared/http.ts";
import { completeJSON } from "../_shared/llm.ts";
import type { Profile } from "../_shared/casegen.ts";
import type { Focus } from "../_shared/focus.ts";
import { checkTerms, umlsKey } from "../_shared/terms.ts";
import { buildLiveProfile } from "../_shared/liveprofile.ts";
import { SYSTEM_PROMPT } from "../_shared/profilegen.ts";
import { timeoutFor } from "./compose.ts";
import { nextCondition, saveProfile } from "./stores.ts";
import type { Picked, Source } from "./types.ts";

/** Live profile attempts per case: a condition whose profile still fails its checks is swapped. */
const LIVE_TRIES = 2;
const TEMPLATE_TIMEOUT_MS = 30_000;

/** The student's next condition in the focus with its profile (see nextCondition for the order).
 *  `waiting`: a student is waiting, so among conditions they've never had, one with a stored profile
 *  goes first. Null when the focus has no condition, or none built cleanly within LIVE_TRIES. */
export async function pickProfile(userId: string, focus: Focus, deadline: number, waiting: boolean): Promise<(Picked & { source: Source }) | null> {
  const tried: string[] = [];
  for (let attempt = 0; attempt < LIVE_TRIES; attempt++) {
    if (Date.now() >= deadline) break;
    const c = await nextCondition(userId, focus, tried, waiting);
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
