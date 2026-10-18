// case-session: everything a student does inside a case, one action per request.
//
//   start    {case_id, exam_mode, time_limit_minutes}  → {attempt_id, hidden_tests}
//   ask      {attempt_id, question}                    → {reply, revealed[], coverage}
//   examine  {attempt_id, maneuver_id}                 → {finding}
//   order    {attempt_id, test_id}                     → {result, abnormal, turnaround_s}
//   submit   {attempt_id, diagnosis, differential, plan} → grade (and queues the next condition
//            in the case's focus, see _shared/prefetch.ts). The grade carries condition insights
//            (about, differential, your_extras; see insights.ts) when the case's profile exists.
//
// Only a student's first submitted attempt on a case moves their rating; a restart after seeing the
// answer is graded as usual but unrated. A submission past the chosen time limit is graded and
// marked over time. Asking and submitting each cost a unit of the daily allowance (_shared/quota.ts).
//
// Every action verifies the caller, then loads the attempt only if it belongs to them. The patient
// LLM sees the persona and revealable facts, never the diagnosis or rubric; its reply is checked for
// diagnosis names, and replies that match no fact get a second check for invented facts.
// Off-topic and inappropriate questions get a fixed reply and reveal nothing (_shared/conduct.ts).
import { body, callerId, HttpError, json, serve } from "../_shared/http.ts";
import { sql } from "../_shared/db.ts";
import { completeJSON } from "../_shared/llm.ts";
import { GRADER, PATIENT, REPLY_CHECKER } from "../_shared/prompts.ts";
import { patientPrompt } from "../_shared/patientprompt.ts";
import { type Actions, grade, type Grade, isSingleDiagnosis, matchesDiagnosis, type Rubric, unrated } from "./grade.ts";
import { conditionInsights, type InsightProfile, type Insights } from "./insights.ts";
import { namedDiagnoses } from "./leak.ts";
import { hiddenTests } from "./menu.ts";
import { workupText } from "./workup.ts";
import { parseFocus } from "../_shared/focus.ts";
import { prepareNext } from "../_shared/prefetch.ts";
import { withQuota } from "../_shared/quota.ts";
import { type Conduct, conductReply, isProfane, MAX_INAPPROPRIATE, parseConduct, strikes } from "../_shared/conduct.ts";

type Fact = { id: string; label: string; reply: string; importance: string; screens_for: string | null };
type Maneuver = { id: string; title: string; finding: string };
type Test = { id: string; name: string; cost: number; turnaround_s: number; delays_care_min: number; result: string; abnormal: boolean };
type Turn = { role: "student" | "patient"; text: string; facts?: string[]; conduct?: Conduct };
type Attempt = {
  id: string; case_id: string; exam_mode: boolean; submitted_at: string | null; transcript: Turn[];
  started_at: Date; time_limit_minutes: number | null;
  revealed_facts: string[]; examined: string[]; ordered_tests: { id: string; at: string }[];
};
type Content = {
  facts: Fact[]; exam: Maneuver[]; tests: Test[]; persona: Record<string, string | number>;
  answer_key: { diagnosis: string; accepted: string[] }; rubric: Rubric;
  focus: string; // study focus the case was generated for
};

const LIMITS = { question: 500, diagnosis: 200, plan: 2000, differential: 10, transcriptTurns: 12 };
/** Facts one reply may reveal; the model lists the most relevant first. More would let one broad
 *  question ("tell me everything") empty the script. */
const MAX_FACTS_PER_REPLY = 3;
/** Slack on a timed attempt for the submit tap and network before it counts as over time. */
const GRACE_MINUTES = 2;

serve(async (req) => {
  const userId = await callerId(req);
  const input = await body<Record<string, unknown>>(req);
  switch (input.action) {
    case "start": return json(await start(userId, input));
    // Each question costs a model call (reply plus check): it counts against the daily limit.
    case "ask": return json(await withQuota(userId, "question", () => ask(userId, input)));
    case "examine": return json(await examine(userId, input));
    case "order": return json(await order(userId, input));
    // Grading costs a model call too, and a quota keeps restart-and-resubmit loops bounded.
    case "submit": return json(await withQuota(userId, "grade", () => submit(userId, input)));
    default: throw new HttpError(400, "unknown action");
  }
});

