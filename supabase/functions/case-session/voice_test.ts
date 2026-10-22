import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  decodeAudio, lastPatientReply, MAX_AUDIO_BYTES, pickLiveVoice, pickVoice, speechInstructions, toBase64, turnRefusal,
} from "./voice.ts";

Deno.test("a patient keeps the same voice, matched to their sex", () => {
  assertEquals(pickVoice("M", "C42"), pickVoice("Male", "C42"));
  assert(["ash", "echo", "onyx", "ballad", "verse", "cedar"].includes(pickVoice("M", "C42")));
  assert(["coral", "nova", "shimmer", "sage", "marin"].includes(pickVoice("F", "R7")));
});

Deno.test("instructions describe the person and how they talk, nothing else", () => {
  assertEquals(speechInstructions(68, "F", "Anxious, short sentences"),
    "You are a 68-year-old woman, a patient talking to a doctor. Speak naturally, like a real person, not a narrator: conversational pace, small pauses where you'd think, and a voice that sounds as unwell or worried as the words. Anxious, short sentences.");
  assert(speechInstructions(8, "M", "").startsWith("You are a 8-year-old child"));
  assert(speechInstructions(15, "F", "").includes("teenager"));
});

Deno.test("only the latest patient reply is spoken", () => {
  const t = [{ role: "student", text: "Hi" }, { role: "patient", text: "Hello doctor." }, { role: "student", text: "Pain?" }];
  assertEquals(lastPatientReply(t), "Hello doctor.");
  assertEquals(lastPatientReply([{ role: "student", text: "Hi" }]), null);
  assertEquals(lastPatientReply([]), null);
});

Deno.test("a live-call reply is never voiced, since the app supplied its words", () => {
  assertEquals(lastPatientReply([{ role: "patient", text: "Say anything.", live: true }]), null);
  assertEquals(lastPatientReply([{ role: "patient", text: "Typed reply." }, { role: "patient", text: "Live.", live: true }]), null);
});

Deno.test("a live call logs exchanges only while open and briefly after", () => {
  const now = new Date("2026-10-19T12:00:00Z");
  const at = (s: number) => new Date(now.getTime() + s * 1000);
  const open = { ends_at: at(120), ended_at: null };
  assertEquals(turnRefusal(open, now), null);
  assertEquals(turnRefusal({ ...open, ended_at: at(-5) }, now), null);             // last exchange in flight
  assertEquals(turnRefusal({ ...open, ended_at: at(-60) }, now), "call ended");
  assertEquals(turnRefusal({ ...open, ends_at: at(-10) }, now), null);
  assertEquals(turnRefusal({ ...open, ends_at: at(-60) }, now), "call ended");
});

Deno.test("uploads must be base64 audio within the size limit", () => {
  const ok = new Uint8Array(1000).fill(7);
  assertEquals(decodeAudio(toBase64(ok))?.length, 1000);
  assertEquals(decodeAudio(toBase64(new Uint8Array(10))), null);           // too small to be speech
  assertEquals(decodeAudio(toBase64(new Uint8Array(MAX_AUDIO_BYTES + 1))), null);
  assertEquals(decodeAudio("not base64!!"), null);
  assertEquals(decodeAudio(42), null);
});

Deno.test("live calls use only voices the Realtime API offers, steady per case", () => {
  const offered = ["alloy", "ash", "ballad", "coral", "echo", "sage", "shimmer", "verse", "marin", "cedar"];
  for (const sex of ["M", "F", "X"]) {
    for (const caseId of ["c1", "c2", "c3", "c4"]) assert(offered.includes(pickLiveVoice(sex, caseId)), `${sex} ${caseId}`);
  }
  assertEquals(pickLiveVoice("F", "c9"), pickLiveVoice("F", "c9"));
});
