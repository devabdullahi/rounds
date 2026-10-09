// Does a patient reply name the diagnosis? Pure, so the matching rules are unit-tested.
//
// Longer names match anywhere, ignoring case ("appendicitis" inside "Appendicitis?"). Short names
// can't: "PE" or "AS" ignoring case would hit everyday words ("as", "pe" in "type"). So a short
// all-caps abbreviation ("MI", "PE", "DVT") matches only as a whole word in capitals, and other
// short names are skipped as too noisy to check. Abbreviations of four or more letters ("COPD")
// are rare enough as words to match whole-word in any case.

const ABBREVIATION = /^[A-Z][A-Z0-9]{1,4}$/;

/** The diagnosis names a reply mentions, from the case's diagnosis and accepted names. */
export function namedDiagnoses(reply: string, names: string[]): string[] {
  const lower = reply.toLowerCase();
  return names.filter((name) => {
    const t = name.trim();
    if (ABBREVIATION.test(t)) return new RegExp(`(^|[^A-Za-z0-9])${t}([^A-Za-z0-9]|$)`, t.length > 3 ? "i" : "").test(reply);
    return t.length > 3 && lower.includes(t.toLowerCase());
  });
}
