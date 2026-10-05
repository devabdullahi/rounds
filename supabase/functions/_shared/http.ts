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
    try {
      return await handler(req);
    } catch (error) {
      if (error instanceof HttpError) return json({ error: error.message }, error.status);
      console.error(error);
      return json({ error: "internal error" }, 500);
    }
  });
}

/** Verifies the bearer token with Supabase Auth and returns the user id. */
export async function callerId(req: Request): Promise<string> {
  const auth = req.headers.get("Authorization");
  if (!auth?.startsWith("Bearer ")) throw new HttpError(401, "missing token");
  const res = await fetch(`${Deno.env.get("SUPABASE_URL")}/auth/v1/user`, {
    headers: { Authorization: auth, apikey: Deno.env.get("SUPABASE_ANON_KEY") ?? "" },
  });
  if (!res.ok) throw new HttpError(401, "invalid token");
  const user = await res.json();
  if (typeof user?.id !== "string") throw new HttpError(401, "invalid token");
  return user.id;
}

export async function body<T>(req: Request): Promise<T> {
  try {
    return await req.json() as T;
  } catch {
    throw new HttpError(400, "body must be JSON");
  }
}
