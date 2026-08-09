# Test strategy

## Goals

The test suite protects the offline Sudoku core, persistent state, responsive UI,
ranked rules, optional Supabase boundary and cross-platform exportability. A
passing shared test is not reported as target-device QA; signing, native file
pickers, haptics and operating-system integration require the actual platform.

## Automated local tests

### Fast suite

```sh
./tests/run_all.sh
```

This runs:

- a headless Godot editor import, allowing a fresh clone to build its global
  class/resource cache before the scripted assertions;
- `tests/test_runner.gd`: solver, validator, generation samples, unique solutions,
  session serialization, save recovery, background timing, idle-work scheduling,
  synchronization retry, unchanged-cell repaint suppression, responsive layout,
  16×16 and leaderboard transformation/scoring tests;
- `tests/ui_smoke_runner.gd`: the complete responsive UI and ranked-flow smoke pass;
- `deno test backend/supabase/tests`: server Sudoku validation tests;
- `deno check` for all three optional Edge Functions.

Current result on 2026-08-09: 107 GDScript assertions, 6 Deno tests and 3 Deno
type checks passed with zero failures.

### Generator stress suite

```sh
SUDOKU_STRESS=1 ./tests/run_all.sh
```

For each of the five 9×9 difficulties it generates 100 puzzles and checks board
legality, solvability, exactly one solution, analyzed difficulty and sample
variety. The fixed 16×16 checks also run.

Current result on 2026-07-26: 2045 GDScript assertions, zero failures; 2 Deno
tests and all 3 type checks also passed.

### Shared UI flow

This flow runs as part of `./tests/run_all.sh`. To execute it independently:

```sh
godot --headless --path . \
  --log-file /tmp/sudoku-ui-smoke.log \
  --script tests/ui_smoke_runner.gd
```

Coverage includes wide and narrow layouts, main menu, difficulty selection,
puzzle generation path, number input, notes, undo/redo, pause, mistake warnings,
completion, ranked upload choice, secure RPC payload shape, settings, local
statistics and cached leaderboard display.

Current result on 2026-08-09: passed with exit code 0.

## Supabase security and integration

These tests require the ignored `config/client.env` and must use a non-production
test UUID.

### Read-only deployed schema inspection

```sh
supabase db query --linked \
  --file backend/supabase/tests/verify_data_api_scores.sql \
  --output table
```

It reports table columns, indexes, forced-RLS flags, anonymous table privileges,
RPC signatures, `SECURITY DEFINER` state and client function grants as one JSON
record.

### Anonymous REST/RLS flow

```sh
./backend/supabase/tests/live_data_api.sh
```

Assertions:

- valid raw-metric RPC submission succeeds;
- replay of the same submission UUID is idempotent;
- a lower score does not overwrite and a higher score does;
- invalid difficulty, implausible duration, ranked hint use and implausible move
  count are rejected;
- direct table select/insert/update/delete are rejected;
- leaderboard RPC returns Top 100 and the caller's rank without player UUIDs;
- the eleventh distinct submission in one minute is rejected.

### Godot HTTPS flow

```sh
godot --headless --path . \
  --log-file /tmp/sudoku-supabase-live.log \
  --script tests/supabase_live_runner.gd
```

This uses the same `SupabaseClient` autoload shipped in the game and checks
submit, leaderboard read and direct-write denial.

Both live tests generate and print a fresh `SUPABASE_TEST_PLAYER_ID`. The Godot
runner now requires the exact server-calculated score, `updated == true` and
`duplicate == false`, so an old idempotency response cannot produce a false
pass. An administrator must delete each printed test UUID from
`score_submission_guards` and `scores`. The 2026-07-26 verification did so and
confirmed zero residual QA rows.

## Build verification

The local verification output is ignored under
`build/verification-20260726/`.

| Platform | Export check | Runtime check on this host |
|---|---|---|
| Android ARM64 | Debug APK passed; v2/v3 signature, package ID, SDK levels and Internet-only permission inspected | Not run; no ADB device or emulator attached |
| iOS | Unsigned Xcode project generated; project, target and scheme parsed | Not compiled or run; installed Xcode selected iOS SDK 26.5 but no matching eligible destination |
| macOS Universal | Debug app exported; x86_64/arm64 and ad-hoc signature verified | Exported binary started and loaded without script/parse errors |
| Windows x86_64 | Debug EXE/PCK exported; PE32+ structure verified | Not run; no Windows or Wine environment |
| Linux x86_64 | Debug ELF/PCK exported; ELF structure verified | Not run; no Linux VM/container display environment |

Shared UI and live Supabase checks cover application logic across all exports,
but they do not convert the three “not run” rows into runtime passes.

## Continuous integration

`.github/workflows/test.yml` runs fast tests for pushes and pull requests, and
the stress suite on `main`, manual dispatch and weekly schedule.

`.github/workflows/build.yml` caches Godot and export templates and builds
Android, Linux, Windows, macOS and an unsigned iOS Xcode project. Artifacts are
kept for 14 days. Release signing is intentionally excluded. All third-party
Actions are pinned to immutable commits, and downloaded Godot archives are
verified with the official 4.7.1 SHA-512 values before execution.

The workflow YAML files pass local actionlint validation. On 2026-07-26 the
clean-clone GitHub runs passed the fast suite, 500-puzzle stress pass and all
five platform export jobs. CI creates its own ignored `build/ci/` directories
and does not depend on committed build outputs.

## Required manual release QA

For every target platform, repeat startup, menu, generation, input, completion,
score submission and leaderboard viewing on the actual deliverable. Also verify:

- safe areas, rotation/resize and 90/100/110 percent interface scale;
- native audio file selection and MP3/WAV/OGG playback;
- suspend/resume timing and save recovery;
- system haptics on Android/iOS;
- keyboard shortcuts and 125–200 percent DPI on desktop;
- offline cache and reconnect queue behavior;
- production signing, installation, upgrade and store packaging.

Android release keys, Apple Team ID/certificates/profiles, Developer ID
notarization and optional Windows Authenticode must never be committed.
