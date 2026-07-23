create extension if not exists pgcrypto;

create table if not exists public.ranked_challenges (
  id uuid primary key default gen_random_uuid(),
  difficulty smallint not null check (difficulty between 1 and 5),
  puzzle char(81) not null check (puzzle ~ '^[0-9]{81}$'),
  solution_hash text not null check (length(solution_hash) = 64),
  puzzle_version integer not null default 1 check (puzzle_version > 0),
  rules_version integer not null default 1 check (rules_version > 0),
  rotation_key text not null,
  active boolean not null default true,
  available_from timestamptz not null,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  constraint ranked_challenge_time_valid check (expires_at > available_from),
  constraint ranked_challenge_rotation_unique unique (difficulty, rotation_key, puzzle_version)
);

create table if not exists public.score_submissions (
  id uuid primary key default gen_random_uuid(),
  idempotency_key uuid unique not null,
  challenge_id uuid not null references public.ranked_challenges(id) on delete restrict,
  installation_id uuid not null,
  display_name varchar(20) not null,
  duration_ms integer not null check (duration_ms between 10000 and 86400000),
  mistakes integer not null check (mistakes between 0 and 999),
  hints_used integer not null check (hints_used = 0),
  final_board char(81) not null check (final_board ~ '^[1-9]{81}$'),
  move_count integer not null check (move_count between 1 and 10000),
  move_digest text,
  client_version varchar(32) not null,
  platform varchar(16) not null check (platform in ('android', 'ios', 'macos', 'windows', 'linux', 'web', 'unknown')),
  completed_at timestamptz,
  submitted_at timestamptz not null default now(),
  verified boolean not null default false,
  rejection_reason text,
  constraint display_name_visible check (display_name = btrim(display_name) and display_name !~ '[[:cntrl:]]')
);

create index if not exists ranked_challenges_active_lookup
  on public.ranked_challenges (difficulty, available_from desc)
  where active = true;
create index if not exists score_challenge_rank
  on public.score_submissions (challenge_id, duration_ms, mistakes, submitted_at)
  where verified = true;
create index if not exists score_installation_lookup
  on public.score_submissions (installation_id, challenge_id, submitted_at desc);

comment on table public.score_submissions is
  'Verified score data. Direct client writes are prohibited; Edge Functions use service role.';
