# Real Scans (Going to the Radiologist) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a case's chest X-ray is ordered, return a real NIH teaching image (signed URL) with a report written from that image, behind a server switch that is off by default.

**Architecture:** A Python import tool builds a small library of expert-labeled NIH ChestX-ray14 images (vision-gated, re-encoded, random UUID names) into a private Storage bucket and `private.scan_assets`. `generate-case` picks an asset for the case's chest X-ray before the writer runs and makes the asset's curated report the result. `case-session` adds a short-lived signed URL plus credit to `order` and `resume` replies only when `REAL_SCANS=on`. iOS gets the data layer now; the screen waits for the owner's canvas pick.

**Tech Stack:** Postgres/Supabase migrations + Storage, Deno edge functions (TypeScript, `deno test`), Python 3 (`unittest`, Pillow, OpenAI Chat Completions with image input), SwiftUI/Swift Testing.

**Spec:** `docs/superpowers/specs/2026-11-13-real-scans-design.md`

## Global Constraints

- Source: NIH ChestX-ray14 only. Chest X-ray only; every other study stays text-only.
- Library only from expert-labeled subsets: NIH radiologist bounding boxes (`BBox_List_2017.csv`) and Google's adjudicated label sets. NLP labels (`Data_Entry_2017.csv` "Finding Labels") never qualify an image.
- Lateral findings (pneumothorax, opacity, nodule_mass, fracture, effusion, atelectasis) need a side from a radiologist box; diffuse findings (edema, emphysema, cardiomegaly) need none and never get one in the report.
- "normal" only from an adjudicated normal label, never from NIH "No Finding".
- Never claim "clinically validated" or "radiologist-reviewed"; never imply NIH endorses Palpo.
- Credit subtitle copy (exact): `Real de-identified teaching image · NIH Clinical Center`. Tap-through: link `https://nihcc.app.box.com/v/ChestXray-NIHCC` and citation `Wang X, Peng Y, Lu L, Lu Z, Bagheri M, Summers RM. ChestX-ray8: Hospital-scale Chest X-ray Database and Benchmarks on Weakly-Supervised Classification and Localization of Common Thorax Diseases. IEEE CVPR 2017.`
- Switch: edge-function secret `REAL_SCANS`; only the exact value `on` serves images. Asset selection runs regardless of the switch.
- Bucket `scans` is private; no Storage policies for `anon`/`authenticated`. Table lives in `private`; no grants to `anon`/`authenticated`.
- Client never sees asset ids, source file names, labels or provenance: only `{url, credit, citation, source_url}`.
- Images: ≈1024 px long edge JPEG, all metadata stripped, object name `<uuid>.jpg`.
- Vision gate model: `gpt-6.1-sol` (strongest in `_shared/llm.ts`), no cost cap (owner).
- Every cloud step (migration push, bucket, import upload, function deploy, secret) is announced to the owner before it runs.
- Commits: no Claude/AI attribution lines.

## Review Focus

1. A pediatric case (age < 18) must never get an adult film: selection returns null → text-only. Test in Task 2.
2. A case whose sampled findings name a side ("left") must not get a right-sided asset. Test in Task 2.
3. A curated report that would be stripped by the case's leak terms (e.g. it names the diagnosis) must not be used: pick another asset or stay text-only. Test in Task 3.
4. `REAL_SCANS` unset, empty or `true` (not `on`) must serve no URL. Test in Task 4.
5. Resuming a case hours later must re-sign (never return a stored URL). Test in Task 4.

---

### Task 0: Owner prerequisites (manual, no code)

- [ ] **Step 1:** Owner fills Google's expert-label form (linked on `https://cloud.google.com/healthcare-api/docs/resources/public-datasets/nih-chest`), downloads both label sets (four findings, all findings) into `knowledge-base/licensed/scans/` (git-ignored).
- [ ] **Step 2:** Owner reads the "License and attribution" text shown with the labels and pastes it into `knowledge-base/licensed/scans/LABEL_TERMS.txt`. If it restricts paid-app use, set `USE_GOOGLE_LABELS = False` in Task 5 (library = NIH boxes only; diffuse findings and normals drop out of MVP; selection then returns null for empty chest X-rays).
- [ ] **Step 3:** Download `BBox_List_2017.csv` and `Data_Entry_2017.csv` from the NIH site into the same folder.

