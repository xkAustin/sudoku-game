# Supabase online leaderboard

The supported online leaderboard uses Supabase PostgreSQL RPCs through the Data
API. The game contains only a project URL and publishable key; it never contains
a database password, secret key or `service_role` key. Local play and saves do
not require Supabase.

## Client configuration

Create the ignored `config/client.env` from the example:

```dotenv
SUPABASE_URL=https://YOUR_PROJECT.supabase.co/rest/v1/
SUPABASE_KEY=your-publishable-key
```

The five export presets include this file when it exists because the publishable
key is intentionally public. Never put a secret or service-role key in it. The
loader also accepts the same process environment variables and supports
`SUPABASE_ANON_KEY` as a legacy alias.

## Deploy the database

The supported base migration and its measured performance upgrade are:

```text
backend/supabase/migrations/006_data_api_scores.sql
backend/supabase/migrations/009_data_api_leaderboard_performance.sql
```

It can be pasted into the target project's SQL Editor, or deployed with Supabase
CLI 2.x:

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

Both migrations are idempotent. Run the temporary-table plan benchmark before
applying migration 009 so the optimization remains evidence-based for the target
PostgreSQL version. The CLI link cache under `supabase/.temp/` is ignored by Git.

The migration creates:

| Object | Purpose |
|---|---|
| `public.scores` | One highest-score row per anonymous installation UUID |
| `scores_global_rank` | Ordered index on score, timestamp and internal ID |
| `public.score_submission_guards` | Per-player idempotency and one-minute rate-limit state |
| `public.calculate_ranked_score` | Server-only deterministic score calculation |
| `public.submit_score` | The only anonymous score mutation entry point |
| `public.get_leaderboard` | The only anonymous leaderboard read entry point |

`scores` stores `player_id`, normalized `player_name`, server-calculated `score`,
`difficulty`, `duration_ms`, `mistakes`, `move_count` and `created_at`.

## Security model

RLS is enabled and forced on both tables. `anon` and `authenticated` have no
direct table privileges, so direct reads, inserts, updates and deletes are
rejected. Only these RPCs are executable:

```text
submit_score(
  uuid, text, smallint, integer, smallint, smallint, integer, uuid
)
get_leaderboard(uuid)
```

The client sends raw ranked-session metrics and an idempotency UUID to
`submit_score`. The server:

- normalizes whitespace and rejects empty, overlong, control or reserved names;
- accepts difficulty 1–6;
- requires a difficulty-specific minimum duration and a 24-hour maximum;
- accepts 0–2 mistakes, zero ranked hints and 8–10,000 moves;
- returns the cached response for the same submission UUID;
- accepts at most ten distinct submissions per player UUID per minute;
- calculates the score itself and ignores any client-side final score;
- updates a row only when the new score is higher.

`get_leaderboard` returns the global Top 100 and the requested player's exact
position without exposing player UUIDs in leaderboard rows. Migration 009 stops
materializing the complete ranked row set: the Top 100 streams from
`scores_global_rank`, and the requested player's position is counted against
their indexed score row.

## Score calculation

The database calculates:

```text
difficulty base
+ max(0, 1,000,000 - duration_ms)
+ max(0, 3 - mistakes) × 25,000
+ max(0, 500 - move_count) × 100
- hints_used × 100,000
```

Difficulty bases are 1M, 2M, 3M, 5M, 8M and 13M. Ranked submissions currently
require zero hints. The GDScript helper mirrors this formula for display and
tests, but its value is not trusted by the server.

## Verification

Inspect deployed structure, indexes, RLS and function privileges:

```sh
supabase db query --linked \
  --file backend/supabase/tests/verify_data_api_scores.sql \
  --output table
```

Before deployment, clean-boot both independent migration chains in disposable
PostgreSQL 17 databases:

```sh
./backend/supabase/tests/clean_boot.sh
```

Run the repeatable anonymous Data API check:

```sh
./backend/supabase/tests/live_data_api.sh
```

Measure the Data API and optional Edge query plans without writing benchmark
rows to production tables:

```sh
supabase db query --linked \
  --file backend/supabase/tests/explain_leaderboard_queries.sql \
  --output json
supabase db query --linked \
  --file backend/supabase/tests/explain_edge_queries.sql \
  --output json
```

The scripts create representative data only in `pg_temp`; all helpers, rows and
indexes disappear when the query session ends.

It verifies a valid bounded score, idempotent replay, lower-score preservation,
higher-score replacement, invalid difficulty/duration/hint/move rejection,
direct table access rejection, RPC leaderboard read and the
eleventh-submission rate limit.

Run the game client's own HTTPS path:

```sh
godot --headless --path . \
  --log-file /tmp/sudoku-supabase-live.log \
  --script tests/supabase_live_runner.gd
```

Both live commands print `SUPABASE_TEST_PLAYER_ID`. Remove the temporary row with
an administrator connection:

```sql
delete from public.score_submission_guards where player_id = 'TEST_UUID';
delete from public.scores where player_id = 'TEST_UUID';
```

