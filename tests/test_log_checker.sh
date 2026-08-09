#!/usr/bin/env sh
set -eu

checker="$(dirname "$0")/check_godot_log.sh"
fixtures="$(dirname "$0")/fixtures"

"$checker" "$fixtures/godot_clean.log"
if "$checker" "$fixtures/godot_script_error.log" >/dev/null 2>&1; then
  echo "Godot log checker accepted a script error" >&2
  exit 1
fi
if "$checker" "$fixtures/missing.log" >/dev/null 2>&1; then
  echo "Godot log checker accepted a missing log" >&2
  exit 1
fi

echo "Godot log checker tests passed"