### Task 1: Storage bucket and asset table

**Files:**
- Create: `supabase/migrations/20261114000000_scan_assets.sql`
- Test: `supabase/tests/scan_assets_rls.sql` (run with `supabase db reset` then `psql`)

**Interfaces:**
- Produces: table `private.scan_assets(id uuid pk default gen_random_uuid(), object_name text not null unique, finding text not null check (finding in ('normal','pneumothorax','opacity','nodule_mass','fracture','effusion','atelectasis','cardiomegaly','edema','emphysema')), side text check (side in ('left','right')), zone text check (zone in ('upper','middle','lower')), view text not null check (view in ('PA','AP')), age int not null, sex text not null check (sex in ('female','male')), report text not null, label_source text not null check (label_source in ('nih_bbox','google_four','google_all')), source_image text not null, gate jsonb not null, active boolean not null default true, created_at timestamptz not null default now())`; index on `(finding, active)`. Bucket `scans` (private, 1 MB, `image/jpeg`).

- [ ] **Step 1: Write the denied-path test** `supabase/tests/scan_assets_rls.sql`: as `authenticated` and as `anon`, `select * from private.scan_assets` errors with permission denied; `select * from storage.objects where bucket_id = 'scans'` returns 0 rows after inserting one object row as `postgres`; as `service_role`, select on the table succeeds.
- [ ] **Step 2:** `supabase db reset && psql "$LOCAL_DB_URL" -f supabase/tests/scan_assets_rls.sql` → FAIL (table missing).
- [ ] **Step 3:** Write the migration: table above, `alter table … enable row level security`, `revoke all on private.scan_assets from anon, authenticated`, bucket insert `('scans','scans',false,1048576,array['image/jpeg']) on conflict do nothing`. Header comment explains why (answer-key-adjacent labels; images served only by signed URL). If Docker is unavailable, run the test with PGlite and say so.
- [ ] **Step 4:** Re-run → PASS.
- [ ] **Step 5:** Commit `Scans: private asset table and bucket`.

### Task 2: Pure selection logic (shared)

**Files:**
- Create: `supabase/functions/_shared/scans.ts`
- Test: `supabase/functions/_shared/scans_test.ts`

**Interfaces:**
- Produces:
  - `type ScanFinding = "normal" | "pneumothorax" | "opacity" | "nodule_mass" | "fracture" | "effusion" | "atelectasis" | "cardiomegaly" | "edema" | "emphysema"`
  - `type ScanAsset = { id: string; object_name: string; finding: ScanFinding; side: "left" | "right" | null; zone: string | null; view: "PA" | "AP"; age: number; sex: "female" | "male"; report: string }`
  - `isChestXray(testName: string): boolean` — `/\bchest\b.*\b(x-?ray|radiograph|film)\b|\bcxr\b/i`
  - `scanFinding(findings: string[]): ScanFinding | null` — `[]` → `"normal"`; else first keyword match by priority pneumothorax > effusion > opacity (consolidation|infiltrate|opacit|airspace) > nodule_mass (nodule|mass) > atelectasis (atelectasis|collapse) > edema (edema|kerley|vascular congestion|cephalization) > cardiomegaly (cardiomegaly|enlarged cardiac|cardiac silhouette) > emphysema (hyperinflat|emphysema|flattened diaphragm) > fracture (rib fracture|fracture); no match → `null` (text-only).
  - `sideHint(texts: string[]): "left" | "right" | null` — only one of `left`/`right` named (word-boundary) → it; both or none → null.
  - `chooseScan(candidates: ScanAsset[], want: { finding: ScanFinding; side: "left" | "right" | null; age: number; sex: "female" | "male" }, seen: Set<string>, rng: () => number): ScanAsset | null`

