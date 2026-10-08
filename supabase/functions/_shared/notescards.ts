// Cards written from a student's notes must read like any other card: about the medicine, never
// about where it came from ("according to your notes", "what does the lecture say…"). These checks
// back up the prompt, and the deck is named after its topic rather than the file it came from.

// Phrases that point at the source instead of the subject.
const SOURCE_MENTION =
  /\b(according to|as (stated|described|noted|mentioned|listed) in|based on|from|per|in) (the |your |these |this )?(notes?|lecture|slides?|handouts?|documents?|text|pdf|photos?|pages?|reading|material)\b|\b(your|the|these) notes\b|\bthe (lecture|slides?|handout|document|text|pdf)\b/i;

/** True when a card talks about the notes instead of the topic. */
export function mentionsSource(text: string): boolean {
  return SOURCE_MENTION.test(text);
}

/** The model's topic title as a deck name: one line, no source words, up to 40 characters. */
export function deckTitle(raw: unknown, fallback: string): string {
  if (typeof raw !== "string") return fallback;
  const title = raw.replace(/\s+/g, " ").trim().replace(/^["']|["']$/g, "");
  if (!title || mentionsSource(title) || /\bnotes?\b/i.test(title)) return fallback;
  return title.length <= 40 ? title : title.slice(0, 39).trimEnd() + "…";
}
