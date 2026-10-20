// The study focus a student picks for new cases, as the app stores it. Pure, so it's testable
// without a database.

import { HttpError } from "./http.ts";

/** Where the student wants to meet patients: anywhere, an office (OSCEs are outpatient), or the hospital. */
export type CareSetting = "" | "clinic" | "hospital";

export type Focus = { kind: "" | "rotation" | "system"; value: string; setting: CareSetting; stored: string };

/** The catalog's triage setting tags each choice draws from. A condition matches when it has any
 *  of them, so one seen in both places (pneumonia) can come up in either. */
export const SETTING_TAGS: Record<Exclude<CareSetting, "">, string[]> = {
  clinic: ["clinic", "pediatric_clinic"],
  hospital: ["emergency", "inpatient", "icu", "labor_delivery", "psychiatric"],
};

/** Tags for a setting; empty means any condition. */
export function settingTags(setting: CareSetting): string[] {
  return setting ? SETTING_TAGS[setting] : [];
}

/** `focus` is "", "rotation:<clerkship>" or "system:<organ system>"; `setting` is "", "clinic" or
 *  "hospital". The setting is part of `stored`, so cases written ahead for one setting are never
 *  handed out in another. */
export function parseFocus(focus: string, setting: unknown = ""): Focus {
  if (!(setting === "" || setting === "clinic" || setting === "hospital")) {
    throw new HttpError(400, "setting must be '', 'clinic' or 'hospital'");
  }
  const suffix = setting ? `@${setting}` : "";
  if (!focus) return { kind: "", value: "", setting, stored: suffix };
  const [kind, value] = focus.split(":");
  if (!(kind === "rotation" || kind === "system") || !/^[a-zA-Z]+$/.test(value ?? "")) {
    throw new HttpError(400, "focus must be '', 'rotation:<clerkship>' or 'system:<organ system>'");
  }
  return { kind, value, setting, stored: focus + suffix };
}
