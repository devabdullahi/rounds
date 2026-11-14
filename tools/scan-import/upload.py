"""Sends reviewed assets to the cloud: JPEGs into the private `scans` bucket, rows into
private.scan_assets. Only `run.py --upload` calls this, and only after the dry run was spot-checked.

Credentials come from the environment and are never printed:
    SUPABASE_URL                  https://<project>.supabase.co
    SUPABASE_SERVICE_ROLE_KEY     service role key (Storage write)
    SUPABASE_DB_URL               postgres connection string (the rows; `private` is not exposed over REST)
"""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
from pathlib import Path
from urllib.parse import unquote, urlparse

ROW_COLUMNS = ["id", "object_name", "finding", "side", "zone", "view", "age", "sex", "report",
               "label_source", "source_image", "gate"]


def require_env(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        raise SystemExit(f"Set {name} (supabase/cloud.env has the project values)")
    return value


def insert_sql(rows: list[dict]) -> str:
    """One INSERT for all rows. The rows travel as a single dollar-quoted JSON document, so no value
    is spliced into SQL text."""
    document = json.dumps([{c: row[c] for c in ROW_COLUMNS} for row in rows])
    if "$rows$" in document:
        raise ValueError("row data contains the SQL quote tag")
    columns = ", ".join(ROW_COLUMNS)
    return (f"insert into private.scan_assets ({columns})\n"
            f"select {columns} from jsonb_populate_recordset(null::private.scan_assets, $rows${document}$rows$::jsonb);\n")


def upload_object(base_url: str, service_key: str, object_name: str, jpeg: bytes) -> None:
    """POSTs one JPEG into the `scans` bucket. The key goes through a curl config on stdin, not argv,
    so the JPEG is passed as a temp file instead."""
    with tempfile.NamedTemporaryFile(suffix=".jpg", delete=False) as f:
        f.write(jpeg)
        path = f.name
    config = "\n".join([f'header = "Authorization: Bearer {service_key}"', f'header = "apikey: {service_key}"',
                        'header = "content-type: image/jpeg"'])
    try:
        result = subprocess.run(
            ["curl", "-sS", "--fail-with-body", "-K", "-", "-X", "POST", "--data-binary", f"@{path}",
             f"{base_url.rstrip('/')}/storage/v1/object/scans/{object_name}"],
            input=config.encode(), capture_output=True)
    finally:
        os.unlink(path)
    if result.returncode != 0:
        raise RuntimeError(f"upload of {object_name} failed: {result.stderr.decode().strip()}")


def insert_rows(db_url: str, rows: list[dict]) -> None:
    """Runs the INSERT through psql. Connection parts go in PG* variables so the password never
    appears in the process list."""
    parts = urlparse(db_url)
    env = {**os.environ, "PGHOST": parts.hostname or "", "PGPORT": str(parts.port or 5432),
           "PGUSER": unquote(parts.username or ""), "PGPASSWORD": unquote(parts.password or ""),
           "PGDATABASE": (parts.path or "/postgres").lstrip("/") or "postgres"}
    result = subprocess.run(["psql", "-v", "ON_ERROR_STOP=1", "-q", "-f", "-"],
                            input=insert_sql(rows), env=env, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"row insert failed: {result.stderr.strip()}")


def upload_all(out_dir: Path, rows: list[dict]) -> None:
    """Uploads every JPEG first, then inserts the rows, so a row never points at a missing object."""
    base_url = require_env("SUPABASE_URL")
    service_key = require_env("SUPABASE_SERVICE_ROLE_KEY")
    db_url = require_env("SUPABASE_DB_URL")
    for row in rows:
        upload_object(base_url, service_key, row["object_name"], (out_dir / row["object_name"]).read_bytes())
    insert_rows(db_url, rows)
