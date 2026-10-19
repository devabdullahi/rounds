import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  CALL_SECONDS, callIdFrom, callSecondsLeft, isOffer, MAX_CALL_SECONDS, MAX_SDP_BYTES, realtimeUSDPerMinute, reservedCostUSD, safetyId, sessionConfig, settlementUSD,
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

Deno.test("a call books its longest possible run, then settles to the time it really ran", () => {
  assert(MAX_CALL_SECONDS > CALL_SECONDS);
  assertEquals(reservedCostUSD(0.6), 0.6 * MAX_CALL_SECONDS / 60);
  // Reservation plus settlement is the cost of the actual duration.
  for (const seconds of [0, 45, CALL_SECONDS, MAX_CALL_SECONDS + 600]) {
    const total = reservedCostUSD(0.6) + settlementUSD(seconds, 0.6);
    assert(Math.abs(total - 0.6 * seconds / 60) < 1e-9, `${seconds}s`);
  }
  assert(settlementUSD(60, 0.6) < 0);
  assertEquals(settlementUSD(-5, 0.6), -reservedCostUSD(0.6));
});

Deno.test("the per-minute rate falls back on a missing or bad override", () => {
  assertEquals(realtimeUSDPerMinute("0.2"), 0.2);
  assertEquals(realtimeUSDPerMinute(undefined, "gpt-realtime-2.1"), 0.15);
  assertEquals(realtimeUSDPerMinute("-1", "gpt-realtime-2.1"), 0.15);
  assertEquals(realtimeUSDPerMinute("abc", "gpt-realtime-2.1-mini"), 0.05);
});

Deno.test("a call runs five minutes while the day's budget allows, then shorter, then not at all", () => {
  // $0.15 a minute against $2 a day.
  assertEquals(callSecondsLeft(0, 0.15, 2), 300);
  assertEquals(callSecondsLeft(1.85, 0.15, 2), 60);
  assertEquals(callSecondsLeft(1.95, 0.15, 2), 0); // 20 s left isn't worth a call
  assertEquals(callSecondsLeft(2.5, 0.15, 2), 0);
});
