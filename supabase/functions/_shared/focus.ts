// The study focus a student picks for new cases, as the app stores it. Pure, so it's testable
// without a database.

import { HttpError } from "./http.ts";

export type Focus = { kind: "" | "rotation" | "system"; value: string; stored: string };

/** "", "rotation:<clerkship>" or "system:<organ system>". */
export function parseFocus(focus: string): Focus {
  if (!focus) return { kind: "", value: "", stored: "" };
  const [kind, value] = focus.split(":");
  if (!(kind === "rotation" || kind === "system") || !/^[a-zA-Z]+$/.test(value ?? "")) {
    throw new HttpError(400, "focus must be '', 'rotation:<clerkship>' or 'system:<organ system>'");
  }
  return { kind, value, stored: focus };
}
