// delete-account: permanently deletes the caller's account and everything in it.
//
//   1. Verify the caller (their own token; nobody can delete someone else).
//   2. Delete the auth user with the service role. Every table hangs off it with on delete
//      cascade (profiles → cases, attempts, flashcards, reviews, usage; cases → case content),
//      so one delete removes all of it. Condition profiles are shared knowledge and stay.
//
// Apple requires apps with accounts to offer this in-app.

import { callerId, HttpError, json, serve } from "../_shared/http.ts";

serve(async (req) => {
  const userId = await callerId(req);
  const res = await fetch(`${Deno.env.get("SUPABASE_URL")}/auth/v1/admin/users/${userId}`, {
    method: "DELETE",
    headers: {
      Authorization: `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")}`,
      apikey: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    },
  });
  if (!res.ok) {
    console.error("delete-account failed", userId, res.status, (await res.text()).slice(0, 200));
    throw new HttpError(502, "your account couldn't be deleted; try again");
  }
  return json({ deleted: true });
});
