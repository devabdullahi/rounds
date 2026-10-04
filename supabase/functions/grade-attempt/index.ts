// grade-attempt: scores a submitted attempt and writes the debrief.
//
// Not wired up yet. Planned flow:
//   1. Verify the attempt belongs to the caller and has submitted_at set.
//   2. Load the answer key from private.case_content (service role only).
//   3. Deterministic scoring from logged IDs: history coverage, red-flag screening,
//      tests ordered (ECG first, unnecessary CTPA, budget).
//   4. LLM grades only the free-text diagnosis and plan against the key's accepted
//      answers and plan keywords; borderline results are flagged for review.
//   5. Write attempts.score and attempts.grade (verdict, feedback, missed_red_flags,
//      rating_delta) and update profiles.rating — columns the app itself cannot write.
//
// Secrets (set with `supabase secrets set`, never in the app): ANTHROPIC_API_KEY.

import "@supabase/functions-js/edge-runtime.d.ts"

Deno.serve((_req) =>
  new Response(JSON.stringify({ error: "grade-attempt is not implemented yet" }), {
    status: 501,
    headers: { "Content-Type": "application/json" },
  })
)
