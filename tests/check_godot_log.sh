#!/usr/bin/env sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 GODOT_LOG" >&2
  exit 64
fi

log_file="$1"
if [ ! -f "$log_file" ]; then
  echo "Godot log does not exist: $log_file" >&2
  exit 66
fi

error_pattern='SCRIPT ERROR:|Parse Error:|Compile Error:|Failed to load script'
if grep -E "$error_pattern" "$log_file" >/dev/null 2>&1; then
  echo "Godot reported a script error in $log_file" >&2
  grep -E "$error_pattern" "$log_file" >&2
  exit 1
fi
