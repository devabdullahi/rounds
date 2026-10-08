// delete-account: permanently deletes the caller's account and everything in it.
//
//   1. Verify the caller (their own token; nobody can delete someone else).
//   2. Remove their profile photo (storage isn't tied to the user row, so it wouldn't cascade).
//   3. Delete the auth user with the service role. Every table hangs off it with on delete
//      cascade (profiles → cases, attempts, flashcards, reviews, usage; cases → case content),
//      so one delete removes all of it. Condition profiles are shared knowledge and stay.
//
// Apple requires apps with accounts to offer this in-app.

import { callerId, HttpError, json, serve } from "../_shared/http.ts";

const SERVICE_HEADERS = {
  Authorization: `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")}`,
  apikey: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
};

serve(async (req) => {
  const userId = await callerId(req);
  const base = Deno.env.get("SUPABASE_URL");

  // Best effort: a leftover photo must not block deleting the account itself.
  const photo = await fetch(`${base}/storage/v1/object/avatars`, {
    method: "DELETE",
    headers: { ...SERVICE_HEADERS, "Content-Type": "application/json" },
    body: JSON.stringify({ prefixes: [`${userId}/avatar.jpg`] }),
  });
  if (!photo.ok) console.error("delete-account photo cleanup failed", userId, photo.status);

  const res = await fetch(`${base}/auth/v1/admin/users/${userId}`, { method: "DELETE", headers: SERVICE_HEADERS });
  if (!res.ok) {
    console.error("delete-account failed", userId, res.status, (await res.text()).slice(0, 200));
    throw new HttpError(502, "your account couldn't be deleted; try again");
  }
  return json({ deleted: true });
});
