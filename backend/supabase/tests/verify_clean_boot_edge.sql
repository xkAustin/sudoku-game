do $$
declare
  submit_function oid;
begin
  if to_regclass('public.ranked_challenges') is null
      or to_regclass('public.score_submissions') is null
      or to_regclass('public.best_verified_scores') is null
      or to_regclass('public.challenge_leaderboard') is null then
    raise exception 'Edge clean boot did not create its tables and private views';
  end if;

  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'score_submissions'
      and column_name in ('source', 'difficulty', 'puzzle')
    group by table_schema, table_name
    having count(*) = 3
  ) then
    raise exception 'Edge clean boot did not apply the offline-upload migration';
  end if;

  if not exists (
    select 1
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname in ('ranked_challenges', 'score_submissions')
      and c.relrowsecurity
      and c.relforcerowsecurity
    group by n.nspname
    having count(*) = 2
  ) then
    raise exception 'Edge tables must both enable and force RLS';
  end if;

  if has_table_privilege('anon', 'public.ranked_challenges', 'select')
      or has_table_privilege('anon', 'public.score_submissions', 'insert') then
    raise exception 'Edge clean boot exposed a private table to anon';
  end if;

  if not has_table_privilege('service_role', 'public.ranked_challenges', 'select')
      or not has_table_privilege('service_role', 'public.challenge_leaderboard', 'select') then
    raise exception 'Edge clean boot did not grant the required service-role reads';
  end if;

  select p.oid
    into submit_function
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'submit_verified_edge_score';
  if submit_function is null
      or not has_function_privilege('service_role', submit_function, 'execute')
      or has_function_privilege('anon', submit_function, 'execute') then
    raise exception 'Edge atomic-submit RPC grants are incorrect';
  end if;

  if to_regclass('public.score_submission_rate_limit_lookup') is null
      or to_regclass('public.score_best_verified_lookup') is null then
    raise exception 'Edge performance indexes are missing';
  end if;
end;
$$;
