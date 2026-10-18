// Voice mode's rules, pure so they're unit-tested: which OpenAI voice a patient speaks with, how to
// steer it, which reply gets spoken, and what audio the student may upload.

/** OpenAI's built-in voices by how they read: lower and higher pitched. */
const LOWER = ["ash", "echo", "onyx", "ballad", "verse", "cedar"];
const HIGHER = ["coral", "nova", "shimmer", "sage", "marin"];

/** Largest recorded turn accepted, decoded: about a minute and a half of AAC at 32 kbps. */
export const MAX_AUDIO_BYTES = 400_000;
/** Longest reply spoken; patient replies are a few sentences, so anything longer isn't one. */
export const MAX_SPOKEN_CHARS = 1200;

/** Small stable hash, so the same patient always gets the same voice. */
function hash(text: string): number {
  let h = 0;
  for (const ch of text) h = (h * 31 + ch.charCodeAt(0)) >>> 0;
  return h;
}

/** A voice that fits the patient's sex, the same one every time for this case. */
export function pickVoice(sex: string, caseId: string): string {
  const s = sex.trim().toLowerCase();
  const pool = s.startsWith("m") ? LOWER : s.startsWith("f") ? HIGHER : [...LOWER, ...HIGHER];
  return pool[hash(caseId) % pool.length];
}

/** How the patient should sound: age, sex and the case's own description of how they talk.
 *  Never the diagnosis: only what the student can already see on the door note. */
export function speechInstructions(age: number, sex: string, howTheyTalk: string): string {
  const who = age < 13 ? `a ${age}-year-old child` : age < 18 ? `a ${age}-year-old teenager` : `a ${age}-year-old ${sex.toLowerCase().startsWith("f") ? "woman" : sex.toLowerCase().startsWith("m") ? "man" : "adult"}`;
  const manner = howTheyTalk.trim() ? ` ${howTheyTalk.trim().replace(/\.?$/, ".")}` : "";
  return `You are ${who}, a patient talking to a doctor. Speak naturally, like a real person, not a narrator.${manner}`;
}

type Turn = { role: string; text: string };

/** The patient's latest reply, the only text this endpoint will speak. */
export function lastPatientReply(transcript: Turn[]): string | null {
  for (let i = transcript.length - 1; i >= 0; i--) {
    if (transcript[i].role === "patient") return transcript[i].text.trim() || null;
  }
  return null;
}

/** The uploaded turn as bytes, or null when it isn't base64 audio of an acceptable size. */
export function decodeAudio(base64: unknown): Uint8Array | null {
  if (typeof base64 !== "string" || base64.length === 0 || base64.length > Math.ceil(MAX_AUDIO_BYTES / 3) * 4 + 4) return null;
  try {
    const bytes = Uint8Array.from(atob(base64), (c) => c.charCodeAt(0));
    return bytes.length >= 256 && bytes.length <= MAX_AUDIO_BYTES ? bytes : null;
  } catch {
    return null;
  }
}

/** Base64 for the JSON reply. Chunked, since spreading a large array overflows the call stack. */
export function toBase64(bytes: Uint8Array): string {
  let binary = "";
  for (let i = 0; i < bytes.length; i += 0x8000) binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(binary);
}
