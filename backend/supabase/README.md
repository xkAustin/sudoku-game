# Supabase backend

The currently supported public online leaderboard uses the Data API migration
`migrations/006_data_api_scores.sql`. See the repository-level
[`SUPABASE.md`](../../SUPABASE.md) for local publishable-key configuration,
database setup, RLS rules and verification.

The signed-challenge Edge Functions below are optional infrastructure for a
future server-verified ranked mode. They are not required by the Data API
leaderboard and their service-role environment variables must never be placed in
the game client.

This directory is deployable with Supabase CLI 2.x. It deliberately exposes no
direct table writes to anonymous clients. Edge Functions access PostgreSQL using
the server-only service role.

## Local setup

1. Run `supabase start --workdir backend` from the repository root.
2. Apply the supported Data API migrations with
   `supabase db reset --workdir backend`.
3. For optional Edge development, apply every SQL file in
   `backend/supabase/edge_migrations/` in filename order, then explicitly apply
   `backend/supabase/edge_seed.sql`.
4. Copy `.env.example` to `.env`. Its development pepper matches
   `edge_seed.sql`.
5. Serve functions with `supabase functions serve --env-file backend/supabase/.env`.
6. Copy `config/client.env.example` to the ignored `config/client.env` and set
   the public project URL and publishable key for a client build.

For production, generate distinct random values of at least 32 bytes for
`CHALLENGE_SIGNING_SECRET` and `SOLUTION_HASH_PEPPER`. Recalculate every seeded
`solution_hash` as lowercase SHA-256 of `solution + pepper`. Secrets belong only
in Supabase Function secrets; do not commit `.env`.

Deploy the supported Data API migration with:

```sh
supabase link --project-ref YOUR_PROJECT_REF
supabase db query --linked \
  --file backend/supabase/migrations/006_data_api_scores.sql
supabase db query --linked \
  --file backend/supabase/tests/explain_leaderboard_queries.sql \
  --output json
supabase db query --linked \
  --file backend/supabase/migrations/009_data_api_leaderboard_performance.sql
```

The benchmark uses 20,000 session-local rows and returns both old and candidate
plans without writing production leaderboard data. Apply migration 009 only
after checking the target project's result.

Only deploy the optional signed-challenge functions when that experimental
service is intentionally enabled:

On a new project, apply every file in `backend/supabase/edge_migrations/` in
filename order. The commands below are the upgrade sequence for an existing
Edge schema that already has migrations 001 through 006.

```sh
supabase db query --linked \
  --file backend/supabase/edge_migrations/007_atomic_edge_submissions.sql
supabase db query --linked \
  --file backend/supabase/edge_migrations/008_edge_service_permissions.sql
supabase db query --linked \
  --file backend/supabase/tests/explain_edge_queries.sql \
  --output json
supabase db query --linked \
  --file backend/supabase/edge_migrations/009_edge_query_performance.sql
supabase secrets set --env-file backend/supabase/.env
supabase functions deploy \
  get-ranked-challenge submit-score get-leaderboard \
  --workdir backend --use-api
./backend/supabase/tests/live_edge_functions.sh
```

Edge migration 008 explicitly gives the Edge runtime only the private table and view
reads it needs; direct client access remains revoked. The three functions
implement API version v1. Breaking changes should use new
function names or route dispatch while keeping v1 available to compatible clients.

## Data and abuse controls

The server stores a random installation UUID, submitted display name, game metrics
and final board. It does not store a hardware identifier or full IP address.
Supabase infrastructure may temporarily process IP data for delivery and abuse
protection according to the project retention settings. Application logs must not
include authorization headers, service keys, complete tokens or request bodies.

The supported Data API RPC denies direct table access, calculates score
server-side from bounded metrics, deduplicates a submission UUID and accepts at
most ten distinct submissions per player UUID per minute. The optional
signed-challenge submit function separately applies a per-installation rolling
limit in the same database transaction as the insert. It streams and counts the
actual request bytes before parsing, so a missing or false `Content-Length`
cannot bypass the hard 16 KiB request-size limit. Privileged Data API requests
have an eight-second default timeout. The Edge leaderboard runs its independent
Top 100 and own-rank reads concurrently.

Verify the optional Edge submission transaction against a disposable or local
database after applying all migrations:

```sh
psql "$DATABASE_URL" \
  --set ON_ERROR_STOP=1 \
  --file backend/supabase/tests/test_atomic_edge_submissions.sql
```

The test rolls back its challenge and score rows.

Before deploying either stack, verify both independent migration chains from an
empty PostgreSQL 17 database:

```sh
./backend/supabase/tests/clean_boot.sh
```

The script rejects duplicate migration versions, starts one disposable
PostgreSQL container, applies the Data API and optional Edge chains to separate
empty databases, reapplies both chains and the Edge seed, asserts objects, RLS,
grants and indexes, runs the atomic Edge submission regression, and removes the
container.

Neither anonymous path proves ownership of a locally generated UUID. A modified
client can fabricate plausible metrics or create new UUIDs, so production should
also configure Supabase gateway/abuse controls and treat the Data API board as a
casual leaderboard. Authenticated, server-issued single-use challenges are
required for stronger integrity.
