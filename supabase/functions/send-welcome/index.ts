// send-welcome: emails a new student once, when they finish onboarding.
//
//   1. Verify the caller (their own token). Guests (anonymous) and accounts without an email get nothing.
//   2. Claim the student's row in private.welcome_emails; a second request finds it taken and stops,
//      so nobody is welcomed twice however often the app asks.
//   3. Send through SES. If sending fails, release the claim so a later request can try again.

import { caller, HttpError, json, serve } from "../_shared/http.ts";
import { sql } from "../_shared/db.ts";
import { sendMail } from "../_shared/mail.ts";
import { welcomeEmail } from "./email.ts";

serve(async (req) => {
  const user = await caller(req);
  if (user.is_anonymous || !user.email) throw new HttpError(403, "only accounts with an email get a welcome");

  const claimed = await sql`
    insert into private.welcome_emails (user_id) values (${user.id})
    on conflict (user_id) do nothing
    returning user_id`;
  if (claimed.length === 0) return json({ sent: false, reason: "already welcomed" });

  const meta = user.user_metadata ?? {};
  const name = String(meta.full_name ?? meta.name ?? "");
  try {
    await sendMail(welcomeEmail(user.email, name));
  } catch (error) {
    await sql`delete from private.welcome_emails where user_id = ${user.id}`;
    console.error("send-welcome failed", user.id, error instanceof Error ? error.message : error);
    throw new HttpError(502, "the welcome email couldn't be sent");
  }
  return json({ sent: true });
});
