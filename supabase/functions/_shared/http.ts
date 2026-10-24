// Shared request plumbing: JSON responses, typed errors, and the caller check every function runs first.

export class HttpError extends Error {
  constructor(readonly status: number, message: string) {
    super(message);
  }
}

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

/** Wraps a handler so thrown HttpErrors become JSON errors and anything else becomes a logged 500. */
export function serve(handler: (req: Request) => Promise<Response>): void {
  Deno.serve(async (req) => {
    if (req.method !== "POST") return json({ error: "POST only" }, 405);
    if (compressedBody(req)) return json({ error: "compressed request bodies are not accepted" }, 415);
    try {
      return await handler(req);
    } catch (error) {
      if (error instanceof HttpError) return json({ error: error.message }, error.status);
      console.error(error);
      return json({ error: "internal error" }, 500);
    }
  });
}

/**
 * True when the request says its body is compressed. Our clients only send plain JSON, so any
 * Content-Encoding other than identity is refused before anything reads or decompresses the body.
 * This closes the Brotli decoding path (a 2026 decoder advisory) and any other codec with it.
 */
export function compressedBody(req: Request): boolean {
  const encoding = req.headers.get("Content-Encoding");
  if (!encoding) return false;
  return encoding.split(",").some((part) => {
    const codec = part.trim().toLowerCase();
    return codec !== "" && codec !== "identity";
  });
}

/** The verified caller, as Supabase Auth reports it. */
export interface Caller {
  id: string;
  email?: string;
  is_anonymous?: boolean;
  user_metadata?: Record<string, unknown>;
}

/** Refuses unless the request carries the service role key: for internal functions with verify_jwt off. */
export function requireServiceRole(req: Request): void {
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!key || !sameText(req.headers.get("Authorization") ?? "", `Bearer ${key}`)) throw new HttpError(401, "internal function");
}

/** Constant-time string comparison, so response timing doesn't reveal how much of a secret matched. */
export function sameText(a: string, b: string): boolean {
  const x = new TextEncoder().encode(a);
  const y = new TextEncoder().encode(b);
  let diff = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  return diff === 0;
}

/** Verifies the bearer token with Supabase Auth and returns the user. */
export async function caller(req: Request): Promise<Caller> {
  const auth = req.headers.get("Authorization");
  if (!auth?.startsWith("Bearer ")) throw new HttpError(401, "missing token");
  const res = await fetch(`${Deno.env.get("SUPABASE_URL")}/auth/v1/user`, {
    headers: { Authorization: auth, apikey: Deno.env.get("SUPABASE_ANON_KEY") ?? "" },
  });
  if (!res.ok) throw new HttpError(401, "invalid token");
  const user = await res.json();
  if (typeof user?.id !== "string") throw new HttpError(401, "invalid token");
  return user as Caller;
}

/** Verifies the bearer token with Supabase Auth and returns the user id. */
export async function callerId(req: Request): Promise<string> {
  return (await caller(req)).id;
}

export async function body<T>(req: Request): Promise<T> {
  try {
    return await req.json() as T;
  } catch {
    throw new HttpError(400, "body must be JSON");
  }
}
