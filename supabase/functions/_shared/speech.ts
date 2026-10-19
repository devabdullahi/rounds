// OpenAI speech for voice mode: the patient's reply as audio (gpt-4o-mini-tts) and the student's
// recorded turn as text (gpt-transcribe). Only case-session calls these, after it has checked the
// caller owns the attempt. Each call is logged in private.llm_usage with an estimated cost, so the
// project-wide daily cap counts it like the text models.

import { recordUsage, takeBudget } from "./usage.ts";

const SPEECH_URL = "https://api.openai.com/v1/audio/speech";
const TRANSCRIBE_URL = "https://api.openai.com/v1/audio/transcriptions";
export const SPEAK_MODEL = "gpt-4o-mini-tts";
export const TRANSCRIBE_MODEL = "gpt-transcribe";
const TIMEOUT_MS = 30_000;

/** Rough list prices for the cap: speech about $0.015 per spoken minute (~900 characters), and
 *  transcription about $0.006 per minute of AAC at ~4 KB a second. */
export function speakCostUSD(characters: number): number {
  return (characters / 900) * 0.015;
}
export function transcribeCostUSD(bytes: number): number {
  return (bytes / 4000 / 60) * 0.006;
}

function key(): string {
  const value = Deno.env.get("OPENAI_API_KEY");
  if (!value) throw new Error("OPENAI_API_KEY is not set");
  return value;
}

/** The text spoken in `voice`, steered by `instructions` (age, manner), as AAC audio. */
export async function speak(text: string, voice: string, instructions: string): Promise<Uint8Array> {
  await takeBudget();
  const res = await fetch(SPEECH_URL, {
    method: "POST",
    headers: { Authorization: `Bearer ${key()}`, "Content-Type": "application/json" },
    signal: AbortSignal.timeout(TIMEOUT_MS),
    body: JSON.stringify({ model: SPEAK_MODEL, voice, input: text, instructions, response_format: "aac" }),
  });
  if (!res.ok) throw new Error(`speech ${res.status}: ${await res.text()}`);
  const audio = new Uint8Array(await res.arrayBuffer());
  await recordUsage("speak", `openai/${SPEAK_MODEL}`, { hit: 0, miss: text.length, output: audio.length, reasoning: 0 }, speakCostUSD(text.length));
  return audio;
}

/** Sample rate of streamed speech: OpenAI's raw PCM is 24 kHz, 16-bit little-endian, mono. */
export const STREAM_SAMPLE_RATE = 24_000;

/** The same speech as a stream of raw PCM, passed on as OpenAI produces it, so the phone starts
 *  playing after the first chunk instead of the whole file. */
export async function speakStream(text: string, voice: string, instructions: string): Promise<ReadableStream<Uint8Array>> {
  await takeBudget();
  const res = await fetch(SPEECH_URL, {
    method: "POST",
    headers: { Authorization: `Bearer ${key()}`, "Content-Type": "application/json" },
    signal: AbortSignal.timeout(TIMEOUT_MS),
    body: JSON.stringify({ model: SPEAK_MODEL, voice, input: text, instructions, response_format: "pcm" }),
  });
  if (!res.ok || !res.body) throw new Error(`speech ${res.status}: ${await res.text()}`);
  await recordUsage("speak", `openai/${SPEAK_MODEL}`, { hit: 0, miss: text.length, output: 0, reasoning: 0 }, speakCostUSD(text.length));
  return res.body;
}

/** What the student said in a recorded m4a turn. `hint` primes medical vocabulary. */
export async function transcribe(audio: Uint8Array, hint: string): Promise<string> {
  await takeBudget();
  const form = new FormData();
  form.append("model", TRANSCRIBE_MODEL);
  form.append("file", new Blob([audio.slice()], { type: "audio/mp4" }), "turn.m4a");
  form.append("language", "en");
  form.append("prompt", hint);
  const res = await fetch(TRANSCRIBE_URL, {
    method: "POST",
    headers: { Authorization: `Bearer ${key()}` },
    signal: AbortSignal.timeout(TIMEOUT_MS),
    body: form,
  });
  if (!res.ok) throw new Error(`transcription ${res.status}: ${await res.text()}`);
  const { text } = await res.json() as { text?: string };
  await recordUsage("transcribe", `openai/${TRANSCRIBE_MODEL}`, { hit: 0, miss: audio.length, output: 0, reasoning: 0 }, transcribeCostUSD(audio.length));
  return (text ?? "").trim();
}
