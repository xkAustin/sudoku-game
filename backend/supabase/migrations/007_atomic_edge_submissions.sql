alter table public.ranked_challenges
  drop constraint if exists ranked_challenges_puzzle_check;
alter table public.ranked_challenges
  add constraint ranked_challenges_puzzle_check check (
    (char_length(puzzle) = 81 and puzzle ~ '^[0-9]+$')
    or (char_length(puzzle) = 256 and puzzle ~ '^[0-9A-G]+$')
  );

alter table public.score_submissions
  drop constraint if exists score_submissions_final_board_check,
  drop constraint if exists score_submissions_puzzle_check;
alter table public.score_submissions
  add constraint score_submissions_final_board_check check (
    (char_length(final_board) = 81 and final_board ~ '^[1-9]+$')
    or (char_length(final_board) = 256 and final_board ~ '^[1-9A-G]+$')
  ),
  add constraint score_submissions_puzzle_check check (
    (char_length(puzzle) = 81 and puzzle ~ '^[0-9]+$')
    or (char_length(puzzle) = 256 and puzzle ~ '^[0-9A-G]+$')
  );

create or replace function public.submit_verified_edge_score(
  p_idempotency_key uuid,
  p_challenge_id uuid,
  p_installation_id uuid,
  p_display_name text,
  p_duration_ms integer,
  p_mistakes integer,
  p_hints_used integer,
  p_final_board text,
  p_move_count integer,
  p_move_digest text,
  p_client_version text,
  p_platform text,
  p_completed_at timestamptz,
  p_source text,
  p_difficulty smallint,
  p_puzzle text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  existing_verified boolean;
  inserted_verified boolean;
  recent_count integer;
begin
  if p_idempotency_key is null or p_challenge_id is null or p_installation_id is null then
    raise exception using errcode = '22023', message = 'submission identifiers are required';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_installation_id::text, 0)
  );

  select verified
    into existing_verified
    from public.score_submissions
    where idempotency_key = p_idempotency_key;
  if found then
    return jsonb_build_object(
      'accepted', true,
      'duplicate', true,
      'verified', existing_verified,
      'rate_limited', false
    );
  end if;

  select count(*)::integer
    into recent_count
    from public.score_submissions
    where installation_id = p_installation_id
      and submitted_at >= pg_catalog.now() - interval '1 minute';
  if recent_count >= 20 then
    return jsonb_build_object(
      'accepted', false,
      'duplicate', false,
      'verified', false,
      'rate_limited', true
    );
  end if;

  insert into public.score_submissions (
    idempotency_key,
    challenge_id,
    installation_id,
    display_name,
    duration_ms,
    mistakes,
    hints_used,
    final_board,
    move_count,
    move_digest,
    client_version,
    platform,
    completed_at,
    source,
    difficulty,
    puzzle,
    verified,
    rejection_reason
  )
  values (
    p_idempotency_key,
    p_challenge_id,
    p_installation_id,
    p_display_name,
    p_duration_ms,
    p_mistakes,
    p_hints_used,
    p_final_board,
    p_move_count,
    p_move_digest,
    p_client_version,
    p_platform,
    p_completed_at,
    p_source,
    p_difficulty,
    p_puzzle,
    true,
    null
  )
  on conflict (idempotency_key) do nothing
  returning verified into inserted_verified;

  if not found then
    select verified
      into existing_verified
      from public.score_submissions
      where idempotency_key = p_idempotency_key;
    return jsonb_build_object(
      'accepted', existing_verified is not null,
      'duplicate', true,
      'verified', coalesce(existing_verified, false),
      'rate_limited', false
    );
  end if;

  return jsonb_build_object(
    'accepted', true,
    'duplicate', false,
    'verified', inserted_verified,
    'rate_limited', false
  );
end;
$$;

revoke all on function public.submit_verified_edge_score(
  uuid, uuid, uuid, text, integer, integer, integer, text,
  integer, text, text, text, timestamptz, text, smallint, text
) from public, anon, authenticated;
grant execute on function public.submit_verified_edge_score(
  uuid, uuid, uuid, text, integer, integer, integer, text,
  integer, text, text, text, timestamptz, text, smallint, text
) to service_role;

comment on function public.submit_verified_edge_score(
  uuid, uuid, uuid, text, integer, integer, integer, text,
  integer, text, text, text, timestamptz, text, smallint, text
) is
  'Atomically enforces the optional Edge submission rolling rate limit and inserts a verified score.';
