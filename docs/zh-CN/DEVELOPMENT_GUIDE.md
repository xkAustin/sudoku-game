# 开发模式指南

Godot Editor 和 Debug 导出默认启动 `res://debug/DebugMain.tscn`。这个入口不会
复制游戏逻辑，而是复用正式的主场景、`GameService`、`AppState`、存档和排行榜
服务，因此测试到的是实际游戏流程，无需先导出 Android、iOS、macOS 或 Windows
应用。

## 启动与快捷入口

在 Godot Editor 中打开项目后按 F5，或执行：

```sh
godot --path .
```

启动页可直接进入主游戏、设置、排行榜、测试棋盘和测试工具。也可使用开发启动
参数：

```sh
godot --path . -- --dev-start=settings
godot --path . -- --dev-start=leaderboard
godot --path . -- --dev-start=game --dev-difficulty=3
godot --path . -- --dev-start=tools
```

`--dev-difficulty` 取值为 `0` 到 `5`。运行中按 `F12` 显示或隐藏独立 Debug
面板。

## Debug 面板

面板显示 FPS、当前场景/页面、当前游戏状态、静态内存和对象数量，并提供：

- 快速创建六档难度测试棋盘；
- 快速完成当前局；
- 触发真实胜利流程和排位三次错误失败流程；
- 重置当前对局和全部未完成局；
- 生成模拟玩家统计和排行榜缓存；
- 通过正式排行榜服务测试联网或本地缓存回退；
- 保留内存状态重新实例化当前 UI；
- 立即重新读取开发配置；
- 二次确认后清理本地存档、设置、缓存和测试数据。

排行榜接口测试遵守正式的联网授权设置。未授权联网时只验证缓存回退，不会绕过
隐私设置发出请求。

## 无重启调参和 Hot Reload

开发参数集中在 `debug/development_config.json`。Debug 运行时每 0.75 秒检查
文件内容，修改以下值后无需重启：

- `default_difficulty`：默认测试难度；
- `test_seed`：测试棋盘种子；
- `test_elapsed_ms`、`test_mistakes`：测试会话初始状态；
- `mock_player_count`：模拟排行榜人数；
- `panel_refresh_seconds`：面板刷新间隔；
- `log_output`：开发日志开关。

`DevelopmentConfig` 和 `DevelopmentDebugManager` 也用 `@export` 暴露了场景级
参数，可在 Inspector 临时调整。普通 GDScript 方法体、样式资源和数据配置修改可
优先使用 Godot 热重载；修改 UI 构建代码后可点“重新加载当前 UI”，无需清掉
内存中的游戏和设置状态。

修改 class name、Autoload、`project.godot`、输入动作或场景节点结构后仍应重启
当前运行。修改平台权限、签名、原生插件、导出过滤规则或安装包结构后，仍需重新
导出并在目标平台验证。

## 正式版本隔离

`AppConfig.DEBUG` 来自 `OS.is_debug_build()`。`project.godot` 的
`run/main_scene.debug` 仅在 Editor 和 Debug 构建中选择 `DebugMain.tscn`；Release
的基础入口保持 `res://ui/scenes/main/main.tscn`。Development Mode 还要求没有
`--no-development-mode` 参数，因此正式构建不会创建调试入口或 Debug 面板，也
不会输出开发日志。

可以在 Debug 构建中预演正式入口：

```sh
godot --path . -- --no-development-mode
```

## 验证

```sh
./tests/run_all.sh
godot --headless --path . \
  --log-file /tmp/sudoku-ui-smoke.log \
  --script tests/ui_smoke_runner.gd
```

`run_all.sh` 包含 `tests/debug_smoke_runner.gd`，会验证开发入口、设置/排行榜快捷
导航、9×9 与 16×16 测试棋盘以及模拟排行榜结构。
