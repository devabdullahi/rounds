// case-session: everything a student does inside a case, one action per request.
//
//   start    {case_id, exam_mode, time_limit_minutes}  → {attempt_id, hidden_tests}
//   resume   {case_id}                                 → {attempt: null | the unsubmitted attempt's
//            conversation, revealed facts, findings, results and progress (resume.ts)}
//   ask      {attempt_id, question}                    → {reply, revealed[], coverage}
//   examine  {attempt_id, maneuver_id}                 → {finding}
//   order    {attempt_id, test_id}                     → {result, abnormal, turnaround_s}
//   transcribe {attempt_id, audio (base64 m4a)}        → {text}   voice mode: the student's turn
//   speak    {attempt_id}                              → {audio (base64 AAC)} the latest patient
//            reply in an OpenAI voice picked for the patient. It speaks only that stored reply,
//            never text the app sends, so it can't be used as a general text-to-speech service.
//   speak_stream {attempt_id}                         → raw PCM (24 kHz, 16-bit, mono), streamed:
//            the same reply as speak, playing as soon as the first chunk lands.
//   ask_aloud {attempt_id, question}                   → one line of JSON (as ask), then the reply's
//            raw PCM in the same response: voice mode's question and spoken answer in one round trip.
//            The reply is checked and stored before any of it is voiced, exactly as for ask.
//   voice_session {attempt_id, sdp}                    → {sdp, call_id, seconds}  live voice: the app's
//            WebRTC offer goes to OpenAI's Realtime API with the patient's instructions and our key,
//            and OpenAI's answer comes back; audio then flows phone ↔ OpenAI (_shared/realtime.ts).
//            Each student has a daily live-voice budget in dollars (LIVE_VOICE_USD_PER_DAY, $2): a call
//            runs up to 5 minutes, shorter when the budget is nearly spent, and none once it's gone.
//   voice_turn {attempt_id, call_id, question, reply}  → like ask  one finished spoken exchange,
//            logged for the transcript and the grade. The reply was already heard, so it's checked
//            afterwards: facts it used light their chips, and a reply that named the diagnosis or
//            invented a medical detail is flagged (the app says so). Too many inappropriate
//            questions hang the call up. Taken only while the call is open (plus a few seconds for
//            the last exchange in flight) and up to a cap per call; the reply is never voiced.
//   voice_end {attempt_id, call_id}                   → {}  the app ended the call; the server hangs up too.
//   submit   {attempt_id, diagnosis, differential, plan} → grade (and queues the next condition
//            in the case's focus, see _shared/prefetch.ts). The grade carries condition insights
//            (about, differential, your_extras; see insights.ts) when the case's profile exists.
//
// Only a student's first submitted attempt on a case moves their rating; a restart after seeing the
// answer is graded as usual but unrated. A submission past the chosen time limit is graded and
// marked over time. Asking and submitting each cost a unit of the daily allowance (_shared/quota.ts),
// and so does each voice call.
//
// Every action verifies the caller, then loads the attempt only if it belongs to them. The patient
// LLM sees the persona and revealable facts, never the diagnosis or rubric; its reply is checked for
// diagnosis names, and replies that match no fact get a second check for invented facts.
// Off-topic and inappropriate questions get a fixed reply and reveal nothing (_shared/conduct.ts).
import { body, callerId, HttpError, json, serve } from "../_shared/http.ts";
import { sql } from "../_shared/db.ts";
import { completeJSON } from "../_shared/llm.ts";
import { GRADER, LIVE_PATIENT, PATIENT, REPLY_CHECKER, VOICE_TURN_REVIEW } from "../_shared/prompts.ts";
import { patientPrompt } from "../_shared/patientprompt.ts";
import { type Actions, grade, type Grade, isSingleDiagnosis, matchesDiagnosis, type Rubric, unrated } from "./grade.ts";
import { conditionInsights, type InsightProfile, type Insights } from "./insights.ts";
import { namedDiagnoses } from "./leak.ts";
import { hiddenTests } from "./menu.ts";
import { resumeState } from "./resume.ts";
import { workupText } from "./workup.ts";
import {
  decodeAudio, lastPatientReply, MAX_SPOKEN_CHARS, MAX_TURNS_PER_CALL, pickLiveVoice, pickVoice, speechInstructions, toBase64, turnRefusal,
} from "./voice.ts";
import {
  callSecondsLeft, DEADLINE_SLACK_SECONDS, isOffer, openCall, realtimeModel, realtimeUSDPerMinute, reservedCostUSD, sessionConfig,
} from "../_shared/realtime.ts";
import { closeCalls } from "../_shared/voicecalls.ts";
import { liveSessionPrompt, voiceTurnPrompt } from "../_shared/patientprompt.ts";
import { recordUsage, takeBudget } from "../_shared/usage.ts";
import { speak, speakStream, STREAM_SAMPLE_RATE, transcribe } from "../_shared/speech.ts";
import { requirePlan } from "../_shared/plan.ts";
import { withQuota } from "../_shared/quota.ts";
import { naturalDenial, naturalRefusal, talksAboutScript } from "./refusal.ts";
import { type Conduct, conductReply, isProfane, MAX_INAPPROPRIATE, parseConduct, strikes } from "../_shared/conduct.ts";

