# AI worklog

## 2026-07-26 — Supabase, CI, builds and security hardening

### Scope

Continued the existing Godot 4.7 architecture without redesigning the game.
Worked on the uncommitted `main` working tree and did not commit, push, reset or
delete user source changes.

### Supabase deployment and verification

Target: the maintainer's linked `sudoku-game` project in
Southeast Asia/Singapore. The project reference is intentionally omitted from
the committed worklog.

Deployment:

```sh
supabase login
supabase link --project-ref <project-ref>
supabase db query --linked \
  --file backend/supabase/migrations/006_data_api_scores.sql
```

The Homebrew install of Supabase CLI was blocked because this macOS version
required a newer Xcode than the installed 26.6. The official Supabase CLI
2.109.1 Darwin ARM64 release binary was downloaded to `/private/tmp` and used
instead. No access token or project key was printed into repository files.

Key migration changes:

- final score is calculated in PostgreSQL from raw session metrics;
- anonymous clients have no direct table privileges;
- `submit_score` and `get_leaderboard` are the only client data paths;
- direct score, guard-table and helper-function access is revoked;
- difficulty, duration, mistakes, ranked hints and move count are validated;
- a submission UUID provides idempotent replay;
- each player UUID is limited to ten distinct accepted attempts per minute;
- only a higher score replaces the stored row;
- leaderboard results omit player UUIDs.

Cloud metadata result:

```text
scores columns:
id, player_id, player_name, score, created_at,
difficulty, duration_ms, mistakes, move_count

indexes:
scores_pkey
scores_player_id_key
scores_global_rank (score DESC, created_at, id)

RLS enabled: true
RLS forced: true
anon SELECT/INSERT/UPDATE/DELETE: false/false/false/false
submit_score SECURITY DEFINER: true
get_leaderboard SECURITY DEFINER: true
```

Anonymous live API result:

```text
valid RPC submission                         HTTP 200
idempotent duplicate                        HTTP 200
lower score without overwrite               HTTP 200
higher score overwrite                      HTTP 200
implausible duration rejected               HTTP 400 / 22023
invalid difficulty/hint use/move count      HTTP 400 / 22023
direct insert/update/delete/read rejected    HTTP 401
leaderboard RPC read                        HTTP 200
eleventh distinct one-minute submit          HTTP 400
```

The Godot 4.7.1 `SupabaseClient` then completed a real HTTPS submit, leaderboard
read and direct-write-denial check. Administrator cleanup removed all REST and
Godot QA rows from both `scores` and `score_submission_guards`; final counts for
the test UUIDs were zero.

### Leaderboard security assessment

Improvement achieved: callers can no longer choose the final score or mutate the
table. Plausibility checks, idempotency and per-UUID throttling stop basic
accidental or scripted abuse.

Residual attack paths:

- generate unlimited anonymous UUIDs;
- patch the client and fabricate metrics within accepted ranges;
- wait for the one-minute window and submit again;
- claim a fast but plausible completion without solving the server's puzzle.

The result is suitable for a casual anonymous leaderboard. Strong integrity
still requires authenticated identity and a server-issued single-use challenge
whose final board, expiry and solution are verified by an Edge Function.

### GitHub Actions

Added:

- `.github/workflows/test.yml` caching for the Godot binary;
- `.github/workflows/build.yml` for Android, Linux, Windows, macOS and an
  unsigned iOS Xcode project;
- Godot 4.7.1/export-template caching;
- Java 17 and Android SDK 36 setup;
- 14-day debug build artifacts;
- an explicit `CIUNSIGNED` Team ID used only in the disposable iOS CI runner.

Local YAML validation:

```text
VALID .github/workflows/test.yml
VALID .github/workflows/build.yml
```

The download URLs for the official Godot 4.7.1 Linux binary, macOS Universal
binary and export templates returned successful HTTP responses. GitHub Actions
itself cannot run until the workflow files are committed and pushed. A temporary
checkout with `config/client.env` absent also exported Linux successfully,
confirming CI can produce an offline build without repository secrets.

### Local automated tests

```text
./tests/run_all.sh
85 GDScript assertions, 0 failures
2 Deno tests, 0 failures
3 Edge Function deno check commands passed

tests/ui_smoke_runner.gd
exit 0; menu/generation/input/completion/ranked upload choice/cache UI passed

SUDOKU_STRESS=1 ./tests/run_all.sh
2045 GDScript assertions, 0 failures
2 Deno tests and 3 type checks passed

tests/supabase_live_runner.gd
Godot submit/read/RLS checks passed
```

### Build and platform QA

Output directory: ignored `build/verification-20260726/`.

```text
Android: debug APK exported; ARM64, min SDK 24, target SDK 36,
         package io.github.xkaustin.sudokugame, Internet-only permission,
         APK Signature v2/v3 verified with Godot debug certificate.
iOS:     project-only export initially blocked by empty Team ID.
         Temporary CIUNSIGNED preset produced the Xcode project successfully.
         xcodebuild parsed target/scheme, but no eligible iOS 26.5 destination
         was installed, so compile/install/run was not possible.
macOS:   Universal x86_64+arm64 debug app exported; ad-hoc signature valid;
         exported application binary started successfully.
Windows: x86_64 PE32+ debug EXE/PCK exported; no Windows/Wine runtime available.
Linux:   x86_64 ELF debug executable/PCK exported; no Linux runtime/display
         environment available.
```

