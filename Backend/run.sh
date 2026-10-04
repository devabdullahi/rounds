#!/usr/bin/env bash
# Dev server. Not wired to the iOS app yet.
set -euo pipefail
uvicorn app.main:app --reload --port 8000
