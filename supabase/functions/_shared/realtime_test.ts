import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  bookedSeconds, callCostUSD, callIdFrom, IDLE_SECONDS, isOffer, MAX_SDP_BYTES, realtimeUSDPerMinute, safetyId, sessionConfig, settlementUSD, SWEEP_SECONDS,
} from "./realtime.ts";

Deno.test("only real SDP offers under the cap are forwarded", () => {
  assert(isOffer("v=0\r\no=- 1 2 IN IP4 127.0.0.1\r\n"));
  assert(!isOffer("hello"));
  assert(!isOffer(42));
  assert(!isOffer("v=0" + "a".repeat(MAX_SDP_BYTES)));
});

Deno.test("the session config keeps instructions, voice and turn detection on the server", () => {
  const config = sessionConfig("Be the patient.", "marin", "gpt-realtime-2.1");
  assertEquals(config.type, "realtime");
  assertEquals(config.model, "gpt-realtime-2.1");
  assertEquals(config.instructions, "Be the patient.");
  assertEquals(config.audio.output.voice, "marin");
  assertEquals(config.audio.input.turn_detection.type, "semantic_vad");
  // The student's words are transcribed: they're logged and graded.
  assertEquals(config.audio.input.transcription.model, "gpt-transcribe");
});

Deno.test("the call id comes from the Location header", () => {
  assertEquals(callIdFrom("/v1/realtime/calls/rtc_u0_EaWOcp3oMQ"), "rtc_u0_EaWOcp3oMQ");
  assertEquals(callIdFrom(null), null);
  assertEquals(callIdFrom("/v1/realtime/calls/../../evil"), null);
});

Deno.test("the safety identifier is a stable hash, never the user id itself", async () => {
  const id = "3b6a1c2e-0000-4000-8000-000000000001";
  const a = await safetyId(id);
  assertEquals(a, await safetyId(id));
  assert(/^[0-9a-f]{64}$/.test(a));
  assert(!a.includes(id));
});

Deno.test("a call books its window plus a sweep, then settles to the time it really ran", () => {
  assertEquals(bookedSeconds(IDLE_SECONDS), IDLE_SECONDS + SWEEP_SECONDS);
  assertEquals(callCostUSD(90, 0.6), 0.9);
  // Booked (open plus extensions, up to a window of `window` seconds) plus settlement is the cost of
  // the actual duration, however long the call grew.
  for (const [ran, window] of [[0, 120], [45, 120], [120, 120], [1800, 1850], [4000, 3990]]) {
    const total = callCostUSD(bookedSeconds(window), 0.6) + settlementUSD(ran, window, 0.6);
    assert(Math.abs(total - 0.6 * ran / 60) < 1e-9, `${ran}s of ${window}s`);
  }
  assert(settlementUSD(60, IDLE_SECONDS, 0.6) < 0);
  assertEquals(settlementUSD(-5, IDLE_SECONDS, 0.6), -callCostUSD(bookedSeconds(IDLE_SECONDS), 0.6));
});

Deno.test("the per-minute rate falls back on a missing or bad override", () => {
  assertEquals(realtimeUSDPerMinute("0.2"), 0.2);
  assertEquals(realtimeUSDPerMinute(undefined, "gpt-realtime-2.1"), 0.15);
  assertEquals(realtimeUSDPerMinute("-1", "gpt-realtime-2.1"), 0.15);
  assertEquals(realtimeUSDPerMinute("abc", "gpt-realtime-2.1-mini"), 0.05);
});