There was no connected Android device or emulator. The Android APK could not be
installed, so touch, native file picker and haptic QA remain manual. The Android
resource inspection emitted a non-fatal unused `themed_icon` reference warning;
the actual adaptive `icon.xml` contains background, foreground and monochrome
layers and the signed APK remains structurally valid.

### Files changed in this execution

Backend and tests:

- `backend/supabase/migrations/006_data_api_scores.sql`
- `backend/supabase/tests/live_data_api.sh`
- `backend/supabase/tests/verify_data_api_scores.sql`
- `tests/supabase_live_runner.gd`
- `autoload/sync_manager.gd`
- `tests/ui_smoke_runner.gd`

CI and repository hygiene:

- `.github/workflows/build.yml`
- `.github/workflows/test.yml`
- `.gitignore`

Documentation:

- `README.md`
- `SUPABASE.md`
- `BUILD.md`
- `docs/PLATFORMS.md`
- `backend/supabase/README.md`
- `TEST_STRATEGY.md`
- `AI_WORKLOG.md`

Other modified files already existed in the uncommitted working tree before
this continuation and were preserved.

### Remaining human-only work

- Commit and push the working tree, then inspect the first GitHub Actions runs.
- Configure Android private release keystore and build/verify APK or AAB.
- Set the real Apple Team ID, certificates and provisioning profiles; compile,
  archive and install on iPhone/iPad.
- Sign macOS with Developer ID, enable the intended hardened runtime, notarize
  and staple.
- Optionally Authenticode-sign Windows.
- Run the complete interaction checklist on real Windows, Linux X11/Wayland,
  Android, iPhone and iPad.
- Decide whether casual anonymous integrity is sufficient. If not, enable
  authentication and server-verifiable signed challenges before public ranking.

## 2026-07-26 final delivery and security pass

### Completed

- Repeated the linked Supabase read-only inventory immediately before release.
  Both tables, all four indexes, all four functions, grants, forced-RLS state,
  empty policy inventory and empty trigger inventory match migration 006.
- Produced sanitized, versioned delivery packages under `builds/` for Windows,
  macOS, Linux and Android. Added per-platform time, environment, size,
  SHA-256 and signing-status records. The builds deliberately contain no local
  Supabase configuration.
- Confirmed a sanitized iOS Xcode project can be generated, but did not commit
  the large generated project or claim an installable IPA without Apple
  signing.
- Added matching Chinese and English delivery, build, deployment, Supabase and
  security documentation plus independent per-platform build guides.
- Replaced the generic security policy and added
  `SECURITY_CHECK_REPORT.md`.
- Ran a repository-wide source security review and Gitleaks 8.30.1 against Git
  history, the working tree and extracted release packages.
- Pinned every third-party GitHub Action to an immutable commit and verified
  downloaded Godot binaries/templates against the official 4.7.1 SHA-512 list.

### Security fixes

- The optional `submit-score` Edge Function now rejects an offline challenge
  after its signed expiry instead of applying the online grace period.
- Save cleanup removes corrupted temporary and backup variants.
- Every runtime custom-audio loader enforces the 10 MB size limit.
- The live Godot Supabase runner uses a fresh UUID and strict, exact response
  assertions, preventing stale idempotency data from creating a false pass.
- `.gitignore` now covers broader environment, certificate, key, provisioning
  and generated native-project patterns while retaining placeholder examples.

### Final verification

```text
Supabase linked structure check: passed
Fast suite: 85 GDScript assertions, 2 Deno tests, 3 type checks; 0 failures
UI smoke: passed
500-puzzle stress suite: 2045 GDScript assertions; 0 failures
GitHub Actions YAML: both files parsed
Windows/macOS ZIP and Linux tar integrity: passed
Android APK: v2/v3 signature verified with Godot debug certificate
Extracted release Gitleaks scan: 0 findings
Git history Gitleaks scan: 0 findings across 2 commits
Repository security scan: 0 unresolved reportable findings after remediation
```

The final pre-commit continuation also:

- made `tests/run_all.sh` perform a complete headless first import, removing a
  fresh-clone dependency on an existing `.godot` class/resource cache;
- raised CI first-import windows from 5 to 30 iterations so SVG assets finish
  before export;
- verified a sanitized fresh copy with 85 GDScript assertions, 2 Deno tests,
  3 Deno checks and a main-scene startup;
- pinned CI Actions and verified Godot downloads with official SHA-512 values;
- repeated linked Supabase catalog verification, confirmed no deployed Edge
  Functions, and found zero suspected test score rows or orphan guard rows.

### Human-only remainder

- Push the final commit and inspect the first GitHub Actions executions.
- Create and protect private production signing material, then generate Android
  release APK/AAB, Developer ID/notarized macOS, signed iOS archive/IPA and
  optional Authenticode Windows packages.
- Complete install/run/interaction QA on real Windows, Linux, Android and iOS
  devices.
- Confirm Apple privacy declarations against the final distribution choices.
- Choose whether the documented casual anonymous leaderboard limitation is
  acceptable or whether authenticated, server-issued single-use challenges are
  required.

## 2026-07-26 open-source repository positioning

- Reclassified the GitHub default branch as a source repository containing game
  source, assets, tests, Supabase backend source, migrations, documentation,
  export presets and clean-clone CI.
- Removed generated `builds/` packages and build metadata from Git tracking
  without deleting the local files.
- Expanded ignore rules for Godot caches, build/export/release directories,
  dependency directories, environment files, secrets, logs and temporary files.
- Updated root and bilingual documentation so prebuilt downloads are published
  through GitHub Releases or platform stores rather than committed to `main`.
