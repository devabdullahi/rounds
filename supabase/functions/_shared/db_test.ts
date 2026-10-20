import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { poolFull, retryWhenFull } from "./db.ts";

const full = Object.assign(new Error("(EMAXCONN) max client connections reached, limit: 200"), { code: "EMAXCONN" });
const noWait = () => Promise.resolve();

Deno.test("a full pooler is recognized by its code or its message", () => {
  assertEquals(poolFull(full), true);
  assertEquals(poolFull(new Error("sorry, too many clients already")), true);
  assertEquals(poolFull(new Error("duplicate key value violates unique constraint")), false);
  assertEquals(poolFull(null), false);
});

Deno.test("a query that hit a full pooler is retried and then succeeds", async () => {
  let calls = 0;
  const result = await retryWhenFull(() => (++calls < 3 ? Promise.reject(full) : Promise.resolve("ok")), noWait);
  assertEquals([result, calls], ["ok", 3]);
});

Deno.test("other errors aren't retried, and a pooler that stays full gives up", async () => {
  let calls = 0;
  await assertRejects(() => retryWhenFull(() => (calls++, Promise.reject(new Error("syntax error"))), noWait), Error, "syntax error");
  assertEquals(calls, 1);
  calls = 0;
  await assertRejects(() => retryWhenFull(() => (calls++, Promise.reject(full)), noWait), Error, "EMAXCONN");
  assertEquals(calls, 4);
});