declare const EdgeRuntime: { waitUntil(promise: Promise<unknown>): void };

type Fact = { id: string; label: string; reply: string; importance: string; screens_for: string | null };
type Maneuver = { id: string; title: string; finding: string };
type Test = { id: string; name: string; cost: number; turnaround_s: number; delays_care_min: number; result: string; abnormal: boolean };
/** `flag` marks a live-voice reply that broke the patient's rules after it was already heard. */
type Turn = { role: "student" | "patient"; text: string; facts?: string[]; conduct?: Conduct; flag?: "diagnosis" | "invented"; live?: boolean };
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

const LIMITS = { question: 500, reply: 1500, diagnosis: 200, plan: 2000, differential: 10, transcriptTurns: 12 };
/** Facts one reply may reveal; the model lists the most relevant first. More would let one broad
 *  question ("tell me everything") empty the script. */
const MAX_FACTS_PER_REPLY = 3;
/** Slack on a timed attempt for the submit tap and network before it counts as over time. */
const GRACE_MINUTES = 2;

serve(async (req) => {
  const userId = await callerId(req);
  // Cases are part of the paid plan; the app's paywall is only the face of this check.
  await requirePlan(userId);
  const input = await body<Record<string, unknown>>(req);
  switch (input.action) {
    case "start": return json(await start(userId, input));
    case "resume": return json(await resume(userId, input));
    // Each question costs a model call (reply plus check): it counts against the daily limit.
    case "ask": return json(await withQuota(userId, "question", () => ask(userId, input)));
    case "examine": return json(await examine(userId, input));
    case "order": return json(await order(userId, input));
    // Voice mode calls paid audio models; each call counts against the daily voice allowance.
    case "transcribe": return json(await withQuota(userId, "voice", () => transcribeTurn(userId, input)));
    case "speak": return json(await withQuota(userId, "voice", () => speakReply(userId, input)));
    // The same reply as raw PCM, streamed as it's made: the first sound in a few hundred ms.
    case "speak_stream": return await withQuota(userId, "voice", () => speakReplyStream(userId, input));
    case "ask_aloud": return await withQuota(userId, "question", () => askAloud(userId, input));
    // A live call is the priciest thing a student can start: one unit of a small daily allowance.
    case "voice_session": return json(await voiceSession(userId, input));
    // Each logged exchange costs a review call, like a typed question.
    case "voice_turn": return json(await withQuota(userId, "question", () => voiceTurn(userId, input)));
    case "voice_end": return json(await voiceEnd(userId, input));
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

/** The student's unsubmitted attempt at this case, if they left one, with everything it holds, so
 *  reopening the case continues it instead of starting over (resume.ts). */
async function resume(userId: string, input: Record<string, unknown>) {
  const caseId = text(input.case_id, "case_id", 16);
  const [open] = await sql<{ id: string }[]>`
    select id from public.attempts
    where user_id = ${userId} and case_id = ${caseId} and submitted_at is null
    order by started_at desc limit 1`;
  if (!open) return { attempt: null };
  const { attempt, content } = await loadAttempt(userId, open.id);
  return { attempt: resumeState(attempt, content, hiddenTests(content.rubric, attempt.exam_mode)) };
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
    } else if (used.length === 0 && looked.length === 0 && await addsFacts(reply, content.facts)) {
      // Grounded replies (a fact or a visible finding) skip this; only free-floating ones are checked.
      // A medical detail the facts don't have is absent, so the patient says no to it.
      reply = naturalDenial(recent.findLast((t) => t.role === "patient")?.text);
    } else if (talksAboutScript(reply)) {
      // "I haven't said what it is": the model talking about its script. Said as a person would instead.
      reply = naturalRefusal(recent.findLast((t) => t.role === "patient")?.text);
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

/** Second check for replies that matched no fact: did the model slip in medical information the
 *  facts don't have? The facts go with it, so a reply that only restates them (the model left out
 *  the ids) passes. */
async function addsFacts(reply: string, facts: { reply: string }[]): Promise<boolean> {
  const verdict = await completeJSON<{ medical_information: boolean }>(
    REPLY_CHECKER,
    `Facts: ${JSON.stringify(facts.map((f) => f.reply))}\nReply: ${JSON.stringify(reply)}`,
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

// MARK: - voice

/** Primes the transcriber for clinical words without saying anything about this case. */
const TRANSCRIBE_HINT = "A medical student is interviewing a patient: history, symptoms, medications, allergies.";

async function transcribeTurn(userId: string, input: Record<string, unknown>) {
  await loadAttempt(userId, input.attempt_id);
  const audio = decodeAudio(input.audio);
  if (!audio) throw new HttpError(400, "audio must be a base64 m4a recording under 400 KB");
  try {
    return { text: await transcribe(audio, TRANSCRIBE_HINT) };
  } catch (error) {
    console.error("transcription failed", error);
    throw new HttpError(502, "couldn't transcribe that; try again or type your question");
  }
}

/** ask, then its reply's voice in the same response: the JSON answer on the first line, so the app
 *  shows the text at once, then PCM as OpenAI makes it. A voice failure (or no voice allowance
 *  left) just ends the stream after the text; the app falls back to its own voice. */
async function askAloud(userId: string, input: Record<string, unknown>): Promise<Response> {
  const answer = await ask(userId, input);
  const { attempt, content } = await loadAttempt(userId, input.attempt_id, false);
  const persona = content.persona;
  const voice = pickVoice(String(persona.sex ?? ""), attempt.case_id);
  const instructions = speechInstructions(Number(persona.age) || 40, String(persona.sex ?? ""), String(persona.voice ?? ""));
  // Supabase may retire a worker whose response is still streaming; registering the stream as
  // background work keeps it alive until the voice is sent (the wall clock still applies).
  let sent!: () => void;
  EdgeRuntime.waitUntil(new Promise<void>((resolve) => (sent = resolve)));
  // Set when the app stops reading (it interrupted the answer), so writing stops quietly.
  let cancelled = false;
  const body = new ReadableStream<Uint8Array>({
    cancel() {
      cancelled = true;
    },
    async start(out) {
      out.enqueue(new TextEncoder().encode(JSON.stringify(answer) + "\n"));
      try {
        await withQuota(userId, "voice", async () => {
          const reader = (await speakStream(answer.reply.slice(0, MAX_SPOKEN_CHARS), voice, instructions)).getReader();
          for (;;) {
            const { done, value } = await reader.read();
            if (done || cancelled) break;
            out.enqueue(value);
          }
        });
      } catch (error) {
        if (!cancelled) console.error("ask_aloud voice failed", error);
      } finally {
        try {
          out.close();
        } catch {
          // Already cancelled by the app.
        }
        sent();
      }
    },
  });
  return new Response(body, { headers: { "Content-Type": "application/octet-stream", "X-Sample-Rate": String(STREAM_SAMPLE_RATE) } });
}

/** The latest stored patient reply, as raw 24 kHz PCM streamed straight from OpenAI. Errors before
 *  the first byte are normal JSON errors (and refund the quota); after that the stream just ends. */
async function speakReplyStream(userId: string, input: Record<string, unknown>): Promise<Response> {
  const { attempt, content } = await loadAttempt(userId, input.attempt_id);
  const reply = lastPatientReply(attempt.transcript);
  if (!reply) throw new HttpError(404, "no patient reply to speak yet");
  const persona = content.persona;
  const voice = pickVoice(String(persona.sex ?? ""), attempt.case_id);
  const instructions = speechInstructions(Number(persona.age) || 40, String(persona.sex ?? ""), String(persona.voice ?? ""));
  try {
    const audio = await speakStream(reply.slice(0, MAX_SPOKEN_CHARS), voice, instructions);
    // Kept alive until the stream is fully read (see askAloud).
    const [toClient, watched] = audio.tee();
    EdgeRuntime.waitUntil(watched.pipeTo(new WritableStream()).catch(() => {}));
    return new Response(toClient, { headers: { "Content-Type": "audio/pcm", "X-Sample-Rate": String(STREAM_SAMPLE_RATE) } });
  } catch (error) {
    console.error("speech stream failed", error);
    throw new HttpError(502, "couldn't voice the reply");
  }
}

async function speakReply(userId: string, input: Record<string, unknown>) {
  const { attempt, content } = await loadAttempt(userId, input.attempt_id);
  const reply = lastPatientReply(attempt.transcript);
  if (!reply) throw new HttpError(404, "no patient reply to speak yet");
  const persona = content.persona;
  const voice = pickVoice(String(persona.sex ?? ""), attempt.case_id);
  const instructions = speechInstructions(Number(persona.age) || 40, String(persona.sex ?? ""), String(persona.voice ?? ""));
  try {
    return { audio: toBase64(await speak(reply.slice(0, MAX_SPOKEN_CHARS), voice, instructions)), format: "aac" };
  } catch (error) {
    console.error("speech failed", error);
    throw new HttpError(502, "couldn't voice the reply");
  }
}

// MARK: - live voice

type Call = { call_id: string; ends_at: Date; ended_at: Date | null; turns: number };

async function voiceSession(userId: string, input: Record<string, unknown>) {
  const { attempt, content } = await loadAttempt(userId, input.attempt_id);
  if (!isOffer(input.sdp)) throw new HttpError(400, "sdp must be a WebRTC offer under 64 KB");
  if (strikes(attempt.transcript) >= MAX_INAPPROPRIATE) {
    throw new HttpError(403, "the patient has stopped answering questions; you can still examine, order tests and submit");
  }
  // One live call per student at a time: a new one ends whatever was still open.
  await closeCalls({ userId, overdueOnly: false });
  const seconds = callSecondsLeft(await liveVoiceSpentToday(userId));
  if (seconds === 0) {
    throw new HttpError(429, "you've used today's live voice time; it resets at midnight UTC. Turn-by-turn voice and typing still work");
  }
  await takeBudget("voice_live");

  const persona = content.persona;
  const instructions = liveSessionPrompt(
    LIVE_PATIENT,
    { name: String(persona.name), age: persona.age, sex: String(persona.sex), voice: String(persona.voice), background: String(persona.background) },
    speechInstructions(Number(persona.age) || 40, String(persona.sex ?? ""), String(persona.voice ?? "")),
    content.facts, content.exam, attempt.transcript.slice(-LIMITS.transcriptTurns),
  );
  const session = sessionConfig(instructions, pickLiveVoice(String(persona.sex ?? ""), attempt.case_id));
  let answer;
  try {
    answer = await openCall(input.sdp, session, userId);
  } catch (error) {
    console.error("realtime call failed", error);
    throw new HttpError(502, "live voice couldn't start; try again or use turn-by-turn voice");
  }
  // A little slack past the app's own deadline before the server treats the call as overdue.
  await sql`insert into private.voice_calls (call_id, user_id, attempt_id, ends_at)
            values (${answer.callId}, ${userId}, ${attempt.id}, now() + make_interval(secs => ${seconds + DEADLINE_SLACK_SECONDS}))`;
  // Booked at the longest the call can run; closing it settles the difference (_shared/voicecalls.ts).
  const zero = { hit: 0, miss: 0, output: 0, reasoning: 0 };
  await recordUsage("voice_live", `openai/${realtimeModel()}`, zero, reservedCostUSD());
  return { sdp: answer.sdp, call_id: answer.callId, seconds };
}

/** What this student's live calls cost today (UTC), from how long each ran. Calls are closed
 *  before this is read, so every one has its end. */
async function liveVoiceSpentToday(userId: string): Promise<number> {
  const [{ seconds }] = await sql<{ seconds: number }[]>`
    -- Capped at each call's deadline: calls closed late before that cap went in say they ran for hours.
    select coalesce(sum(extract(epoch from least(coalesce(ended_at, ends_at), ends_at) - started_at)), 0)::float8 as seconds
    from private.voice_calls
    where user_id = ${userId} and started_at >= (now() at time zone 'utc')::date::timestamp at time zone 'utc'`;
  return (seconds / 60) * realtimeUSDPerMinute();
}

async function ownCall(userId: string, attemptId: string, callId: unknown): Promise<Call> {
  if (typeof callId !== "string" || !/^rtc_[A-Za-z0-9_]+$/.test(callId)) throw new HttpError(400, "call_id required");
  const [call] = await sql<Call[]>`
    select call_id, ends_at, ended_at, turns from private.voice_calls
    where call_id = ${callId} and user_id = ${userId} and attempt_id = ${attemptId}`;
  if (!call) throw new HttpError(404, "call not found");
  return call;
}

async function voiceTurn(userId: string, input: Record<string, unknown>) {
  const question = text(input.question, "question", LIMITS.question);
  const reply = text(input.reply ?? "", "reply", LIMITS.reply, false);
  const { attempt, content } = await loadAttempt(userId, input.attempt_id);
  const call = await ownCall(userId, attempt.id, input.call_id);
  const refusal = turnRefusal(call);
  if (refusal) throw new HttpError(409, refusal);
  // Counted before the review call, atomically, so parallel requests can't log past the cap.
  const counted = await sql`update private.voice_calls set turns = turns + 1
                            where call_id = ${call.call_id} and turns < ${MAX_TURNS_PER_CALL} returning call_id`;
  if (counted.length === 0) throw new HttpError(409, "this call has logged as many exchanges as it can");
  await closeCalls({ userId, overdueOnly: true });

  const known = new Map(content.facts.map((f) => [f.id, f]));
  let conduct: Conduct = isProfane(question) ? "inappropriate" : "clinical";
  let used: string[] = [];
  let flag: Turn["flag"];
  // The reply was already heard, so a failed review still logs the turn, just without chips.
  try {
    const review = await completeJSON<{ conduct: string; fact_ids: string[]; invented: boolean }>(
      VOICE_TURN_REVIEW, voiceTurnPrompt(content.facts, content.exam, question, reply), 150, { task: "check" },
    );
    if (conduct === "clinical") conduct = parseConduct(review.conduct);
    used = [...new Set(review.fact_ids ?? [])].filter((id) => known.has(id)).slice(0, MAX_FACTS_PER_REPLY);
    if (review.invented === true) flag = "invented";
  } catch (error) {
    console.error("voice turn review failed", error);
  }
  if (namedDiagnoses(reply, [content.answer_key.diagnosis, ...content.answer_key.accepted]).length > 0) flag = "diagnosis";
  if (flag) console.warn("live patient broke a rule", { attempt: attempt.id, flag });
  if (conduct !== "clinical") used = [];

  const asked: Turn = conduct === "clinical" ? { role: "student", text: question } : { role: "student", text: question, conduct };
  // `live`: the app reported these words, so speak never voices them.
  const said: Turn = flag ? { role: "patient", text: reply, facts: used, flag, live: true } : { role: "patient", text: reply, facts: used, live: true };
  const [row] = await sql<{ revealed_facts: string[] }[]>`
    update public.attempts set transcript = transcript || ${sql.json([asked, said])},
      revealed_facts = revealed_facts || array(select f from unnest(${used}::text[]) f where not f = any(revealed_facts))
    where id = ${attempt.id} and submitted_at is null
    returning revealed_facts`;
  if (!row) throw new HttpError(409, "attempt already submitted");

  // Past its deadline, or too many inappropriate questions: the call ends from here too.
  const tooRude = strikes([...attempt.transcript, asked]) >= MAX_INAPPROPRIATE;
  const ended = call.ended_at !== null || new Date(call.ends_at).getTime() < Date.now() || tooRude;
  if (ended && call.ended_at === null) await closeCalls({ callId: call.call_id, overdueOnly: false });

  const fresh = used.filter((id) => !attempt.revealed_facts.includes(id));
  const base = { reply, conduct, flag: flag ?? null, ended };
  if (attempt.exam_mode) return { ...base, revealed: [], revealed_ids: [], coverage: { got: 0, total: 0 } };
  const key = content.rubric.key_facts;
  return {
    ...base,
    revealed: fresh.map((id) => ({ id, label: known.get(id)!.label })),
    revealed_ids: row.revealed_facts,
    coverage: { got: key.filter((f) => row.revealed_facts.includes(f.id)).length, total: key.length },
  };
}

async function voiceEnd(userId: string, input: Record<string, unknown>) {
  const { attempt } = await loadAttempt(userId, input.attempt_id, false);
  const call = await ownCall(userId, attempt.id, input.call_id);
  if (call.ended_at === null) await closeCalls({ callId: call.call_id, overdueOnly: false });
  return {};
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
  return saved;
}

/** The condition insights for a graded attempt, or nothing when the case has no profile (older
 *  hand-written cases) or it can't be read: insights are extra, never a reason to lose a grade.
 *  They go into the stored grade too, so a revisit shows the same. */
async function insights(caseId: string, differential: string[], key: Content["answer_key"]): Promise<Insights | Record<never, never>> {
  try {
    // The live profile kept with the case; older cases fall back to the stored one.
    const [row] = await sql<{ profile: InsightProfile | null }[]>`
      select coalesce(c.profile, p.profile) as profile from private.case_content c
      left join private.condition_profiles p on p.slug = c.condition_slug
      where c.case_id = ${caseId}`;
    return row?.profile ? conditionInsights(row.profile, differential, [key.diagnosis, ...key.accepted]) : {};
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
