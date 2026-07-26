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

api_root="${SUPABASE_URL%/}"
player_id="${SUPABASE_TEST_PLAYER_ID:-$(uuidgen | tr '[:upper:]' '[:lower:]')}"
player_name="Codex QA $(date -u +%H%M%S)"
body_file="$(mktemp "${TMPDIR:-/tmp}/sudoku-supabase-body.XXXXXX")"
trap 'rm -f "$body_file"' EXIT

request() {
	local method="$1"
	local path="$2"
	local payload="${3:-}"
	local status
	local args=(
		--silent --show-error
		--output "$body_file"
		--write-out "%{http_code}"
		--request "$method"
		--header "apikey: $SUPABASE_KEY"
		--header "Authorization: Bearer $SUPABASE_KEY"
		--header "Content-Type: application/json"
	)
	if [[ -n "$payload" ]]; then
		args+=(--data "$payload")
	fi
	status="$(curl "${args[@]}" "$api_root/$path")"
	printf '%s' "$status"
}

submission_payload() {
	local submission_id="$1"
	local difficulty="$2"
	local duration_ms="$3"
	local mistakes="${4:-0}"
	local move_count="${5:-120}"
	jq -nc \
		--arg player_id "$player_id" \
		--arg player_name "$player_name" \
		--arg submission_id "$submission_id" \
		--argjson difficulty "$difficulty" \
		--argjson duration_ms "$duration_ms" \
		--argjson mistakes "$mistakes" \
		--argjson move_count "$move_count" \
		'{
			p_player_id: $player_id,
			p_player_name: $player_name,
			p_difficulty: $difficulty,
			p_duration_ms: $duration_ms,
			p_mistakes: $mistakes,
			p_hints_used: 0,
			p_move_count: $move_count,
			p_submission_id: $submission_id
		}'
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

first_submission="$(uuidgen | tr '[:upper:]' '[:lower:]')"
first_payload="$(submission_payload "$first_submission" 3 120000 0 120)"
status="$(request POST "rpc/submit_score" "$first_payload")"
assert_status "$status" "200" "valid RPC submission"
first_score="$(jq -er '.score' "$body_file")"
jq -e '.updated == true and .duplicate == false and .score >= 1 and .score <= 20000000' "$body_file" >/dev/null

status="$(request POST "rpc/submit_score" "$first_payload")"
assert_status "$status" "200" "idempotent duplicate"
jq -e '.duplicate == true' "$body_file" >/dev/null

lower_payload="$(submission_payload "$(uuidgen | tr '[:upper:]' '[:lower:]')" 1 900000 2 600)"
status="$(request POST "rpc/submit_score" "$lower_payload")"
assert_status "$status" "200" "lower score accepted without overwrite"
jq -e --argjson score "$first_score" '.updated == false and .score == $score' "$body_file" >/dev/null

higher_payload="$(submission_payload "$(uuidgen | tr '[:upper:]' '[:lower:]')" 6 60000 0 80)"
status="$(request POST "rpc/submit_score" "$higher_payload")"
assert_status "$status" "200" "higher score overwrites"
jq -e --argjson score "$first_score" '.updated == true and .score > $score' "$body_file" >/dev/null

invalid_payload="$(submission_payload "$(uuidgen | tr '[:upper:]' '[:lower:]')" 6 1000 0 80)"
status="$(request POST "rpc/submit_score" "$invalid_payload")"
assert_status "$status" "400" "implausible duration rejected"
jq -e '.code == "22023"' "$body_file" >/dev/null

invalid_difficulty_payload="$(submission_payload "$(uuidgen | tr '[:upper:]' '[:lower:]')" 7 120000 0 80)"
status="$(request POST "rpc/submit_score" "$invalid_difficulty_payload")"
assert_status "$status" "400" "invalid difficulty rejected"
jq -e '.code == "22023"' "$body_file" >/dev/null

ranked_hint_payload="$(submission_payload "$(uuidgen | tr '[:upper:]' '[:lower:]')" 3 120000 0 80)"
ranked_hint_payload="$(jq '.p_hints_used = 1' <<<"$ranked_hint_payload")"
status="$(request POST "rpc/submit_score" "$ranked_hint_payload")"
assert_status "$status" "400" "ranked hint use rejected"
jq -e '.code == "22023"' "$body_file" >/dev/null

invalid_moves_payload="$(submission_payload "$(uuidgen | tr '[:upper:]' '[:lower:]')" 3 120000 0 2)"
status="$(request POST "rpc/submit_score" "$invalid_moves_payload")"
assert_status "$status" "400" "implausible move count rejected"
jq -e '.code == "22023"' "$body_file" >/dev/null

direct_payload="$(jq -nc --arg player_id "$player_id" '{player_id:$player_id,player_name:"Direct write",score:9999999}')"
status="$(request POST "scores" "$direct_payload")"
assert_status "$status" "401" "direct insert rejected"

status="$(request PATCH "scores?player_id=eq.$player_id" '{"score":9999999}')"
assert_status "$status" "401" "direct update rejected"

status="$(request DELETE "scores?player_id=eq.$player_id")"
assert_status "$status" "401" "direct delete rejected"

status="$(request GET "scores?select=*")"
assert_status "$status" "401" "direct table read rejected"

leaderboard_payload="$(jq -nc --arg player_id "$player_id" '{p_player_id:$player_id}')"
status="$(request POST "rpc/get_leaderboard" "$leaderboard_payload")"
assert_status "$status" "200" "leaderboard RPC read"
jq -e '.entries | type == "array"' "$body_file" >/dev/null
jq -e --arg player_id "$player_id" '.self_entry.rank >= 1 and (.self_entry | has("player_id") | not)' "$body_file" >/dev/null

# Three accepted unique submissions already consumed this player's current
# one-minute window. Add seven, then verify that the eleventh is rejected.
for attempt in $(seq 1 7); do
	payload="$(submission_payload "$(uuidgen | tr '[:upper:]' '[:lower:]')" 2 $((120000 + attempt * 1000)) 0 $((120 + attempt)))"
	status="$(request POST "rpc/submit_score" "$payload")"
	assert_status "$status" "200" "rate-limit setup $attempt/7"
done

rate_limited_payload="$(submission_payload "$(uuidgen | tr '[:upper:]' '[:lower:]')" 2 150000 0 140)"
status="$(request POST "rpc/submit_score" "$rate_limited_payload")"
assert_status "$status" "400" "eleventh unique submission rate-limited"
jq -e '.message == "submission rate limit exceeded"' "$body_file" >/dev/null

echo "SUPABASE_TEST_PLAYER_ID=$player_id"
echo "All live Supabase Data API checks passed."