- [ ] **Step 1: Write failing tests** (parameterized tables):
  - `isChestXray`: "Chest X-ray" ✓, "chest radiograph (PA and lateral)" ✓, "CXR" ✓, "CT chest" ✗, "Abdominal X-ray" ✗.
  - `scanFinding`: `[]`→"normal"; `["Right lower lobe consolidation"]`→"opacity"; `["Small left pleural effusion","Consolidation"]`→"effusion"; `["Kerley B lines"]`→"edema"; `["Widened mediastinum"]`→null.
  - `sideHint`: `["left basilar crackles"]`→"left"; `["left effusion","right consolidation"]`→null; `["bilateral infiltrates"]`→null.
  - `chooseScan`: same sex required; `age < 18` with only adult assets → null; age diff > 15 years excluded; `want.side="left"` never returns a right asset; lateral finding with `want.side=null` accepts either side; unseen preferred over seen; all seen → returns a seen one; no candidate → null.
- [ ] **Step 2:** `cd supabase/functions && deno test _shared/scans_test.ts` → FAIL (module missing).
- [ ] **Step 3:** Implement the four functions. `chooseScan`: filter by finding, sex, age rule (both <18 or both ≥18, and |Δ| ≤ 15), side; split unseen/seen; pick uniformly with `rng` from unseen, else seen.
- [ ] **Step 4:** Re-run → PASS.
- [ ] **Step 5:** Commit `Scans: chest X-ray asset selection rules`.

### Task 3: Attach the scan during case generation

**Files:**
- Create: `supabase/functions/generate-case/scan.ts`
- Modify: `supabase/functions/_shared/casegen.ts` (`PlannedTest` gets `scan_asset_id?: string; scan_report?: string`)
- Modify: `supabase/functions/generate-case/compose.ts:86-89` (call `attachScan` after `freshPlan`, before `buildSkeleton`)
- Modify: `supabase/functions/generate-case/writer.ts:52` (studies with `scan_report` are not sent to the writer)
- Modify: `supabase/functions/generate-case/template.ts:155-158` and `rows.ts:49-60` (a study with `scan_report` uses it verbatim as `result`, `abnormal = finding !== "normal"`, and the stored test keeps `scan_asset_id`)
- Test: `supabase/functions/generate-case/scan_test.ts`, extend `rows_test.ts`

**Interfaces:**
- Consumes: Task 2 exports.
- Produces: `attachScan(plan: CasePlan, userId: string, banned: string[], rng: () => number): Promise<CasePlan>`; pure core `applyScan(plan: CasePlan, asset: ScanAsset | null, banned: string[]): CasePlan`. Stored test rows gain `scan_asset_id: string | null`.

- [ ] **Step 1: Write failing tests** for `applyScan`:
  - Plan with "Chest X-ray" findings `["Right lower lobe consolidation"]` + opacity/right asset → that test's `findings` equals the asset report's sentences, `scan_report` = asset.report, `scan_asset_id` = asset.id.
  - Asset `null` → plan unchanged.
  - Asset whose report contains a banned term (`banned = ["pneumothorax"]`, report "Right pneumothorax.") → plan unchanged (Review Focus 3).
  - Exam findings with "affected side" become "right side" for a right asset; no change for diffuse findings.
  - `buildRows` with a `scan_report` study → `result` equals the report, `scan_asset_id` set; `test_menu` has no `scan_asset_id`.
- [ ] **Step 2:** `deno test generate-case/scan_test.ts generate-case/rows_test.ts` → FAIL.
- [ ] **Step 3:** Implement. `attachScan` (DB part): finds the first `isChestXray` study; `want.finding = scanFinding(test.findings ?? [])`, `want.side = sideHint([...test.findings, ...plan.exam.map(f => f.finding)])`; loads candidates `select … from private.scan_assets where active and finding = $1`; `seen` = `select distinct t->>'scan_asset_id' from private.case_content cc join public.cases c on c.id = cc.case_id, jsonb_array_elements(cc.tests) t where c.created_by = $userId and t ? 'scan_asset_id'`; then `applyScan`. Any DB error → log and return the plan unchanged (a case must never fail because of scans).
- [ ] **Step 4:** Re-run, plus full `deno test generate-case/` → PASS.
- [ ] **Step 5:** Commit `Scans: pick the image before the case is written`.

### Task 4: Serve the image in order and resume

