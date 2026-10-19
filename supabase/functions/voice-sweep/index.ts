// voice-sweep: hangs up every live call past its deadline, whoever it belongs to.
//
// Internal only: a pg_cron job calls it each minute with the service role key (migration
// 20261019000300_voice_call_sweeper). Without it, an overdue call ended only when its own student
// made another voice request, so a client that never reported back could keep a call open until
// OpenAI's own session limit. Each closed call is hung up and its cost settled (_shared/voicecalls.ts).

import { json, serve } from "../_shared/http.ts";
import { requireServiceRole } from "../_shared/internal.ts";
import { closeCalls } from "../_shared/voicecalls.ts";

serve(async (req) => {
  requireServiceRole(req);
  return json({ closed: await closeCalls({ overdueOnly: true }) });
});