function text(value: unknown, field: string, max: number, required = true): string {
  if (typeof value !== "string" || (required && !value.trim())) throw new HttpError(400, `${field} required`);
  if (value.length > max) throw new HttpError(400, `${field} too long`);
  return value.trim();
}

async function loadAttempt(userId: string, attemptId: unknown, open = true): Promise<{ attempt: Attempt; content: Content }> {
  if (typeof attemptId !== "string" || !/^[0-9a-f-]{36}$/.test(attemptId)) throw new HttpError(400, "attempt_id required");
  const rows = await sql<(Attempt & Content)[]>`
    select a.id, a.case_id, a.exam_mode, a.submitted_at, a.started_at, a.time_limit_minutes, a.transcript, a.revealed_facts, a.examined, a.ordered_tests,
           c.facts, c.exam, c.tests, c.persona, c.answer_key, c.rubric, c.focus
    from public.attempts a join private.case_content c on c.case_id = a.case_id
    where a.id = ${attemptId} and a.user_id = ${userId}`;
  if (rows.length === 0) throw new HttpError(404, "attempt not found");
  if (open && rows[0].submitted_at) throw new HttpError(409, "attempt already submitted");
  const { facts, exam, tests, persona, answer_key, rubric, focus, ...attempt } = rows[0];
  return { attempt, content: { facts, exam, tests, persona, answer_key, rubric, focus } };
}

// MARK: - start

async function start(userId: string, input: Record<string, unknown>) {
  const caseId = text(input.case_id, "case_id", 16);
  const limit = input.time_limit_minutes;
  if (limit !== null && limit !== undefined && !(Number.isInteger(limit) && (limit as number) >= 1 && (limit as number) <= 120)) {
    throw new HttpError(400, "time_limit_minutes must be 1–120 or null");
  }
  const visible = await sql`select 1 from public.cases where id = ${caseId} and (published or created_by = ${userId})`;
  if (visible.length === 0) throw new HttpError(404, "case not found");
  const examMode = input.exam_mode === true;
  const [row] = await sql<{ id: string }[]>`
    insert into public.attempts (user_id, case_id, exam_mode, time_limit_minutes)
    values (${userId}, ${caseId}, ${examMode}, ${(limit as number | null) ?? null})
    returning id`;
  const [content] = await sql<{ rubric: Rubric }[]>`select rubric from private.case_content where case_id = ${caseId}`;
  return { attempt_id: row.id, hidden_tests: content ? hiddenTests(content.rubric, examMode) : [] };
}

// MARK: - ask

async function ask(userId: string, input: Record<string, unknown>) {
  const question = text(input.question, "question", LIMITS.question);
  const { attempt, content } = await loadAttempt(userId, input.attempt_id);
  // Refused before any model call; throwing also hands back the question's quota.
  if (strikes(attempt.transcript) >= MAX_INAPPROPRIATE) {
    throw new HttpError(403, "the patient has stopped answering questions; you can still examine, order tests and submit");
  }
  const recent = attempt.transcript.slice(-LIMITS.transcriptTurns);
  const persona = content.persona;
  const prompt = patientPrompt(
    { name: String(persona.name), age: persona.age, sex: String(persona.sex), voice: String(persona.voice), background: String(persona.background) },
    content.facts, content.exam, recent, question,
  );

  const known = new Map(content.facts.map((f) => [f.id, f]));
  let reply = String(persona.fallback ?? "");
  let used: string[] = [];
  let looked: string[] = [];   // exam findings described as what anyone could see (no chip)
  let conduct: Conduct = isProfane(question) ? "inappropriate" : "clinical";
  try {
    if (conduct === "clinical") {
      const answer = await completeJSON<{ conduct: string; fact_ids: string[]; seen_ids?: string[]; reply: string }>(PATIENT, prompt, 400, { task: "patient" });
      conduct = parseConduct(answer.conduct);
      used = [...new Set(answer.fact_ids ?? [])].filter((id) => known.has(id)).slice(0, MAX_FACTS_PER_REPLY);
      looked = (answer.seen_ids ?? []).filter((id) => content.exam.some((m) => m.id === id));
      reply = (answer.reply ?? "").trim() || reply;
    }
    if (conduct !== "clinical") {
      used = [];
      reply = conductReply(conduct, strikes(attempt.transcript) + (conduct === "inappropriate" ? 1 : 0));
    } else if (namedDiagnoses(reply, [content.answer_key.diagnosis, ...content.answer_key.accepted]).length > 0) {
      // Never let the patient name the diagnosis: fall back to the scripted wording.
      reply = used.length ? used.map((id) => known.get(id)!.reply).join(" ") : String(persona.fallback);
    } else if (used.length === 0 && looked.length === 0 && await addsFacts(reply)) {
      // Grounded replies (a fact or a visible finding) skip this; only free-floating ones are checked.
      reply = String(persona.fallback);
    }
  } catch (error) {
    console.error("patient reply failed", error);
    throw new HttpError(502, "the patient didn't answer; try again");
  }

  const fresh = used.filter((id) => !attempt.revealed_facts.includes(id));
  const asked: Turn = conduct === "clinical" ? { role: "student", text: question } : { role: "student", text: question, conduct };
  const turns: Turn[] = [asked, { role: "patient", text: reply, facts: used }];
  // Appended in SQL, not written back whole, so two questions in flight can't drop each other's turns.
  const [row] = await sql<{ revealed_facts: string[] }[]>`
    update public.attempts set transcript = transcript || ${sql.json(turns)},
      revealed_facts = revealed_facts || array(select f from unnest(${used}::text[]) f where not f = any(revealed_facts))
    where id = ${attempt.id} and submitted_at is null
    returning revealed_facts`;
  if (!row) throw new HttpError(409, "attempt already submitted");
  const revealed = row.revealed_facts;

  // Exam mode shows no progress while the case runs. The app requires these fields, so they come
  // back empty rather than missing.
  if (attempt.exam_mode) return { reply, conduct, revealed: [], revealed_ids: [], coverage: { got: 0, total: 0 } };
  const key = content.rubric.key_facts;
  return {
    reply,
    conduct,
    revealed: fresh.map((id) => ({ id, label: known.get(id)!.label })),
    revealed_ids: revealed,
    coverage: { got: key.filter((f) => revealed.includes(f.id)).length, total: key.length },
  };
}

