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
```

The migration creates `scores`, `score_submission_guards`,
`scores_global_rank`, `normalize_player_name`, `calculate_ranked_score`,
`submit_score`, and `get_leaderboard`. Both tables force RLS, have no client
table policy or direct table privilege, and expose only the two public RPCs to
anonymous clients. The current migration creates no trigger.

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

## Optional signed-challenge functions

Before deploying the optional Edge Functions, apply their private atomic-submit
migration:

```sh
supabase db query --linked \
  --file backend/supabase/migrations/007_atomic_edge_submissions.sql
supabase db query --linked \
  --file backend/supabase/migrations/008_edge_service_permissions.sql
```

Migration 008 explicitly grants the Edge runtime only the private table and
view reads it needs; direct client access remains revoked. Migration 007 locks
each installation ID while checking the rolling one-minute limit and
inserting the verified score. The Edge submit handler also streams and counts
the real request bytes, so missing or false `Content-Length` values cannot bypass
the 16 KiB limit. Verify a local or disposable database with:

```sh
psql "$DATABASE_URL" \
  --set ON_ERROR_STOP=1 \
  --file backend/supabase/tests/test_atomic_edge_submissions.sql
```

The verification transaction rolls back all test rows.
