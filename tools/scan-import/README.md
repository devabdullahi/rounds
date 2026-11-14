# scan-import

Builds the real chest X-ray library (NIH ChestX-ray14) behind the app's "real scans" feature: curated
rows in `private.scan_assets` and JPEGs in the private `scans` Storage bucket as `<uuid>.jpg`.

Only expert-labelled images qualify: NIH's radiologist boxes (`BBox_List_2017.csv`) and Google's
adjudicated all-findings labels. NIH's NLP labels never do, and "normal" only comes from an adjudicated
normal label, never NIH's "No Finding". Reports describe signs and never name a diagnosis
(`reports.py`); the server shows them verbatim.

## Order

1. Put the label files in `knowledge-base/licensed/scans/` (git-ignored; raw files never go in git):
   `BBox_List_2017.csv`, `Data_Entry_2017.csv`, and (optional) Google's all-findings `test_labels.csv`
   saved as `google_all_findings_test_labels.csv`. The Google column names in `candidates.py` are
   unconfirmed; check them against the file first. Set `USE_GOOGLE_LABELS = False` to skip Google.
2. `pip install -r requirements.txt` and `export OPENAI_API_KEY=...` (or `tools/kb-generate/.env`).
3. Dry run (default), e.g. `python3 run.py --dry-run --limit 50`. Downloads images one by one into
   `raw/`, re-encodes them, runs the vision gate (`gpt-6.1-sol`, 3 passes, all must agree with the label)
   and writes `out/` with the JPEGs and `assets.json`. Spot-check the JPEGs against their reports.
4. `python3 run.py --upload` sends exactly what `out/assets.json` holds. Environment (never printed):
   `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_DB_URL` (values in `supabase/cloud.env`;
   needs `psql` and curl). JPEGs go first, then the rows. This writes to the real project: say so first.

Targets: up to 30 assets per (finding, side) and at least 60 normals.

## Tests

`python3 -m unittest` (no network, no OpenAI calls).
