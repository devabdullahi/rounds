import { assertEquals } from "jsr:@std/assert";
import { deckTitle, mentionsSource } from "./notescards.ts";

Deno.test("cards that point at the notes are caught", () => {
  for (const text of [
    "According to the notes, what is the first-line treatment?",
    "What do your notes say about BNP?",
    "As described in the lecture, which drug class…",
    "Based on these slides, what defines HFrEF?",
    "What does the PDF list as a cause?",
  ]) assertEquals(mentionsSource(text), true, text);
});

Deno.test("ordinary clinical cards pass", () => {
  for (const text of [
    "What ejection fraction defines HFrEF?",
    "Which finding on exam suggests volume overload?",
    "A 54-year-old with exertional dyspnea: what is the next test?",
    "What does an S3 gallop indicate?",
  ]) assertEquals(mentionsSource(text), false, text);
});

Deno.test("deck titles are the topic, tidy and short", () => {
  assertEquals(deckTitle("  Heart   failure ", "Notes"), "Heart failure");
  assertEquals(deckTitle("\"Asthma\"", "Notes"), "Asthma");
  assertEquals(deckTitle("Cardiology lecture notes", "Fallback"), "Fallback");
  assertEquals(deckTitle(undefined, "Fallback"), "Fallback");
  assertEquals(deckTitle("A".repeat(60), "x").length, 40);
});
