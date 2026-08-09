-- Read-only production context plus a representative before/after benchmark
-- for the optional Edge query indexes. All benchmark rows, indexes and helper
-- functions live in pg_temp and disappear when this query session ends.
-- Run before applying migration 010:
--   supabase db query --linked \
--     --file backend/supabase/tests/explain_edge_queries.sql \
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
    'local_hit_blocks', (plan #>> '{0,Plan,Local Hit Blocks}')::integer,
    'local_read_blocks', (plan #>> '{0,Plan,Local Read Blocks}')::integer,
    'temp_written_blocks', (plan #>> '{0,Plan,Temp Written Blocks}')::integer,
    'node_types', jsonb_path_query_array(plan, '$[0].Plan.**."Node Type"'),
    'index_names', jsonb_path_query_array(plan, '$[0].Plan.**."Index Name"')
  );
$$;

create temporary table benchmark_score_submissions (
  id uuid primary key,
  challenge_id uuid not null,
  installation_id uuid not null,
  display_name varchar(20) not null,
  duration_ms integer not null,
  mistakes integer not null,
  move_count integer not null,
  submitted_at timestamptz not null,
  verified boolean not null
);

-- Existing migration 001 indexes provide the baseline.
create index benchmark_score_challenge_rank
  on benchmark_score_submissions (
    challenge_id,
    duration_ms,
    mistakes,
    submitted_at
  )
  where verified = true;

create index benchmark_score_installation_lookup
  on benchmark_score_submissions (
    installation_id,
    challenge_id,
    submitted_at desc
  );

insert into benchmark_score_submissions (
  id,
  challenge_id,
  installation_id,
  display_name,
  duration_ms,
  mistakes,
  move_count,
  submitted_at,
  verified
)
select
  md5('edge-submission-' || value)::uuid,
  md5('edge-challenge-' || ((value / 100) % 10))::uuid,
  md5('edge-installation-' || (value % 100))::uuid,
  'Player ' || (value % 100),
  60000 + (value % 300000),
  value % 5,
  80 + (value % 200),
  timestamptz '2026-01-01 00:00:00+00' + value * interval '1 second',
  value % 17 <> 0
from generate_series(1, 50000) value;

analyze benchmark_score_submissions;

create temporary table benchmark_edge_plans (
  label text primary key,
  plan jsonb not null
);

insert into benchmark_edge_plans (label, plan)
values
  (
    'rate_limit_before',
    pg_temp.explain_json($query$
      select count(*)
      from pg_temp.benchmark_score_submissions
      where installation_id = md5('edge-installation-99')::uuid
        and submitted_at >= timestamptz '2026-01-01 13:52:20+00'
    $query$)
  ),
  (
    'leaderboard_before',
    pg_temp.explain_json($query$
      with best_verified_scores as (
        select distinct on (challenge_id, installation_id)
          id,
          challenge_id,
          installation_id,
          display_name,
          duration_ms,
          mistakes,
          move_count,
          submitted_at
        from pg_temp.benchmark_score_submissions
        where verified = true
        order by
          challenge_id,
          installation_id,
          duration_ms,
          mistakes,
          submitted_at
      ), challenge_leaderboard as (
        select
          challenge_id,
          installation_id,
          display_name,
          duration_ms,
          mistakes,
          move_count,
          submitted_at,
          row_number() over (
            partition by challenge_id
            order by duration_ms, mistakes, submitted_at
          ) as rank
        from best_verified_scores
      )
      select rank, display_name, duration_ms, mistakes, move_count, submitted_at
      from challenge_leaderboard
      where challenge_id = md5('edge-challenge-1')::uuid
      order by rank
      limit 100
    $query$)
  );

-- Migration 010 candidate indexes.
create index benchmark_rate_limit_lookup
  on benchmark_score_submissions (installation_id, submitted_at desc);

create index benchmark_best_verified_lookup
  on benchmark_score_submissions (
    challenge_id,
    installation_id,
    duration_ms,
    mistakes,
    submitted_at,
    id
  )
  include (display_name, move_count)
  where verified = true;

analyze benchmark_score_submissions;

insert into benchmark_edge_plans (label, plan)
values
  (
    'rate_limit_after',
    pg_temp.explain_json($query$
      select count(*)
      from pg_temp.benchmark_score_submissions
      where installation_id = md5('edge-installation-99')::uuid
        and submitted_at >= timestamptz '2026-01-01 13:52:20+00'
    $query$)
  ),
  (
    'leaderboard_after',
    pg_temp.explain_json($query$
      with best_verified_scores as (
        select distinct on (challenge_id, installation_id)
          id,
          challenge_id,
          installation_id,
          display_name,
          duration_ms,
          mistakes,
          move_count,
          submitted_at
        from pg_temp.benchmark_score_submissions
        where verified = true
        order by
          challenge_id,
          installation_id,
          duration_ms,
          mistakes,
          submitted_at
      ), challenge_leaderboard as (
        select
          challenge_id,
          installation_id,
          display_name,
          duration_ms,
          mistakes,
          move_count,
          submitted_at,
          row_number() over (
            partition by challenge_id
            order by duration_ms, mistakes, submitted_at
          ) as rank
        from best_verified_scores
      )
      select rank, display_name, duration_ms, mistakes, move_count, submitted_at
      from challenge_leaderboard
      where challenge_id = md5('edge-challenge-1')::uuid
      order by rank
      limit 100
    $query$)
  );

with metrics as (
  select
    pg_temp.plan_metrics(
      (select plan from benchmark_edge_plans where label = 'rate_limit_before')
    ) as rate_limit_before,
    pg_temp.plan_metrics(
      (select plan from benchmark_edge_plans where label = 'rate_limit_after')
    ) as rate_limit_after,
    pg_temp.plan_metrics(
      (select plan from benchmark_edge_plans where label = 'leaderboard_before')
    ) as leaderboard_before,
    pg_temp.plan_metrics(
      (select plan from benchmark_edge_plans where label = 'leaderboard_after')
    ) as leaderboard_after
)
select jsonb_build_object(
  'production', jsonb_build_object(
    'challenges', (select count(*) from public.ranked_challenges),
    'score_submissions', (select count(*) from public.score_submissions),
    'candidate_indexes_present', (
      select coalesce(jsonb_object_agg(required.index_name, indexes.indexname is not null), '{}'::jsonb)
      from (
        values
          ('score_submission_rate_limit_lookup'),
          ('score_best_verified_lookup')
      ) required(index_name)
      left join pg_indexes indexes
        on indexes.schemaname = 'public'
        and indexes.tablename = 'score_submissions'
        and indexes.indexname = required.index_name
    )
  ),
  'synthetic_rows', (select count(*) from benchmark_score_submissions),
  'rate_limit_query', jsonb_build_object(
    'before', rate_limit_before,
    'after', rate_limit_after,
    'execution_speedup', round(
      (rate_limit_before->>'execution_time_ms')::numeric
      / nullif((rate_limit_after->>'execution_time_ms')::numeric, 0),
      2
    )
  ),
  'leaderboard_query', jsonb_build_object(
    'before', leaderboard_before,
    'after', leaderboard_after,
    'execution_speedup', round(
      (leaderboard_before->>'execution_time_ms')::numeric
      / nullif((leaderboard_after->>'execution_time_ms')::numeric, 0),
      2
    )
  )
) as edge_benchmark
from metrics;