/** Second check for replies that matched no fact: did the model slip in medical information? */
async function addsFacts(reply: string): Promise<boolean> {
  const verdict = await completeJSON<{ medical_information: boolean }>(
    REPLY_CHECKER,
    `Reply: ${JSON.stringify(reply)}`,
    50,
    { task: "check" },
  );
  return verdict.medical_information === true;
}

// MARK: - examine / order

async function examine(userId: string, input: Record<string, unknown>) {
  const id = text(input.maneuver_id, "maneuver_id", 60);
  const { attempt, content } = await loadAttempt(userId, input.attempt_id);
  const maneuver = content.exam.find((m) => m.id === id);
  if (!maneuver) throw new HttpError(404, "maneuver not found");
  if (!attempt.examined.includes(id)) {
    // The membership test runs in SQL too, so a double tap can't record the maneuver twice.
    await sql`update public.attempts set examined = array_append(examined, ${id})
              where id = ${attempt.id} and submitted_at is null and not ${id} = any(examined)`;
  }
  return { finding: maneuver.finding };
}

async function order(userId: string, input: Record<string, unknown>) {
  const id = text(input.test_id, "test_id", 60);
  const { attempt, content } = await loadAttempt(userId, input.attempt_id);
  const test = content.tests.find((t) => t.id === id);
  if (!test || hiddenTests(content.rubric, attempt.exam_mode).includes(id)) throw new HttpError(404, "test not found");
  if (!attempt.ordered_tests.some((t) => t.id === id)) {
    // Appended in SQL and skipped if already there, so concurrent orders keep each other.
    await sql`update public.attempts set ordered_tests = ordered_tests || ${sql.json([{ id, at: new Date().toISOString() }])}
              where id = ${attempt.id} and submitted_at is null and not ordered_tests @> ${sql.json([{ id }])}`;
  }
  return { result: test.result, abnormal: test.abnormal, turnaround_s: test.turnaround_s };
}

// MARK: - submit

