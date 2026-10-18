import { assert, assertEquals } from "jsr:@std/assert@1";
import { decodeAudio, lastPatientReply, MAX_AUDIO_BYTES, pickVoice, speechInstructions, toBase64 } from "./voice.ts";

Deno.test("a patient keeps the same voice, matched to their sex", () => {
  assertEquals(pickVoice("M", "C42"), pickVoice("Male", "C42"));
  assert(["ash", "echo", "onyx", "ballad", "verse", "cedar"].includes(pickVoice("M", "C42")));
  assert(["coral", "nova", "shimmer", "sage", "marin"].includes(pickVoice("F", "R7")));
});

Deno.test("instructions describe the person and how they talk, nothing else", () => {
  assertEquals(speechInstructions(68, "F", "Anxious, short sentences"),
    "You are a 68-year-old woman, a patient talking to a doctor. Speak naturally, like a real person, not a narrator. Anxious, short sentences.");
  assert(speechInstructions(8, "M", "").startsWith("You are a 8-year-old child"));
  assert(speechInstructions(15, "F", "").includes("teenager"));
});

Deno.test("only the latest patient reply is spoken", () => {
  const t = [{ role: "student", text: "Hi" }, { role: "patient", text: "Hello doctor." }, { role: "student", text: "Pain?" }];
  assertEquals(lastPatientReply(t), "Hello doctor.");
  assertEquals(lastPatientReply([{ role: "student", text: "Hi" }]), null);
  assertEquals(lastPatientReply([]), null);
});

Deno.test("uploads must be base64 audio within the size limit", () => {
  const ok = new Uint8Array(1000).fill(7);
  assertEquals(decodeAudio(toBase64(ok))?.length, 1000);
  assertEquals(decodeAudio(toBase64(new Uint8Array(10))), null);           // too small to be speech
  assertEquals(decodeAudio(toBase64(new Uint8Array(MAX_AUDIO_BYTES + 1))), null);
  assertEquals(decodeAudio("not base64!!"), null);
  assertEquals(decodeAudio(42), null);
});
