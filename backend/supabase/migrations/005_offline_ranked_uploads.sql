alter table public.score_submissions
  add column if not exists source varchar(16) not null default 'online',
  add column if not exists difficulty smallint,
  add column if not exists puzzle text;

update public.score_submissions s
set
  difficulty = c.difficulty,
  puzzle = c.puzzle
from public.ranked_challenges c
where s.challenge_id = c.id
  and (s.difficulty is null or s.puzzle is null);

alter table public.score_submissions
  alter column difficulty set not null,
  alter column puzzle set not null,
  drop constraint if exists score_submissions_source_check,
  drop constraint if exists score_submissions_difficulty_check,
  drop constraint if exists score_submissions_puzzle_check;

alter table public.score_submissions
  add constraint score_submissions_source_check check (source in ('online', 'offline')),
  add constraint score_submissions_difficulty_check check (difficulty between 1 and 6),
  add constraint score_submissions_puzzle_check check (puzzle ~ '^([0-9]{81}|[0-9A-G]{256})$');

create index if not exists score_source_difficulty_lookup
  on public.score_submissions (source, difficulty, submitted_at desc)
  where verified = true;

comment on column public.score_submissions.source is
  'online for a server-issued challenge, offline for a locally generated ranked puzzle uploaded later.';
