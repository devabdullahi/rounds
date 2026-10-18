import { assertEquals } from "jsr:@std/assert@1";
import { PROVIDERS, settingFor, type Task, thinkingFields, usageOf } from "./llm.ts";

Deno.test("providers without thinking get the plain token cap", () => {
  assertEquals(thinkingFields(false, 400, "high"), { max_tokens: 400 });
});

Deno.test("effort off disables thinking explicitly, since DeepSeek thinks by default", () => {
  assertEquals(thinkingFields(true, 400, "off"), { max_tokens: 400, thinking: { type: "disabled" } });
});

Deno.test("thinking calls get reasoning headroom on top of the answer budget", () => {
  assertEquals(thinkingFields(true, 7000, "high"), { max_tokens: 15000, thinking: { type: "enabled" }, reasoning_effort: "high" });
  assertEquals(thinkingFields(true, 8000, "low").max_tokens, 10000);
  assertEquals(thinkingFields(true, 200, "max").max_tokens, 16200);
});

const deepseek = PROVIDERS.deepseek;
const noEnv = () => undefined;

Deno.test("each DeepSeek task gets its model and effort", () => {
  const cases: [Task, string, string][] = [
    ["patient", "deepseek-flash", "off"],
    ["check", "deepseek-flash", "off"],
    ["cards", "deepseek-flash", "off"],
    ["case", "deepseek-flash", "off"],
    ["grade", "deepseek-v4-pro", "high"],
    ["profile", "deepseek-v4-pro", "low"],
  ];
  for (const [task, model, effort] of cases) {
    assertEquals(settingFor(deepseek, task, noEnv), { model, effort }, task);
  }
});

Deno.test("a per-task override beats the global one, which beats the default", () => {
  const env = (k: string) => ({ LLM_MODEL: "deepseek-chat", LLM_MODEL_PATIENT: "deepseek-v4-pro" } as Record<string, string>)[k];
  assertEquals(settingFor(deepseek, "patient", env).model, "deepseek-v4-pro");
  assertEquals(settingFor(deepseek, "cards", env).model, "deepseek-chat");
});

Deno.test("providers without task settings use their one model and never think", () => {
  assertEquals(settingFor(PROVIDERS.openai, "grade", noEnv), { model: "gpt-4.1", effort: "off" });
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