**Files:**
- Create: `supabase/functions/case-session/scanurl.ts`
- Modify: `supabase/functions/case-session/index.ts:362-372` (`order`) and `:178-187` (`resume`)
- Modify: `supabase/functions/case-session/resume.ts` (ordered entries pass through an optional `scan`)
- Test: `supabase/functions/case-session/scanurl_test.ts`, extend `resume_test.ts`

**Interfaces:**
- Produces: `type ScanReply = { url: string; credit: string; citation: string; source_url: string }`; `scansOn(env: (k: string) => string | undefined): boolean`; `signScans(testIds: { id: string; scan_asset_id?: string | null }[], sign: (objectName: string) => Promise<string>): Promise<Map<string, ScanReply>>`. `order` reply: `{result, abnormal, turnaround_s, scan?: ScanReply}`; resume `ordered[]` items gain optional `scan`.
- Credit/citation/source_url constants copied exactly from Global Constraints. Signed URL lifetime 3600 s, via `POST ${SUPABASE_URL}/storage/v1/object/sign/scans/<object_name>` with the service role key.

- [ ] **Step 1: Write failing tests:** `scansOn` true only for `"on"` (table: undefined, "", "true", "ON ", "off" → false) (Review Focus 4); `signScans` skips tests without `scan_asset_id`; calls `sign` once per asset each time (no caching across calls) (Review Focus 5); `resumeState` keeps `scan` when given and omits the key otherwise.
- [ ] **Step 2:** `deno test case-session/` → FAIL.
- [ ] **Step 3:** Implement; in `order` and `resume`, when `scansOn` and the test has `scan_asset_id`, look up `object_name` in `private.scan_assets` and sign. Signing failure → reply without `scan` (text result still works). Existing 404 for another user's attempt stays first.
- [ ] **Step 4:** Re-run → PASS; also run the existing denied-path tests in `case-session/`.
- [ ] **Step 5:** Commit `Scans: signed image URL with the X-ray result`.

### Task 5: Import tool

**Files:**
- Create: `tools/scan-import/README.md`, `candidates.py`, `reports.py`, `gate.py`, `encode.py`, `upload.py`, `run.py`, `test_candidates.py`, `test_reports.py`

**Interfaces:**
- Produces rows for `private.scan_assets` (Task 1 columns) and objects `scans/<uuid>.jpg`.
- `candidates.py`: `side_zone(x: float, y: float, w: float, h: float, width: int = 1024, height: int = 1024) -> tuple[str | None, str | None]` — box centre left of image midline → patient **right** (radiographic convention), right of midline → **left**; box crossing the midline by > 10% of width → `(None, None)`; zone by centre y thirds upper/middle/lower. `nih_box_candidates(bbox_csv, entry_csv) -> list[dict]` mapping NIH box labels Atelectasis→atelectasis, Effusion→effusion, Infiltrate/Pneumonia→opacity, Mass/Nodule→nodule_mass, Pneumothorax→pneumothorax, Cardiomegaly→cardiomegaly (side None). `google_candidates(...)` (only if `USE_GOOGLE_LABELS`): adjudicated normal and diffuse findings (edema, emphysema, cardiomegaly) from the all-findings set; lateral findings from Google sets are skipped (no side).
- `reports.py`: `report(finding: str, side: str | None, zone: str | None) -> str` — descriptive wording, never the diagnosis name, e.g. opacity → "Airspace opacity in the {side} {zone} zone. No pleural effusion. Heart size within normal limits."; pneumothorax → "Visible visceral pleural line with absent lung markings peripherally on the {side}."; effusion → "Blunting of the {side} costophrenic angle with a meniscus."; nodule_mass → "Rounded opacity in the {side} {zone} zone."; atelectasis → "Linear opacity with volume loss in the {side} {zone} zone."; cardiomegaly → "Cardiothoracic ratio greater than 0.5."; edema → "Bilateral perihilar haziness with vascular congestion."; emphysema → "Hyperinflated lungs with flattened hemidiaphragms."; normal → "Lungs are clear. Heart size within normal limits. No pleural effusion or pneumothorax."
- `gate.py`: `gate(image_bytes) -> dict` — `gpt-6.1-sol`, 3 independent passes, each asked (without the label) for the main finding from the `ScanFinding` list and its side; asset kept only if all 3 agree with the label (finding, and side for lateral findings); stores the three answers in `gate`.
- `encode.py`: `reencode(png_bytes) -> bytes` — Pillow, long edge 1024, grayscale JPEG quality 88, no EXIF/ICC/text chunks; reject if output < 40 KB or image std-dev < 20 (quality check after resize).
- `run.py`: `--dry-run` (default: writes `knowledge-base/licensed/scans/out/` with JPEGs + `assets.json` for spot-checks) and `--upload` (Storage + rows). Images fetched one by one from `https://storage.googleapis.com/gcs-public-data--healthcare-nih-chest-xray/png/<file>`. Target ≤ 30 assets per (finding, side) and ≥ 60 normals.

