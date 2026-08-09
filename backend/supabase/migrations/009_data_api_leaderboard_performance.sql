create or replace function public.get_leaderboard(
  p_player_id uuid default null
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with top_rows as (
    select
      row_number() over (order by score desc, created_at asc, id asc)::bigint as rank,
      player_name as display_name,
      score,
      created_at as submitted_at
    from public.scores
    order by score desc, created_at asc, id asc
    limit 100
  ),
  own_score as materialized (
    select id, player_name, score, created_at
    from public.scores
    where player_id = p_player_id
  ),
  self_row as (
    select
      (
        select count(*) + 1
        from public.scores higher
        where higher.score > own_score.score
          or (
            higher.score = own_score.score
            and (
              higher.created_at < own_score.created_at
              or (higher.created_at = own_score.created_at and higher.id < own_score.id)
            )
          )
      )::bigint as rank,
      own_score.player_name as display_name,
      own_score.score,
      own_score.created_at as submitted_at
    from own_score
  )
  select jsonb_build_object(
    'entries', coalesce(
      (select jsonb_agg(to_jsonb(top_rows) order by rank) from top_rows),
      '[]'::jsonb
    ),
    'self_entry', coalesce(
      (select to_jsonb(self_row) from self_row),
      '{}'::jsonb
    )
  );
$$;

revoke all on function public.get_leaderboard(uuid) from public;
grant execute on function public.get_leaderboard(uuid) to anon, authenticated;

comment on function public.get_leaderboard(uuid) is
  'Returns the indexed global Top 100 plus the requested anonymous player position without materializing the complete ranked table.';
