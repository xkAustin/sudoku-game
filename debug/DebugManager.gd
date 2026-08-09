class_name DevelopmentDebugManager
extends Node

# Debug 专用：通过信号向调试入口请求导航或注入测试局，避免 Debug UI 依赖主界面内部结构。
signal status_changed(message: String)
signal destination_requested(destination: String)
signal session_requested(session: GameSession)
signal reload_requested
signal leaderboard_test_finished(success: bool, message: String)

@export_range(0, 5, 1) var default_difficulty := 1
@export_range(1, 100, 1) var mock_player_count := 12
@export var log_actions := true

var current_destination := "launcher"
var development_config: DevelopmentConfig
var _game_host: Node
var _leaderboard_probe: LeaderboardService

func _ready() -> void:
	development_config = get_node_or_null("DevelopmentConfig") as DevelopmentConfig
	set_process(false)
	if not _development_mode_enabled():
		return
	if development_config != null:
		development_config.config_reloaded.connect(_on_config_reloaded)
		_apply_config(development_config.values)
	_log("Development manager enabled")

func is_enabled() -> bool:
	return _development_mode_enabled()

func register_game_host(game_host: Node) -> void:
	_game_host = game_host

func set_destination(destination: String) -> void:
	if not is_enabled():
		return
	current_destination = destination
	destination_requested.emit(destination)

func reload_current_ui() -> void:
	if not is_enabled():
		return
	reload_requested.emit()
	_set_status("已重新实例化当前 UI，内存中的游戏与设置状态已保留")

func create_test_board(difficulty: int = -1, game_mode: String = "local") -> GameSession:
	if not is_enabled():
		return null
	var selected_difficulty := clampi(default_difficulty if difficulty < 0 else difficulty, 0, 5)
	var session := make_test_session(selected_difficulty, game_mode)
	if session == null:
		_set_status("测试棋盘创建失败")
		return null
	current_destination = "game"
	session_requested.emit(session)
	_set_status("已创建%s测试棋盘：%s" % ["排位" if game_mode == "ranked" else "本地", _difficulty_name(selected_difficulty)])
	return session

func make_test_session(difficulty: int, game_mode: String = "local") -> GameSession:
	var selected_difficulty := clampi(difficulty, 0, 5)
	var generation_result: Dictionary
	var seed_value := _config_int("test_seed", 20260803)
	if selected_difficulty == 5:
		generation_result = HexadokuGenerator.new().generate(seed_value)
	else:
		var puzzle := SudokuValidator.string_to_board(SudokuGenerator.FALLBACKS[selected_difficulty])
		generation_result = {
			"puzzle": puzzle,
			"solution": SudokuSolver.new().solve(puzzle),
			"difficulty": selected_difficulty,
		}
	if generation_result.get("solution", PackedInt32Array()).is_empty():
		return null
	var session := GameSession.create(
		generation_result["puzzle"],
		generation_result["solution"],
		selected_difficulty,
		game_mode
	)
	session.elapsed_ms = _config_int("test_elapsed_ms", 95000)
	session.mistakes = _config_int("test_mistakes", 0)
	return session

func reset_current_game() -> void:
	if not is_enabled():
		return
	var app_state := _app_state()
	var save_manager := _save_manager()
	if app_state == null or save_manager == null:
		return
	var empty_games := {"data_version": 1, "games": {}}
	app_state.set("current_session", null)
	app_state.set("active_games", empty_games)
	save_manager.call("write_json", "active_games.json", empty_games)
	var service: Node = _game_service()
	if service != null:
		service.session = null
	var event_bus := _event_bus()
	if event_bus != null:
		event_bus.emit_signal("session_changed")
	set_destination("menu")
	_set_status("当前对局和所有未完成局已重置")

func quick_complete_game() -> bool:
	if not is_enabled():
		return false
	var service: Node = _game_service()
	if service == null or service.session == null:
		create_test_board()
		service = _game_service()
	if service == null or service.session == null:
		_set_status("没有可完成的测试对局")
		return false
	var session: GameSession = service.session
	var target := -1
	for index in session.board.size():
		if session.puzzle[index] == 0:
			target = index
			session.board[index] = session.solution[index]
	if target < 0:
		_set_status("测试棋盘没有可编辑单元格")
		return false
	session.board[target] = 0
	session.completed = false
	service.select(target)
	service.enter_number(session.solution[target])
	_set_status("已触发胜利流程")
	return true

func test_victory_flow(difficulty: int = -1) -> void:
	create_test_board(difficulty, "local")
	quick_complete_game()

func test_failure_flow(difficulty: int = -1) -> bool:
	var session := create_test_board(difficulty, "ranked")
	var service: Node = _game_service()
	if session == null or service == null:
		return false
	var target := -1
	for index in session.board.size():
		if not session.is_clue(index):
			target = index
			break
	if target < 0:
		return false
	service.select(target)
	for offset in 3:
		var wrong_value := (session.solution[target] + offset) % session.grid_size + 1
		service.enter_number(wrong_value)
	_set_status("已触发排位三次错误失败流程")
	return true

func simulate_player_data() -> void:
	if not is_enabled():
		return
	var app_state := _app_state()
	var save_manager := _save_manager()
	if app_state == null or save_manager == null:
		return
	var profile: Dictionary = app_state.get("profile")
	profile["display_name"] = "Debug Player"
	var statistics := {
		"data_version": 2,
		"started": 30,
		"completed": 24,
		"operations": 1784,
		"current_streak": 4,
		"longest_streak": 11,
		"by_difficulty": {},
	}
	for difficulty in 6:
		statistics["by_difficulty"][str(difficulty)] = {
			"started": 5,
			"completed": 4,
			"best_ms": 75000 + difficulty * 45000,
			"operations": 180 + difficulty * 28,
		}
	app_state.set("profile", profile)
	app_state.set("statistics", statistics)
	save_manager.call("write_json", "profile.json", profile)
	save_manager.call("write_json", "statistics.json", statistics)
	var event_bus := _event_bus()
	if event_bus != null:
		event_bus.emit_signal("settings_changed", PackedStringArray())
	_set_status("已生成 Debug Player 和统计测试数据")

