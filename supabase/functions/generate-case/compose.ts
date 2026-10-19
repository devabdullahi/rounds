// Composing one patient from a profile: plan them in code, never repeating a patient the student
// already has, give them a name, have the model voice them, then check the writing (structure,
// diagnosis leaks, invented facts) and fall back to templates if the writer fails.
import { HttpError } from "../_shared/http.ts";
import { completeJSON } from "../_shared/llm.ts";
import { BudgetExceeded } from "../_shared/usage.ts";
import { CASE_FIXER, CASE_VOICE, FACT_AUDITOR, FACT_FIXER } from "../_shared/prompts.ts";
import { acceptedNames, type CasePlan, leakTerms, planCase, type Profile } from "../_shared/casegen.ts";
import type { Focus } from "../_shared/focus.ts";
import { auditPrompt, candidateFlags, confirmWithUmls, type Flag, fixRequest, type PlanItems, parseClaims } from "../_shared/factaudit.ts";
import { conceptOf } from "../_shared/terms.ts";
import { patientName } from "../_shared/names.ts";
import { backgroundForWriter, type PatientBackground } from "./background.ts";
import { applyFixes, assemble, checkWriting, fixPrompt, leakSpots, neutralIds, type Voice, voicePrompt, type Writing } from "./writer.ts";
import { buildSkeleton } from "./skeleton.ts";
import { templateVoice } from "./template.ts";
import { fingerprint, PLAN_TRIES } from "./fingerprint.ts";
import { buildRows } from "./rows.ts";
import { findBackground } from "./stores.ts";
import type { CaseRows, History, Picked } from "./types.ts";

/** Writer tries before falling back to templates. A typical write takes 7–9 s on DeepSeek Flash. */
const WRITE_ATTEMPTS = 2;
/** One writer try while a student waits; a second slow try still fits the inline budget. */
export const INLINE_WRITER_MS = 20_000;
/** One writer try in the background, where there's time to wait for a slow reply. */
export const BACKGROUND_WRITER_MS = 45_000;
/** Kept back from the writer for the template fallback and its leak fix, so a slow writer can't
 *  leave a case with nothing but an error. */
const FALLBACK_RESERVE_MS = 15_000;
const CHECK_TIMEOUT_MS = 10_000;
const FIX_TIMEOUT_MS = 12_000;
/** Names drawn before accepting one the student has met: with ~600k combinations a repeat is rare. */
const NAME_TRIES = 10;

/** What's left of the deadline for one call, capped; past the deadline, a timeout error. */
export function timeoutFor(deadline: number, maximum: number): number {
  const remaining = deadline - Date.now();
  if (remaining <= 0) throw new HttpError(504, "patient generation timed out; try again");
  return Math.min(remaining, maximum);
}

/** A plan whose fingerprint the student doesn't hold yet. A condition can come back once a topic is
 *  used up, but always as a different patient: another severity, decade, sex or set of symptoms. */
async function freshPlan(profile: Profile, opts: Parameters<typeof planCase>[2], history: History): Promise<{ plan: CasePlan; print: string }> {
  let plan = planCase(profile, Math.random, opts);
  let print = await fingerprint(plan);
  for (let i = 1; i < PLAN_TRIES && history.fingerprints.has(print); i++) {
    plan = planCase(profile, Math.random, opts);
    print = await fingerprint(plan);
  }
  if (history.fingerprints.has(print)) throw new HttpError(503, "Couldn't find a new patient for this topic just now. Tap to try again.");
  return { plan, print };
}

/** A name the student hasn't met yet. */
function freshName(plan: CasePlan, history: History): string {
  let name = patientName(plan.sex, plan.age, Math.random);
  for (let i = 1; i < NAME_TRIES && history.names.has(name); i++) name = patientName(plan.sex, plan.age, Math.random);
  return name;
}

