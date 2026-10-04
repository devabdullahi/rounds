// patient-reply: the simulated patient's answer to one student question.
//
// Not wired up yet. Planned flow (see reports for the design rationale):
//   1. Verify the caller owns the attempt and it isn't submitted.
//   2. Load the case's facts from private.case_content (service role; never sent to the app).
//   3. Classify the question → matching fact IDs (cheap model or keyword match).
//   4. Have the LLM voice ONLY those facts in the patient's words. The diagnosis is never in its prompt.
//   5. Checker pass: reject replies that add unlisted facts or hint at the diagnosis.
//   6. Append to attempts.transcript + revealed_facts; return { reply, revealed[] }.
//      In exam mode, revealed[] is returned empty (labels stay hidden until the debrief).
//
// Secrets (set with `supabase secrets set`, never in the app): ANTHROPIC_API_KEY.

import "@supabase/functions-js/edge-runtime.d.ts"

Deno.serve((_req) =>
  new Response(JSON.stringify({ error: "patient-reply is not implemented yet" }), {
    status: 501,
    headers: { "Content-Type": "application/json" },
  })
)
