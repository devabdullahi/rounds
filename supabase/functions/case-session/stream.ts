// What of a patient reply the student may see while the model is still writing it. Pure, so the
// rules are unit-tested.
//
// The patient model writes {"conduct", "fact_ids", "seen_ids", "reply"} in that order, so by the time
// the reply starts, its conduct and facts are known. Only a reply that will pass unchanged is shown
// early: a clinical one grounded in a fact or a visible finding (an ungrounded one waits for the
// second check, which may swap it). Each piece is checked for the diagnosis name and script talk
// before it's shown, and the last word is held back until the next one starts, so a name is always
// whole (and caught) before any of it could be shown. A reply that trips a check stops showing;
// the finished answer replaces whatever was shown either way.

import { namedDiagnoses } from "./leak.ts";
import { talksAboutScript } from "./refusal.ts";

/** The fields of a patient answer that are complete so far, and the reply's text so far. */
export type PartialAnswer = { conduct?: string; factIds?: string[]; seenIds?: string[]; reply?: string };

/** Reads what it can from the model's unfinished JSON. Arrays count only once closed; the reply is
 *  its decoded text up to the last whole character. */
export function partialAnswer(raw: string): PartialAnswer {
  const out: PartialAnswer = {};
  const conduct = raw.match(/"conduct"\s*:\s*"([^"\\]*)"/);
  if (conduct) out.conduct = conduct[1];
  out.factIds = idList(raw, "fact_ids");
  out.seenIds = idList(raw, "seen_ids");
  const start = raw.match(/"reply"\s*:\s*"/);
  if (start?.index !== undefined) out.reply = stringPrefix(raw.slice(start.index + start[0].length));
  return out;
}

function idList(raw: string, key: string): string[] | undefined {
  const match = raw.match(new RegExp(`"${key}"\\s*:\\s*(\\[[^\\]]*\\])`));
  if (!match) return undefined;
  try {
    const list = JSON.parse(match[1]);
    return Array.isArray(list) ? list.filter((id): id is string => typeof id === "string") : undefined;
  } catch {
    return undefined;
  }
}

const ESCAPES: Record<string, string> = { '"': '"', "\\": "\\", "/": "/", b: "\b", f: "\f", n: "\n", r: "\r", t: "\t" };

/** A JSON string body decoded up to its closing quote, or up to the last complete character. */
function stringPrefix(body: string): string {
  let text = "";
  for (let i = 0; i < body.length; i++) {
    const c = body[i];
    if (c === '"') break;
    if (c !== "\\") {
      text += c;
      continue;
    }
    const next = body[i + 1];
    if (next === undefined) break;
    if (next === "u") {
      const hex = body.slice(i + 2, i + 6);
      if (!/^[0-9a-fA-F]{4}$/.test(hex)) break;
      text += String.fromCharCode(parseInt(hex, 16));
      i += 5;
    } else {
      text += ESCAPES[next] ?? next;
      i += 1;
    }
  }
  return text;
}

/** Follows one streamed reply and says how much of it the student may see. */
export class ReplyGate {
  private shown = "";
  /** Undecided until the reply starts; then whether this reply streams at all. */
  private open: boolean | undefined;

  constructor(
    private readonly names: string[],
    private readonly facts: Set<string>,
    private readonly findings: Set<string>,
  ) {}

  /** The reply text the student may see now, or null when that hasn't grown since last time. */
  update(raw: string): string | null {
    if (this.open === false) return null;
    const answer = partialAnswer(raw);
    if (answer.reply === undefined) return null;
    if (this.open === undefined) {
      const grounded = (answer.factIds ?? []).some((id) => this.facts.has(id))
        || (answer.seenIds ?? []).some((id) => this.findings.has(id));
      this.open = answer.conduct === "clinical" && grounded;
      if (!this.open) return null;
    }
    if (namedDiagnoses(answer.reply, this.names).length > 0 || talksAboutScript(answer.reply)) {
      this.open = false;
      return null;
    }
    // Up to the last whitespace: the word being written waits until the next one starts.
    const cut = answer.reply.search(/\s\S*$/);
    const safe = cut < 0 ? "" : answer.reply.slice(0, cut).trimEnd();
    if (safe.length <= this.shown.length) return null;
    this.shown = safe;
    return safe;
  }
}