/** Plans the patient in code, has the model write them and checks the writing. */
export async function composeCase(
  { profile, clerkships, organ_systems: systems, synonyms }: Picked, focus: Focus, deadline: number, history: History,
  writerMs = INLINE_WRITER_MS,
): Promise<CaseRows> {
  // Clinical psychology is a focus like any rotation; its cases are written as a psychologist's intake.
  const psychology = focus.kind === "rotation" && focus.value === "clinicalPsychology";
  const dermatology = focus.kind === "rotation" && focus.value === "dermatology";
  // A heart case: filed under cardiology or the cardiovascular system, or made for either focus.
  const cardiac = clerkships.includes("cardiology") || systems.includes("cardiovascular") ||
    (focus.kind === "rotation" && focus.value === "cardiology") || (focus.kind === "system" && focus.value === "cardiovascular");
  const { plan, print } = await freshPlan(profile, { psychology, dermatology, cardiac }, history);
  const terms = leakTerms(profile);
  const background = await findBackground(plan, [profile.triage.name, ...acceptedNames(profile.teaching.accepted_names, synonyms)]);
  const skeleton = buildSkeleton(profile, plan, background, Math.random);
  const name = freshName(plan, history);
  let user = voicePrompt(profile, plan, skeleton, background, name);
  const items = planItems(profile, plan, background);
  let writing: Writing | null = null;
  let problems: string[] = [];
  const writerDeadline = deadline - FALLBACK_RESERVE_MS;
  for (let attempt = 0; attempt < WRITE_ATTEMPTS; attempt++) {
    if (Date.now() >= writerDeadline) break;
    try {
      writing = assemble(skeleton, await completeJSON<Voice>(CASE_VOICE, user, 5000, {
        task: "case", timeoutMs: timeoutFor(writerDeadline, writerMs),
      }), name);
      problems = checkWriting(writing, plan, terms);
      if (problems.length) {
        writing = await fixLeaks(writing, terms, deadline);
        problems = checkWriting(writing, plan, terms);
      }
    } catch (error) {
      // Out of budget: say so, rather than quietly write a plainer case from templates.
      if (error instanceof BudgetExceeded) throw error;
      problems = [`reply unusable: ${(error as Error).message.slice(0, 200)}`];
    }
    if (problems.length === 0) break;
    user += `\n\nYour previous reply had these problems. Fix them and reply with the full JSON again:\n- ${problems.join("\n- ")}`;
  }
  // Facts the plan doesn't support are reworded in place: a few lines in seconds, where a full
  // rewrite takes 7–9 s and can invent something else.
  let writtenBy: string | undefined;
  if (writing && problems.length === 0) {
    writing = await fixUnsupported(writing, await auditCase(writing, items, deadline), profile.slug, deadline);
  } else {
    // The writer failed: a plainer case from templates beats no case. Its words come only from the plan.
    console.warn("generate-case: writer failed, using templates", profile.slug, problems.slice(0, 3));
    writing = assemble(skeleton, templateVoice(profile, plan, skeleton, background, Math.random), name);
    writtenBy = "template";
    problems = checkWriting(writing, plan, terms);
    if (problems.length) {
      writing = await fixLeaks(writing, terms, deadline);
      problems = checkWriting(writing, plan, terms);
    }
  }
  if (!writing || problems.length > 0) {
    console.error("generate-case: writing failed", profile.slug, problems);
    throw new HttpError(502, "the patient couldn't be written; try again");
  }
  return { ...buildRows(profile, clerkships, systems, synonyms, plan, neutralIds(writing), focus, background?.id ?? null, writtenBy), fingerprint: print };
}

/** Everything the writer was given that a fact may state: planned symptoms, the presentation's
 *  details, risk factors and history, and the background record. Absent symptoms apart, since the
 *  patient may only deny those. */
