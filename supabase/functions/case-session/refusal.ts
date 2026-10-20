// The patient never talks about its own script. The fast chat model sometimes answers a question its
// facts don't cover with "I haven't said what it is", and repeats it word for word; that line is
// swapped for something a real patient would say. Pure, so the rules are unit-tested.

/** Replies that talk about the case instead of from inside it. */
const META = /\b(?:i\s+(?:haven't|have not|didn't|did not)\s+(?:said|told you|mentioned)|my (?:facts|notes|script|instructions)|(?:not|isn't|wasn't) in my (?:facts|notes|list|information)|the facts (?:say|don't))\b/i;

/** What a person says when they can't or won't answer, in a few shapes so a repeat sounds natural. */
const NATURAL = [
  "Honestly, I'm not sure. I'd have to think about it.",
  "I'd rather not get into that right now.",
  "I really don't know, sorry.",
  "Hmm, I can't say for sure.",
];

/** What a patient says to a health question their facts don't cover: anything not listed is absent. */
const DENIALS = [
  "No, nothing like that.",
  "Not that I've noticed, no.",
  "No, I haven't had that.",
  "No, that hasn't been a problem.",
];

export function talksAboutScript(reply: string): boolean {
  return META.test(reply);
}

/** A natural stand-in for a scripted refusal, never the patient's previous reply word for word. */
export function naturalRefusal(previous: string | undefined, rng: () => number = Math.random): string {
  const options = NATURAL.filter((line) => line !== previous?.trim());
  return options[Math.floor(rng() * options.length) % options.length];
}

/** A plain "no" in place of a reply that slipped in a medical detail the case doesn't have. Never the
 *  previous reply word for word. */
export function naturalDenial(previous: string | undefined, rng: () => number = Math.random): string {
  const options = DENIALS.filter((line) => line !== previous?.trim());
  return options[Math.floor(rng() * options.length) % options.length];
}
