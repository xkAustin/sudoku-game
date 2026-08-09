do $$
declare
  leaderboard_source text;
begin
  if to_regclass('public.scores') is null
      or to_regclass('public.score_submission_guards') is null then
    raise exception 'Data API clean boot did not create both required tables';
  end if;

  if not exists (
    select 1
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname in ('scores', 'score_submission_guards')
      and c.relrowsecurity
      and c.relforcerowsecurity
    group by n.nspname
    having count(*) = 2
  ) then
    raise exception 'Data API tables must both enable and force RLS';
  end if;

  if has_table_privilege('anon', 'public.scores', 'select')
      or has_table_privilege('anon', 'public.scores', 'insert')
      or has_table_privilege('anon', 'public.score_submission_guards', 'select') then
    raise exception 'Data API clean boot exposed a private table to anon';
  end if;

  if to_regprocedure('public.submit_score(uuid,text,smallint,integer,smallint,smallint,integer,uuid)') is null
      or to_regprocedure('public.get_leaderboard(uuid)') is null then
    raise exception 'Data API clean boot did not create both public RPCs';
  end if;

  if not has_function_privilege(
      'anon',
      'public.submit_score(uuid,text,smallint,integer,smallint,smallint,integer,uuid)',
      'execute'
    ) or not has_function_privilege('anon', 'public.get_leaderboard(uuid)', 'execute') then
    raise exception 'Data API RPC grants are incomplete';
  end if;

  if to_regclass('public.scores_global_rank') is null then
    raise exception 'Data API ranking index is missing';
  end if;

  select p.prosrc
    into leaderboard_source
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'get_leaderboard'
      and pg_get_function_identity_arguments(p.oid) = 'p_player_id uuid';
  if leaderboard_source is null or leaderboard_source not ilike '%own_score as materialized%' then
    raise exception 'Data API performance migration was not applied';
  end if;
end;
$$;
