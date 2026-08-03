extends PanelContainer

# Debug 专用：独立运行时面板，只在 Development Mode 中显示。
var debug_manager: DevelopmentDebugManager
var fps_label: Label
var scene_label: Label
var game_state_label: Label
var memory_label: Label
var status_label: Label
var difficulty_picker: OptionButton
var clear_confirmation_deadline := 0
var _refresh_elapsed := 0.0

func _ready() -> void:
	var app_config := get_node_or_null("/root/AppConfig")
	visible = app_config != null and bool(app_config.get("development_mode"))
	if not visible:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(false)
		return
	_build_panel()
	set_process(true)

func bind_manager(manager: DevelopmentDebugManager) -> void:
	debug_manager = manager
	if not manager.status_changed.is_connected(_on_status_changed):
		manager.status_changed.connect(_on_status_changed)
	if difficulty_picker != null:
		difficulty_picker.select(manager.default_difficulty)

func _process(delta: float) -> void:
	if debug_manager == null:
		return
	_refresh_elapsed += delta
	var interval := 0.5
	if debug_manager.development_config != null:
		interval = float(debug_manager.development_config.value("panel_refresh_seconds", interval))
	if _refresh_elapsed < interval:
		return
	_refresh_elapsed = 0.0
	fps_label.text = "FPS：%d" % Engine.get_frames_per_second()
	scene_label.text = "当前场景：" + debug_manager.current_scene_name()
	game_state_label.text = "游戏状态：" + debug_manager.game_state_text()
	memory_label.text = "静态内存：%.1f MB · 对象：%d" % [
		float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0,
		int(Performance.get_monitor(Performance.OBJECT_COUNT)),
	]

func _build_panel() -> void:
	name = "DebugPanel"
	custom_minimum_size = Vector2(390, 680)
	theme = ThemeManager.build(true, false)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)
	var scroll := ScrollContainer.new()
	margin.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 9)
	scroll.add_child(content)

	var title_row := HBoxContainer.new()
	content.add_child(title_row)
	var title := Label.new()
	title.text = "Development Panel"
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var close_button := _button("隐藏")
	close_button.pressed.connect(hide)
	title_row.add_child(close_button)

	fps_label = _info_label("FPS：--")
	scene_label = _info_label("当前场景：DebugMain.tscn / launcher")
	game_state_label = _info_label("游戏状态：未加载")
	memory_label = _info_label("静态内存：--")
	content.add_child(fps_label)
	content.add_child(scene_label)
	content.add_child(game_state_label)
	content.add_child(memory_label)

	_add_separator(content)
	var picker_row := HBoxContainer.new()
	picker_row.add_theme_constant_override("separation", 8)
	content.add_child(picker_row)
	difficulty_picker = OptionButton.new()
	difficulty_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for difficulty_name in ["入门", "简单", "中等", "困难", "专家", "终极 16×16"]:
		difficulty_picker.add_item(difficulty_name)
	picker_row.add_child(difficulty_picker)
	var board_button := _button("创建棋盘")
	board_button.pressed.connect(_create_board)
	picker_row.add_child(board_button)

	_add_action(content, "快速完成当前局", _quick_complete)
	_add_action(content, "测试胜利流程", _test_victory)
	_add_action(content, "测试排位失败流程", _test_failure)
	_add_action(content, "重置当前游戏数据", _reset_game)

	_add_separator(content)
	_add_action(content, "生成玩家和排行榜测试数据", _generate_test_data)
	_add_action(content, "仅模拟排行榜数据", _simulate_leaderboard)
	_add_action(content, "测试排行榜接口 / 缓存回退", _test_leaderboard)
	_add_action(content, "重新加载当前 UI", _reload_ui)
	_add_action(content, "立即热重载开发配置", _reload_config)
	_add_action(content, "清理全部本地存档（需二次点击）", _clear_local_save)

	_add_separator(content)
	status_label = _info_label("F12 显示/隐藏面板；修改 development_config.json 会自动生效")
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(status_label)

func _create_board() -> void:
	debug_manager.create_test_board(difficulty_picker.selected)

func _quick_complete() -> void:
	debug_manager.quick_complete_game()

func _test_victory() -> void:
	debug_manager.test_victory_flow(difficulty_picker.selected)

func _test_failure() -> void:
	debug_manager.test_failure_flow(difficulty_picker.selected)

func _reset_game() -> void:
	debug_manager.reset_current_game()

func _generate_test_data() -> void:
	debug_manager.generate_test_data()

func _simulate_leaderboard() -> void:
	debug_manager.simulate_leaderboard_data()

func _test_leaderboard() -> void:
	debug_manager.test_leaderboard_interface()

func _reload_ui() -> void:
	debug_manager.reload_current_ui()

func _reload_config() -> void:
	debug_manager.refresh_config()

func _clear_local_save() -> void:
	var now := Time.get_ticks_msec()
	if now > clear_confirmation_deadline:
		clear_confirmation_deadline = now + 4000
		status_label.text = "再次点击同一按钮确认清理全部本地数据"
		return
	clear_confirmation_deadline = 0
	debug_manager.clear_local_save()

func _on_status_changed(message: String) -> void:
	if status_label != null:
		status_label.text = message

func _add_action(parent: VBoxContainer, text: String, action: Callable) -> void:
	var action_button := _button(text)
	action_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_button.pressed.connect(action)
	parent.add_child(action_button)

func _button(text: String) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size.y = 42
	return result

func _info_label(text: String) -> Label:
	var result := Label.new()
	result.text = text
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return result

func _add_separator(parent: VBoxContainer) -> void:
	parent.add_child(HSeparator.new())
