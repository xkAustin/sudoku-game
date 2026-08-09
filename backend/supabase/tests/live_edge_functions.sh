#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
config_file="${SUPABASE_CLIENT_ENV:-$project_root/config/client.env}"

if [[ ! -f "$config_file" ]]; then
	echo "Missing Supabase client configuration: $config_file" >&2
	exit 2
fi

set -a
# shellcheck disable=SC1090
source "$config_file"
set +a

: "${SUPABASE_URL:?SUPABASE_URL is required}"
: "${SUPABASE_KEY:?SUPABASE_KEY is required}"

project_url="${SUPABASE_URL%/}"
project_url="${project_url%/rest/v1}"
function_root="$project_url/functions/v1"
body_file="$(mktemp "${TMPDIR:-/tmp}/sudoku-edge-body.XXXXXX")"
trap 'rm -f "$body_file"' EXIT

request() {
	local method="$1"
	local function_path="$2"
	local authenticated="$3"
	local payload="${4:-}"
	local args=(
		--silent --show-error
		--output "$body_file"
		--write-out "%{http_code}"
		--request "$method"
		--header "Content-Type: application/json"
	)
	if [[ "$authenticated" == "yes" ]]; then
		args+=(
			--header "apikey: $SUPABASE_KEY"
			--header "Authorization: Bearer $SUPABASE_KEY"
		)
	fi
	if [[ -n "$payload" ]]; then
		args+=(--data "$payload")
	fi
	curl "${args[@]}" "$function_root/$function_path"
}

assert_status() {
	local actual="$1"
	local expected="$2"
	local label="$3"
	if [[ "$actual" != "$expected" ]]; then
		echo "FAIL $label: HTTP $actual, body: $(<"$body_file")" >&2
		exit 1
	fi
	echo "PASS $label: HTTP $actual"
}

status="$(request GET "get-leaderboard?difficulty=1&limit=5" no)"
assert_status "$status" "401" "JWT gateway rejects an unauthenticated request"

status="$(request GET "get-leaderboard?difficulty=1&limit=5" yes)"
assert_status "$status" "200" "leaderboard function"
jq -e '.success == true and (.entries | type == "array")' "$body_file" >/dev/null

status="$(request GET "get-ranked-challenge?difficulty=1" yes)"
case "$status" in
	200)
		jq -e '.success == true and .challenge_token != null' "$body_file" >/dev/null
		;;
	404)
		jq -e '.success == false and .error.code == "NO_CHALLENGE"' "$body_file" >/dev/null
		;;
	*)
		echo "FAIL ranked challenge function: HTTP $status, body: $(<"$body_file")" >&2
		exit 1
		;;
esac
echo "PASS ranked challenge function: HTTP $status"

status="$(request POST "submit-score" yes '{}')"
assert_status "$status" "400" "submit function rejects an invalid shape"
jq -e '.success == false and .error.code == "INVALID_REQUEST"' "$body_file" >/dev/null

echo "All live Supabase Edge Function checks passed."
