import { assertEquals } from "jsr:@std/assert";
import { conductReply, isProfane, MAX_INAPPROPRIATE, parseConduct, strikes } from "./conduct.ts";

Deno.test("profanity is caught, including hidden spellings", () => {
  for (const text of ["what the fuck", "F*CK this", "f**k", "this is sh!t", "you bitch", "piss off", "stfu", "Bullshit"]) {
    assertEquals(isProfane(text), true, text);
  }
});

Deno.test("clinical words that contain the same letters pass", () => {
  for (const text of [
    "Any shiitake mushrooms or new foods?",
    "Do you have pain when you pass urine?",
    "How many sexual partners have you had in the last year?",
    "Do you drink alcohol or use any drugs?",
    "Have you ever felt like hurting yourself?",
    "Does your shift work affect your sleep?",
    "Any bloody stool?",
  ]) {
    assertEquals(isProfane(text), false, text);
  }
});

Deno.test("an unknown label counts as clinical", () => {
  assertEquals(parseConduct("off_topic"), "off_topic");
  assertEquals(parseConduct("inappropriate"), "inappropriate");
  assertEquals(parseConduct("rude"), "clinical");
  assertEquals(parseConduct(undefined), "clinical");
});

Deno.test("only flagged student turns are strikes", () => {
  assertEquals(strikes([
    { role: "student", conduct: "inappropriate" },
    { role: "patient" },
    { role: "student", conduct: "off_topic" },
    { role: "student" },
    { role: "student", conduct: "inappropriate" },
  ]), 2);
});

Deno.test("the last allowed strike gets the closing line", () => {
  assertEquals(conductReply("inappropriate", MAX_INAPPROPRIATE), "I'm not comfortable continuing this conversation.");
  assertEquals(conductReply("inappropriate", 1).includes("respectful"), true);
});
