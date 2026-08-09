grant usage on schema public to service_role;

grant select on table
  public.ranked_challenges,
  public.score_submissions,
  public.best_verified_scores,
  public.challenge_leaderboard
to service_role;

comment on table public.ranked_challenges is
  'Ranked challenge data. Direct clients have no access; optional Edge Functions read it with service_role.';
