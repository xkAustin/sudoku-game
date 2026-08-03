# Development Mode Guide

Godot Editor runs and debug exports start at `res://debug/DebugMain.tscn`. The
launcher reuses the production main scene, `GameService`, `AppState`, storage
and leaderboard services, so it exercises real game flows without first
exporting an Android, iOS, macOS or Windows application.

## Launch and shortcuts

Press F5 after opening the project in Godot Editor, or run:

```sh
godot --path .
```

The launcher opens the main game, settings, leaderboard, a test board or the
test tools directly. Development startup arguments are also available:

```sh
godot --path . -- --dev-start=settings
godot --path . -- --dev-start=leaderboard
godot --path . -- --dev-start=game --dev-difficulty=3
godot --path . -- --dev-start=tools
```

`--dev-difficulty` accepts `0` through `5`. Press `F12` while running to show or
hide the independent Debug panel.

## Debug panel

The panel reports FPS, current scene/view, game state, static memory and object
count. It can:

- create test boards at all six difficulty levels;
- complete the current game quickly;
- trigger the real victory and three-mistake ranked failure flows;
- reset the current and all unfinished games;
- generate mock player statistics and leaderboard cache data;
- test the production leaderboard service and its cache fallback;
- reinstantiate the current UI while preserving in-memory state;
- reload development configuration immediately; and
- clear local saves, settings, caches and fixtures after a second confirmation.

The leaderboard probe respects the production network-consent setting. Without
consent it verifies cache fallback and does not bypass the privacy setting.

## Restart-free tuning and hot reload

Development parameters are grouped in `debug/development_config.json`. A debug
run checks the file every 0.75 seconds and applies these values without restart:

- `default_difficulty`: default test difficulty;
- `test_seed`: deterministic board seed;
- `test_elapsed_ms` and `test_mistakes`: initial test-session state;
- `mock_player_count`: number of mock leaderboard entries;
- `panel_refresh_seconds`: panel update interval; and
- `log_output`: development logging switch.

`DevelopmentConfig` and `DevelopmentDebugManager` also expose scene-level
defaults with `@export` for temporary Inspector tuning. Prefer Godot hot reload
for ordinary GDScript method bodies, style resources and data configuration.
After editing programmatic UI construction, use **Reload current UI** to rebuild
the interface without clearing in-memory game and setting state.

Restart the running project after changing class names, autoloads,
`project.godot`, input actions or scene node structure. Platform permissions,
signing, native plugins, export filters and package layout still require a new
export and target-platform verification.

## Release isolation

`AppConfig.DEBUG` comes from `OS.is_debug_build()`. The `run/main_scene.debug`
project override selects `DebugMain.tscn` only for Editor and debug builds; the
base release entry remains `res://ui/scenes/main/main.tscn`. Development Mode
also requires the absence of `--no-development-mode`, so release builds do not
create the launcher or Debug panel and produce no development logs.

Exercise the production startup path from a debug build with:

```sh
godot --path . -- --no-development-mode
```

## Validation

```sh
./tests/run_all.sh
godot --headless --path . \
  --log-file /tmp/sudoku-ui-smoke.log \
  --script tests/ui_smoke_runner.gd
```

`run_all.sh` includes `tests/debug_smoke_runner.gd`, which covers the launcher,
settings/leaderboard shortcuts, 9x9 and 16x16 test sessions, and mock
leaderboard structure.