Do not use a production player's UUID for testing.

## Verified deployment record

On 2026-07-26 migration 006 was applied to the maintainer's `sudoku-game`
project with Supabase CLI 2.109.1 and then independently queried.

Confirmed results:

- `scores` contains all nine expected columns and
  `score_submission_guards` exists.
- `scores_pkey`, `scores_player_id_key`, `scores_global_rank` and
  `score_submission_guards_pkey` exist with the expected definitions.
- RLS is enabled and forced on both tables.
- `anon` has no direct select, insert, update or delete privilege on either
  table.
- `submit_score` and `get_leaderboard` are `SECURITY DEFINER`; only the intended
  RPCs are executable by `anon` and `authenticated`.
- Helper functions are not executable by client roles, and all four functions
  use an empty `search_path`.
- There are no table policies or triggers. This is intentional: direct table
  privileges are revoked and all client access goes through the two RPCs.
- Valid anonymous RPC submission and leaderboard read returned HTTP 200.
- Implausible duration and the eleventh distinct one-minute submission returned
  HTTP 400.
- Direct table read/insert/update/delete returned HTTP 401.
- The Godot 4.7.1 client passed real HTTPS submit/read/RLS checks.
- All temporary QA rows and guard rows were removed; the final residual count
  for the test UUIDs was zero.
- `supabase functions list` returned no deployed Edge Functions. This matches
  the supported Data API architecture; the optional legacy/future functions
  remain source-only until a maintainer explicitly deploys and validates them.

The read-only structural check was repeated immediately before the final release
commit on 2026-07-26 and returned the same table, function, grant, index, policy
and trigger inventory. A final name-pattern/orphan check found zero suspected
Codex/test/QA score rows and zero orphan submission-guard rows.

### Performance and optional Edge deployment — 2026-08-09

Migrations 009 and 010 were applied to the same healthy hosted PostgreSQL 17
project after real `EXPLAIN (ANALYZE, BUFFERS)` comparisons on session-local
representative data:

- Data API leaderboard, 20,000 rows: worst-ranked player improved from
  47.256 ms to 8.843 ms (5.34×), and best-ranked player improved from
  38.278 ms to 0.877 ms (43.65×). The candidate plan eliminated 181 temporary
  write blocks.
- Optional Edge history, 50,000 rows: the rolling rate-limit lookup improved
  from 0.137 ms to 0.080 ms (1.71×), while the challenge leaderboard improved
  from 10.102 ms to 4.522 ms (2.23×) and changed to an index-only scan.
- A post-migration rerun confirmed both production indexes exist and retained
  the intended plan shape.
- The complete Data API live check passed, including RPC compatibility, forced
  RLS, direct-access denial, idempotency and rate limiting. Its one score row and
  one guard row were deleted by exact UUID and the cleanup returned one row for
  each table.
- `get-ranked-challenge`, `submit-score` and `get-leaderboard` were deployed as
  version 3. All three are `ACTIVE` with JWT verification enabled and all
  required server secret names present.
- Live Edge smoke passed: unauthenticated access returned HTTP 401,
  `get-leaderboard` returned HTTP 200, the empty challenge state returned the
  expected HTTP 404, and an invalid submission returned HTTP 400.

## Remaining security limit

This is basic hardening for a casual anonymous leaderboard, not proof of gameplay.
A modified client can generate a new UUID and submit fabricated but plausible
metrics, or wait out the per-UUID limit. The current system cannot prove device
ownership, bind a score to a server-issued puzzle or prevent Sybil identities.

For stronger competition, require Supabase Auth and submit a server-issued
challenge ID, signed nonce and final board to an Edge Function that verifies the
solution, expiry and single-use status before calling a private database
function. The optional signed-challenge functions under
`backend/supabase/functions/` are retained as a foundation for that future mode.
On a new project, apply every file in `backend/supabase/edge_migrations/` in
filename order before deploying those functions. Existing Edge deployments can
continue from the applicable upgrade migration below.
Before deploying them, also apply
`backend/supabase/edge_migrations/007_atomic_edge_submissions.sql`; it makes the
per-installation rolling limit and verified score insert one locked transaction.
Apply `backend/supabase/edge_migrations/008_edge_service_permissions.sql` as well; it
grants the Edge runtime only the private table and view reads those functions
need while keeping direct client access revoked.
Before deploying the functions, run the temporary Edge plan benchmark and apply
`backend/supabase/edge_migrations/009_edge_query_performance.sql`; it adds the two
measured lookup indexes without expanding privileges.
The submit function also counts streamed request bytes instead of trusting the
`Content-Length` header. Privileged Data API requests have an eight-second
default timeout, and the leaderboard loads its independent Top 100 and own-rank
queries concurrently. A disposable-database regression check is available at
`backend/supabase/tests/test_atomic_edge_submissions.sql`; deployed functions
can be checked without writing rows using
`backend/supabase/tests/live_edge_functions.sh`.
