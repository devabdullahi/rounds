import { assert, assertEquals } from "jsr:@std/assert@1";
import { buildLiveProfile, LIVE_STAGES, normalize } from "./liveprofile.ts";

// The template's own examples (acute appendicitis) answer each call, so the profile is valid.
const exampleFor = (user: string) => {
  const keys = user.match(/exactly these keys: ([^.]+)\./)?.[1].split(", ") ?? [];
  const stage = LIVE_STAGES.find((s) => s.sections.join(", ") === keys.join(", "))!;
  return JSON.parse(stage.example);
};

Deno.test("a section that comes back unusable is rewritten at once, with its problems, and the profile passes", async () => {
  const realFetch = globalThis.fetch;
  globalThis.fetch = () => Promise.resolve(new Response("", { status: 404 })); // the APIs know nothing
  try {
    const calls: { keys: string; feedback: boolean }[] = [];
    let brokeTeaching = false;
    const { profile, problems } = await buildLiveProfile("acute-appendicitis", { name: "Acute appendicitis" }, "", {
      umlsKey: "test", system: "",
      complete: (_system, user) => {
        const keys = user.match(/exactly these keys: ([^.]+)\./)?.[1] ?? "";
        calls.push({ keys, feedback: user.includes("Your previous reply had these problems") });
        if (keys === "teaching" && !brokeTeaching) {
          brokeTeaching = true;
          return Promise.reject(new Error("Expected ',' or '}' after property value in JSON"));
        }
        return Promise.resolve(exampleFor(user));
      },
      termErrors: () => Promise.resolve([]),
    });
    assertEquals(problems, []);
    assert("teaching" in profile);
    assertEquals(calls.filter((c) => c.keys === "teaching").map((c) => c.feedback), [false, true]);
    assertEquals(calls.length, LIVE_STAGES.length + 1);
  } finally {
    globalThis.fetch = realFetch;
  }
});

Deno.test("normalize fixes what would only cost a rewrite: empty ECG, a repeated accepted name", () => {
  const part = { ecg: {}, teaching: { accepted_names: ["Seasonal affective disorder", "SAD", "seasonal affective disorder"] } };
  normalize(part);
  assertEquals(part, { ecg: { findings: [] }, teaching: { accepted_names: ["Seasonal affective disorder", "SAD"] } });
});
