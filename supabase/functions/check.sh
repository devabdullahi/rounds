#!/usr/bin/env bash
# Type-checks every edge function and runs every Deno test, the same way CI does.
#
#   supabase/functions/check.sh
#
# Each function folder has its own deno.json (it maps "postgres"), and a config only covers tests
# in its own folder, so each folder is checked on its own. _shared has no config of its own; it
# borrows generate-case's, which maps the same imports.
set -euo pipefail
cd "$(dirname "$0")"
FLAGS=(--node-modules-dir=none)

for dir in */; do
  dir=${dir%/}
  config="$dir/deno.json"
  [ -f "$config" ] || config=generate-case/deno.json
  if [ -f "$dir/index.ts" ]; then
    echo "== check $dir"
    deno check "${FLAGS[@]}" --config "$config" "$dir/index.ts"
  fi
  if compgen -G "$dir/*_test.ts" >/dev/null; then
    echo "== test $dir"
    deno test "${FLAGS[@]}" --allow-all --config "$config" "$dir/"
  fi
done
