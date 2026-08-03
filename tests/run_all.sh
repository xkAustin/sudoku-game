#!/usr/bin/env sh
set -eu

if command -v godot >/dev/null 2>&1; then
  GODOT_BIN=godot
elif command -v godot4 >/dev/null 2>&1; then
  GODOT_BIN=godot4
else
  echo "Godot 4.7 executable not found in PATH" >&2
  exit 127
fi

GODOT_TEST_LOG="${TMPDIR:-/tmp}/sudoku-godot-tests.log"
GODOT_IMPORT_LOG="${TMPDIR:-/tmp}/sudoku-godot-import.log"
"$GODOT_BIN" --headless --path . --editor --quit-after 30 --log-file "$GODOT_IMPORT_LOG"
"$GODOT_BIN" --headless --path . --log-file "$GODOT_TEST_LOG" --script tests/test_runner.gd
"$GODOT_BIN" --headless --path . --log-file "${TMPDIR:-/tmp}/sudoku-debug-smoke.log" --script tests/debug_smoke_runner.gd
deno test --allow-env backend/supabase/tests
deno check backend/supabase/functions/get-ranked-challenge/index.ts
deno check backend/supabase/functions/submit-score/index.ts
deno check backend/supabase/functions/get-leaderboard/index.ts