async function submit(userId: string, input: Record<string, unknown>) {
  const diagnosis = text(input.diagnosis, "diagnosis", LIMITS.diagnosis);
  const plan = text(input.plan ?? "", "plan", LIMITS.plan, false);
  const differential = Array.isArray(input.differential)
    ? input.differential.slice(0, LIMITS.differential).map((d) => text(d, "differential item", LIMITS.diagnosis))
    : [];
  const { attempt, content } = await loadAttempt(userId, input.attempt_id);

  const rubric = content.rubric;
  const ordered = attempt.ordered_tests.map((t) => t.id);
  const deadline = attempt.time_limit_minutes === null
    ? null
    : new Date(attempt.started_at).getTime() + (attempt.time_limit_minutes + GRACE_MINUTES) * 60_000;
  const actions: Actions = {
    revealed: attempt.revealed_facts, examined: attempt.examined, ordered,
    overTime: deadline !== null && Date.now() > deadline,
  };
  let judged;
  try {
    judged = await judge(rubric, diagnosis, differential, plan, workupText(content.tests, content.exam, ordered, attempt.examined));
  } catch (error) {
    console.error("grading failed", error);
    throw new HttpError(502, "grading failed; try again");
  }
  const graded: Grade & Partial<Insights> = { ...grade(rubric, actions, judged), ...await insights(attempt.case_id, differential, content.answer_key) };

  const saved = await sql.begin(async (tx) => {
    // One submit at a time per student and case, so two attempts submitted together can't both be
    // the "first" and both move the rating.
    await tx`select pg_advisory_xact_lock(hashtext(${`${userId}:${attempt.case_id}`}))`;
    const [{ repeat }] = await tx<{ repeat: boolean }[]>`
      select exists (select 1 from public.attempts
                     where user_id = ${userId} and case_id = ${attempt.case_id} and submitted_at is not null) as repeat`;
    const result = repeat ? unrated(graded) : graded;
    const [profile] = await tx<{ rating: number }[]>`
      with graded as (
        update public.attempts set diagnosis = ${diagnosis}, differential = ${differential}, plan = ${plan},
          submitted_at = now(), score = ${result.score}, grade = ${tx.json(result)}
        where id = ${attempt.id} and submitted_at is null
        returning user_id
      )
      update public.profiles p set rating = p.rating + ${result.rating_delta}
      from graded where p.id = graded.user_id
      returning p.rating`;
    return profile ? { ...result, rating: profile.rating } : null;
  });
  if (!saved) throw new HttpError(409, "attempt already submitted");
  // The student's next case in this topic should find a fresh condition ready. A failure here
  // must not cost them their grade.
  try {
    await prepareNext(parseFocus(content.focus));
  } catch (error) {
    console.error("prepare next after grading", error);
  }
  return saved;
}

/** The condition insights for a graded attempt, or nothing when the case has no profile (older
 *  hand-written cases) or it can't be read: insights are extra, never a reason to lose a grade.
 *  They go into the stored grade too, so a revisit shows the same. */
async function insights(caseId: string, differential: string[], key: Content["answer_key"]): Promise<Insights | Record<never, never>> {
  try {
    const [row] = await sql<{ profile: InsightProfile }[]>`
      select p.profile from private.case_content c
      join private.condition_profiles p on p.slug = c.condition_slug
      where c.case_id = ${caseId}`;
    return row ? conditionInsights(row.profile, differential, [key.diagnosis, ...key.accepted]) : {};
  } catch (error) {
    console.error("condition insights", error);
    return {};
  }
}

/** Keeps the student's text inside its delimiters: a typed closing tag can't end the block early. */
function quoted(text: string): string {
  return text.replace(/<\/?student_[a-z]*>/gi, "");
}

async function judge(r: Rubric, diagnosis: string, differential: string[], plan: string, workup: string) {
  const exact = matchesDiagnosis(diagnosis, [r.diagnosis, ...r.accepted]);
  const verdict = await completeJSON<{ diagnosis_correct: boolean; plan_appropriate: boolean; plan_note: string }>(
    GRADER,
    `Correct diagnosis: ${r.diagnosis} (accepted: ${r.accepted.join(", ")}); severity ${r.severity}.

<student_diagnosis>
${quoted(diagnosis)}
</student_diagnosis>

<student_differential>
${quoted(differential.join("; ") || "(none)")}
</student_differential>

<student_plan>
${quoted(plan || "(none)")}
</student_plan>

<student_workup>
${workup}
</student_workup>`,
    200,
    { task: "grade" },
  );
  return {
    // The model may only widen the match to a close synonym of one committed answer; it can never
    // accept a list or a negation that the word match rejected.
    diagnosisCorrect: exact || (verdict.diagnosis_correct === true && isSingleDiagnosis(diagnosis)),
    planAppropriate: !!plan && verdict.plan_appropriate === true,
    planNote: plan ? (verdict.plan_note ?? "") : "No plan was given.",
  };
}
