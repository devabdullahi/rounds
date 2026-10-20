// Live voice over OpenAI's Realtime API (WebRTC, unified interface). The app sends its SDP offer
// here; we forward it with the session config and our key to /v1/realtime/calls and hand back
// OpenAI's SDP answer. Audio then flows phone ↔ OpenAI and our server is out of the loop, so the
// key and the patient's instructions never reach the device.
//
// No OpenAI-Beta header: that is the old beta interface.

const CALLS_URL = "https://api.openai.com/v1/realtime/calls";

/** The speech-to-speech model; REALTIME_MODEL overrides it (e.g. gpt-realtime-2.1). Mini by default:
 *  in a side-by-side test (2026-10-19) it answered in character as well, its first audio came sooner
 *  (~0.7 s vs ~0.9 s) and it costs about a third, so the daily budget buys about three times the
 *  minutes. */
export function realtimeModel(): string {
  return Deno.env.get("REALTIME_MODEL") ?? "gpt-realtime-2.1-mini";
}

/** How long one live call may run before the app (and failing that, the server) ends it. */
export const CALL_SECONDS = 300;

/** Slack past the app's own deadline before the server treats a call as overdue. */
export const DEADLINE_SLACK_SECONDS = 30;

/** How often voice-sweep hangs up overdue calls (its pg_cron schedule, migration
 *  20261019000300_voice_call_sweeper). */
export const SWEEP_SECONDS = 60;

/** The longest a call can really run: its deadline, the slack, then at most one sweep interval
 *  before the sweeper hangs it up, even when the app never reports back. */
export const MAX_CALL_SECONDS = CALL_SECONDS + DEADLINE_SLACK_SECONDS + SWEEP_SECONDS;

/** Estimated USD per minute of a live call, for the project-wide daily cap (the audio isn't
 *  metered here: it flows phone ↔ OpenAI). REALTIME_USD_PER_MINUTE overrides it. */
export function realtimeUSDPerMinute(raw = Deno.env.get("REALTIME_USD_PER_MINUTE"), model = realtimeModel()): number {
  const value = Number(raw);
  if (raw !== undefined && Number.isFinite(value) && value > 0) return value;
  // About $0.05 a minute on mini (audio $10/$20 per 1M tokens), $0.15 on the full model.
  return model.endsWith("-mini") ? 0.05 : 0.15;
}

/** What one student may spend on live voice a day, in USD (2026-10-19: $2, then they'd buy more).
 *  LIVE_VOICE_USD_PER_DAY overrides it. */
export function dailyVoiceBudgetUSD(raw = Deno.env.get("LIVE_VOICE_USD_PER_DAY")): number {
  const value = Number(raw);
  return raw !== undefined && Number.isFinite(value) && value > 0 ? value : 2;
}

/** A call shorter than this isn't worth opening: the student would barely get a question in. */
export const MIN_CALL_SECONDS = 30;

/** How long the next call may run, given what the student spent on live voice today: the usual
 *  CALL_SECONDS, or less when the day's budget is nearly used up; 0 when it can't buy a short call. */
export function callSecondsLeft(spentUSD: number, perMinute = realtimeUSDPerMinute(), budget = dailyVoiceBudgetUSD()): number {
  // The epsilon keeps float error ($0.15 left at $0.15 a minute = 59.999… s) from losing a second.
  const affordable = Math.floor(((budget - spentUSD) / perMinute) * 60 + 1e-6);
  return affordable < MIN_CALL_SECONDS ? 0 : Math.min(CALL_SECONDS, affordable);
}

/** What a call books against the daily cap when it opens: the longest it could run. */
export function reservedCostUSD(perMinute = realtimeUSDPerMinute()): number {
  return (perMinute * MAX_CALL_SECONDS) / 60;
}

/** The correction booked when a call closes, so the cap ends up charged for the time it actually
 *  ran. Negative for every call that ended inside the reservation. */
export function settlementUSD(seconds: number, perMinute = realtimeUSDPerMinute()): number {
  return (perMinute * Math.max(0, seconds)) / 60 - reservedCostUSD(perMinute);
}

/** Largest SDP offer accepted; real offers are a few KB. */
export const MAX_SDP_BYTES = 64 * 1024;

