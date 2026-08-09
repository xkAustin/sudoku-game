# Supabase Guide

## Client environment variables

```sh
cp config/client.env.example config/client.env
```

```dotenv
SUPABASE_URL=https://YOUR_PROJECT.supabase.co/rest/v1/
SUPABASE_KEY=your-publishable-key
```

`config/client.env` is ignored. Never place a secret or `service_role` key in it.

## Deploy the migration

```sh
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase db query --linked \
  --file backend/supabase/migrations/006_data_api_scores.sql
supabase db query --linked \
  --file backend/supabase/tests/explain_leaderboard_queries.sql \
  --output json
supabase db query --linked \
  --file backend/supabase/migrations/009_data_api_leaderboard_performance.sql
```

The migration creates `scores`, `score_submission_guards`,
`scores_global_rank`, `normalize_player_name`, `calculate_ranked_score`,
`submit_score`, and `get_leaderboard`. Both tables force RLS, have no client
table policy or direct table privilege, and expose only the two public RPCs to
anonymous clients. The current migration creates no trigger.
The plan script uses only `pg_temp` data and compares the original complete-rank
materialization with migration 009 on the target PostgreSQL version.

## Structure and security verification

```sh
supabase db query --linked \
  --file backend/supabase/tests/verify_data_api_scores.sql \
  --output table
./backend/supabase/tests/live_data_api.sh
godot --headless --path . --script tests/supabase_live_runner.gd
```

Live tests create QA leaderboard rows. Use the printed UUID and an administrator
connection to clean `score_submission_guards` and `scores`. Never put a
service-role key in a test script.

This design provides basic protection for a casual leaderboard. The server
calculates the final score and validates metrics, but anonymous UUIDs and
client-reported metrics can still be fabricated.

The benchmark and live test run on 2026-08-09 measured a 5.34× worst-rank and
43.65× best-rank improvement at 20,000 representative rows. The live Data API
flow passed after migration 009, and its exact test score and guard UUID were
removed.

## Optional signed-challenge functions

Before deploying the optional Edge Functions, apply their private atomic-submit
migration:

```sh
supabase db query --linked \
  --file backend/supabase/migrations/007_atomic_edge_submissions.sql
supabase db query --linked \
  --file backend/supabase/migrations/008_edge_service_permissions.sql
supabase db query --linked \
  --file backend/supabase/tests/explain_edge_queries.sql \
  --output json
supabase db query --linked \
  --file backend/supabase/migrations/010_edge_query_performance.sql
supabase functions deploy \
  get-ranked-challenge submit-score get-leaderboard \
  --workdir backend --use-api
./backend/supabase/tests/live_edge_functions.sh
```

Migration 008 explicitly grants the Edge runtime only the private table and
view reads it needs; direct client access remains revoked. Migration 007 locks
each installation ID while checking the rolling one-minute limit and
inserting the verified score. The Edge submit handler also streams and counts
the real request bytes, so missing or false `Content-Length` values cannot bypass
the 16 KiB limit. Privileged Data API requests use an eight-second default
timeout, and the leaderboard loads its independent Top 100 and own-rank reads
concurrently. The Edge benchmark creates 50,000 session-local rows; migration
010 is applied only after its two indexes improve the target plans. Verify a
local or disposable database with:

```sh
psql "$DATABASE_URL" \
  --set ON_ERROR_STOP=1 \
  --file backend/supabase/tests/test_atomic_edge_submissions.sql
```

The verification transaction rolls back all test rows.

On 2026-08-09 the rate-limit lookup improved by 1.71× and the challenge
leaderboard by 2.23× in the pre-deployment benchmark. After deployment, all
three functions were `ACTIVE` at version 3 with JWT verification enabled; the
no-write live smoke returned the expected 401, 200, 404 and 400 responses.
