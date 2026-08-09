create index if not exists score_submission_rate_limit_lookup
  on public.score_submissions (installation_id, submitted_at desc);

create index if not exists score_best_verified_lookup
  on public.score_submissions (
    challenge_id,
    installation_id,
    duration_ms,
    mistakes,
    submitted_at,
    id
  )
  include (display_name, move_count)
  where verified = true;

comment on index public.score_submission_rate_limit_lookup is
  'Supports the optional Edge rolling per-installation submission limit.';
comment on index public.score_best_verified_lookup is
  'Supports selecting each installation best verified score within a challenge.';
