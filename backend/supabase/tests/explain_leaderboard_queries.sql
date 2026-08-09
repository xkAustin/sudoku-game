-- Read-only production context plus a representative before/after benchmark
-- for the supported Data API leaderboard. All benchmark rows and helper
-- functions live in pg_temp and disappear when this query session ends.
-- Run before applying migration 009:
--   supabase db query --linked \
--     --file backend/supabase/tests/explain_leaderboard_queries.sql \
--     --output json

create or replace function pg_temp.explain_json(statement text)
returns jsonb
language plpgsql
as $$
declare
  plan jsonb;
begin
  execute 'explain (analyze, buffers, format json) ' || statement into plan;
  return plan;
end;
$$;

create or replace function pg_temp.plan_metrics(plan jsonb)
returns jsonb
language sql
immutable
strict
as $$
  select jsonb_build_object(
    'planning_time_ms', (plan #>> '{0,Planning Time}')::numeric,
    'execution_time_ms', (plan #>> '{0,Execution Time}')::numeric,
    'total_cost', (plan #>> '{0,Plan,Total Cost}')::numeric,
    'shared_hit_blocks', (plan #>> '{0,Plan,Shared Hit Blocks}')::integer,
    'shared_read_blocks', (plan #>> '{0,Plan,Shared Read Blocks}')::integer,
    'temp_written_blocks', (plan #>> '{0,Plan,Temp Written Blocks}')::integer,
    'node_types', jsonb_path_query_array(plan, '$[0].Plan.**."Node Type"'),
    'index_names', jsonb_path_query_array(plan, '$[0].Plan.**."Index Name"')
  );
$$;

create temporary table benchmark_scores (
  id bigint primary key,
  player_id uuid not null unique,
  player_name varchar(20) not null,
  score bigint not null,
  created_at timestamptz not null
);

create index benchmark_scores_global_rank
  on benchmark_scores (score desc, created_at asc, id asc);

insert into benchmark_scores (id, player_id, player_name, score, created_at)
select
  value,
  md5('leaderboard-player-' || value)::uuid,
  'Player ' || value,
  20000000 - value,
  timestamptz '2026-01-01 00:00:00+00' + value * interval '1 millisecond'
from generate_series(1, 20000) value;

analyze benchmark_scores;

with plans as (
  select
    pg_temp.explain_json($query$
      with target as materialized (
        select player_id
        from pg_temp.benchmark_scores
        order by score asc, created_at desc, id desc
        limit 1
      ),
      ranked as materialized (
        select
          rank() over (order by score desc, created_at asc, id asc)::bigint as rank,
          player_id,
          player_name as display_name,
          score,
          created_at as submitted_at
        from pg_temp.benchmark_scores
      ),
      top_rows as (
        select rank, display_name, score, submitted_at
        from ranked
        where rank <= 100
        order by rank
      ),
      self_row as (
        select rank, display_name, score, submitted_at
        from ranked
        where player_id = (select player_id from target)
        limit 1
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
      )
    $query$) as baseline_worst,
    pg_temp.explain_json($query$
      with target as materialized (
        select player_id
        from pg_temp.benchmark_scores
        order by score asc, created_at desc, id desc
        limit 1
      ),
      top_rows as (
        select
          row_number() over (order by score desc, created_at asc, id asc)::bigint as rank,
          player_name as display_name,
          score,
          created_at as submitted_at
        from pg_temp.benchmark_scores
        order by score desc, created_at asc, id asc
        limit 100
      ),
      own_score as materialized (
        select id, player_name, score, created_at
        from pg_temp.benchmark_scores
        where player_id = (select player_id from target)
      ),
      self_row as (
        select
          (
            select count(*) + 1
            from pg_temp.benchmark_scores higher
            where higher.score > own_score.score
              or (
                higher.score = own_score.score
                and (
                  higher.created_at < own_score.created_at
                  or (
                    higher.created_at = own_score.created_at
                    and higher.id < own_score.id
                  )
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
      )
    $query$) as candidate_worst,
    pg_temp.explain_json($query$
      with target as materialized (
        select player_id
        from pg_temp.benchmark_scores
        order by score desc, created_at asc, id asc
        limit 1
      ),
      ranked as materialized (
        select
          rank() over (order by score desc, created_at asc, id asc)::bigint as rank,
          player_id,
          player_name as display_name,
          score,
          created_at as submitted_at
        from pg_temp.benchmark_scores
      ),
      top_rows as (
        select rank, display_name, score, submitted_at
        from ranked
        where rank <= 100
        order by rank
      ),
      self_row as (
        select rank, display_name, score, submitted_at
        from ranked
        where player_id = (select player_id from target)
        limit 1
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
      )
    $query$) as baseline_best,
    pg_temp.explain_json($query$
      with target as materialized (
        select player_id
        from pg_temp.benchmark_scores
        order by score desc, created_at asc, id asc
        limit 1
      ),
      top_rows as (
        select
          row_number() over (order by score desc, created_at asc, id asc)::bigint as rank,
          player_name as display_name,
          score,
          created_at as submitted_at
        from pg_temp.benchmark_scores
        order by score desc, created_at asc, id asc
        limit 100
      ),
      own_score as materialized (
        select id, player_name, score, created_at
        from pg_temp.benchmark_scores
        where player_id = (select player_id from target)
      ),
      self_row as (
        select
          (
            select count(*) + 1
            from pg_temp.benchmark_scores higher
            where higher.score > own_score.score
              or (
                higher.score = own_score.score
                and (
                  higher.created_at < own_score.created_at
                  or (
                    higher.created_at = own_score.created_at
                    and higher.id < own_score.id
                  )
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
      )
    $query$) as candidate_best
), metrics as (
  select
    pg_temp.plan_metrics(baseline_worst) as baseline_worst,
    pg_temp.plan_metrics(candidate_worst) as candidate_worst,
    pg_temp.plan_metrics(baseline_best) as baseline_best,
    pg_temp.plan_metrics(candidate_best) as candidate_best
  from plans
)
select jsonb_build_object(
  'production_rows', (select count(*) from public.scores),
  'synthetic_rows', (select count(*) from benchmark_scores),
  'worst_ranked_player', jsonb_build_object(
    'baseline', baseline_worst,
    'candidate', candidate_worst,
    'execution_speedup', round(
      (baseline_worst->>'execution_time_ms')::numeric
      / nullif((candidate_worst->>'execution_time_ms')::numeric, 0),
      2
    )
  ),
  'best_ranked_player', jsonb_build_object(
    'baseline', baseline_best,
    'candidate', candidate_best,
    'execution_speedup', round(
      (baseline_best->>'execution_time_ms')::numeric
      / nullif((candidate_best->>'execution_time_ms')::numeric, 0),
      2
    )
  )
) as leaderboard_benchmark
from metrics;
