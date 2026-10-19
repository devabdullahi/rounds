import { assert, assertEquals, assertThrows } from "jsr:@std/assert@1";
import { HttpError } from "./http.ts";
import { requireServiceRole, sameSecret } from "./internal.ts";

Deno.test("secrets match only when identical", () => {
  assert(sameSecret("Bearer abc", "Bearer abc"));
  assert(!sameSecret("Bearer abd", "Bearer abc"));
  assert(!sameSecret("Bearer ab", "Bearer abc"));
  assert(!sameSecret("Bearer abcd", "Bearer abc"));
  assert(!sameSecret("", "Bearer abc"));
});

Deno.test("internal functions refuse anything but the service role key", () => {
  Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "service-key");
  const req = (auth?: string) => new Request("http://x", { method: "POST", headers: auth ? { Authorization: auth } : {} });
  requireServiceRole(req("Bearer service-key"));
  for (const auth of [undefined, "Bearer anon-key", "service-key"]) {
    const error = assertThrows(() => requireServiceRole(req(auth)), HttpError);
    assertEquals(error.status, 401);
  }
  Deno.env.delete("SUPABASE_SERVICE_ROLE_KEY");
  assertThrows(() => requireServiceRole(req("Bearer ")), HttpError);
});
