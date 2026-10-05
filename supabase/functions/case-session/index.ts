// case-session: everything a student does inside a case, one action per request.
//
//   start    {case_id, exam_mode, time_limit_minutes}  → {attempt_id}
//   ask      {attempt_id, question}                    → {reply, revealed[], coverage}
//   examine  {attempt_id, maneuver_id}                 → {finding}
//   order    {attempt_id, test_id}                     → {result, abnormal, turnaround_s}
//   submit   {attempt_id, diagnosis, differential, plan} → grade
//
// Every action verifies the caller, then loads the attempt only if it belongs to them. The patient
// LLM sees the persona and revealable facts, never the diagnosis or rubric; its reply is checked for
// diagnosis names, and replies that match no fact get a second check for invented facts.
import { body, callerId, HttpError, json, serve } from "../_shared/http.ts";
import { sql } from "../_shared/db.ts";
import { completeJSON } from "../_shared/llm.ts";
import { leaks } from "../_shared/casegen.ts";
import { GRADER, PATIENT, REPLY_CHECKER } from "../_shared/prompts.ts";
import { type Actions, grade, matchesDiagnosis, type Rubric } from "./grade.ts";

type Fact = { id: string; label: string; reply: string; importance: string; screens_for: string | null };
type Maneuver = { id: string; title: string; finding: string };
type Test = { id: string; name: string; cost: number; turnaround_s: number; delays_care_min: number; result: string; abnormal: boolean };
type Turn = { role: "student" | "patient"; text: string; facts?: string[] };
type Attempt = {
  id: string; case_id: string; exam_mode: boolean; submitted_at: string | null; transcript: Turn[];
  revealed_facts: string[]; examined: string[]; ordered_tests: { id: string; at: string }[];
};
type Content = {
  facts: Fact[]; exam: Maneuver[]; tests: Test[]; persona: Record<string, string | number>;
  answer_key: { diagnosis: string; accepted: string[] }; rubric: Rubric;
};

const LIMITS = { question: 500, diagnosis: 200, plan: 2000, differential: 10, transcriptTurns: 12 };

