import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { SCAN_CREDIT, scansOn, signObject, signScans } from "./scanurl.ts";

for (const [value, expected] of [[undefined, false], ["", false], ["true", false], ["ON ", false], ["off", false], ["on", true]] as const) {
  Deno.test(`scansOn(${JSON.stringify(value)}) is ${expected}`, () => {
    assertEquals(scansOn((k) => (k === "REAL_SCANS" ? value : undefined)), expected);
  });
}

Deno.test("only tests with a scan asset are signed, and the reply carries just the public fields", async () => {
  const seen: string[] = [];
  const m = await signScans(
    [{ id: "cxr", scan_asset_id: "a1" }, { id: "cbc" }, { id: "ecg", scan_asset_id: null }],
    (a) => { seen.push(a); return Promise.resolve(`https://x/${a}`); },
  );
  assertEquals(seen, ["a1"]);
  assertEquals([...m.keys()], ["cxr"]);
  const scan = m.get("cxr")!;
  assertEquals(Object.keys(scan).sort(), ["citation", "credit", "source_url", "url"]);
  assertEquals(scan.credit, SCAN_CREDIT);
});

Deno.test("links are signed afresh on every call", async () => {
  let n = 0;
  const sign = () => Promise.resolve(`https://x/${++n}`);
  const tests = [{ id: "cxr", scan_asset_id: "a1" }];
  const first = await signScans(tests, sign);
  const second = await signScans(tests, sign);
  assertEquals(n, 2);
  assertEquals(first.get("cxr")!.url === second.get("cxr")!.url, false);
});

Deno.test("signObject posts to the scans bucket with the service key (bearer and apikey) and joins the reply path", async () => {
  let call: { url: string; init: RequestInit } | undefined;
  const fake = ((url: string, init: RequestInit) => {
    call = { url, init };
    return Promise.resolve(new Response(JSON.stringify({ signedURL: "/object/sign/scans/o.jpg?token=t" })));
  }) as unknown as typeof fetch;
  const url = await signObject("https://p.supabase.co", "KEY", "o.jpg", fake);
  assertEquals(url, "https://p.supabase.co/storage/v1/object/sign/scans/o.jpg?token=t");
  assertEquals(call!.url, "https://p.supabase.co/storage/v1/object/sign/scans/o.jpg");
  assertEquals(JSON.parse(call!.init.body as string), { expiresIn: 3600 });
  assertEquals((call!.init.headers as Record<string, string>).Authorization, "Bearer KEY");
  assertEquals((call!.init.headers as Record<string, string>).apikey, "KEY");
});

Deno.test("signObject rejects on a failed reply", async () => {
  const fake = (() => Promise.resolve(new Response("no", { status: 500 }))) as unknown as typeof fetch;
  await assertRejects(() => signObject("https://p", "K", "o.jpg", fake));
});
