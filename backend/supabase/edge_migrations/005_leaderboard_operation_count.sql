-- Optional signed-challenge Edge schema: include operation counts in view rebuilds.
drop view if exists public.challenge_leaderboard;
drop view if exists public.best_verified_scores;

create view public.best_verified_scores
with (security_invoker = true)
as
select distinct on (s.challenge_id, s.installation_id)
  s.id,
  s.challenge_id,
  s.installation_id,
  s.display_name,
  s.duration_ms,
  s.mistakes,
  s.move_count,
  s.submitted_at
from public.score_submissions s
where s.verified = true
order by s.challenge_id, s.installation_id, s.duration_ms, s.mistakes, s.submitted_at;

create view public.challenge_leaderboard
with (security_invoker = true)
as
select
  b.challenge_id,
  b.installation_id,
  b.display_name,
  b.duration_ms,
  b.mistakes,
  b.move_count,
  b.submitted_at,
  row_number() over (
    partition by b.challenge_id
    order by b.duration_ms, b.mistakes, b.submitted_at
  ) as rank
from public.best_verified_scores b;

revoke all on public.best_verified_scores from anon, authenticated;
revoke all on public.challenge_leaderboard from anon, authenticated;
