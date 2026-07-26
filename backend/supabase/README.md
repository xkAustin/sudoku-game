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

1. Run `supabase start` from the repository root.
2. Apply migrations with `supabase db reset`.
3. Copy `.env.example` to `.env`. Its development pepper matches `seed.sql`.
4. Serve functions with `supabase functions serve --env-file backend/supabase/.env`.
5. Copy `config/client.env.example` to the ignored `config/client.env` and set
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
```

Only deploy the optional signed-challenge functions when that experimental
service is intentionally enabled:

```sh
supabase secrets set --env-file backend/supabase/.env
supabase functions deploy get-ranked-challenge
supabase functions deploy submit-score
supabase functions deploy get-leaderboard
```

The three functions implement API version v1. Breaking changes should use new
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
limit and hard request-size limit.

Neither anonymous path proves ownership of a locally generated UUID. A modified
client can fabricate plausible metrics or create new UUIDs, so production should
also configure Supabase gateway/abuse controls and treat the Data API board as a
casual leaderboard. Authenticated, server-issued single-use challenges are
required for stronger integrity.
