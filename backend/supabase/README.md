# Supabase backend

This directory is deployable with Supabase CLI 2.x. It deliberately exposes no
direct table writes to anonymous clients. Edge Functions access PostgreSQL using
the server-only service role.

## Local setup

1. Run `supabase start` from the repository root.
2. Apply migrations with `supabase db reset`.
3. Copy `.env.example` to `.env`. Its development pepper matches `seed.sql`.
4. Serve functions with `supabase functions serve --env-file backend/supabase/.env`.
5. Set the public project URL and anon key in `config/app_config.gd` for a mobile
   build.

For production, generate distinct random values of at least 32 bytes for
`CHALLENGE_SIGNING_SECRET` and `SOLUTION_HASH_PEPPER`. Recalculate every seeded
`solution_hash` as lowercase SHA-256 of `solution + pepper`. Secrets belong only
in Supabase Function secrets; do not commit `.env`.

Deploy in this order:

```sh
supabase db push
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

The submit function applies a per-installation rolling submission limit and hard
request-size limit. Production should also enable gateway rate limiting.
