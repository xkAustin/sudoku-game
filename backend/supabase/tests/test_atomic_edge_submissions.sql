begin;

do $$
begin
  if not has_schema_privilege('service_role', 'public', 'usage') then
    raise exception 'service_role lacks usage on public schema';
  end if;
  if not has_table_privilege('service_role', 'public.ranked_challenges', 'select') then
    raise exception 'service_role lacks select on ranked_challenges';
  end if;
  if not has_table_privilege('service_role', 'public.score_submissions', 'select') then
    raise exception 'service_role lacks select on score_submissions';
  end if;
  if not has_table_privilege('service_role', 'public.best_verified_scores', 'select') then
    raise exception 'service_role lacks select on best_verified_scores';
  end if;
  if not has_table_privilege('service_role', 'public.challenge_leaderboard', 'select') then
    raise exception 'service_role lacks select on challenge_leaderboard';
  end if;
end;
$$;

do $$
declare
  test_challenge_id uuid := gen_random_uuid();
  test_installation_id uuid := gen_random_uuid();
  first_submission_id uuid := gen_random_uuid();
  submission_id uuid;
  result jsonb;
begin
  insert into public.ranked_challenges (
    id,
    difficulty,
    puzzle,
    solution_hash,
    rotation_key,
    available_from,
    expires_at
  )
  values (
    test_challenge_id,
    1,
    repeat('0', 81),
    repeat('0', 64),
    'atomic-edge-security-test',
    now() - interval '1 minute',
    now() + interval '1 hour'
  );

  for attempt in 1..20 loop
    submission_id := case when attempt = 1 then first_submission_id else gen_random_uuid() end;
    result := public.submit_verified_edge_score(
      submission_id,
      test_challenge_id,
      test_installation_id,
      'Security Test',
      120000,
      0,
      0,
      repeat('1', 81),
      120,
      null,
      'security-test',
      'unknown',
      null,
      'online',
      1::smallint,
      repeat('0', 81)
    );
    if result->>'accepted' <> 'true' or result->>'rate_limited' <> 'false' then
      raise exception 'submission % was unexpectedly rejected: %', attempt, result;
    end if;
  end loop;

  result := public.submit_verified_edge_score(
    gen_random_uuid(),
    test_challenge_id,
    test_installation_id,
    'Security Test',
    120000,
    0,
    0,
    repeat('1', 81),
    120,
    null,
    'security-test',
    'unknown',
    null,
    'online',
    1::smallint,
    repeat('0', 81)
  );
  if result->>'accepted' <> 'false' or result->>'rate_limited' <> 'true' then
    raise exception 'twenty-first submission was not rate limited: %', result;
  end if;

  result := public.submit_verified_edge_score(
    first_submission_id,
    test_challenge_id,
    test_installation_id,
    'Security Test',
    120000,
    0,
    0,
    repeat('1', 81),
    120,
    null,
    'security-test',
    'unknown',
    null,
    'online',
    1::smallint,
    repeat('0', 81)
  );
  if result->>'accepted' <> 'true' or result->>'duplicate' <> 'true' then
    raise exception 'idempotent replay was not preserved after the limit: %', result;
  end if;
end;
$$;

rollback;
