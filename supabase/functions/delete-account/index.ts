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

  // Best effort: a leftover file must not block deleting the account itself. Everything in the
  // student's folder goes, not only the avatar, in case other files were ever added there.
  const listed = await fetch(`${base}/storage/v1/object/list/avatars`, {
    method: "POST",
    headers: { ...SERVICE_HEADERS, "Content-Type": "application/json" },
    body: JSON.stringify({ prefix: `${userId}/`, limit: 1000 }),
  });
  const names = listed.ok ? ((await listed.json()) as { name: string }[]).map((f) => `${userId}/${f.name}`) : [];
  const files = [...new Set([`${userId}/avatar.jpg`, ...names])];
  const photo = await fetch(`${base}/storage/v1/object/avatars`, {
    method: "DELETE",
    headers: { ...SERVICE_HEADERS, "Content-Type": "application/json" },
    body: JSON.stringify({ prefixes: files }),
  });
  if (!photo.ok) console.error("delete-account file cleanup failed", userId, photo.status);

  const res = await fetch(`${base}/auth/v1/admin/users/${userId}`, { method: "DELETE", headers: SERVICE_HEADERS });
  if (!res.ok) {
    console.error("delete-account failed", userId, res.status, (await res.text()).slice(0, 200));
    throw new HttpError(502, "your account couldn't be deleted; try again");
  }
  return json({ deleted: true });
});
