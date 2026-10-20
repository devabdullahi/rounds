// Fits a condition profile to the care setting the student picked, so the patient is met there:
// the door note (template.ts) and the writer (writer.ts) both read `triage.settings`.
import type { Profile } from "../_shared/casegen.ts";
import { type CareSetting, settingTags } from "../_shared/focus.ts";

/** The profile with only the settings that match the student's pick, first one leading (it names
 *  the encounter). In a clinic the critical tier is dropped when a milder one exists: a patient that
 *  sick is sent to the ED, not interviewed in an office. With no pick, or no match, it's unchanged. */
export function forSetting(profile: Profile, setting: CareSetting): Profile {
  const tags = settingTags(setting);
  const settings = profile.triage.settings.filter((s) => tags.includes(s));
  if (settings.length === 0) return profile;
  let severity = profile.course.severity;
  if (setting === "clinic" && severity.critical && Object.keys(severity).some((s) => s !== "critical")) {
    const { critical: _critical, ...milder } = severity;
    severity = milder;
  }
  return { ...profile, triage: { ...profile.triage, settings }, course: { ...profile.course, severity } };
}
