import { assertEquals } from "jsr:@std/assert@1";
import { type Effort, PROVIDERS, settingFor, type Task, thinkingFields, usageOf } from "./llm.ts";

Deno.test("providers without thinking get the plain token cap", () => {
  assertEquals(thinkingFields(undefined, 400, "high"), { max_tokens: 400 });
});

Deno.test("effort off disables thinking explicitly, since DeepSeek thinks by default", () => {
  assertEquals(thinkingFields("deepseek", 400, "off"), { max_tokens: 400, thinking: { type: "disabled" } });
});

Deno.test("thinking calls get reasoning headroom on top of the answer budget", () => {
  assertEquals(thinkingFields("deepseek", 7000, "high"), { max_tokens: 15000, thinking: { type: "enabled" }, reasoning_effort: "high" });
  assertEquals(thinkingFields("deepseek", 8000, "low").max_tokens, 10000);
  assertEquals(thinkingFields("deepseek", 200, "max").max_tokens, 16200);
});

Deno.test("OpenAI reasoning models get max_completion_tokens and an effort, never max_tokens", () => {
  assertEquals(thinkingFields("openai", 7000, "medium"), { max_completion_tokens: 11000, reasoning_effort: "medium" });
  assertEquals(thinkingFields("openai", 400, "off"), { max_completion_tokens: 4400 });
});

const deepseek = PROVIDERS.deepseek;
const noEnv = () => undefined;

Deno.test("each DeepSeek task gets its model and effort", () => {
  const cases: [Task, string, Effort][] = [
    ["patient", "deepseek-flash", "off"],
    ["check", "deepseek-flash", "off"],
    ["cards", "deepseek-flash", "off"],
    ["case", "deepseek-flash", "off"],
    ["grade", "deepseek-flash", "high"],
  ];
  for (const [task, model, effort] of cases) {
    assertEquals(settingFor(deepseek, task, noEnv), { model, effort }, task);
  }
});

Deno.test("condition profiles go to OpenAI's GPT-6.1 Sol at medium effort", () => {
  assertEquals(settingFor(deepseek, "profile", noEnv), { provider: "openai", model: "gpt-6.1-sol", effort: "medium" });
});

Deno.test("an overridden model is sent to the provider its name belongs to", () => {
  const back = (k: string) => ({ LLM_MODEL_PROFILE: "deepseek-flash" } as Record<string, string>)[k];
  assertEquals(settingFor(deepseek, "profile", back), { provider: "deepseek", model: "deepseek-flash", effort: "medium" });
  const toSol = (k: string) => ({ LLM_MODEL_GRADE: "gpt-6.1-sol" } as Record<string, string>)[k];
  assertEquals(settingFor(deepseek, "grade", toSol), { provider: "openai", model: "gpt-6.1-sol", effort: "high" });
});

Deno.test("a per-task override beats the global one, which beats the default", () => {
  const env = (k: string) => ({ LLM_MODEL: "deepseek-chat", LLM_MODEL_PATIENT: "deepseek-v4-pro" } as Record<string, string>)[k];
  assertEquals(settingFor(deepseek, "patient", env).model, "deepseek-v4-pro");
  assertEquals(settingFor(deepseek, "cards", env).model, "deepseek-chat");
});

Deno.test("providers without task settings use their one model and never think", () => {
  assertEquals(settingFor(PROVIDERS.openai, "grade", noEnv), { model: "gpt-6.1-sol", effort: "off" });
});

Deno.test("usage reads DeepSeek's cache split and reasoning tokens", () => {
  const reply = { usage: { prompt_tokens: 141, completion_tokens: 368, prompt_cache_hit_tokens: 128, prompt_cache_miss_tokens: 13, completion_tokens_details: { reasoning_tokens: 335 } } };
  assertEquals(usageOf(reply), { hit: 128, miss: 13, output: 368, reasoning: 335 });
});

Deno.test("usage reads Anthropic's input and cache fields", () => {
  const reply = { usage: { input_tokens: 100, cache_read_input_tokens: 400, cache_creation_input_tokens: 50, output_tokens: 20 } };
  assertEquals(usageOf(reply), { hit: 400, miss: 150, output: 20, reasoning: 0 });
});

Deno.test("a reply without usage counts as zero", () => {
  assertEquals(usageOf({}), { hit: 0, miss: 0, output: 0, reasoning: 0 });
});
