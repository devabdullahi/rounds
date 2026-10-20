// The values generate-case's modules pass between them.
import type { Profile } from "../_shared/casegen.ts";

/** A condition's profile with the catalog data a case needs. */
export type Picked = { profile: Profile; clerkships: string[]; organ_systems: string[]; synonyms: string[] };

/** Where a case's profile came from, for the timing log. */
export type Source = "stored" | "live";

/** A catalog condition for the focus, with its validated stored profile when it has one. */
export type Condition = {
  slug: string; triage: Profile["triage"]; background: string | null; clerkships: string[]; organ_systems: string[]; synonyms: string[];
  stored: Profile | null;
};

/** Everything a case inserts except its owner and bed code: built once, kept as a ready case, and
 *  inserted when the student starts it. `fingerprint` marks the patient as given to this student. */
export type CaseRows = {
  // deno-lint-ignore no-explicit-any
  case: Record<string, any>;
  // deno-lint-ignore no-explicit-any
  content: Record<string, any>;
  fingerprint?: string;
};

/** What a student already has, so the next patient is never the same one: their patients'
 *  fingerprints and names. */
export type History = { fingerprints: Set<string>; names: Set<string> };

export type GenerationStart = { status: "started"; token: string } | { status: "pending" } | { status: "failed" };
