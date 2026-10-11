// Load test for the database path of case-session: many students examining and ordering tests at once.
// No AI calls besides writing one patient. Usage: deno run -A load.ts <concurrency> <total>
const URL = Deno.env.get("SB_URL")!, ANON = Deno.env.get("SB_ANON")!;
const [concurrency, total] = [Number(Deno.args[0] ?? 50), Number(Deno.args[1] ?? 300)];
const guests: { token: string; id: string }[] = [];

async function guest() {
  const r = await fetch(`${URL}/auth/v1/signup`, { method: "POST", headers: { apikey: ANON, "Content-Type": "application/json" }, body: "{}" });
  const j = await r.json();
  return { token: j.access_token as string, id: j.user.id as string };
}
async function fn(token: string, name: string, body: unknown) {
  const t0 = performance.now();
  const r = await fetch(`${URL}/functions/v1/${name}`, { method: "POST", headers: { apikey: ANON, Authorization: `Bearer ${token}`, "Content-Type": "application/json" }, body: JSON.stringify(body) });
  const text = await r.text();
  return { status: r.status, ms: performance.now() - t0, text };
}

const owner = await guest(); guests.push(owner);
const made = await fn(owner.token, "generate-case", { focus: "rotation:internalMedicine" });
const bed = JSON.parse(made.text).case_id;
const cr = await fetch(`${URL}/rest/v1/cases?id=eq.${bed}&select=maneuvers,test_menu`, { headers: { apikey: ANON, Authorization: `Bearer ${owner.token}` } });
const [{ maneuvers, test_menu }] = await cr.json();
const exams = maneuvers.map((m: { id: string }) => m.id), tests = test_menu.map((t: { id: string }) => t.id);

// Attempts to spread the load over (one owner can start many attempts on its own case).
const attempts: string[] = [];
for (let i = 0; i < 20; i++) attempts.push(JSON.parse((await fn(owner.token, "case-session", { action: "start", case_id: bed, exam_mode: false, time_limit_minutes: null })).text).attempt_id);
console.log(`case ${bed}: ${exams.length} maneuvers, ${tests.length} tests, ${attempts.length} attempts; ${concurrency} at once, ${total} requests`);

const results: { status: number; ms: number; text: string }[] = [];
let next = 0;
async function worker() {
  while (next < total) {
    const i = next++;
    const attempt = attempts[i % attempts.length];
    const body = i % 2 ? { action: "examine", attempt_id: attempt, maneuver_id: exams[i % exams.length] } : { action: "order", attempt_id: attempt, test_id: tests[i % tests.length] };
    results.push(await fn(owner.token, "case-session", body));
  }
}
const t0 = performance.now();
await Promise.all(Array.from({ length: concurrency }, worker));
const secs = (performance.now() - t0) / 1000;
const ms = results.map((r) => r.ms).sort((a, b) => a - b);
const pct = (p: number) => Math.round(ms[Math.min(ms.length - 1, Math.floor(ms.length * p))]);
const by: Record<string, number> = {};
for (const r of results) by[r.status] = (by[r.status] ?? 0) + 1;
const errors = [...new Set(results.filter((r) => r.status >= 400).map((r) => `${r.status} ${r.text.slice(0, 90)}`))].slice(0, 4);
console.log(JSON.stringify({ seconds: +secs.toFixed(1), rps: +(total / secs).toFixed(1), statuses: by, p50: pct(0.5), p95: pct(0.95), p99: pct(0.99), errors }));
await Deno.writeTextFile(Deno.env.get("SB_USERS_FILE")!, guests.map((g) => g.id).join("\n") + "\n", { append: true });
