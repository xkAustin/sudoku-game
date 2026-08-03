# Development Mode

中文：[开发模式指南](docs/zh-CN/DEVELOPMENT_GUIDE.md) ·
English: [Development Mode Guide](docs/en-US/DEVELOPMENT_GUIDE.md)

Godot Editor and debug builds start at `res://debug/DebugMain.tscn`. This
launcher opens the existing main game, settings and leaderboard UI, or creates a
deterministic test board without exporting an application. Press `F12` to show
or hide the independent runtime Debug panel.

Run the default launcher:

```sh
godot --path .
```

Open a target directly:

```sh
godot --path . -- --dev-start=settings
godot --path . -- --dev-start=leaderboard
godot --path . -- --dev-start=game --dev-difficulty=3
godot --path . -- --dev-start=tools
```

The panel reports FPS, current scene/view, game state, static memory and object
count. It can create boards, complete games, trigger victory/ranked-failure
flows, reset active games, generate player/leaderboard fixtures, probe the
leaderboard with its normal permission/cache behavior, reload the current UI,
reload development parameters and clear local data after a second confirmation.

Development parameters are in `debug/development_config.json`. The running
debug build polls the file and applies changes without a restart. The matching
`@export` defaults are on `DevelopmentConfig` and `DevelopmentDebugManager`, so
temporary scene-local values can also be tuned in the Inspector.

`AppConfig.DEBUG` uses `OS.is_debug_build()`. The `run/main_scene.debug` project
setting selects `DebugMain.tscn` only for Editor and debug builds; the base
release entry remains `res://ui/scenes/main/main.tscn`. Development features
also require the absence of `--no-development-mode`. To exercise the protected
production bootstrap path from a debug build:

```sh
godot --path . -- --no-development-mode
```

GDScript method-body and resource changes can usually be hot reloaded while the
game runs. Use **Reload current UI** after changing UI construction code while
preserving in-memory state. Restart the running project after changing class
names, autoloads, `project.godot`, input actions or scene node structure.
Platform APIs, permissions, signing, export filters, native plugins and final
package layout still require the matching exported app and target-device QA.
