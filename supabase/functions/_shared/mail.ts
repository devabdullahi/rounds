// Sends one email through Amazon SES over SMTP, with no third-party library.
//
// Implicit TLS on port 465: Supabase Edge Functions block outbound 25 and 587. Credentials are the
// SES SMTP user and password (function secrets SES_SMTP_HOST / SES_SMTP_USER / SES_SMTP_PASS),
// and mail goes out from AUTH_SENDER_EMAIL, an identity verified in SES.

export interface Mail {
  to: string;
  subject: string;
  html: string;
  text: string;
}

const encoder = new TextEncoder();
const decoder = new TextDecoder();
/** A stalled SES connection is cut after this, so the caller's error handling always runs. */
const TIMEOUT_MS = 15_000;

export async function sendMail(mail: Mail): Promise<void> {
  const host = env("SES_SMTP_HOST");
  const from = env("AUTH_SENDER_EMAIL");
  for (const address of [mail.to, from]) {
    // An address is copied into SMTP commands and headers: only printable ASCII without spaces or
    // angle brackets, so it can't end a command or add a header of its own.
    if (!/^[\x21-\x7E]+@[\x21-\x7E]+$/.test(address) || /[<>]/.test(address)) throw new Error("invalid email address");
  }

  const conn = await Deno.connectTls({ hostname: host, port: 465 });
  // Closing the connection makes any pending read throw, which ends the exchange below.
  const timer = setTimeout(() => conn.close(), TIMEOUT_MS);
  const reader = new LineReader(conn);
  // Each step is named explicitly: a label taken from the command would put the base64
  // credentials into error messages, and from there into the logs.
  const send = async (line: string, expect: number, step: string) => {
    await writeAll(conn, line + "\r\n");
    await reader.expect(expect, step);
  };

  try {
    await reader.expect(220, "greeting");
    await send(`EHLO ${from.split("@")[1]}`, 250, "EHLO");
    await send("AUTH LOGIN", 334, "AUTH");
    await send(btoa(env("SES_SMTP_USER")), 334, "AUTH user");
    await send(btoa(env("SES_SMTP_PASS")), 235, "AUTH password");
    await send(`MAIL FROM:<${from}>`, 250, "MAIL FROM");
    await send(`RCPT TO:<${mail.to}>`, 250, "RCPT TO");
    await send("DATA", 354, "DATA");
    await writeAll(conn, message(mail, from) + "\r\n.\r\n");
    await reader.expect(250, "message");
    await send("QUIT", 221, "QUIT").catch(() => {});   // the message is already accepted
  } finally {
    clearTimeout(timer);
    try { conn.close(); } catch { /* already closed by the timeout */ }
  }
}

/** `write` may send only part of a buffer; keep going until every byte is out. */
async function writeAll(conn: Deno.Conn, text: string): Promise<void> {
  const bytes = encoder.encode(text);
  for (let sent = 0; sent < bytes.length;) sent += await conn.write(bytes.subarray(sent));
}

/** A multipart/alternative message: plain text first, HTML second, both base64 so no line needs escaping. */
function message(mail: Mail, from: string): string {
  const boundary = `rounds-${crypto.randomUUID()}`;
  return [
    `From: Rounds <${from}>`,
    `To: <${mail.to}>`,
    `Subject: ${encodeHeader(mail.subject)}`,
    `Date: ${new Date().toUTCString()}`,
    `Message-ID: <${crypto.randomUUID()}@${from.split("@")[1]}>`,
    "MIME-Version: 1.0",
    `Content-Type: multipart/alternative; boundary="${boundary}"`,
    "",
    `--${boundary}`,
    "Content-Type: text/plain; charset=utf-8",
    "Content-Transfer-Encoding: base64",
    "",
    base64Lines(mail.text),
    `--${boundary}`,
    "Content-Type: text/html; charset=utf-8",
    "Content-Transfer-Encoding: base64",
    "",
    base64Lines(mail.html),
    `--${boundary}--`,
  ].join("\r\n");
}

/** RFC 2047 encoded word, so names with accents survive the subject line. */
function encodeHeader(value: string): string {
  const clean = value.replace(/[\r\n]+/g, " ");
  return /^[\x20-\x7E]*$/.test(clean) ? clean : `=?utf-8?B?${toBase64(encoder.encode(clean))}?=`;
}

function base64Lines(text: string): string {
  return toBase64(encoder.encode(text)).replace(/.{1,76}/g, "$&\r\n").trimEnd();
}

function toBase64(bytes: Uint8Array): string {
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary);
}

function env(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`${name} is not set`);
  return value;
}

/** Reads SMTP replies line by line; a reply ends on the line whose code is followed by a space. */
class LineReader {
  private buffer = "";
  constructor(private conn: Deno.Conn) {}

  async expect(code: number, step: string): Promise<void> {
    while (true) {
      const line = await this.line();
      if (/^\d{3} /.test(line) || line.length < 4) {
        if (!line.startsWith(String(code))) throw new Error(`SMTP ${step} refused: ${line.slice(0, 160)}`);
        return;
      }
    }
  }

  private async line(): Promise<string> {
    while (!this.buffer.includes("\r\n")) {
      const chunk = new Uint8Array(1024);
      const n = await this.conn.read(chunk);
      if (n === null) throw new Error("SMTP connection closed");
      this.buffer += decoder.decode(chunk.subarray(0, n), { stream: true });
    }
    const end = this.buffer.indexOf("\r\n");
    const line = this.buffer.slice(0, end);
    this.buffer = this.buffer.slice(end + 2);
    return line;
  }
}
