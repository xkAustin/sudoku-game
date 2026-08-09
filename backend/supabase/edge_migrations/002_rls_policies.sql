-- Optional signed-challenge Edge schema; migration versions are unique in this chain.
alter table public.ranked_challenges enable row level security;
alter table public.ranked_challenges force row level security;
alter table public.score_submissions enable row level security;
alter table public.score_submissions force row level security;

revoke all on public.ranked_challenges from anon, authenticated;
revoke all on public.score_submissions from anon, authenticated;

-- There are intentionally no anon/authenticated policies. Published puzzles and
-- leaderboard rows are exposed only by versioned Edge Functions, which omit secrets.
-- service_role bypasses RLS in the server environment.

grant usage on schema public to anon, authenticated;
