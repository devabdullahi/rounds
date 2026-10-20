import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { type Effort, parseJSON, PROVIDERS, retryWait, settingFor, type Task, thinkingFields, usageOf } from "./llm.ts";

Deno.test("providers without thinking get the plain token cap", () => {
  assertEquals(thinkingFields(undefined, 400, "high"), { max_tokens: 400 });
});

Deno.test("OpenAI reasoning models get max_completion_tokens and an effort, never max_tokens", () => {
  assertEquals(thinkingFields("openai", 7000, "medium"), { max_completion_tokens: 11000, reasoning_effort: "medium" });
  assertEquals(thinkingFields("openai", 400, "off"), { max_completion_tokens: 400, reasoning_effort: "none" });
});

const openai = PROVIDERS.openai;
const noEnv = () => undefined;

Deno.test("an overridden model is sent to the provider its name belongs to", () => {
  const toClaude = (k: string) => ({ LLM_MODEL_PROFILE: "claude-sonnet-5-5" } as Record<string, string>)[k];
  assertEquals(settingFor(openai, "profile", toClaude), { provider: "anthropic", model: "claude-sonnet-5-5", effort: "off" });
  const toLuna = (k: string) => ({ LLM_MODEL_GRADE: "gpt-6-luna" } as Record<string, string>)[k];
  assertEquals(settingFor(openai, "grade", toLuna), { provider: "openai", model: "gpt-6-luna", effort: "medium" });
});

Deno.test("a per-task override beats the global one, which beats the default", () => {
  const env = (k: string) => ({ LLM_MODEL: "gpt-6-luna", LLM_MODEL_PATIENT: "gpt-6.1-sol" } as Record<string, string>)[k];
  assertEquals(settingFor(openai, "patient", env).model, "gpt-6.1-sol");
  assertEquals(settingFor(openai, "cards", env).model, "gpt-6-luna");
});

Deno.test("each OpenAI task gets its model and effort: Luna without reasoning for chat, Sol for judgment", () => {
  const cases: [Task, string, Effort][] = [
    ["patient", "gpt-6-luna", "off"],
    ["check", "gpt-6-luna", "off"],
    ["grade", "gpt-6.1-sol", "medium"],
    ["profile", "gpt-6.1-sol", "medium"],
  ];
  for (const [task, model, effort] of cases) {
    assertEquals(settingFor(PROVIDERS.openai, task, noEnv), { model, effort }, task);
  }
});

Deno.test("flashcards go to DeepSeek V4.1 Flash and case writing to GPT-5.4 mini, without thinking", () => {
  assertEquals(settingFor(openai, "cards", noEnv), { provider: "deepseek", model: "deepseek-flash", effort: "off" });
  assertEquals(settingFor(openai, "case", noEnv), { model: "gpt-5.4-mini", effort: "off" });
  assertEquals(thinkingFields("deepseek", 400, "off"), { max_tokens: 400, thinking: { type: "disabled" } });
});

Deno.test("usage reads DeepSeek's cache split", () => {
  const reply = { usage: { prompt_tokens: 141, completion_tokens: 30, prompt_cache_hit_tokens: 128, prompt_cache_miss_tokens: 13 } };
  assertEquals(usageOf(reply), { hit: 128, miss: 13, output: 30, reasoning: 0 });
});

Deno.test("providers without task settings use their one model and never think", () => {
  assertEquals(settingFor(PROVIDERS.anthropic, "grade", noEnv), { model: "claude-sonnet-5-5", effort: "off" });
});

Deno.test("usage reads OpenAI's cached prompt tokens and reasoning tokens", () => {
  const reply = { usage: { prompt_tokens: 141, completion_tokens: 368, prompt_tokens_details: { cached_tokens: 128 }, completion_tokens_details: { reasoning_tokens: 335 } } };
  assertEquals(usageOf(reply), { hit: 128, miss: 13, output: 368, reasoning: 335 });
});

Deno.test("usage reads Anthropic's input and cache fields", () => {
  const reply = { usage: { input_tokens: 100, cache_read_input_tokens: 400, cache_creation_input_tokens: 50, output_tokens: 20 } };
  assertEquals(usageOf(reply), { hit: 400, miss: 150, output: 20, reasoning: 0 });
});

Deno.test("a reply without usage counts as zero", () => {
  assertEquals(usageOf({}), { hit: 0, miss: 0, output: 0, reasoning: 0 });
});

Deno.test("parseJSON keeps the first object when more text or a second object follows it", () => {
  assertEquals(parseJSON('{"a": 1, "b": "x}"}\n{"a": 2}'), { a: 1, b: "x}" });
  assertEquals(parseJSON('Here: {"a": {"b": "q\\"}"}} and then } more'), { a: { b: 'q"}' } });
  assertEquals(parseJSON('```json\n{"a": 3}\n```'), { a: 3 });
});

Deno.test("parseJSON still fails when no object closes", () => {
  assertThrows(() => parseJSON('{"a": 1'));
});

Deno.test("provider errors worth retrying wait a little; client errors don't retry", () => {
  const mid = () => 0.5;
  assertEquals(retryWait(429, null, 0, mid), 1000);
  assertEquals(retryWait(503, null, 1, mid), 3000);
  assertEquals(retryWait(429, "2", 0, mid), 2000);
  assertEquals(retryWait(429, "120", 0, mid), 10000);
  assertEquals(retryWait(400, null, 0, mid), null);
  assertEquals(retryWait(401, null, 0, mid), null);
});
