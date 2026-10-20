// Closing live calls (private.voice_calls): mark them ended, hang up with OpenAI, and settle what
// each one cost on the project-wide daily cap. Shared by case-session (one student's calls) and
// voice-sweep (every overdue call, each minute), so a call ends the same way whoever ends it.

import { sql } from "./db.ts";
import { hangUp, realtimeModel, settlementUSD } from "./realtime.ts";
import { recordUsage } from "./usage.ts";

/** Which open calls to close. With no user or call id, every overdue call in the project. */
export type CallScope = { userId?: string; callId?: string; overdueOnly: boolean };

const NO_TOKENS = { hit: 0, miss: 0, output: 0, reasoning: 0 };

/** Closes the open calls in scope and returns how many. The update claims each row once, so two
 *  closers racing on the same call hang it up and settle it only once. */
export async function closeCalls({ userId, callId, overdueOnly }: CallScope): Promise<number> {
  const calls = await sql<{ call_id: string; seconds: number }[]>`
    update private.voice_calls set ended_at = now()
    where ended_at is null
      and (${userId ?? null}::uuid is null or user_id = ${userId ?? null}::uuid)
      and (${callId ?? null}::text is null or call_id = ${callId ?? null}::text)
      and (not ${overdueOnly} or ends_at < now())
    returning call_id, extract(epoch from now() - started_at)::float8 as seconds`;
  await Promise.all(calls.map(async (call) => {
    await hangUp(call.call_id);
    await recordUsage("voice_live_settle", `openai/${realtimeModel()}`, NO_TOKENS, settlementUSD(call.seconds));
  }));
  return calls.length;
}