function planItems(profile: Profile, plan: CasePlan, background: PatientBackground | null): PlanItems {
  const texts = (list: unknown) => (Array.isArray(list) ? list : []).map((x) => (typeof x === "string" ? x : x?.text)).filter((x): x is string => !!x);
  const hpi = profile.presentation.hpi as Record<string, unknown>;
  const details = Object.entries(hpi).filter(([k]) => k !== "associated_symptoms" && k !== "pertinent_negatives")
    .flatMap(([, v]) => (typeof v === "string" ? [v] : texts(v)));
  const p = profile.patient as Record<string, unknown>;
  const record = background ? backgroundForWriter(background) : null;
  return {
    present: plan.symptomsPresent,
    absent: plan.symptomsAbsent,
    background: [
      ...profile.presentation.chief_complaints.map((c) => c.text), ...details,
      ...texts(p.risk_factors), ...texts(p.comorbidities), ...texts(p.social_history), ...texts(p.family_history), ...texts(p.risk_medications),
      ...(record ? [...record.chronic_conditions, ...record.current_medications, ...record.allergies, record.smoking, ...record.social] : []),
    ],
  };
}

/** The fact audit (_shared/factaudit.ts): claims the plan doesn't support. Advisory if it can't
 *  run: a failed audit call never blocks a case. */
async function auditCase(writing: Writing, items: PlanItems, deadline: number): Promise<Flag[]> {
  try {
    const reply = await completeJSON(FACT_AUDITOR, auditPrompt(items, writing.facts ?? []), 2500, {
      task: "audit", timeoutMs: timeoutFor(deadline, CHECK_TIMEOUT_MS),
    });
    const flags = candidateFlags(parseClaims(reply, items.present.length + items.absent.length + items.background.length), items);
    const remaining = deadline - Date.now();
    if (!flags.some((flag) => flag.kind === "invented") || remaining <= 0) return flags;
    let timer: ReturnType<typeof setTimeout> | undefined;
    try {
      return await Promise.race([
        confirmWithUmls(flags, items, conceptOf),
        new Promise<Flag[]>((resolve) => {
          timer = setTimeout(() => resolve(flags), remaining);
        }),
      ]);
    } finally {
      if (timer !== undefined) clearTimeout(timer);
    }
  } catch (error) {
    console.error("generate-case: fact audit failed", (error as Error).message.slice(0, 200));
    return [];
  }
}

/** Rewords the flagged facts so they drop (or deny) what the plan doesn't support. */
async function fixUnsupported(writing: Writing, flags: Flag[], slug: string, deadline: number): Promise<Writing> {
  if (!flags.length) return writing;
  try {
    const reply = await completeJSON<{ fixes?: { where: string; text: string }[] }>(FACT_FIXER, fixRequest(flags, writing.facts), 2000, {
      task: "case", timeoutMs: timeoutFor(deadline, FIX_TIMEOUT_MS),
    });
    console.log("generate-case: fact audit fixed", slug, flags.map((f) => `${f.kind}: ${f.claim}`));
    return applyFixes(writing, Array.isArray(reply.fixes) ? reply.fixes : []);
  } catch (error) {
    console.error("generate-case: fact fix failed", (error as Error).message.slice(0, 200));
    return writing;
  }
}

/** Rewords only the fields that named the diagnosis. Leaks are the usual reason a writing fails, and
 *  this takes 2–3 s where a full rewrite takes 15–20 s. Returns the writing unchanged if it can't. */
async function fixLeaks(w: Writing, terms: string[], deadline: number): Promise<Writing> {
  const { leaked, where } = leakSpots(w, terms);
  if (!leaked.length) return w;
  try {
    const reply = await completeJSON<{ fixes?: { where: string; text: string }[] }>(CASE_FIXER, fixPrompt(w, where, leaked), 1500, {
      task: "case", timeoutMs: timeoutFor(deadline, FIX_TIMEOUT_MS),
    });
    return applyFixes(w, Array.isArray(reply.fixes) ? reply.fixes : []);
  } catch (error) {
    console.error("generate-case: leak fix failed", (error as Error).message.slice(0, 200));
    return w;
  }
}