/** Turn detection, decided here rather than in the app. Semantic VAD judges from the words whether
 *  the student has finished, so it cuts in less on the pauses of someone thinking up a question.
 *  "high" answers soonest (end-of-turn waiting is a third of a voice reply's delay); if students
 *  get cut off mid-question, REALTIME_EAGERNESS=medium (or low) gives them longer. */
function turnDetection() {
  const eagerness = Deno.env.get("REALTIME_EAGERNESS") ?? "high";
  return { type: "semantic_vad", eagerness: ["low", "medium", "high", "auto"].includes(eagerness) ? eagerness : "high" };
}

/** Primes the student's transcript for clinical words without saying anything about this case. */
const TRANSCRIBE_PROMPT = "A medical student is interviewing a patient: history, symptoms, medications, allergies.";

/** A real SDP offer: text that starts with v=0 and fits the size cap. */
export function isOffer(sdp: unknown): sdp is string {
  return typeof sdp === "string" && sdp.startsWith("v=0") && new TextEncoder().encode(sdp).length <= MAX_SDP_BYTES;
}

/** The session config sent with the offer. Input transcription is on, because the student's own
 *  words are logged and graded; the patient's words come from the model's audio transcript.
 *
 *  Accepted risk: the app holds the call's data channel, so a modified client can send its own
 *  session.update (new instructions, no output cap). This API offers no way to lock the session
 *  from the server short of a sideband connection held for the whole call, which an edge function
 *  can't do. What bounds it: the call needs an active plan and a unit of the small daily
 *  allowance, it is hung up within MAX_CALL_SECONDS by voice-sweep, and its cost is booked. */
export function sessionConfig(instructions: string, voice: string, model = realtimeModel()) {
  return {
    type: "realtime",
    model,
    instructions,
    output_modalities: ["audio"],
    // Audio counts against this: a 400 cap cut a four-sentence reply off mid-sentence (status
    // "incomplete", reason max_output_tokens; 2026-10-19), and that reply needed ~830. Replies are
    // told to stay at 1-2 sentences; the cap is only a backstop against a runaway answer.
    max_output_tokens: 1500,
    audio: {
      input: { transcription: { model: "gpt-transcribe", prompt: TRANSCRIBE_PROMPT }, turn_detection: turnDetection() },
      output: { voice },
    },
  };
}

/** The call id from the Location header ("/v1/realtime/calls/rtc_…"), or null. */
export function callIdFrom(location: string | null): string | null {
  const id = location?.split("/").pop() ?? "";
  return /^rtc_[A-Za-z0-9_]+$/.test(id) ? id : null;
}

/** A stable, privacy-preserving id for OpenAI's abuse monitoring: a hash, never an email. */
export async function safetyId(userId: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(`rounds:${userId}`));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function apiKey(): string {
  const key = Deno.env.get("OPENAI_API_KEY");
  if (!key) throw new Error("OPENAI_API_KEY is not set");
  return key;
}

/** Opens the call: OpenAI's SDP answer and the call's id. Throws with OpenAI's error text on failure. */
export async function openCall(offer: string, session: unknown, userId: string): Promise<{ sdp: string; callId: string }> {
  const form = new FormData();
  form.set("sdp", offer);
  form.set("session", JSON.stringify(session));
  const res = await fetch(CALLS_URL, {
    method: "POST",
    headers: { Authorization: `Bearer ${apiKey()}`, "OpenAI-Safety-Identifier": await safetyId(userId) },
    body: form,
    signal: AbortSignal.timeout(15_000),
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`realtime ${res.status}: ${text.slice(0, 500)}`);
  const callId = callIdFrom(res.headers.get("location"));
  if (!callId || !text.startsWith("v=0")) throw new Error("realtime answer missing SDP or call id");
  return { sdp: text, callId };
}

/** Ends a call from the server side. Best effort: a call that already ended is fine. */
export async function hangUp(callId: string): Promise<void> {
  try {
    const res = await fetch(`${CALLS_URL}/${callId}/hangup`, {
      method: "POST",
      headers: { Authorization: `Bearer ${apiKey()}` },
      signal: AbortSignal.timeout(10_000),
    });
    if (!res.ok && res.status !== 404) console.error("realtime hangup failed", res.status, await res.text());
  } catch (error) {
    console.error("realtime hangup failed", error);
  }
}
