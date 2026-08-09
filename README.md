# Sudoku Game

Documentation: [中文](docs/zh-CN/README.md) ·
[English](docs/en-US/README.md)

This is the public open-source repository. It contains the game source, assets,
tests, Supabase backend source, migrations, documentation, export presets and
reproducible CI workflows. Generated applications and installers are not
tracked on the default branch.

- **Download a prebuilt version:** use
  [GitHub Releases](https://github.com/xkAustin/sudoku-game/releases) when a
  maintainer has published one.
- **Build from source:** follow the bilingual build guides, optionally add an
  ignored publishable Supabase client configuration, then export with Godot.

A complete offline-first Sudoku game for Godot 4.7 Stable. It targets Android,
iOS, macOS, Windows and Linux without accounts, advertising, tracking SDKs or
unrelated permissions. Network access is optional and used only for signed ranked
challenges, score synchronization and leaderboards.

## Included

- Six local and ranked difficulty choices, including a 16×16 Ultimate board.
- A UI-independent core with validation, MRV backtracking, solution counting capped
  at two, uniqueness checks and weighted logic/search difficulty analysis.
- Touch, mouse and keyboard play; notes, transactional cleanup, undo/redo, hints,
  conflicts, timer, pause, completion flow, settings and statistics.
- Light, dark, system and high-contrast themes, interface scaling, 48 px targets
  and reduced motion.
- Versioned atomic JSON under `user://`, main/temporary/backup recovery, debounced
  autosave, resumable games and a random installation UUID unrelated to hardware
  identifiers.
- A global Top 100 leaderboard with the player's own rank, offline snapshots,
  a bounded retry queue and highest-score-only uploads.
- A Supabase Data API client, restrictive RLS, an atomic score RPC, plus optional
  signed-challenge Edge Functions for future server-verified ranked play.
- Export presets and release guidance for every target platform.

## Architecture and data flow

```text
Control UI / keyboard / touch
		↓
GameService and ranked/leaderboard services
		↓
GameSession, MoveRecord, Sudoku core
		↓
SaveManager (user:// JSON), SupabaseClient (Data API) or NetworkManager (optional Edge Functions)
		↓
Supabase PostgreSQL (restricted Data API RPC) or optional service-role Edge Functions
```

The core under `core/sudoku` has no UI dependency. UI never opens files; it calls
services and autoloads. Network code never changes a board.

Key flows:

1. Local game: choose difficulty → worker generates a full board → clues are removed
   only while solution count remains one → session autosaves.
2. Move: UI sends intent → `GameService` creates one `MoveRecord`, including peer
   note cleanup → UI refreshes and the save is debounced.
3. Ranked game: the client presents fair-play rules and temporarily locks puzzle
   assistance without changing global settings → it uses a server challenge when
   available or generates an offline puzzle → completion enters the local queue.
4. Leaderboard: reconnect sends the completed session's raw metrics and an
   idempotency UUID → a restricted database function validates the metrics,
   rate-limits the installation and calculates the score server-side →
   PostgreSQL atomically keeps only the installation's higher score → the global
   Top 100 is cached for offline use.

The Data API leaderboard is the supported online path. The signed-challenge Edge
Functions are retained as optional future infrastructure and are not required for
the global leaderboard.

## Directory map

```text
autoload/                 state, atomic save, navigation, HTTP and synchronization
config/                   public product/API constants and configuration example
debug/                    Editor launcher, runtime panel, fixtures and live config
core/models/              session and transactional move model
core/services/            game, challenge and leaderboard application services
core/sudoku/              solver, generator, validator, uniqueness and difficulty
scripts/                  isolated Supabase Data API and leaderboard modules
ui/components/            accessible Sudoku cell control
ui/scenes/main/           responsive application and main scene
ui/themes/                theme resource and builder
assets/app_icons/         original SVG application/adaptive icons
backend/supabase/         SQL, seed, Edge Functions and backend tests
tests/                    executable Godot runner and full-suite command
docs/                     bilingual build, deployment and security instructions
.github/workflows/        clean-clone tests and reproducible debug exports
export_presets.cfg        Android, iOS, macOS, Windows and Linux presets
```

## Environment and local run

Required for normal development:

- Godot **4.7.1 Stable** with matching export templates.
- Deno 2.x for backend validation and TypeScript checks.

Additional release tools are platform-specific: OpenJDK 17 and Android SDK 36
for Android; Xcode and the iOS SDK for Apple exports; Supabase CLI 2.x only when
deploying or inspecting the backend.

1. Install Godot 4.7.1 Stable.
2. Open this directory in Godot; SVG icons import automatically.
3. Press F5 or run `godot --path .`.

No network configuration is required. Debug runs start at
`res://debug/DebugMain.tscn`, which provides direct game/settings/leaderboard
entry points and an `F12` runtime panel. Release exports automatically bypass
the development UI and load `res://ui/scenes/main/main.tscn`. See
[Development Mode](DEVELOPMENT.md) for hot reload, runtime configuration and
startup arguments.

For online development, copy `config/client.env.example` to the ignored
`config/client.env` and provide the project Data API URL and publishable key.
Never put a secret or service-role key in the client. Follow
[the Supabase leaderboard guide](SUPABASE.md).

Product name, package ID, app version and API version are grouped in
`config/app_config.gd`; mirror identity changes into `project.godot` and
`export_presets.cfg`, whose exporters require literals. Icons are under
`assets/app_icons`.

The release package identifier is `io.github.xkaustin.sudokugame`.

## Controls

| Action | Keyboard |
|---|---|
| Digit | 1–9 |
| Delete | Backspace / Delete |
| Notes | N |
| Undo / redo | Ctrl/Cmd + Z / Ctrl/Cmd + Shift + Z |
| Select | Arrow keys |
| Pause | Esc |

Every action is also visible; no required action depends on hover.

## Tests

Run the fast suite:

```sh
./tests/run_all.sh
```

The script performs the required headless Godot import first, so it also works
in a fresh clone with no `.godot` cache. It exits nonzero on any GDScript,
Sudoku, serialization, debug smoke, shared UI smoke, Deno test or TypeScript
failure. GitHub Actions runs this complete fast suite on each push and pull request. Run the
100-puzzles-per-difficulty stress pass locally with:

```sh
SUDOKU_STRESS=1 ./tests/run_all.sh
```

Stress checks legality, solvability, uniqueness, analyzed difficulty and variety.
The shared UI flow is part of the fast suite. To run it independently, use:

```sh
godot --headless --path . \
  --log-file /tmp/sudoku-ui-smoke.log \
  --script tests/ui_smoke_runner.gd
```

With an ignored `config/client.env` configured for a test project, the optional
Godot HTTPS check is:

```sh
godot --headless --path . --script tests/supabase_live_runner.gd
```

The repository also contains a repeatable anonymous REST/RLS check at
`backend/supabase/tests/live_data_api.sh`. Both live checks create a temporary
leaderboard row which a project administrator must delete afterward. See
[`TEST_STRATEGY.md`](TEST_STRATEGY.md) for scope and cleanup.

GitHub Actions runs the fast and scheduled stress suites. A separate build
workflow exports Android debug, Linux debug, Windows debug, macOS debug and an
unsigned iOS Xcode project, caching the matching Godot binary and export
templates. Third-party Actions are pinned to immutable commits, and Godot
archives are checked against the official 4.7.1 SHA-512 values before use.

## Local storage

The app uses `profile.json`, `settings.json`, `active_games.json`,
`statistics.json`, `installation.json`, `cached_challenges.json`,
`leaderboard_cache.json` and `pending_submissions.json` under `user://`. Writes go
to a temporary file, flush, rotate the previous file to `.bak`, then atomically
rename. Reads try the main file, `.tmp`, then `.bak`; a valid recovery candidate
is promoted to a new main file. Invalid JSON is renamed `.corrupt-TIMESTAMP`.

Documents are versioned independently; missing fields receive safe defaults or are
migrated when the app starts. Reset Local Data removes progress, statistics,
settings, caches, pending/dead-letter uploads and imported audio while deliberately
preserving only the random installation UUID.

## Export

Install Godot 4.7 export templates, keep signing material in local/CI secrets, and
use `export_presets.cfg`. See the complete [build guide](BUILD.md) and
[platform status](docs/PLATFORMS.md) for Android ARM64, iOS/Xcode, macOS
Universal, Windows x86_64 and Linux X11/Wayland.

Platform-specific bilingual instructions are under
[`docs/zh-CN/build/`](docs/zh-CN/build/) and
[`docs/en-US/build/`](docs/en-US/build/).

On 2026-07-26 the clean-clone CI successfully produced Android, Linux, Windows
and macOS debug artifacts plus an unsigned iOS Xcode project. CI artifacts are
temporary, local outputs remain under ignored build directories, and prebuilt
public downloads belong in GitHub Releases rather than the default branch.
Target-device QA and production signing remain separate requirements.

## Security and known limits

RLS is enabled and forced on the score and submission-guard tables. Anonymous
clients have no direct `SELECT`, `INSERT`, `UPDATE` or `DELETE` privilege.
`get_leaderboard` is the only public read path and `submit_score` is the only
public mutation path. The submit RPC validates difficulty, plausible duration,
mistakes, ranked hint use and move count, deduplicates a submission UUID,
limits each installation UUID to ten accepted submissions per minute, calculates
the final score server-side and atomically keeps only improvements. The client
uses only a publishable key.

The migration and these API properties were deployed and verified against the
maintainer's Supabase project on 2026-07-26. A different project must apply and
verify the same migration independently; exact commands are in `SUPABASE.md`.
The final secret, history, permission and repository scan record is in
[`SECURITY_CHECK_REPORT.md`](SECURITY_CHECK_REPORT.md).

Offline completion data and the anonymous UUID reside on a player-controlled
device and can be modified by an advanced attacker. An attacker can still select
a fresh UUID, fabricate metrics that fall inside the accepted ranges, replay
requests after the rate-limit window, or patch the client. The server-side
calculation prevents arbitrary final-score writes but does not prove that a real
puzzle was solved. The public Data API leaderboard is therefore appropriate for
casual competition, not esports-grade anti-cheat. Stronger guarantees require
authenticated players and server-issued, server-verifiable challenges.

The analyzer implements naked/hidden singles and combines candidate complexity,
search nodes and backtrack depth into stable bands. It does not produce a human
proof for every named advanced technique such as X-Wing. Uniqueness remains an
independent hard validation and classification never uses clue count alone.

The repository uses original code-only SVG icons and no bundled third-party fonts,
music or artwork. Default input sound is synthesized in memory. Players can import
an MP3, WAV or OGG button sound (up to 10 MB), which is copied into app-local storage.
Android feedback uses the system haptic-feedback API without override flags, while
iOS requests the device-default strength; feedback remains subject to the platform's
global haptic setting and the in-app mobile-only switch.

## License

MIT. See [LICENSE](LICENSE).
