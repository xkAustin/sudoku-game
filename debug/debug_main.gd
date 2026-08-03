extends Control

# Debug 专用：编辑器默认入口。Release 构建会直接进入正式主场景，不创建调试界面。
const MAIN_SCENE := preload("res://ui/scenes/main/main.tscn")

@onready var content_host: Control = $ContentHost
@onready var debug_manager: DevelopmentDebugManager = $DebugManager
@onready var debug_panel: PanelContainer = $DebugPanelLayer/DebugPanel

var _current_main: Control
var _last_destination := "launcher"

func _ready() -> void:
	if not _development_mode_enabled():
		debug_panel.hide()
		_load_main("menu")
		return
	debug_manager.destination_requested.connect(_open_destination)
	debug_manager.session_requested.connect(_open_session)
	debug_manager.reload_requested.connect(_reload_current_view)
	debug_panel.call("bind_manager", debug_manager)
	debug_panel.hide()
	_show_launcher()
	_apply_startup_arguments()

func _unhandled_input(event: InputEvent) -> void:
	if not _development_mode_enabled() or not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if key_event.pressed and not key_event.echo \
			and (key_event.is_action_pressed("toggle_debug_panel") or key_event.keycode == KEY_F12):
		debug_panel.visible = not debug_panel.visible
		get_viewport().set_input_as_handled()

func _show_launcher() -> void:
	_last_destination = "launcher"
	debug_manager.current_destination = "launcher"
	_clear_content()
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("101827")
	content_host.add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_host.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	panel.theme = ThemeManager.build(true, false)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)
	var kicker := Label.new()
	kicker.text = "DEBUG / DEVELOPMENT MODE"
	content.add_child(kicker)
	var title := Label.new()
	title.text = "数独开发快捷入口"
	title.add_theme_font_size_override("font_size", 34)
	content.add_child(title)
	var summary := Label.new()
	summary.text = "无需导出 App，直接进入目标页面或创建测试棋盘。F12 可随时打开调试面板。"
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(summary)
	_add_launcher_button(content, "进入主游戏", "menu")
	_add_launcher_button(content, "打开设置页面", "settings")
	_add_launcher_button(content, "打开排行榜", "leaderboard")
	_add_launcher_button(content, "创建默认难度测试棋盘", "game")
	_add_launcher_button(content, "打开测试工具面板", "tools")

func _add_launcher_button(parent: VBoxContainer, text: String, destination: String) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 52
	button.pressed.connect(debug_manager.set_destination.bind(destination))
	parent.add_child(button)

func _open_destination(destination: String) -> void:
	_last_destination = destination
	match destination:
		"launcher":
			_show_launcher()
		"tools":
			_show_launcher()
			_last_destination = "tools"
			debug_manager.current_destination = "tools"
			debug_panel.show()
		"game":
			debug_manager.create_test_board()
		"menu", "settings", "leaderboard":
			_load_main(destination)
		_:
			_load_main("menu")

func _open_session(session: GameSession) -> void:
	_load_main("menu")
	_current_main.call("debug_start_session", session)
	debug_manager.current_destination = "game"
	_last_destination = "game"

func _load_main(destination: String) -> void:
	_clear_content()
	_current_main = MAIN_SCENE.instantiate()
	content_host.add_child(_current_main)
	if _development_mode_enabled():
		debug_manager.register_game_host(_current_main)
		_current_main.call("debug_open_view", destination)
		debug_manager.current_destination = destination
	_last_destination = destination

func _reload_current_view() -> void:
	if _last_destination == "launcher" or _last_destination == "tools":
		var tools_was_open := _last_destination == "tools"
		_show_launcher()
		if tools_was_open:
			_last_destination = "tools"
			debug_manager.current_destination = "tools"
			debug_panel.show()
		return
	if _last_destination == "game" and _current_main != null:
		var service: Variant = _current_main.get("game_service")
		var active_session: GameSession = service.get("session") if service is Node else null
		_load_main("menu")
		if active_session != null:
			_current_main.call("debug_start_session", active_session)
			debug_manager.current_destination = "game"
		return
	_load_main(_last_destination)

func _apply_startup_arguments() -> void:
	var destination := ""
	var difficulty := -1
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--dev-start="):
			destination = argument.trim_prefix("--dev-start=")
		elif argument.begins_with("--dev-difficulty="):
			difficulty = clampi(int(argument.trim_prefix("--dev-difficulty=")), 0, 5)
	if difficulty >= 0:
		debug_manager.default_difficulty = difficulty
	if not destination.is_empty():
		debug_manager.set_destination(destination)

func _clear_content() -> void:
	_current_main = null
	if debug_manager != null:
		debug_manager.register_game_host(null)
	for child in content_host.get_children():
		content_host.remove_child(child)
		child.queue_free()

func _development_mode_enabled() -> bool:
	var app_config := get_node_or_null("/root/AppConfig")
	return app_config != null and bool(app_config.get("development_mode"))