- [ ] **Step 1: Write failing tests:** `side_zone(100,100,80,80)` → `("right","upper")`; `side_zone(800,700,80,80)` → `("left","lower")`; `side_zone(400,400,300,100)` → `(None, None)`; for every finding (parameterized, both sides), `report(...)` contains none of `{"pneumonia","pneumothorax","effusion","edema","emphysema","cardiomegaly","atelectasis","nodule","mass","fracture"}` as a whole word, except the normal report's fixed "No pleural effusion or pneumothorax" (normal cases have no such diagnosis); diffuse findings never contain "left" or "right".
- [ ] **Step 2:** `cd tools/scan-import && python3 -m unittest` → FAIL.
- [ ] **Step 3:** Implement the modules; README documents order, dry-run vs upload, and that raw files stay in `knowledge-base/licensed/scans/`. Pillow is a new tools dependency (owner asked for re-encoding; note in PR).
- [ ] **Step 4:** Re-run → PASS. Run `python3 run.py --dry-run` on ~50 candidates; owner spot-checks the JPEGs and reports.
- [ ] **Step 5:** Commit `Scans: NIH import tool (dry run by default)`.

### Task 6: iOS data layer

**Files:**
- Create: `Rounds - IOS/Rounds/Model/Case/ScanImage.swift`
- Modify: `Rounds - IOS/Rounds/Model/Case/TestResult.swift` (add `var scan: ScanImage? = nil`)
- Modify: `Rounds - IOS/Rounds/Services/Cases/LiveCaseService.swift:161-164,488` (decode optional `scan`) and the resume DTO mapping for ordered tests
- Test: `Rounds - IOS/RoundsTests/Case/ScanReplyDecodingTests.swift`

**Interfaces:**
- Produces: `struct ScanImage: Hashable, Sendable { let url: URL; let credit: String; let citation: String; let sourceURL: URL }`. Wire DTO stays private in `LiveCaseService.swift` with snake_case `source_url`.

- [ ] **Step 1: Write failing tests:** order reply JSON without `scan` → `TestResult.scan == nil`; with `scan` → fields mapped, `sourceURL.absoluteString == "https://nihcc.app.box.com/v/ChestXray-NIHCC"`; malformed `url` → `scan == nil` and the text result still decodes.
- [ ] **Step 2:** `xcodegen generate` then `xcodebuild … test` → FAIL.
- [ ] **Step 3:** Implement; mocks unchanged (no scan).
- [ ] **Step 4:** Tests PASS; build passes with zero errors.
- [ ] **Step 5:** Commit `Scans: decode the image with an X-ray result`.

### Task 7: Radiologist screen design (canvas, stop for owner)

- [ ] **Step 1:** Build a claude.ai Design canvas for "Going to the radiologist": scan on top (zoom/pan/full screen), report below, credit subtitle (exact copy above) with tap-through sheet, loading and signing-failure states, light and dark, Phosphor icons, glass buttons, no orange.
- [ ] **Step 2:** Owner picks a direction. The Swift screen (with `-screen` debug names, Reduce Motion, accessibility labels) gets its own short plan after the pick.

### Task 8: Cloud rollout (announce each step first)

- [ ] **Step 1:** `supabase db push --linked` (Task 1 migration).
- [ ] **Step 2:** `supabase functions deploy generate-case` and `case-session` (switch still off: replies unchanged except chest X-ray reports now come from assets).
- [ ] **Step 3:** `python3 run.py --upload` after the owner approves the dry run.
- [ ] **Step 4:** `REAL_SCANS=on` only after the Swift screen ships in an approved App Store build.
