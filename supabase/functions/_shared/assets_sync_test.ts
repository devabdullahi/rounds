// The functions bundle copies of files the knowledge-base tools own, since edge functions can't read
// outside supabase/functions when deployed. These tests fail when a copy falls behind its source.
import { assertEquals } from "jsr:@std/assert@1";
import assets from "./profilegen_assets.json" with { type: "json" };

const root = new URL("../../../", import.meta.url);

Deno.test("reference ranges match the knowledge base's copy", async () => {
  const bundled = JSON.parse(await Deno.readTextFile(new URL("./reference_ranges.json", import.meta.url)));
  const source = JSON.parse(await Deno.readTextFile(new URL("knowledge-base/reference_ranges.json", root)));
  assertEquals(bundled, source);
});

Deno.test("profile prompts were exported at the generator's current prompt version", async () => {
  const generator = await Deno.readTextFile(new URL("tools/kb-generate/generate.py", root));
  const version = generator.match(/^PROMPT_VERSION\s*=\s*["']([^"']+)["']/m);
  assertEquals(assets.prompt_version, version?.[1]);
});
