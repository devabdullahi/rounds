# Load test

Fires many students' examine and order requests at `case-session` at once: the database path, with
no AI calls besides writing one patient. Run it against the cloud project before launch and after
changing how functions reach Postgres.

```bash
export SB_URL=https://mpyxaefnytviwnjuqtbu.supabase.co SB_ANON=<anon key from Config/Secrets.xcconfig>
export SB_USERS_FILE=/tmp/rounds-load-users.txt   # guest ids it creates, to delete afterwards
deno run -A load.ts 50 400                        # 50 at once, 400 requests
```

It prints requests per second, status counts and p50/p95/p99 latency. 404 "test not found" is
expected (practice mode hides some tests). Delete the guests listed in `SB_USERS_FILE` afterwards.

Results on the free plan (Nano compute, pooler limit 200 clients), 2026-10-11:

| At once | Before (direct connections) | After (pooler, 1 connection, 2 s idle) |
|---|---|---|
| 25 | | 0% errors, p50 0.39 s |
| 50 | | 4.5% errors |
| 100 | 91% errors ("too many clients") | 16% errors, p50 0.42 s |
