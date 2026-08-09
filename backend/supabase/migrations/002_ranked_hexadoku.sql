alter table public.ranked_challenges
  drop constraint if exists ranked_challenges_difficulty_check,
  drop constraint if exists ranked_challenges_puzzle_check;

alter table public.ranked_challenges
  alter column puzzle type text using btrim(puzzle);

alter table public.ranked_challenges
  add constraint ranked_challenges_difficulty_check check (difficulty between 1 and 6),
  add constraint ranked_challenges_puzzle_check check (
    (char_length(puzzle) = 81 and puzzle ~ '^[0-9]+$')
    or (char_length(puzzle) = 256 and puzzle ~ '^[0-9A-G]+$')
  );

alter table public.score_submissions
  drop constraint if exists score_submissions_final_board_check;

alter table public.score_submissions
  alter column final_board type text using btrim(final_board);

alter table public.score_submissions
  add constraint score_submissions_final_board_check check (
    (char_length(final_board) = 81 and final_board ~ '^[1-9]+$')
    or (char_length(final_board) = 256 and final_board ~ '^[1-9A-G]+$')
  );