serve(async (req) => {
  const userId = await callerId(req);
  const input = await body<Record<string, unknown>>(req);
  switch (input.action) {
    case "start": return json(await start(userId, input));
    case "ask": return json(await ask(userId, input));
    case "examine": return json(await examine(userId, input));
    case "order": return json(await order(userId, input));
    case "submit": return json(await submit(userId, input));
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
    select a.id, a.case_id, a.exam_mode, a.submitted_at, a.transcript, a.revealed_facts, a.examined, a.ordered_tests,
           c.facts, c.exam, c.tests, c.persona, c.answer_key, c.rubric
    from public.attempts a join private.case_content c on c.case_id = a.case_id
    where a.id = ${attemptId} and a.user_id = ${userId}`;
  if (rows.length === 0) throw new HttpError(404, "attempt not found");
  if (open && rows[0].submitted_at) throw new HttpError(409, "attempt already submitted");
  const { facts, exam, tests, persona, answer_key, rubric, ...attempt } = rows[0];
  return { attempt, content: { facts, exam, tests, persona, answer_key, rubric } };
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
  const [row] = await sql<{ id: string }[]>`
    insert into public.attempts (user_id, case_id, exam_mode, time_limit_minutes)
    values (${userId}, ${caseId}, ${input.exam_mode === true}, ${(limit as number | null) ?? null})
    returning id`;
  return { attempt_id: row.id };
}

// MARK: - ask

async function ask(userId: string, input: Record<string, unknown>) {
  const question = text(input.question, "question", LIMITS.question);
  const { attempt, content } = await loadAttempt(userId, input.attempt_id);
  const recent = attempt.transcript.slice(-LIMITS.transcriptTurns);
  const persona = content.persona;
  const prompt = `You are ${persona.name}, ${persona.age}, ${persona.sex === "F" ? "female" : "male"}.
Voice: ${persona.voice}
Background: ${persona.background}
Facts you may reveal: ${JSON.stringify(content.facts.map(({ id, reply }) => ({ id, content: reply })))}
Conversation so far: ${JSON.stringify(recent.map(({ role, text }) => ({ role, text })))}
Student's latest message: ${JSON.stringify(question)}`;

  const known = new Map(content.facts.map((f) => [f.id, f]));
  let reply = String(persona.fallback ?? "");
  let used: string[] = [];
  try {
    const answer = await completeJSON<{ fact_ids: string[]; reply: string }>(PATIENT, prompt, 400);
    used = (answer.fact_ids ?? []).filter((id) => known.has(id));
    reply = (answer.reply ?? "").trim() || reply;
    const terms = [content.answer_key.diagnosis, ...content.answer_key.accepted].map((t) => t.toLowerCase()).filter((t) => t.length > 3);
    if (leaks(reply, terms).length > 0) {
      // Never let the patient name the diagnosis: fall back to the scripted wording.
      reply = used.length ? used.map((id) => known.get(id)!.reply).join(" ") : String(persona.fallback);
    } else if (used.length === 0 && await addsFacts(reply)) {
      reply = String(persona.fallback);
    }
  } catch (error) {
    console.error("patient reply failed", error);
    throw new HttpError(502, "the patient didn't answer; try again");
  }

  const fresh = used.filter((id) => !attempt.revealed_facts.includes(id));
  const revealed = [...attempt.revealed_facts, ...fresh];
  const transcript = [...attempt.transcript, { role: "student", text: question }, { role: "patient", text: reply, facts: used }];
  await sql`update public.attempts set transcript = ${sql.json(transcript)}, revealed_facts = ${revealed}
            where id = ${attempt.id} and submitted_at is null`;

  const key = content.rubric.key_facts;
  return {
    reply,
    revealed: attempt.exam_mode ? [] : fresh.map((id) => ({ id, label: known.get(id)!.label })),
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
    await sql`update public.attempts set examined = array_append(examined, ${id}) where id = ${attempt.id} and submitted_at is null`;
  }
  return { finding: maneuver.finding };
}

async function order(userId: string, input: Record<string, unknown>) {
  const id = text(input.test_id, "test_id", 60);
  const { attempt, content } = await loadAttempt(userId, input.attempt_id);
  const test = content.tests.find((t) => t.id === id);
  if (!test) throw new HttpError(404, "test not found");
  if (!attempt.ordered_tests.some((t) => t.id === id)) {
    const ordered = [...attempt.ordered_tests, { id, at: new Date().toISOString() }];
    await sql`update public.attempts set ordered_tests = ${sql.json(ordered)} where id = ${attempt.id} and submitted_at is null`;
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
  const [{ budget }] = await sql<{ budget: number }[]>`select budget from public.cases where id = ${attempt.case_id}`;

  const rubric = content.rubric;
  const ordered = attempt.ordered_tests.map((t) => t.id);
  const actions: Actions = {
    revealed: attempt.revealed_facts, examined: attempt.examined, ordered, budget,
    spent: content.tests.filter((t) => ordered.includes(t.id)).reduce((s, t) => s + t.cost, 0),
  };
  const judged = await judge(rubric, diagnosis, plan);
  const result = grade(rubric, actions, judged);

  const [profile] = await sql<{ rating: number }[]>`
    with graded as (
      update public.attempts set diagnosis = ${diagnosis}, differential = ${differential}, plan = ${plan},
        submitted_at = now(), score = ${result.score}, grade = ${sql.json(result)}
      where id = ${attempt.id} and submitted_at is null
      returning user_id
    )
    update public.profiles p set rating = p.rating + ${result.rating_delta}
    from graded where p.id = graded.user_id
    returning p.rating`;
  if (!profile) throw new HttpError(409, "attempt already submitted");
  return { ...result, rating: profile.rating };
}

async function judge(r: Rubric, diagnosis: string, plan: string) {
  const exact = matchesDiagnosis(diagnosis, [r.diagnosis, ...r.accepted]);
  const verdict = await completeJSON<{ diagnosis_correct: boolean; plan_appropriate: boolean; plan_note: string }>(
    GRADER,
    `Correct diagnosis: ${r.diagnosis} (accepted: ${r.accepted.join(", ")}); severity ${r.severity}.
Student diagnosis: ${JSON.stringify(diagnosis)}
Student plan: ${JSON.stringify(plan || "(none)")}`,
    200,
  );
  return {
    diagnosisCorrect: exact || verdict.diagnosis_correct === true,
    planAppropriate: !!plan && verdict.plan_appropriate === true,
    planNote: plan ? (verdict.plan_note ?? "") : "No plan was given.",
  };
}
