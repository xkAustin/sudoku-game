# Sudoku Game

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
- Light, dark, system and high-contrast themes, 48 px targets and reduced motion.
- Versioned atomic JSON under `user://`, corruption backup, debounced autosave,
  resumable games and a random installation UUID unrelated to hardware identifiers.
- Per-difficulty leaderboard snapshots with the player's own rank, cached challenges,
  a bounded backoff queue and idempotent uploads.
- Supabase migrations, restrictive RLS, views, signed challenges and three Deno
  Edge Functions with server-side score validation.
- Export presets and release guidance for every target platform.

## Architecture and data flow

```text
Control UI / keyboard / touch
		↓
GameService and ranked/leaderboard services
		↓
GameSession, MoveRecord, Sudoku core
		↓
SaveManager (user:// JSON) or NetworkManager (Edge Functions)
		↓
Supabase PostgreSQL behind service-role-only Edge Functions
```

The core under `core/sudoku` has no UI dependency. UI never opens files; it calls
services and autoloads. Network code never changes a board.

Key flows:

1. Local game: choose difficulty → worker generates a full board → clues are removed
   only while solution count remains one → session autosaves.
2. Move: UI sends intent → `GameService` creates one `MoveRecord`, including peer
   note cleanup → UI refreshes and the save is debounced.
3. Ranked game: the client presents fair-play rules and temporarily locks puzzle
   assistance without changing global settings → server returns a signed fixed puzzle
   without its solution → client verifies uniqueness and caches it → completion enters
   the local queue → reconnect triggers bounded retry → server validates and stores it.
4. Server: validate shape/name/timing → idempotency → load challenge → HMAC/rule/time
   checks → validate clues, rows, columns and boxes → peppered solution hash → rate
   limit → verified insert → personal-best response.

## Directory map

```text
autoload/                 state, atomic save, navigation, HTTP and synchronization
config/                   public product/API constants and configuration example
core/models/              session and transactional move model
core/services/            game, challenge and leaderboard application services
core/sudoku/              solver, generator, validator, uniqueness and difficulty
ui/components/            accessible Sudoku cell control
ui/scenes/main/           responsive application and main scene
ui/themes/                theme resource and builder
assets/app_icons/         original SVG application/adaptive icons
backend/supabase/         SQL, seed, Edge Functions and backend tests
tests/                    executable Godot runner and full-suite command
docs/                     platform release instructions
```

## Run locally

1. Install Godot **4.7 Stable**.
2. Open this directory in Godot; SVG icons import automatically.
3. Press F5 or run `godot --path .`.

No network configuration is required. The entry scene is
`res://ui/scenes/main/main.tscn`.

For online development, copy the two public values from
`config/client.env.example` into `config/app_config.gd`. Never put a service-role
key in the client. Follow [the backend guide](backend/supabase/README.md).

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

It exits nonzero on any GDScript, Sudoku, serialization, Deno test or TypeScript
failure. Run the required 100-puzzles-per-difficulty stress pass in CI with:

```sh
SUDOKU_STRESS=1 ./tests/run_all.sh
```

Stress checks legality, solvability, uniqueness, analyzed difficulty and variety.

## Local storage

The app uses `profile.json`, `settings.json`, `active_games.json`,
`statistics.json`, `installation.json`, `cached_challenges.json`,
`leaderboard_cache.json` and `pending_submissions.json` under `user://`. Writes go
to a temporary file, flush, rotate the previous file to `.bak`, then atomically
rename. Invalid JSON is renamed `.corrupt-TIMESTAMP` and defaults are restored.

Documents are versioned independently; missing fields receive safe defaults or are
migrated when the app starts.

## Export

Install Godot 4.7 export templates, keep signing material in local/CI secrets, and
use `export_presets.cfg`. See the complete [build guide](BUILD.md) and
[platform status](docs/PLATFORMS.md) for Android ARM64, iOS/Xcode, macOS
Universal, Windows x86_64 and Linux X11/Wayland.

## Security and known limits

RLS denies anonymous/authenticated table and view access. Only service-role Edge
Functions can read unpublished challenges or write scores. Challenge responses omit
the answer and `solution_hash`. Server inputs are rebuilt and checked; errors have a
stable structure without stack traces. Never log secrets or complete tokens.

Offline completion data resides on a player-controlled device and can be modified
by an advanced attacker. Signed challenges, final-board validation, plausibility
checks, rate limits and idempotency are baseline anti-cheat—not bank-grade or
esports-grade security.

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
