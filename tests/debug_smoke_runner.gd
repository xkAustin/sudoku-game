extends SceneTree

# Debug 专用：验证开发入口、快捷导航、测试棋盘和模拟排行榜数据的基本契约。
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1180, 780)
	var debug_scene: Control = load("res://debug/DebugMain.tscn").instantiate()
	root.add_child(debug_scene)
	await process_frame
	await process_frame
	var app_config: Node = root.get_node("AppConfig")
	_assert(bool(app_config.get("DEBUG")) and bool(app_config.get("development_mode")), "debug build enables Development Mode")
	var manager: Node = debug_scene.get_node("DebugManager")
	var panel := debug_scene.get_node("DebugPanelLayer/DebugPanel") as PanelContainer
	_assert(manager != null and manager.is_enabled(), "DebugManager is enabled")
	_assert(panel != null and not panel.visible, "Debug panel starts hidden and is available on demand")
	_assert(debug_scene.get_node("ContentHost").get_child_count() >= 1, "Debug launcher renders")

	manager.set_destination("settings")
	await process_frame
	var main: Node = debug_scene.get_node("ContentHost").get_child(0)
	_assert(str(main.get("_current_view")) == "settings", "settings shortcut opens the existing settings UI")
	manager.set_destination("leaderboard")
	await process_frame
	main = debug_scene.get_node("ContentHost").get_child(0)
	_assert(str(main.get("_current_view")) == "leaderboard", "leaderboard shortcut opens the existing leaderboard UI")

	var session: GameSession = manager.call("make_test_session", 2)
	_assert(session != null and session.difficulty == 2 and session.board.size() == 81, "test board uses a valid 9x9 session")
	var ultimate_session: GameSession = manager.call("make_test_session", 5)
	_assert(ultimate_session != null and ultimate_session.board.size() == 256, "test board supports the 16x16 difficulty")
	var snapshot: Dictionary = manager.call("build_mock_leaderboard_snapshot", 7)
	_assert(snapshot.get("entries", []).size() == 7 and not snapshot.get("self_entry", {}).is_empty(), "mock leaderboard snapshot is usable")

	print("Debug smoke tests: %d failures" % failures)
	debug_scene.queue_free()
	quit(1 if failures > 0 else 0)

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("Debug smoke: " + message)