func simulate_leaderboard_data(player_count: int = -1) -> Dictionary:
	if not is_enabled():
		return {}
	var save_manager := _save_manager()
	if save_manager == null:
		return {}
	var count := mock_player_count if player_count < 1 else player_count
	var snapshot := build_mock_leaderboard_snapshot(count)
	save_manager.call("write_json", OnlineLeaderboard.CACHE_FILE, {
		"data_version": 3,
		"global": snapshot,
	})
	_set_status("已写入 %d 条本地排行榜测试数据" % snapshot.get("entries", []).size())
	return snapshot

func generate_test_data() -> void:
	simulate_player_data()
	simulate_leaderboard_data()

func build_mock_leaderboard_snapshot(player_count: int) -> Dictionary:
	var entries: Array[Dictionary] = []
	for index in clampi(player_count, 1, 100):
		entries.append({
			"rank": index + 1,
			"display_name": "Debug Player %02d" % (index + 1),
			"score": 2500000 - index * 17321,
			"submitted_at": "2026-08-03T%02d:00:00Z" % (index % 24),
		})
	return {
		"entries": entries,
		"self_entry": entries[min(3, entries.size() - 1)].duplicate(true),
		"source": "debug",
		"cached_at": Time.get_datetime_string_from_system(true),
	}

func test_leaderboard_interface() -> void:
	if not is_enabled():
		return
	if _leaderboard_probe != null and is_instance_valid(_leaderboard_probe):
		_leaderboard_probe.queue_free()
	_leaderboard_probe = LeaderboardService.new()
	add_child(_leaderboard_probe)
	_leaderboard_probe.loaded.connect(_on_leaderboard_loaded)
	_leaderboard_probe.failed.connect(_on_leaderboard_failed)
	_set_status("正在测试排行榜接口；未授权联网时会验证本地缓存回退")
	var app_state := _app_state()
	_leaderboard_probe.fetch(0, str(app_state.get("installation_id")) if app_state != null else "")

func clear_local_save() -> void:
	if not is_enabled():
		return
	var app_state := _app_state()
	if app_state == null:
		return
	app_state.call("reset_local_data")
	var service: Node = _game_service()
	if service != null:
		service.session = null
	set_destination("menu")
	_set_status("本地存档、缓存、设置和测试数据已清理；安装 ID 已保留")

func game_state_text() -> String:
	if _game_host == null or not is_instance_valid(_game_host):
		return "未加载游戏界面"
	if _game_host.has_method("debug_snapshot"):
		var snapshot: Dictionary = _game_host.call("debug_snapshot")
		return "%s | %s" % [snapshot.get("view", "unknown"), snapshot.get("session", "无对局")]
	return "游戏界面已加载"

func current_scene_name() -> String:
	if _game_host != null and is_instance_valid(_game_host):
		return _game_host.scene_file_path.get_file() + " / " + current_destination
	return "DebugMain.tscn / " + current_destination

func refresh_config() -> bool:
	return development_config.reload_if_changed(true) if development_config != null else false

func _game_service() -> Node:
	if _game_host == null or not is_instance_valid(_game_host):
		return null
	var service: Variant = _game_host.get("game_service")
	return service as Node if service is Node else null

func _on_config_reloaded(config_values: Dictionary) -> void:
	_apply_config(config_values)
	_set_status("开发配置已热重载")

func _apply_config(config_values: Dictionary) -> void:
	default_difficulty = clampi(int(config_values.get("default_difficulty", default_difficulty)), 0, 5)
	mock_player_count = clampi(int(config_values.get("mock_player_count", mock_player_count)), 1, 100)
	log_actions = bool(config_values.get("log_output", log_actions))

func _on_leaderboard_loaded(snapshot: Dictionary) -> void:
	var source := str(snapshot.get("source", "unknown"))
	var entries: Array = snapshot.get("entries", [])
	var count: int = entries.size()
	var message := "排行榜接口可用：%s，%d 条记录" % [source, count]
	leaderboard_test_finished.emit(true, message)
	_set_status(message)

func _on_leaderboard_failed(message: String) -> void:
	var detail := "排行榜接口测试失败：" + message
	leaderboard_test_finished.emit(false, detail)
	_set_status(detail)

func _config_int(key: String, fallback: int) -> int:
	return int(development_config.value(key, fallback)) if development_config != null else fallback

func _set_status(message: String) -> void:
	status_changed.emit(message)
	_log(message)

func _log(message: String) -> void:
	if log_actions and OS.is_debug_build():
		print("[Development] " + message)

func _difficulty_name(difficulty: int) -> String:
	return ["入门", "简单", "中等", "困难", "专家", "终极"][clampi(difficulty, 0, 5)]

func _development_mode_enabled() -> bool:
	var app_config := get_node_or_null("/root/AppConfig")
	return app_config != null and bool(app_config.get("development_mode"))

func _app_state() -> Node:
	return get_node_or_null("/root/AppState")

func _save_manager() -> Node:
	return get_node_or_null("/root/SaveManager")

func _event_bus() -> Node:
	return get_node_or_null("/root/EventBus")
