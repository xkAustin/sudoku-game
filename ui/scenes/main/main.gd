extends Control

const DIFFICULTY_ZH := ["入门", "简单", "中等", "困难", "专家", "终极"]
const DIFFICULTY_EN := ["Beginner", "Easy", "Medium", "Hard", "Expert", "Ultimate"]
const THEME_VALUES := ["system", "light", "dark"]
const LANGUAGE_VALUES := ["system", "zh", "en"]
const SHORTCUT_ACTIONS := ["undo", "redo", "erase", "notes", "pause", "hint", "new_game", "settings"]
const MAX_CUSTOM_SOUND_BYTES := 10 * 1024 * 1024
const RuntimeAudioLoaderScript := preload("res://ui/audio/runtime_audio_loader.gd")
const PAUSE_BLUR_SHADER_CODE := """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_lod = 5.8;
uniform vec4 tint_color : source_color = vec4(0.95, 0.97, 1.0, 0.38);

void fragment() {
	vec4 blurred = textureLod(screen_texture, SCREEN_UV, blur_lod);
	vec2 point = abs(UV - vec2(0.5)) - vec2(0.455);
	float distance_to_rounding = length(max(point, vec2(0.0))) + min(max(point.x, point.y), 0.0) - 0.045;
	float mask = 1.0 - smoothstep(-0.0025, 0.0025, distance_to_rounding);
	blurred.rgb = mix(blurred.rgb, tint_color.rgb, tint_color.a);
	COLOR = vec4(blurred.rgb, mask * 0.985);
}
"""
const ICONS := {
	"back": preload("res://assets/icons/back.svg"), "undo": preload("res://assets/icons/undo.svg"),
	"redo": preload("res://assets/icons/redo.svg"), "erase": preload("res://assets/icons/erase.svg"),
	"notes": preload("res://assets/icons/notes.svg"), "pause": preload("res://assets/icons/pause.svg"),
	"play": preload("res://assets/icons/play.svg"), "hint": preload("res://assets/icons/hint.svg"),
	"warning": preload("res://assets/icons/warning.svg"), "error": preload("res://assets/icons/error.svg"),
	"record": preload("res://assets/icons/record.svg"),
	"chevron": preload("res://assets/icons/chevron.svg")
}

var game_service := GameService.new()
var challenge_service := RankedChallengeService.new()
var leaderboard_service := LeaderboardService.new()
var ui_sounds := UISoundManager.new()
var content: VBoxContainer
var shell_outer: VBoxContainer
var shell_margin: MarginContainer
var status_label: Label
var toast_panel: PanelContainer
var toast_label: Label
var timer_label: Label
var mistakes_label: Label
var mistake_icon: TextureRect
var notes_button: Button
var pause_button: Button
var pause_overlay: Control
var pause_blur_layer: ColorRect
var cell_buttons: Array[SudokuCellButton] = []
var number_buttons: Dictionary = {}
var _ranked_difficulty := -1
var _ranked_resume_session: GameSession
var _pending_offline_ranked := false
var _leaderboard_difficulty := 0
var _leaderboard_snapshot: Dictionary = {}
var _leaderboard_results: VBoxContainer
var _current_view := "menu"
var _difficulty_ranked := false
var _last_wide_layout := false
var _layout_refresh_queued := false
var _last_layout_size := Vector2.ZERO
var _toast_token := 0
var _transition_token := 0
var _last_mistake_count := -1
var _capturing_shortcut := ""
var _shortcut_capture_button: Button
var _sound_customization_expanded := false
var _completed_units: Dictionary = {}
var _completed_units_initialized := false
var _pending_ranked_submission: Dictionary = {}
var _ranked_result_session: GameSession
var _ranked_upload_state := ""
var _leaderboard_refresh_after_sync := false

func _ready() -> void:
	_ensure_shortcut_settings()
	_configure_initial_window()
	add_child(game_service)
	add_child(challenge_service)
	add_child(leaderboard_service)
	add_child(ui_sounds)
	game_service.generation_finished.connect(_on_generation_finished)
	game_service.generation_failed.connect(_on_generation_failed)
	game_service.completed.connect(_on_game_completed)
	game_service.failed.connect(_on_ranked_failed)
	challenge_service.challenge_received.connect(_on_challenge_received)
	challenge_service.challenge_failed.connect(_on_challenge_failed)
	leaderboard_service.loaded.connect(_show_leaderboard_snapshot)
	leaderboard_service.failed.connect(_on_leaderboard_failed)
	SyncManager.flush_completed.connect(_on_sync_flush_completed)
	EventBus.toast_requested.connect(_show_toast)
	EventBus.session_changed.connect(_refresh_game)
	EventBus.settings_changed.connect(_apply_theme)
	EventBus.network_changed.connect(_on_network_changed)
	EventBus.pending_count_changed.connect(_on_pending_changed)
	EventBus.navigation_requested.connect(_navigate)
	_build_shell()
	_last_wide_layout = _is_wide_layout()
	_last_layout_size = size
	resized.connect(_on_layout_resized)
	_update_shell_width()
	_apply_theme()
	_show_menu()
	set_process(true)

func _process(_delta: float) -> void:
	if timer_label != null and is_instance_valid(timer_label) and game_service.session != null:
		timer_label.text = _format_time(game_service.session.elapsed_ms) if bool(AppState.settings.get("show_timer", true)) else _l("计时已隐藏", "Timer hidden")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back()

func _input(input_event: InputEvent) -> void:
	if not input_event is InputEventKey:
		return
	var event := input_event as InputEventKey
	if not event.pressed or event.echo:
		return
	if not _capturing_shortcut.is_empty():
		_capture_shortcut_event(event)
		get_viewport().set_input_as_handled()
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit:
		return
	if _event_matches_shortcut(event, "settings"):
		AppState.save_session_now()
		_show_settings()
		get_viewport().set_input_as_handled()
		return
	if _event_matches_shortcut(event, "new_game"):
		AppState.save_session_now()
		_show_difficulty(false)
		get_viewport().set_input_as_handled()
		return
	if _current_view == "difficulty" and event.keycode >= KEY_1 and event.keycode <= KEY_6:
		var choice: int = int(event.keycode - KEY_1)
		_choose_difficulty(choice, _difficulty_ranked)
		get_viewport().set_input_as_handled()
		return
	if _current_view != "game":
		return
	var handled := true
	if not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed and event.keycode >= KEY_1 and event.keycode <= KEY_9:
		game_service.enter_number(event.keycode - KEY_0)
	elif not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed and event.keycode >= KEY_A and event.keycode <= KEY_G and game_service.session != null and game_service.session.grid_size == 16:
		game_service.enter_number(10 + event.keycode - KEY_A)
	elif _event_matches_shortcut(event, "erase") or event.keycode == KEY_DELETE:
		game_service.erase()
	elif _event_matches_shortcut(event, "notes"):
		_toggle_notes()
	elif _event_matches_shortcut(event, "pause") or event.keycode == KEY_ESCAPE:
		_toggle_pause()
	elif not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed and event.keycode == KEY_UP:
		game_service.move_selection(-1, 0)
	elif not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed and event.keycode == KEY_DOWN:
		game_service.move_selection(1, 0)
	elif not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed and event.keycode == KEY_LEFT:
		game_service.move_selection(0, -1)
	elif not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed and event.keycode == KEY_RIGHT:
		game_service.move_selection(0, 1)
	elif _event_matches_shortcut(event, "redo"):
		game_service.redo()
	elif _event_matches_shortcut(event, "undo"):
		game_service.undo()
	elif _event_matches_shortcut(event, "hint"):
		game_service.hint()
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()

func _build_shell() -> void:
	var background := Panel.new()
	background.name = "Background"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	shell_margin = MarginContainer.new()
	shell_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell_margin.add_theme_constant_override("margin_left", 24)
	shell_margin.add_theme_constant_override("margin_right", 24)
	shell_margin.add_theme_constant_override("margin_top", 10)
	shell_margin.add_theme_constant_override("margin_bottom", 10)
	add_child(shell_margin)
	shell_outer = VBoxContainer.new()
	shell_outer.add_theme_constant_override("separation", 10)
	shell_outer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	shell_outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell_margin.add_child(shell_outer)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	shell_outer.add_child(top)
	var brand := Label.new()
	brand.text = _l("SUDOKU / 数独", "SUDOKU")
	brand.add_theme_font_size_override("font_size", 18)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(brand)
	status_label = Label.new()
	status_label.text = _l("离线可玩", "Works offline")
	status_label.add_theme_font_size_override("font_size", 15)
	top.add_child(status_label)
	content = VBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	shell_outer.add_child(content)
	toast_panel = PanelContainer.new()
	toast_panel.theme_type_variation = "ToastPanel"
	toast_panel.anchor_left = 0.5
	toast_panel.anchor_right = 0.5
	toast_panel.anchor_top = 1.0
	toast_panel.anchor_bottom = 1.0
	toast_panel.offset_left = -240
	toast_panel.offset_right = 240
	toast_panel.offset_top = -76
	toast_panel.offset_bottom = -18
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.z_index = 90
	toast_panel.visible = false
	add_child(toast_panel)
	toast_label = Label.new()
	toast_label.custom_minimum_size.x = 420
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.add_theme_font_size_override("font_size", 22)
	toast_panel.add_child(toast_label)

func _update_shell_width() -> void:
	if shell_outer != null:
		var side_margin := 28 if _is_wide_layout() else 24
		shell_margin.add_theme_constant_override("margin_left", side_margin)
		shell_margin.add_theme_constant_override("margin_right", side_margin)
		var maximum_width := 2440.0 if _is_wide_layout() else 1120.0
		shell_outer.custom_minimum_size.x = clampf(size.x - side_margin * 2.0, 320.0, maximum_width)

func _on_layout_resized() -> void:
	_update_shell_width()
	var is_wide := _is_wide_layout()
	var geometry_changed := _last_layout_size.distance_to(size) >= 84.0
	if (is_wide == _last_wide_layout and not geometry_changed) or _layout_refresh_queued:
		return
	_last_wide_layout = is_wide
	_last_layout_size = size
	_layout_refresh_queued = true
	call_deferred("_rebuild_current_layout")

func _rebuild_current_layout() -> void:
	_layout_refresh_queued = false
	match _current_view:
		"menu":
			_show_menu()
		"difficulty":
			_show_difficulty(_difficulty_ranked)
		"game":
			_show_game()
		"statistics":
			_show_statistics()
		"ranked_briefing":
			_show_ranked_briefing(_ranked_difficulty, _ranked_resume_session)
		"settings":
			_show_settings()
		"leaderboard":
			_show_leaderboard()

func _is_wide_layout() -> bool:
	return size.x >= 1240.0 and size.x > size.y * 1.12

func _apply_theme() -> void:
	var mode := str(AppState.settings.get("theme", "system"))
	var dark := mode == "dark" or (mode == "system" and DisplayServer.is_dark_mode_supported() and DisplayServer.is_dark_mode())
	theme = ThemeManager.build(dark, bool(AppState.settings.get("high_contrast", false)))
	content.scale = Vector2.ONE * float(AppState.settings.get("ui_scale", 1.0))
	var panel: Panel = get_node_or_null("Background")
	if panel != null:
		var box := StyleBoxFlat.new()
		box.bg_color = theme.get_color("background", "App")
		panel.add_theme_stylebox_override("panel", box)

func _configure_initial_window() -> void:
	if OS.has_feature("mobile"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	if usable.size.x <= 0 or usable.size.y <= 0:
		return
	# macOS reports window geometry in physical pixels on Retina displays. Scale
	# the logical desktop limits so the default window does not open at half size.
	var display_scale := maxf(DisplayServer.screen_get_scale(screen), 1.0) if OS.get_name() == "macOS" else 1.0
	var safe_inset := int(24.0 * display_scale)
	var target := Vector2i(
		clampi(int(usable.size.x * 0.88), int(1260.0 * display_scale), int(1720.0 * display_scale)),
		clampi(int(usable.size.y * 0.88), int(800.0 * display_scale), int(1100.0 * display_scale))
	)
	target.x = mini(target.x, usable.size.x - safe_inset * 2)
	target.y = mini(target.y, usable.size.y - safe_inset * 2)
	DisplayServer.window_set_size(target)
	var target_position := usable.position + (usable.size - target) / 2
	DisplayServer.window_set_position(target_position)

func _l(zh: String, en: String) -> String:
	return en if _language() == "en" else zh

func _language() -> String:
	var selected := str(AppState.settings.get("language", "system"))
	if selected == "system":
		return "zh" if OS.get_locale_language().begins_with("zh") else "en"
	return selected

func _difficulty_name(index: int) -> String:
	return DIFFICULTY_EN[index] if _language() == "en" else DIFFICULTY_ZH[index]

func _is_mobile_device(platform_name: String = "") -> bool:
	var platform := OS.get_name() if platform_name.is_empty() else platform_name
	return platform in ["Android", "iOS"]

func _ensure_shortcut_settings() -> void:
	var current: Variant = AppState.settings.get("shortcuts", {})
	var changed := false
	if not current is Dictionary:
		current = {}
		changed = true
	var shortcuts: Dictionary = current
	var platform_name := OS.get_name()
	var defaults := _default_shortcuts(platform_name)
	var saved_platform := str(AppState.settings.get("shortcut_platform", ""))
	if not saved_platform.is_empty() and saved_platform != platform_name:
		shortcuts = defaults.duplicate(true)
		changed = true
	for action in SHORTCUT_ACTIONS:
		if not shortcuts.has(action) or not shortcuts[action] is Dictionary:
			shortcuts[action] = defaults[action]
			changed = true
	AppState.settings["shortcuts"] = shortcuts
	if saved_platform != platform_name:
		changed = true
	AppState.settings["shortcut_platform"] = platform_name
	if not AppState.settings.has("hide_completed_numbers"):
		AppState.settings["hide_completed_numbers"] = true
		changed = true
	if not AppState.settings.has("custom_ui_sound_path"):
		AppState.settings["custom_ui_sound_path"] = ""
		AppState.settings["custom_ui_sound_name"] = ""
		changed = true
	if not AppState.settings.has("error_sound"):
		AppState.settings["error_sound"] = true
		changed = true
	if not AppState.settings.has("custom_error_sound_path"):
		AppState.settings["custom_error_sound_path"] = ""
		AppState.settings["custom_error_sound_name"] = ""
		changed = true
	if not AppState.settings.has("leaderboard_network_allowed"):
		AppState.settings["leaderboard_network_allowed"] = false
		changed = true
	if not AppState.settings.has("leaderboard_auto_refresh"):
		AppState.settings["leaderboard_auto_refresh"] = false
		changed = true
	if not AppState.settings.has("ranked_auto_upload"):
		AppState.settings["ranked_auto_upload"] = false
		changed = true
	if int(AppState.settings.get("data_version", 1)) < 8:
		AppState.settings["data_version"] = 8
		changed = true
	if changed:
		AppState.save_settings()

func _default_shortcuts(platform_name: String = "") -> Dictionary:
	var platform := OS.get_name() if platform_name.is_empty() else platform_name
	var is_mac := platform in ["macOS", "iOS"]
	var is_windows := platform == "Windows"
	var primary_ctrl := not is_mac
	var primary_meta := is_mac
	return {
		"undo": _shortcut_binding(KEY_Z, false, false, primary_ctrl, primary_meta),
		"redo": _shortcut_binding(KEY_Y if is_windows else KEY_Z, not is_windows, false, primary_ctrl, primary_meta),
		"erase": _shortcut_binding(KEY_BACKSPACE if is_mac else KEY_DELETE),
		"notes": _shortcut_binding(KEY_N),
		"pause": _shortcut_binding(KEY_SPACE),
		"hint": _shortcut_binding(KEY_H),
		"new_game": _shortcut_binding(KEY_N, false, false, primary_ctrl, primary_meta),
		"settings": _shortcut_binding(KEY_COMMA, false, false, primary_ctrl, primary_meta)
	}

func _shortcut_binding(keycode: Key, shift: bool = false, alt: bool = false, control: bool = false, meta: bool = false) -> Dictionary:
	return {"keycode": int(keycode), "shift": shift, "alt": alt, "ctrl": control, "meta": meta}

func _event_to_binding(event: InputEventKey) -> Dictionary:
	var code := event.keycode if event.keycode != 0 else event.physical_keycode
	return {"keycode": int(code), "shift": event.shift_pressed, "alt": event.alt_pressed, "ctrl": event.ctrl_pressed, "meta": event.meta_pressed}

func _binding_for(action: String) -> Dictionary:
	var shortcuts: Dictionary = AppState.settings.get("shortcuts", {})
	var value: Variant = shortcuts.get(action, _default_shortcuts().get(action, {}))
	return value if value is Dictionary else {}

func _bindings_equal(first: Dictionary, second: Dictionary) -> bool:
	return int(first.get("keycode", 0)) == int(second.get("keycode", 0)) \
		and bool(first.get("shift", false)) == bool(second.get("shift", false)) \
		and bool(first.get("alt", false)) == bool(second.get("alt", false)) \
		and bool(first.get("ctrl", false)) == bool(second.get("ctrl", false)) \
		and bool(first.get("meta", false)) == bool(second.get("meta", false))

func _event_matches_shortcut(event: InputEventKey, action: String) -> bool:
	return _bindings_equal(_event_to_binding(event), _binding_for(action))

func _shortcut_display(binding: Dictionary) -> String:
	var keycode := int(binding.get("keycode", 0))
	if keycode == 0:
		return _l("未设置", "Not set")
	var key_text := OS.get_keycode_string(keycode)
	match keycode:
		KEY_SPACE:
			key_text = _l("空格", "Space")
		KEY_BACKSPACE:
			key_text = "⌫" if OS.get_name() == "macOS" else "Backspace"
		KEY_DELETE:
			key_text = "⌦" if OS.get_name() == "macOS" else "Delete"
		KEY_COMMA:
			key_text = ","
	if OS.get_name() == "macOS":
		return ("⌃" if bool(binding.get("ctrl", false)) else "") \
			+ ("⌥" if bool(binding.get("alt", false)) else "") \
			+ ("⇧" if bool(binding.get("shift", false)) else "") \
			+ ("⌘" if bool(binding.get("meta", false)) else "") + key_text
	var parts: Array[String] = []
	if bool(binding.get("ctrl", false)):
		parts.append("Ctrl")
	if bool(binding.get("alt", false)):
		parts.append("Alt")
	if bool(binding.get("shift", false)):
		parts.append("Shift")
	if bool(binding.get("meta", false)):
		parts.append("Meta")
	parts.append(key_text)
	return "+".join(parts)

func _shortcut_action_label(action: String) -> String:
	return {
		"undo": _l("撤销", "Undo"), "redo": _l("重做", "Redo"),
		"erase": _l("删除数字", "Erase value"), "notes": _l("切换笔记", "Toggle notes"),
		"pause": _l("暂停或继续", "Pause or resume"), "hint": _l("提示", "Hint"),
		"new_game": _l("新游戏", "New game"), "settings": _l("打开设置", "Open settings")
	}.get(action, action)

func _begin_shortcut_capture(action: String, button: Button) -> void:
	_cancel_shortcut_capture()
	_capturing_shortcut = action
	_shortcut_capture_button = button
	button.text = _l("请按下新快捷键…", "Press new shortcut…")
	button.theme_type_variation = "ActiveToolButton"
	button.grab_focus()

func _capture_shortcut_event(event: InputEventKey) -> void:
	if event.keycode == KEY_ESCAPE:
		_cancel_shortcut_capture()
		return
	var binding := _event_to_binding(event)
	if int(binding.get("keycode", 0)) in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
		return
	for other_action in SHORTCUT_ACTIONS:
		if other_action != _capturing_shortcut and _bindings_equal(binding, _binding_for(other_action)):
			_show_toast(_l("该快捷键已用于“%s”", "Shortcut is already used by “%s”") % _shortcut_action_label(other_action))
			return
	var shortcuts: Dictionary = AppState.settings.get("shortcuts", {}).duplicate(true)
	shortcuts[_capturing_shortcut] = binding
	AppState.settings["shortcuts"] = shortcuts
	AppState.save_settings()
	if _shortcut_capture_button != null and is_instance_valid(_shortcut_capture_button):
		_shortcut_capture_button.text = _shortcut_display(binding)
		_shortcut_capture_button.theme_type_variation = "ShortcutButton"
	_capturing_shortcut = ""
	_shortcut_capture_button = null
	_show_toast(_l("快捷键已更新", "Shortcut updated"))

func _cancel_shortcut_capture() -> void:
	if _shortcut_capture_button != null and is_instance_valid(_shortcut_capture_button) and not _capturing_shortcut.is_empty():
		_shortcut_capture_button.text = _shortcut_display(_binding_for(_capturing_shortcut))
		_shortcut_capture_button.theme_type_variation = "ShortcutButton"
	_capturing_shortcut = ""
	_shortcut_capture_button = null

func _restore_shortcut_defaults() -> void:
	AppState.settings["shortcuts"] = _default_shortcuts()
	AppState.settings["shortcut_platform"] = OS.get_name()
	AppState.save_settings()
	_show_settings()
	_show_toast(_l("已恢复系统默认快捷键", "System-default shortcuts restored"))

func _show_menu() -> void:
	_current_view = "menu"
	_clear_content()
	content.alignment = BoxContainer.ALIGNMENT_CENTER if _is_wide_layout() else BoxContainer.ALIGNMENT_BEGIN
	var wide := _is_wide_layout()
	var menu_parent: Container = content
	if not wide:
		var menu_scroll := _page_scroll()
		content.add_child(menu_scroll)
		var menu_body := VBoxContainer.new()
		menu_body.add_theme_constant_override("separation", 16)
		menu_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		menu_scroll.add_child(menu_body)
		menu_parent = menu_body
	var hero := PanelContainer.new()
	hero.name = "HomeHero"
	hero.theme_type_variation = "HomeHero"
	hero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_parent.add_child(hero)
	var hero_margin := MarginContainer.new()
	hero_margin.add_theme_constant_override("margin_left", 24 if wide else 18)
	hero_margin.add_theme_constant_override("margin_right", 24 if wide else 18)
	hero_margin.add_theme_constant_override("margin_top", 20 if wide else 16)
	hero_margin.add_theme_constant_override("margin_bottom", 20 if wide else 16)
	hero.add_child(hero_margin)
	var hero_body := VBoxContainer.new()
	hero_body.add_theme_constant_override("separation", 10)
	hero_margin.add_child(hero_body)
	_add_heading(_l("今天，解一道数独", "Make time for a Sudoku"), _l("选择模式开始；未完成的进度会自动保存在本机。", "Choose a mode to begin. Your progress is saved on this device."), _l("离线优先 · 隐私友好", "OFFLINE FIRST · PRIVATE"), hero_body)
	var continue_info := _find_latest_saved_game()
	var primary_parent: Container = menu_parent
	var quick_parent: Container = menu_parent
	if wide:
		var dashboard := HBoxContainer.new()
		dashboard.add_theme_constant_override("separation", 36)
		dashboard.custom_minimum_size.y = 600
		dashboard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		menu_parent.add_child(dashboard)
		var primary := _home_panel_column(dashboard)
		primary_parent = primary
		var quick := _home_panel_column(dashboard)
		quick_parent = quick
	_add_home_section_heading(primary_parent, _l("游戏模式", "Play"), _l("选择你此刻想要的挑战方式", "Choose the challenge that feels right"))
	if not continue_info.is_empty():
		_add_home_action(
			primary_parent,
			_l("继续上次游戏", "Continue game"),
			_l("%s难度 · 恢复上次未完成的棋盘", "%s · Resume your unfinished board") % _difficulty_name(int(continue_info["difficulty"])),
			_resume_saved.bind(str(continue_info["mode"]), int(continue_info["difficulty"])),
			wide
		)
	_add_home_action(primary_parent, _l("新建本地游戏", "New local game"), _l("六档难度 · 支持 9×9 与 16×16 · 完全离线", "Six levels · 9×9 and 16×16 · Fully offline"), _show_difficulty.bind(false), wide)
	_add_home_action(primary_parent, _l("排位挑战", "Ranked challenge"), _l("六档难度 · 离线可玩 · 完成后自行选择是否上传", "Six levels · Play offline · Choose whether to upload after completion"), _show_difficulty.bind(true), wide)
	_add_home_section_heading(quick_parent, _l("记录与设置", "Progress & Settings"), _l("查看进度，调整你的游戏体验", "Review progress and tailor your experience"))
	_add_home_action(quick_parent, _l("个人统计", "Statistics"), _l("完成局数、胜率、连胜与各难度时间纪录", "Games, win rate, streaks and time records"), Callable(self, "_show_statistics"), wide)
	_add_home_action(quick_parent, _l("排行榜", "Leaderboard"), _l("查看缓存排名；联网时可获取最新成绩", "View cached rankings or refresh online"), Callable(self, "_show_leaderboard"), wide)
	_add_home_action(quick_parent, _l("偏好设置", "Settings"), _l("主题、语言、辅助功能、显示名称与本地数据", "Theme, language, accessibility, profile and data"), Callable(self, "_show_settings"), wide)
	var privacy := Label.new()
	privacy.text = _l("本地唯一解 · 自动保存 · 无广告 · 无追踪", "Unique puzzles · Auto-save · No ads · No tracking")
	privacy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	privacy.add_theme_font_size_override("font_size", 20)
	privacy.add_theme_color_override("font_color", theme.get_color("muted", "App"))
	menu_parent.add_child(privacy)

func _show_difficulty(ranked: bool) -> void:
	_current_view = "difficulty"
	_difficulty_ranked = ranked
	_clear_content()
	_add_back_header(_l("选择难度", "Choose difficulty"), _l("排位挑战", "Ranked challenge") if ranked else _l("本地游戏", "Local game"))
	var wide := _is_wide_layout()
	var difficulty_scroll := _page_scroll()
	content.add_child(difficulty_scroll)
	var difficulty_body := VBoxContainer.new()
	difficulty_body.name = "DifficultyBody"
	difficulty_body.add_theme_constant_override("separation", 18)
	difficulty_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	difficulty_scroll.add_child(difficulty_body)
	var intro := PanelContainer.new()
	intro.theme_type_variation = "DifficultyIntro"
	intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	difficulty_body.add_child(intro)
	var intro_margin := MarginContainer.new()
	intro_margin.add_theme_constant_override("margin_left", 24)
	intro_margin.add_theme_constant_override("margin_right", 24)
	intro_margin.add_theme_constant_override("margin_top", 17)
	intro_margin.add_theme_constant_override("margin_bottom", 17)
	intro.add_child(intro_margin)
	var intro_text := Label.new()
	intro_text.text = _l(
		"选择后将先显示公平规则；排位累计 3 次错误会结束本局，六档挑战均可离线缓存。" if ranked else "从轻松入门到 16×16 终极棋盘，选择适合当前节奏的一局。",
		"Review the fair-play rules before starting; 3 mistakes end a ranked game, and all six challenges support offline caching." if ranked else "Choose a pace from a relaxed introduction through the 16×16 Ultimate board."
	)
	intro_text.theme_type_variation = "HeroSubtitle"
	intro_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_margin.add_child(intro_text)
	var difficulty_grid := GridContainer.new()
	difficulty_grid.name = "DifficultyGrid"
	difficulty_grid.columns = 3 if wide else 1
	difficulty_grid.add_theme_constant_override("h_separation", 16)
	difficulty_grid.add_theme_constant_override("v_separation", 16)
	difficulty_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	difficulty_body.add_child(difficulty_grid)
	var count := 6
	for index in count:
		var descriptions := [_l("直接候选，适合初次体验", "Straightforward candidates for first-time play"), _l("基础排除，节奏轻松", "Gentle elimination and a relaxed pace"), _l("候选组合，需要专注", "Candidate combinations that need focus"), _l("复杂排除，挑战推理", "Advanced elimination and deeper reasoning"), _l("深层逻辑与有限搜索", "Layered logic with limited search"), _l("16×16 棋盘 · 使用 1–9 与 A–G", "16×16 board · Uses 1–9 and A–G")]
		var card := PanelContainer.new()
		card.theme_type_variation = "DifficultyCard"
		card.custom_minimum_size.y = 176 if wide else 150
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		difficulty_grid.add_child(card)
		var card_margin := MarginContainer.new()
		card_margin.add_theme_constant_override("margin_left", 18)
		card_margin.add_theme_constant_override("margin_right", 18)
		card_margin.add_theme_constant_override("margin_top", 16)
		card_margin.add_theme_constant_override("margin_bottom", 16)
		card.add_child(card_margin)
		var card_body := VBoxContainer.new()
		card_body.add_theme_constant_override("separation", 10)
		card_margin.add_child(card_body)
		var meta := Label.new()
		meta.text = (_l("16×16 · 终极棋盘", "16×16 · Ultimate grid") if index == 5 else _l("9×9 · 第 %d 档", "9×9 · Level %d") % (index + 1))
		meta.theme_type_variation = "EyebrowLabel"
		card_body.add_child(meta)
		var button := _button(_difficulty_name(index), descriptions[index])
		button.theme_type_variation = "DifficultyButton"
		button.custom_minimum_size.y = 70 if wide else 72
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_choose_difficulty.bind(index, ranked))
		card_body.add_child(button)
		var description := Label.new()
		description.text = descriptions[index]
		description.theme_type_variation = "SectionSummary"
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_body.add_child(description)

func _choose_difficulty(difficulty: int, ranked: bool) -> void:
	if ranked:
		_ranked_resume_session = null
		_show_ranked_briefing(difficulty)
	else:
		_show_loading(_l("正在后台生成唯一解题目…", "Generating a unique puzzle…"))
		game_service.generate_async(difficulty)

func _show_ranked_briefing(difficulty: int, saved_session: GameSession = null) -> void:
	_current_view = "ranked_briefing"
	_ranked_difficulty = clampi(difficulty, 0, 5)
	_ranked_resume_session = saved_session
	_clear_content()
	_add_back_header(_l("排位公平规则", "Ranked Fair-Play Rules"), _difficulty_name(_ranked_difficulty))
	var scroll := _page_scroll()
	content.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var card := PanelContainer.new()
	card.name = "RankedBriefingCard"
	card.theme_type_variation = "RankedBriefingCard"
	card.custom_minimum_size.x = 820 if _is_wide_layout() else maxf(280.0, size.x - 54.0)
	center.add_child(card)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 26)
	card.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	margin.add_child(body)
	var eyebrow := Label.new()
	eyebrow.text = _l("公平竞赛", "FAIR PLAY")
	eyebrow.theme_type_variation = "EyebrowLabel"
	body.add_child(eyebrow)
	var title := Label.new()
	title.text = _l("继续排位：保留基础操作，限制解题辅助", "Resume ranked play with core controls and limited assistance") if saved_session != null else _l("保留基础操作，关闭解题辅助", "Core controls remain available; puzzle assistance is restricted")
	title.add_theme_font_size_override("font_size", 32)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(title)
	var rules := Label.new()
	rules.text = _l(
		"• 不显示同行、同列、宫格与相同数字高亮\n• 自动检查并显示错误；累计 3 次错误后本局立即结束\n• 不自动清理草稿，也不隐藏已经填满的数字\n• 草稿、撤销、重做和暂停可用；提示不可用",
		"• No row, column, box or matching-value highlights\n• Mistakes are checked and shown; the game ends immediately after 3 mistakes\n• Notes are not cleared automatically, and completed number keys remain visible\n• Notes, undo, redo and pause are available; hints are unavailable"
	)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules.add_theme_constant_override("line_spacing", 8)
	body.add_child(rules)
	var temporary := PanelContainer.new()
	temporary.theme_type_variation = "RankedNotice"
	body.add_child(temporary)
	var temporary_text := Label.new()
	temporary_text.text = _l("上述辅助限制和三次错误规则只对本局生效，不会修改全局设置。离线排位完成后同样可选择上传；成绩会先保存在本机，联网刷新排行榜时提交。", "These assistance limits and the three-mistake rule apply only to this game and never change global settings. Completed offline ranked results can also be uploaded; they remain on this device until the next online leaderboard refresh.")
	temporary_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	temporary.add_child(temporary_text)
	var actions: BoxContainer = HBoxContainer.new() if _is_wide_layout() else VBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	body.add_child(actions)
	var start := _button(_l("同意规则并继续", "Accept rules and resume") if saved_session != null else _l("同意规则并开始", "Accept rules and start"))
	start.theme_type_variation = "PrimaryActionButton"
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start.pressed.connect(_resume_ranked_after_briefing.bind(saved_session) if saved_session != null else _begin_ranked_challenge.bind(_ranked_difficulty))
	actions.add_child(start)
	var cancel := _button(_l("返回选择难度", "Back to difficulties"))
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(_show_difficulty.bind(true))
	actions.add_child(cancel)

func _begin_ranked_challenge(difficulty: int) -> void:
	_ranked_resume_session = null
	_ranked_difficulty = clampi(difficulty, 0, 5)
	_pending_offline_ranked = false
	_show_loading(_l("正在获取排位题目…", "Fetching ranked puzzle…"))
	var cached := challenge_service.cached(_ranked_difficulty)
	if not cached.is_empty() and (not NetworkManager.online or not AppConfig.online_configured()):
		_on_challenge_received(cached)
	elif not NetworkManager.online or not AppConfig.online_configured():
		_start_offline_ranked()
	else:
		challenge_service.fetch(_ranked_difficulty)

func _start_offline_ranked() -> void:
	_pending_offline_ranked = true
	_show_loading(_l("正在生成离线排位题目…", "Generating an offline ranked puzzle…"))
	if not game_service.generate_async(_ranked_difficulty):
		_pending_offline_ranked = false
		_show_toast(_l("题目生成任务正在运行，请稍后重试", "Puzzle generation is already running. Try again shortly."))
		_show_difficulty(true)

func _resume_ranked_after_briefing(saved_session: GameSession) -> void:
	if saved_session == null:
		_show_difficulty(true)
		return
	_ranked_resume_session = null
	game_service.resume_session(saved_session)
	_show_game()

func _show_loading(message: String) -> void:
	_current_view = "loading"
	_clear_content()
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)
	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 26)
	content.add_child(label)
	var hint := Label.new()
	hint.text = _l("生成和验证不会阻塞界面", "Generation and validation run without freezing the interface")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(hint)
	var bottom := Control.new()
	bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(bottom)

func _on_generation_finished(result: Dictionary) -> void:
	if _pending_offline_ranked:
		_pending_offline_ranked = false
		var ranked_session := GameSession.create(result["puzzle"], result["solution"], int(result["difficulty"]), "ranked")
		ranked_session.offline_ranked = true
		AppState.record_start(ranked_session.difficulty)
		game_service.resume_session(ranked_session)
		_show_toast(_l("已开始离线排位，完成后可选择是否上传", "Offline ranked game started; choose whether to upload after completion."))
	else:
		game_service.start_session(result)
	_show_game()

func _on_generation_failed(message: String) -> void:
	var ranked_generation := _pending_offline_ranked
	_pending_offline_ranked = false
	_show_toast(message)
	if _current_view == "loading":
		_show_difficulty(ranked_generation)

func _on_challenge_received(challenge: Dictionary) -> void:
	_pending_offline_ranked = false
	var puzzle := SudokuValidator.string_to_board(str(challenge.get("puzzle", "")))
	var solution := SudokuSolver.new().solve(puzzle) if puzzle.size() == 81 else GridSolver.new(16, 4).solve(puzzle)
	var solution_count := SudokuSolver.new().count_solutions(puzzle, 2) if puzzle.size() == 81 else GridSolver.new(16, 4).count_solutions(puzzle, 2)
	var expected_size := 256 if _ranked_difficulty == 5 else 81
	if puzzle.size() != expected_size or solution.is_empty() or solution_count != 1:
		_show_toast(_l("排位题目校验失败", "Ranked puzzle validation failed"))
		_start_offline_ranked()
		return
	var session := GameSession.create(puzzle, solution, _ranked_difficulty, "ranked")
	session.challenge_id = str(challenge.get("challenge_id", ""))
	session.challenge_token = str(challenge.get("challenge_token", ""))
	session.offline_ranked = not NetworkManager.online or not AppConfig.online_configured()
	AppState.record_start(session.difficulty)
	game_service.resume_session(session)
	_show_game()

func _on_challenge_failed(message: String) -> void:
	var cached := challenge_service.cached(_ranked_difficulty)
	if not cached.is_empty():
		_show_toast(_l("网络不可用，已使用缓存题目", "Network unavailable. Using a cached puzzle."))
		_on_challenge_received(cached)
	else:
		_show_toast(_l("在线排位暂不可用，已切换为离线排位", "Online ranked play is unavailable; starting an offline ranked game."))
		_start_offline_ranked()

func _show_game() -> void:
	_current_view = "game"
	_clear_content()
	cell_buttons.clear()
	_completed_units.clear()
	_completed_units_initialized = false
	_last_mistake_count = -1
	var wide := _is_wide_layout()
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	content.add_child(header)
	var back := _icon_button("", "back", _l("返回", "Back"))
	back.custom_minimum_size = Vector2(54, 54)
	back.pressed.connect(_confirm_leave_game)
	header.add_child(back)
	var title := Label.new()
	var mode_title := _l("离线排位 · ", "Offline Ranked · ") if game_service.session.offline_ranked else (_l("排位 · ", "Ranked · ") if game_service.session.mode == "ranked" else _l("本地 · ", "Local · "))
	title.text = mode_title + _difficulty_name(game_service.session.difficulty)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", theme.get_color("accent", "App"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)
	timer_label = Label.new()
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(timer_label)
	var mistakes_box := HBoxContainer.new()
	mistakes_box.add_theme_constant_override("separation", 5)
	mistakes_box.custom_minimum_size.x = 122 if game_service.session.mode == "ranked" else 96
	header.add_child(mistakes_box)
	mistake_icon = TextureRect.new()
	mistake_icon.name = "MistakeLevelIcon"
	mistake_icon.texture = ICONS["error"]
	mistake_icon.custom_minimum_size = Vector2(24, 24)
	mistake_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mistake_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mistakes_box.add_child(mistake_icon)
	mistakes_label = Label.new()
	mistakes_label.custom_minimum_size.x = 92 if game_service.session.mode == "ranked" else 66
	mistakes_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mistakes_box.add_child(mistakes_label)
	if game_service.session.mode == "ranked":
		var ranked_notice := PanelContainer.new()
		ranked_notice.name = "RankedGameNotice"
		ranked_notice.theme_type_variation = "RankedNotice"
		content.add_child(ranked_notice)
		var ranked_notice_text := Label.new()
		ranked_notice_text.text = _l(
			"离线排位 · 可暂停和撤销重做；3 次错误结束，完成后可选择上传" if game_service.session.offline_ranked else "公平模式 · 可暂停和撤销重做；累计 3 次错误结束本局",
			"Offline ranked · Pause, undo and redo are available; 3 mistakes end the game, and completed results can be uploaded" if game_service.session.offline_ranked else "Fair-play mode · Pause, undo and redo are available; 3 mistakes end the game"
		)
		ranked_notice_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ranked_notice_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ranked_notice.add_child(ranked_notice_text)
	var available_width := maxf(content.size.x, size.x - 64.0)
	var controls_width := clampf(available_width * 0.34, 500.0, 720.0)
	var side := clampf(minf(size.y * 0.68, available_width - controls_width - 48.0), 440.0, 1120.0) if wide else minf(size.x - 40.0, size.y * 0.54)
	var board_center := _build_board(side)
	var controls := _build_game_controls(wide)
	if wide:
		var game_body := HBoxContainer.new()
		game_body.add_theme_constant_override("separation", 52)
		game_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		game_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_child(game_body)
		board_center.size_flags_stretch_ratio = 1.7
		game_body.add_child(board_center)
		controls.custom_minimum_size.x = controls_width
		controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		controls.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		game_body.add_child(controls)
	else:
		var game_scroll := _page_scroll()
		content.add_child(game_scroll)
		var compact_game := VBoxContainer.new()
		compact_game.add_theme_constant_override("separation", 18)
		compact_game.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		game_scroll.add_child(compact_game)
		compact_game.add_child(board_center)
		compact_game.add_child(controls)
	_refresh_game()

func _build_board(side: float) -> CenterContainer:
	var board_center := CenterContainer.new()
	board_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var panel := PanelContainer.new()
	panel.theme_type_variation = "GameBoardPanel"
	panel.custom_minimum_size = Vector2(side, side)
	board_center.add_child(panel)
	var board_margin := MarginContainer.new()
	board_margin.add_theme_constant_override("margin_left", 6)
	board_margin.add_theme_constant_override("margin_right", 6)
	board_margin.add_theme_constant_override("margin_top", 6)
	board_margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(board_margin)
	var board := GridContainer.new()
	board.columns = game_service.session.grid_size
	board.add_theme_constant_override("h_separation", 0)
	board.add_theme_constant_override("v_separation", 0)
	board_margin.add_child(board)
	for index in game_service.session.board.size():
		var cell := SudokuCellButton.new()
		cell.configure(index, game_service.session.grid_size, game_service.session.box_size)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cell.pressed.connect(_play_selection_sound)
		cell.pressed.connect(game_service.select.bind(index))
		board.add_child(cell)
		cell_buttons.append(cell)
	var overlay_margin := MarginContainer.new()
	overlay_margin.add_theme_constant_override("margin_left", 0)
	overlay_margin.add_theme_constant_override("margin_right", 0)
	overlay_margin.add_theme_constant_override("margin_top", 0)
	overlay_margin.add_theme_constant_override("margin_bottom", 0)
	overlay_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(overlay_margin)
	pause_overlay = PanelContainer.new()
	pause_overlay.theme_type_variation = "PauseBoardOverlay"
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_overlay.visible = false
	overlay_margin.add_child(pause_overlay)
	pause_blur_layer = ColorRect.new()
	pause_blur_layer.name = "PauseBlurLayer"
	pause_blur_layer.color = Color.WHITE
	pause_blur_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var blur_shader := Shader.new()
	blur_shader.code = PAUSE_BLUR_SHADER_CODE
	var blur_material := ShaderMaterial.new()
	blur_material.shader = blur_shader
	blur_material.set_shader_parameter("blur_lod", 5.8)
	blur_material.set_shader_parameter("tint_color", Color(theme.get_color("surface", "App"), 0.40))
	pause_blur_layer.material = blur_material
	pause_overlay.add_child(pause_blur_layer)
	var pause_center := CenterContainer.new()
	pause_overlay.add_child(pause_center)
	var pause_card := PanelContainer.new()
	pause_card.theme_type_variation = "PauseMessageCard"
	pause_card.custom_minimum_size = Vector2(320, 190)
	pause_center.add_child(pause_card)
	var pause_content := VBoxContainer.new()
	pause_content.alignment = BoxContainer.ALIGNMENT_CENTER
	pause_content.add_theme_constant_override("separation", 14)
	pause_card.add_child(pause_content)
	var pause_title := Label.new()
	pause_title.text = _l("游戏已暂停", "Game Paused")
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_title.add_theme_font_size_override("font_size", 34)
	pause_content.add_child(pause_title)
	var pause_subtitle := Label.new()
	pause_subtitle.text = _l("计时已停止", "The timer is stopped")
	pause_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_subtitle.add_theme_color_override("font_color", theme.get_color("muted", "App"))
	pause_content.add_child(pause_subtitle)
	var resume := _icon_button(_l("继续游戏", "Resume"), "play")
	resume.pressed.connect(_toggle_pause)
	pause_content.add_child(resume)
	var board_outline := Panel.new()
	board_outline.name = "BoardOutline"
	board_outline.theme_type_variation = "GameBoardOutline"
	board_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_outline.z_index = 20
	panel.add_child(board_outline)
	return board_center

func _build_game_controls(wide: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "GameControlsPanel"
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	var controls := VBoxContainer.new()
	controls.add_theme_constant_override("separation", 16)
	margin.add_child(controls)
	if wide:
		_add_section_title(controls, _l("操作面板", "Controls"))
	var tools := GridContainer.new()
	tools.columns = 2 if wide else 5
	tools.add_theme_constant_override("h_separation", 10)
	tools.add_theme_constant_override("v_separation", 10)
	controls.add_child(tools)
	for tool in [[_l("撤销", "Undo"), "undo", Callable(game_service, "undo")], [_l("重做", "Redo"), "redo", Callable(game_service, "redo")], [_l("删除", "Erase"), "erase", Callable(game_service, "erase")]]:
		var button := _icon_button(str(tool[0]), str(tool[1]), str(tool[0]))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(tool[2])
		tools.add_child(button)
	notes_button = _icon_button(_l("草稿", "Notes"), "notes", _l("草稿模式", "Notes mode"))
	notes_button.toggle_mode = true
	notes_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notes_button.pressed.connect(_toggle_notes)
	tools.add_child(notes_button)
	pause_button = _icon_button(_l("暂停", "Pause"), "pause", _l("暂停或继续", "Pause or resume"))
	pause_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_button.pressed.connect(_toggle_pause)
	tools.add_child(pause_button)
	var numpad := GridContainer.new()
	numpad.columns = (4 if wide else 8) if game_service.session.grid_size == 16 else (3 if wide else 9)
	numpad.add_theme_constant_override("h_separation", 8)
	numpad.add_theme_constant_override("v_separation", 8)
	controls.add_child(numpad)
	for value in range(1, game_service.session.grid_size + 1):
		var number := _button(SudokuCellButton.value_label(value))
		number.theme_type_variation = "NumberPadButton"
		number.custom_minimum_size.y = 88 if wide else 72
		number.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		number.pressed.connect(game_service.enter_number.bind(value))
		numpad.add_child(number)
		number_buttons[value] = number
	if game_service.session.mode == "local":
		var hint_button := _icon_button(_l("提示", "Hint"), "hint", _l("填入当前格；本地成绩会记录提示次数", "Fill the current cell; local stats record hint use"))
		hint_button.pressed.connect(game_service.hint)
		controls.add_child(hint_button)
	return panel

func _refresh_game() -> void:
	if _current_view != "game" or game_service.session == null:
		return
	var selected := game_service.selected_index
	var selected_value := game_service.session.board[selected] if selected >= 0 else 0
	var selected_notes := game_service.session.notes[selected] if selected >= 0 and selected_value == 0 else 0
	var grid_size := game_service.session.grid_size
	var box_size := game_service.session.box_size
	var auto_check := game_service.effective_setting("auto_check", true)
	var highlight_same := game_service.effective_setting("highlight_same", true)
	var highlighted_note_values := ((1 << selected_value) if selected_value != 0 else selected_notes) if highlight_same else 0
	var conflicts: Variant = (SudokuValidator.conflicts(game_service.session.board) if grid_size == 9 else GridSolver.new(grid_size, box_size).conflicts(game_service.session.board)) if auto_check else {}
	for index in mini(game_service.session.board.size(), cell_buttons.size()):
		var row := index / grid_size
		var column := index % grid_size
		var selected_row := selected / grid_size if selected >= 0 else -1
		var selected_column := selected % grid_size if selected >= 0 else -1
		var related := row == selected_row or column == selected_column or (row / box_size == selected_row / box_size and column / box_size == selected_column / box_size)
		var value := game_service.session.board[index]
		cell_buttons[index].disabled = game_service.paused
		var notes := game_service.session.notes[index]
		cell_buttons[index].update_state(
			value,
			notes,
			game_service.session.is_clue(index),
			index == selected,
			related and game_service.effective_setting("highlight_related", true),
			selected_value != 0 and value == selected_value and highlight_same,
			auto_check and conflicts.has(index),
			notes & highlighted_note_values
		)
	_update_completed_unit_animations()
	var value_counts := PackedInt32Array()
	value_counts.resize(grid_size + 1)
	for board_value in game_service.session.board:
		if board_value > 0 and board_value <= grid_size:
			value_counts[board_value] += 1
	var hide_completed := game_service.effective_setting("hide_completed_numbers", true)
	for value in number_buttons:
		var number_button: Button = number_buttons[value]
		if is_instance_valid(number_button):
			var completed_value := hide_completed and value_counts[int(value)] >= grid_size
			number_button.visible = true
			number_button.text = "" if completed_value else SudokuCellButton.value_label(int(value))
			number_button.disabled = completed_value
			number_button.focus_mode = Control.FOCUS_NONE if completed_value else Control.FOCUS_ALL
			number_button.mouse_filter = Control.MOUSE_FILTER_IGNORE if completed_value else Control.MOUSE_FILTER_STOP
			number_button.theme_type_variation = "NumberPadPlaceholder" if completed_value else "NumberPadButton"
	if timer_label != null:
		timer_label.text = _format_time(game_service.session.elapsed_ms)
	if mistakes_label != null:
		var show_mistakes := game_service.effective_setting("show_mistakes", true)
		var mistake_count := game_service.session.mistakes
		var ranked := game_service.session.mode == "ranked"
		var danger := mistake_count >= 3
		mistakes_label.text = (_l("错误 %d / 3", "%d / 3 errors") % mistake_count) if ranked else ((_l("错误 %d", "%d errors") % mistake_count) if show_mistakes else "")
		var indicator_color := theme.get_color("muted", "App")
		if ranked and mistake_count == 1:
			indicator_color = Color("ff9f0a")
		elif ranked and mistake_count == 2:
			indicator_color = Color("ff6b35")
		elif danger:
			indicator_color = Color("ff453a")
		mistakes_label.add_theme_color_override("font_color", indicator_color if ranked and mistake_count > 0 else (Color("ff453a") if danger else theme.get_color("text", "App")))
		if mistake_icon != null:
			mistake_icon.visible = ranked or show_mistakes
			mistake_icon.texture = ICONS["warning"] if mistake_count >= 2 else ICONS["error"]
			mistake_icon.modulate = Color(indicator_color, 0.0) if ranked and mistake_count == 0 else indicator_color
			if mistake_count > _last_mistake_count and mistake_count in [1, 2, 3]:
				mistake_icon.scale = Vector2(0.78, 0.78)
				create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(mistake_icon, "scale", Vector2.ONE, 0.28)
		_last_mistake_count = mistake_count
	if notes_button != null:
		notes_button.text = _l("草稿", "Notes")
		notes_button.button_pressed = game_service.notes_mode
		notes_button.theme_type_variation = "NotesActiveButton" if game_service.notes_mode else "Button"
	if pause_button != null:
		pause_button.text = _l("继续", "Resume") if game_service.paused else _l("暂停", "Pause")
		pause_button.icon = ICONS["play"] if game_service.paused else ICONS["pause"]
	if pause_overlay != null:
		pause_overlay.visible = game_service.paused

func _update_completed_unit_animations() -> void:
	if game_service.session == null or game_service.session.mode != "local":
		_completed_units.clear()
		_completed_units_initialized = false
		return
	var current := _completed_unit_indices()
	if _completed_units_initialized and not bool(AppState.settings.get("reduce_motion", false)):
		for key in current:
			if not _completed_units.has(key):
				var indices: Array = current[key]
				for offset in indices.size():
					var cell_index := int(indices[offset])
					if cell_index >= 0 and cell_index < cell_buttons.size():
						cell_buttons[cell_index].play_completion_pulse(float(offset) * 0.026)
	_completed_units = current
	_completed_units_initialized = true

func _completed_unit_indices() -> Dictionary:
	var result: Dictionary = {}
	var board := game_service.session.board
	var grid_size := game_service.session.grid_size
	var box_size := game_service.session.box_size
	for unit in grid_size:
		var row_indices: Array = []
		var column_indices: Array = []
		var row_complete := true
		var column_complete := true
		for offset in grid_size:
			var row_index := unit * grid_size + offset
			var column_index := offset * grid_size + unit
			row_indices.append(row_index)
			column_indices.append(column_index)
			row_complete = row_complete and board[row_index] != 0
			column_complete = column_complete and board[column_index] != 0
		if row_complete:
			result["row_%d" % unit] = row_indices
		if column_complete:
			result["column_%d" % unit] = column_indices
	for box_row in box_size:
		for box_column in box_size:
			var box_indices: Array = []
			var box_complete := true
			for row_offset in box_size:
				for column_offset in box_size:
					var index := (box_row * box_size + row_offset) * grid_size + box_column * box_size + column_offset
					box_indices.append(index)
					box_complete = box_complete and board[index] != 0
			if box_complete:
				result["box_%d_%d" % [box_row, box_column]] = box_indices
	return result

func _toggle_notes() -> void:
	game_service.notes_mode = not game_service.notes_mode
	_refresh_game()

func _toggle_pause() -> void:
	game_service.set_paused(not game_service.paused)
	_show_toast(_l("游戏已暂停", "Game paused") if game_service.paused else _l("继续游戏", "Game resumed"))

func _confirm_leave_game() -> void:
	AppState.save_session_now()
	_show_toast(_l("进度已保存", "Progress saved"))
	_show_menu()

func _on_game_completed(session: GameSession) -> void:
	_ranked_result_session = session if session.mode == "ranked" else null
	_pending_ranked_submission = _build_ranked_submission(session) if session.mode == "ranked" else {}
	_ranked_upload_state = ""
	if session.mode == "ranked":
		if bool(AppState.settings.get("ranked_auto_upload", false)):
			_queue_ranked_result(false)
		else:
			_ranked_upload_state = "choice"
	_show_result(session)

func _build_ranked_submission(session: GameSession) -> Dictionary:
	var source := "offline" if session.offline_ranked or session.challenge_id.is_empty() else "online"
	return {
		"challenge_id": session.challenge_id,
		"challenge_token": session.challenge_token,
		"source": source,
		"difficulty": session.difficulty + 1,
		"puzzle": SudokuValidator.board_to_string(session.puzzle),
		"installation_id": AppState.installation_id,
		"display_name": AppState.profile.get("display_name", "Player"),
		"duration_ms": session.elapsed_ms,
		"mistakes": session.mistakes,
		"hints_used": session.hints_used,
		"final_board": SudokuValidator.board_to_string(session.board),
		"move_count": session.operation_count,
		"move_digest": "",
		"client_version": AppConfig.APP_VERSION,
		"platform": OS.get_name().to_lower(),
		"completed_at": Time.get_datetime_string_from_system(true)
	}

func _queue_ranked_result(refresh_ui: bool = true) -> void:
	if _pending_ranked_submission.is_empty() or _ranked_result_session == null:
		return
	var submission_source := str(_pending_ranked_submission.get("source", "online"))
	SyncManager.enqueue(_pending_ranked_submission.duplicate(true))
	_pending_ranked_submission.clear()
	_ranked_upload_state = "queued"
	# Offline-ranked results deliberately stay local until the player next
	# refreshes the online leaderboard. Online results can submit immediately.
	if submission_source == "online" and NetworkManager.online and AppConfig.online_configured():
		SyncManager.flush_now()
	if refresh_ui:
		_show_result(_ranked_result_session)
		_show_toast(_l("成绩已保存到上传队列", "Result saved to the upload queue"))

func _decline_ranked_upload() -> void:
	if _ranked_result_session == null:
		return
	_pending_ranked_submission.clear()
	_ranked_upload_state = "declined"
	_show_result(_ranked_result_session)
	_show_toast(_l("本局成绩不会上传", "This result will not be uploaded"))

func _on_ranked_failed(session: GameSession) -> void:
	_current_view = "ranked_failed"
	_clear_content()
	var wide := _is_wide_layout()
	var failure_scroll := _page_scroll()
	content.add_child(failure_scroll)
	var failure_center := CenterContainer.new()
	failure_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	failure_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	failure_scroll.add_child(failure_center)
	var failure_card := PanelContainer.new()
	failure_card.name = "RankedFailureCard"
	failure_card.theme_type_variation = "ResultCard"
	failure_card.custom_minimum_size.x = 720 if wide else maxf(260.0, size.x - 60.0)
	failure_center.add_child(failure_card)
	var body := VBoxContainer.new()
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", 18)
	failure_card.add_child(body)
	var icon_center := CenterContainer.new()
	body.add_child(icon_center)
	var icon_panel := PanelContainer.new()
	icon_panel.theme_type_variation = "CompletionMark"
	icon_center.add_child(icon_panel)
	var icon := TextureRect.new()
	icon.texture = ICONS["warning"]
	icon.custom_minimum_size = Vector2(54, 54)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = Color("ff453a")
	icon_panel.add_child(icon)
	var kicker := Label.new()
	kicker.text = _l("排位已结束", "RANKED GAME ENDED")
	kicker.theme_type_variation = "EyebrowLabel"
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(kicker)
	var title := Label.new()
	title.text = _l("已达到错误上限", "Mistake limit reached")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42 if wide else 36)
	title.add_theme_color_override("font_color", Color("ff453a"))
	body.add_child(title)
	var subtitle := Label.new()
	subtitle.text = _l("第 3 次错误已记录，本局已自动结束。", "Your third mistake was recorded, so this game ended automatically.")
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 21)
	subtitle.add_theme_color_override("font_color", theme.get_color("muted", "App"))
	body.add_child(subtitle)
	var metrics := GridContainer.new()
	metrics.name = "RankedFailureMetrics"
	metrics.columns = 3 if size.x >= 390.0 else 1
	metrics.add_theme_constant_override("h_separation", 12)
	metrics.add_theme_constant_override("v_separation", 12)
	metrics.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(metrics)
	_add_result_metric(metrics, _l("用时", "TIME"), _format_time(session.elapsed_ms))
	_add_result_metric(metrics, _l("错误", "ERRORS"), str(session.mistakes))
	_add_result_metric(metrics, _l("操作", "MOVES"), str(session.operation_count))
	var explanation := PanelContainer.new()
	explanation.theme_type_variation = "RankedNotice"
	explanation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(explanation)
	var explanation_text := Label.new()
	explanation_text.text = _l("排位模式允许暂停、撤销、重做与草稿，但累计三次错误会结束本局，且不会提交排行榜成绩。", "Ranked play allows pause, undo, redo and notes, but three mistakes end the game and no leaderboard result is submitted.")
	explanation_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	explanation_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.add_child(explanation_text)
	var actions: BoxContainer = HBoxContainer.new() if wide else VBoxContainer.new()
	actions.add_theme_constant_override("separation", 14)
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(actions)
	var retry := _icon_button(_l("重新挑战", "Try again"), "play")
	retry.theme_type_variation = "PrimaryActionButton"
	retry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	retry.pressed.connect(_show_ranked_briefing.bind(session.difficulty))
	actions.add_child(retry)
	var menu := _button(_l("返回首页", "Home"))
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.pressed.connect(_show_menu)
	actions.add_child(menu)

func _show_result(session: GameSession) -> void:
	_current_view = "result"
	_clear_content()
	var wide := _is_wide_layout()
	var result_scroll := _page_scroll()
	content.add_child(result_scroll)
	var result_center := CenterContainer.new()
	result_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	result_scroll.add_child(result_center)
	var result_card := PanelContainer.new()
	result_card.name = "ResultCard"
	result_card.theme_type_variation = "ResultCard"
	result_card.custom_minimum_size.x = 760 if wide else maxf(260.0, size.x - 60.0)
	result_center.add_child(result_card)
	var result_body := VBoxContainer.new()
	result_body.alignment = BoxContainer.ALIGNMENT_CENTER
	result_body.add_theme_constant_override("separation", 18)
	result_card.add_child(result_body)
	var completion_mark_center := CenterContainer.new()
	result_body.add_child(completion_mark_center)
	var completion_mark := PanelContainer.new()
	completion_mark.theme_type_variation = "CompletionMark"
	completion_mark_center.add_child(completion_mark)
	var completion_icon := TextureRect.new()
	completion_icon.texture = ICONS["record"]
	completion_icon.custom_minimum_size = Vector2(54, 54)
	completion_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	completion_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	completion_icon.modulate = theme.get_color("accent", "App")
	completion_mark.add_child(completion_icon)
	var kicker := Label.new()
	kicker.text = _l("本局完成", "PUZZLE COMPLETE")
	kicker.theme_type_variation = "EyebrowLabel"
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_body.add_child(kicker)
	var result_title := Label.new()
	result_title.text = _l("解题完成", "Puzzle solved")
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.add_theme_font_size_override("font_size", 44 if wide else 38)
	result_body.add_child(result_title)
	var result_subtitle := Label.new()
	result_subtitle.text = _l("难度：", "Difficulty: ") + _difficulty_name(session.difficulty) + _l(" · 已完成", " · Completed")
	result_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_subtitle.add_theme_font_size_override("font_size", 22)
	result_subtitle.add_theme_color_override("font_color", theme.get_color("muted", "App"))
	result_body.add_child(result_subtitle)
	var metrics := GridContainer.new()
	metrics.name = "ResultMetrics"
	metrics.columns = 3 if size.x >= 390.0 else 1
	metrics.add_theme_constant_override("h_separation", 12)
	metrics.add_theme_constant_override("v_separation", 12)
	metrics.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_body.add_child(metrics)
	_add_result_metric(metrics, _l("用时", "TIME"), _format_time(session.elapsed_ms))
	_add_result_metric(metrics, _l("错误", "ERRORS"), str(session.mistakes))
	_add_result_metric(metrics, _l("操作", "MOVES"), str(session.operation_count))
	if session.new_best:
		var record_panel := PanelContainer.new()
		record_panel.theme_type_variation = "RecordPanel"
		record_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		result_body.add_child(record_panel)
		var record_row := HBoxContainer.new()
		record_row.add_theme_constant_override("separation", 14)
		record_panel.add_child(record_row)
		var record_icon := TextureRect.new()
		record_icon.texture = ICONS["record"]
		record_icon.custom_minimum_size = Vector2(38, 38)
		record_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		record_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		record_icon.modulate = theme.get_color("accent", "App")
		record_row.add_child(record_icon)
		var record_copy := VBoxContainer.new()
		record_copy.add_theme_constant_override("separation", 3)
		record_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		record_row.add_child(record_copy)
		var record_title := Label.new()
		record_title.text = _l("恭喜，刷新时间纪录！", "New personal best!")
		record_title.add_theme_font_size_override("font_size", 28 if wide else 25)
		record_title.add_theme_color_override("font_color", theme.get_color("accent", "App"))
		record_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		record_copy.add_child(record_title)
		var record_detail := Label.new()
		record_detail.text = _l("新纪录 · 难度：", "New record · Difficulty: ") + _difficulty_name(session.difficulty) + " · " + _format_time(session.elapsed_ms)
		record_detail.add_theme_color_override("font_color", theme.get_color("muted", "App"))
		record_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		record_copy.add_child(record_detail)
	var hints_note := Label.new()
	hints_note.text = _l("本局使用提示 %d 次", "%d hints used") % session.hints_used
	hints_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hints_note.add_theme_font_size_override("font_size", 20)
	hints_note.add_theme_color_override("font_color", theme.get_color("muted", "App"))
	result_body.add_child(hints_note)
	if session.mode == "ranked":
		_add_ranked_upload_panel(result_body, session, wide)
	var actions: BoxContainer = HBoxContainer.new() if wide else VBoxContainer.new()
	actions.name = "ResultActions"
	actions.add_theme_constant_override("separation", 14)
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_body.add_child(actions)
	var again := _icon_button(_l("再来一局", "Play again"), "play")
	again.theme_type_variation = "PrimaryActionButton"
	again.custom_minimum_size = Vector2(250 if wide else 0, 72)
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.pressed.connect(_show_difficulty.bind(session.mode == "ranked"))
	actions.add_child(again)
	var menu := _button(_l("返回首页", "Home"))
	menu.custom_minimum_size = Vector2(250 if wide else 0, 72)
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.pressed.connect(_show_menu)
	actions.add_child(menu)

func _add_ranked_upload_panel(parent: Container, session: GameSession, wide: bool) -> void:
	var panel := PanelContainer.new()
	panel.name = "RankedUploadChoice"
	panel.theme_type_variation = "RankedNotice"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	panel.add_child(body)
	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	body.add_child(title)
	var detail := Label.new()
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.theme_type_variation = "SectionSummary"
	body.add_child(detail)
	if _ranked_upload_state == "choice":
		title.text = _l("是否上传本局成绩？", "Upload this result?")
		detail.text = _l(
			"当前为离线排位，选择上传后会先保存在本机，下次联网刷新排行榜时提交。" if session.offline_ranked else "你可以将成绩上传到排行榜，也可以仅保留本地统计。",
			"This offline result will stay on this device and upload before the next online leaderboard refresh." if session.offline_ranked else "You can upload this result to the leaderboard or keep it only in local statistics."
		)
		var actions: BoxContainer = HBoxContainer.new() if wide else VBoxContainer.new()
		actions.add_theme_constant_override("separation", 10)
		actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.add_child(actions)
		var upload := _button(_l("上传到排行榜", "Upload to leaderboard"))
		upload.name = "RankedUploadButton"
		upload.theme_type_variation = "PrimaryActionButton"
		upload.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		upload.pressed.connect(_queue_ranked_result)
		actions.add_child(upload)
		var decline := _button(_l("不上传", "Don't upload"))
		decline.name = "RankedDeclineButton"
		decline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		decline.pressed.connect(_decline_ranked_upload)
		actions.add_child(decline)
	elif _ranked_upload_state == "queued":
		title.text = _l("成绩已加入上传队列", "Result queued for upload")
		detail.text = _l(
			"联网刷新排行榜时会先上传本地待传成绩，再获取更新后的排名。",
			"Saved results upload before the leaderboard is refreshed the next time you are online."
		)
	else:
		title.text = _l("本局选择不上传", "Result kept private")
		detail.text = _l("成绩只计入本机个人统计，不会进入排行榜。", "This result remains in local statistics and will not appear on the leaderboard.")

func _show_statistics() -> void:
	_current_view = "statistics"
	_clear_content()
	_add_back_header(_l("个人统计", "Statistics"), _l("只保存在此设备", "Stored only on this device"))
	var wide := _is_wide_layout()
	var stats_scroll := _page_scroll()
	content.add_child(stats_scroll)
	var stats_body := VBoxContainer.new()
	stats_body.name = "StatisticsBody"
	stats_body.add_theme_constant_override("separation", 20)
	stats_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_scroll.add_child(stats_body)
	var overview := PanelContainer.new()
	overview.theme_type_variation = "StatsHero"
	overview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_body.add_child(overview)
	var overview_margin := MarginContainer.new()
	overview_margin.add_theme_constant_override("margin_left", 26)
	overview_margin.add_theme_constant_override("margin_right", 26)
	overview_margin.add_theme_constant_override("margin_top", 20)
	overview_margin.add_theme_constant_override("margin_bottom", 20)
	overview.add_child(overview_margin)
	var overview_text := VBoxContainer.new()
	overview_text.add_theme_constant_override("separation", 5)
	overview_margin.add_child(overview_text)
	var overview_title := Label.new()
	overview_title.text = _l("你的数独旅程", "Your Sudoku Journey")
	overview_title.add_theme_font_size_override("font_size", 32)
	overview_text.add_child(overview_title)
	var overview_subtitle := Label.new()
	overview_subtitle.text = _l("在这台设备上完成的每一局，都会沉淀为下方的进度与纪录。", "Every game completed on this device contributes to the progress and records below.")
	overview_subtitle.theme_type_variation = "HeroSubtitle"
	overview_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overview_text.add_child(overview_subtitle)
	_add_section_title(stats_body, _l("进度概览", "Progress Overview"))
	var stats_grid := GridContainer.new()
	stats_grid.name = "StatisticsOverviewGrid"
	stats_grid.columns = 5 if wide else 2
	stats_grid.add_theme_constant_override("h_separation", 14)
	stats_grid.add_theme_constant_override("v_separation", 14)
	stats_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_body.add_child(stats_grid)
	var stats := AppState.statistics
	var started := int(stats.get("started", 0))
	var completed_count := int(stats.get("completed", 0))
	_add_statistic_metric(stats_grid, _l("完成局数", "Games completed"), str(completed_count))
	_add_statistic_metric(stats_grid, _l("胜率", "Win rate"), "%.1f%%" % (float(completed_count) * 100.0 / float(started) if started > 0 else 0.0))
	_add_statistic_metric(stats_grid, _l("累计操作", "Total moves"), str(int(stats.get("operations", 0))))
	_add_statistic_metric(stats_grid, _l("当前连胜", "Current streak"), str(int(stats.get("current_streak", 0))))
	_add_statistic_metric(stats_grid, _l("最长连胜", "Longest streak"), str(int(stats.get("longest_streak", 0))))
	_add_section_title(stats_body, _l("各难度时间纪录", "Time Records by Difficulty"))
	var best_grid := GridContainer.new()
	best_grid.name = "StatisticsRecordGrid"
	best_grid.columns = 3 if wide else 1
	best_grid.add_theme_constant_override("h_separation", 14)
	best_grid.add_theme_constant_override("v_separation", 14)
	best_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_body.add_child(best_grid)
	for difficulty in 6:
		var item: Dictionary = stats.get("by_difficulty", {}).get(str(difficulty), {})
		var best := int(item.get("best_ms", 0))
		_add_statistics_record(best_grid, _difficulty_name(difficulty), _format_time(best) if best > 0 else "—", int(item.get("completed", 0)), int(item.get("operations", 0)))

func _show_settings() -> void:
	_current_view = "settings"
	_clear_content()
	_add_back_header(_l("设置", "Settings"), _l("隐私友好，可随时修改", "Private by design and easy to change"))
	var wide := _is_wide_layout()
	var settings_scroll := _page_scroll()
	content.add_child(settings_scroll)
	var settings_body := VBoxContainer.new()
	settings_body.add_theme_constant_override("separation", 24 if wide else 14)
	settings_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings_scroll.add_child(settings_body)
	var overview: Container = HBoxContainer.new() if wide else VBoxContainer.new()
	overview.add_theme_constant_override("separation", 36 if wide else 14)
	overview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_body.add_child(overview)
	var profile_column := VBoxContainer.new()
	profile_column.add_theme_constant_override("separation", 12)
	profile_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overview.add_child(profile_column)
	var preferences_column := VBoxContainer.new()
	preferences_column.add_theme_constant_override("separation", 10)
	preferences_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overview.add_child(preferences_column)
	_add_section_title(profile_column, _l("个人与外观", "Profile & Appearance"))
	var name_label := Label.new()
	name_label.text = _l("显示名称（1–20 个字符）", "Display name (1–20 characters)")
	profile_column.add_child(name_label)
	var name_edit := LineEdit.new()
	name_edit.text = str(AppState.profile.get("display_name", "Player"))
	name_edit.max_length = 20
	name_edit.caret_blink = true
	name_edit.caret_blink_interval = 0.55
	name_edit.custom_minimum_size.y = 60
	profile_column.add_child(name_edit)
	var save_name := _button(_l("保存显示名称", "Save display name"))
	save_name.pressed.connect(_save_name.bind(name_edit))
	profile_column.add_child(save_name)
	var theme_label := Label.new()
	theme_label.text = _l("主题", "Theme")
	profile_column.add_child(theme_label)
	_add_choice_picker(profile_column, [_l("跟随系统", "System"), _l("浅色", "Light"), _l("深色", "Dark")], THEME_VALUES, str(AppState.settings.get("theme", "system")), Callable(self, "_set_theme_value"))
	var language_label := Label.new()
	language_label.text = _l("语言", "Language")
	profile_column.add_child(language_label)
	_add_choice_picker(profile_column, [_l("跟随系统", "System"), "简体中文", "English"], LANGUAGE_VALUES, str(AppState.settings.get("language", "system")), Callable(self, "_set_language_value"))
	_add_section_title(preferences_column, _l("游戏与辅助功能", "Gameplay & Accessibility"))
	var toggle_grid := GridContainer.new()
	toggle_grid.columns = 2 if wide else 1
	toggle_grid.add_theme_constant_override("h_separation", 12)
	toggle_grid.add_theme_constant_override("v_separation", 10)
	toggle_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preferences_column.add_child(toggle_grid)
	var gameplay_settings: Array = [["sound", _l("音效", "Sound")], ["error_sound", _l("错误提示音", "Mistake sound")], ["auto_check", _l("自动检查错误", "Check mistakes automatically")], ["auto_clear_notes", _l("自动清理草稿", "Clear notes automatically")], ["hide_completed_numbers", _l("隐藏已填完数字", "Hide completed numbers")], ["highlight_same", _l("高亮相同数字", "Highlight matching values")], ["highlight_related", _l("高亮相关区域", "Highlight related cells")], ["show_timer", _l("显示计时器", "Show timer")], ["show_mistakes", _l("显示错误次数", "Show mistake count")], ["high_contrast", _l("高对比度", "Increase contrast")], ["reduce_motion", _l("减少动态效果", "Reduce motion")]]
	if _is_mobile_device():
		gameplay_settings.insert(1, ["vibration", _l("震动（跟随系统）", "Haptics (follows system)")])
	for setting in gameplay_settings:
		_add_setting_toggle(toggle_grid, str(setting[0]), str(setting[1]), wide)
	_add_custom_sound_settings(preferences_column, wide)
	_add_section_title(preferences_column, _l("排行榜", "Leaderboard"))
	var leaderboard_settings := GridContainer.new()
	leaderboard_settings.columns = 1
	leaderboard_settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preferences_column.add_child(leaderboard_settings)
	_add_setting_toggle(leaderboard_settings, "leaderboard_auto_refresh", _l("进入排行榜后自动刷新", "Refresh automatically when opening leaderboard"), wide)
	_add_setting_toggle(leaderboard_settings, "ranked_auto_upload", _l("自动上传所有排位完成成绩", "Automatically upload every completed ranked game"), wide)
	var leaderboard_note := Label.new()
	leaderboard_note.text = _l("自动上传默认关闭。关闭时每局完成后可选择是否上传；离线选择上传的成绩会保存在本机，下次联网刷新排行榜时先上传再更新排名。", "Automatic upload is off by default. When off, each completed game asks whether to upload. Offline uploads remain on this device and are sent before the leaderboard refreshes next time you are online.")
	leaderboard_note.theme_type_variation = "SettingsNote"
	leaderboard_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preferences_column.add_child(leaderboard_note)
	var privacy := Label.new()
	privacy.text = _l("隐私说明：不收集真实身份、硬件标识、位置、通讯录或广告标识。只有选择上传时，排位才会提交随机安装 ID、显示名称、题目与游戏成绩。", "Privacy: We do not collect your real identity, hardware identifiers, location, contacts or advertising identifiers. Ranked play submits a random installation ID, display name, puzzle and game result only when upload is selected.")
	privacy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	profile_column.add_child(privacy)
	var version := Label.new()
	version.text = "%s · %s" % [AppConfig.PRODUCT_NAME, AppConfig.APP_VERSION]
	profile_column.add_child(version)
	var reset := _button(_l("重置本地数据", "Reset local data"))
	reset.pressed.connect(_reset_data)
	profile_column.add_child(reset)
	if not _is_mobile_device():
		var shortcut_column := VBoxContainer.new()
		shortcut_column.add_theme_constant_override("separation", 14)
		shortcut_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		settings_body.add_child(shortcut_column)
		_add_section_title(shortcut_column, _l("键盘快捷键", "Keyboard Shortcuts"))
		var shortcut_note := Label.new()
		shortcut_note.text = _l("方向键移动选中格；点击右侧按键即可重新录入。", "Arrow keys move the selection. Choose a binding to record a new shortcut.")
		shortcut_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		shortcut_note.add_theme_color_override("font_color", theme.get_color("muted", "App"))
		shortcut_column.add_child(shortcut_note)
		var shortcut_grid := GridContainer.new()
		shortcut_grid.columns = 2 if wide else 1
		shortcut_grid.add_theme_constant_override("h_separation", 12)
		shortcut_grid.add_theme_constant_override("v_separation", 12)
		shortcut_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shortcut_column.add_child(shortcut_grid)
		for action in SHORTCUT_ACTIONS:
			_add_shortcut_row(shortcut_grid, action)
		var restore_shortcuts := _button(_l("恢复系统默认快捷键", "Restore system defaults"))
		restore_shortcuts.pressed.connect(_restore_shortcut_defaults)
		shortcut_column.add_child(restore_shortcuts)

func _show_leaderboard() -> void:
	_current_view = "leaderboard"
	_clear_content()
	_add_back_header(_l("排行榜", "Leaderboard"), _l("前 100 名；离线时显示缓存", "Top 100 · Cached results are available offline"))
	var wide := _is_wide_layout()
	var scroll := _page_scroll()
	content.add_child(scroll)
	var body := VBoxContainer.new()
	body.name = "LeaderboardBody"
	body.add_theme_constant_override("separation", 18)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	var controls := PanelContainer.new()
	controls.theme_type_variation = "LeaderboardControlCard"
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(controls)
	var controls_margin := MarginContainer.new()
	controls_margin.add_theme_constant_override("margin_left", 22)
	controls_margin.add_theme_constant_override("margin_right", 22)
	controls_margin.add_theme_constant_override("margin_top", 18)
	controls_margin.add_theme_constant_override("margin_bottom", 18)
	controls.add_child(controls_margin)
	var controls_body := VBoxContainer.new()
	controls_body.add_theme_constant_override("separation", 12)
	controls_margin.add_child(controls_body)
	var controls_title := Label.new()
	controls_title.text = _l("查看本周排位", "View this week's ranking")
	controls_title.add_theme_font_size_override("font_size", 28)
	controls_body.add_child(controls_title)
	var controls_note := Label.new()
	controls_note.text = _l("排行榜默认只读取本地缓存；联网刷新时会先上传已选择上传的本地成绩，再获取最新排名。", "The leaderboard reads local cache by default. An online refresh first uploads saved results you chose to share, then fetches the latest ranking.")
	controls_note.theme_type_variation = "SectionSummary"
	controls_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls_body.add_child(controls_note)
	var selector_row: Container = HBoxContainer.new() if wide else VBoxContainer.new()
	selector_row.add_theme_constant_override("separation", 12)
	selector_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_body.add_child(selector_row)
	var difficulty_column := VBoxContainer.new()
	difficulty_column.add_theme_constant_override("separation", 6)
	difficulty_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector_row.add_child(difficulty_column)
	var difficulty_label := Label.new()
	difficulty_label.text = _l("难度", "Difficulty")
	difficulty_label.theme_type_variation = "SettingsNote"
	difficulty_column.add_child(difficulty_label)
	_add_choice_picker(difficulty_column, DIFFICULTY_ZH if _language() != "en" else DIFFICULTY_EN, ["0", "1", "2", "3", "4", "5"], str(_leaderboard_difficulty), Callable(self, "_set_leaderboard_difficulty"))
	var action_column := VBoxContainer.new()
	action_column.add_theme_constant_override("separation", 6)
	action_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector_row.add_child(action_column)
	var network_label := Label.new()
	network_label.text = _l("联网权限", "Network access")
	network_label.theme_type_variation = "SettingsNote"
	action_column.add_child(network_label)
	var network_allowed := bool(AppState.settings.get("leaderboard_network_allowed", false))
	var refresh := _button(_l("刷新最新排名", "Refresh latest ranking") if network_allowed else _l("允许联网并刷新", "Allow network & refresh"))
	refresh.name = "LeaderboardRefreshButton"
	refresh.theme_type_variation = "PrimaryActionButton" if network_allowed else "Button"
	refresh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	refresh.pressed.connect(_refresh_leaderboard if network_allowed else _grant_leaderboard_network_and_refresh)
	action_column.add_child(refresh)
	if network_allowed:
		var revoke := _button(_l("撤销排行榜联网权限", "Revoke leaderboard network access"))
		revoke.name = "LeaderboardRevokeButton"
		revoke.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		revoke.pressed.connect(_revoke_leaderboard_network)
		controls_body.add_child(revoke)
	var auto_note := Label.new()
	auto_note.text = _l(
		"自动刷新：已开启" if bool(AppState.settings.get("leaderboard_auto_refresh", false)) else "自动刷新：已关闭（可在设置中调整）",
		"Auto-refresh: On" if bool(AppState.settings.get("leaderboard_auto_refresh", false)) else "Auto-refresh: Off (change in Settings)"
	)
	auto_note.theme_type_variation = "SettingsNote"
	controls_body.add_child(auto_note)
	_leaderboard_results = VBoxContainer.new()
	_leaderboard_results.name = "LeaderboardResults"
	_leaderboard_results.add_theme_constant_override("separation", 14)
	_leaderboard_results.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_leaderboard_results)
	_leaderboard_snapshot = leaderboard_service.cached_snapshot(_leaderboard_difficulty)
	_render_leaderboard_snapshot()
	if network_allowed and bool(AppState.settings.get("leaderboard_auto_refresh", false)) and AppConfig.online_configured():
		call_deferred("_refresh_leaderboard")

func _set_leaderboard_difficulty(value: String) -> void:
	_leaderboard_difficulty = clampi(int(value), 0, 5)
	_show_leaderboard()

func _grant_leaderboard_network_and_refresh() -> void:
	AppState.settings["leaderboard_network_allowed"] = true
	AppState.save_settings()
	_show_leaderboard()
	_refresh_leaderboard()

func _revoke_leaderboard_network() -> void:
	AppState.settings["leaderboard_network_allowed"] = false
	AppState.save_settings()
	_show_leaderboard()
	_show_toast(_l("已撤销排行榜联网权限", "Leaderboard network access revoked"))

func _refresh_leaderboard() -> void:
	if not bool(AppState.settings.get("leaderboard_network_allowed", false)):
		_show_toast(_l("请先授予排行榜联网权限", "Grant leaderboard network access first"))
		return
	if not AppConfig.online_configured():
		_show_toast(_l("在线服务尚未配置，继续显示本地缓存", "Online services are not configured; showing local cache"))
		return
	var loading := content.find_child("LeaderboardLoading", true, false) as Label
	if loading == null and _leaderboard_results != null:
		loading = Label.new()
		loading.name = "LeaderboardLoading"
		loading.theme_type_variation = "SettingsNote"
		_leaderboard_results.add_child(loading)
	if SyncManager.has_pending():
		_leaderboard_refresh_after_sync = true
		if loading != null:
			loading.text = _l("正在上传本地排位成绩，随后更新排行榜…", "Uploading saved ranked results before refreshing the leaderboard…")
		SyncManager.flush_now()
		return
	if loading != null:
		loading.text = _l("正在获取最新排名…", "Fetching the latest ranking…")
	leaderboard_service.fetch(_leaderboard_difficulty, AppState.installation_id)

func _on_sync_flush_completed(success: bool) -> void:
	if not _leaderboard_refresh_after_sync:
		return
	_leaderboard_refresh_after_sync = false
	if _current_view != "leaderboard":
		return
	if not success:
		_show_toast(_l("部分本地成绩暂未上传，仍将刷新现有排行榜", "Some saved results could not be uploaded yet; refreshing the available leaderboard."))
	var loading := content.find_child("LeaderboardLoading", true, false) as Label
	if loading != null:
		loading.text = _l("正在获取最新排名…", "Fetching the latest ranking…")
	leaderboard_service.fetch(_leaderboard_difficulty, AppState.installation_id)

func _show_leaderboard_snapshot(snapshot: Dictionary) -> void:
	if _current_view != "leaderboard":
		return
	_leaderboard_snapshot = snapshot.duplicate(true)
	_render_leaderboard_snapshot()

func _on_leaderboard_failed(message: String) -> void:
	if _current_view == "leaderboard":
		var loading := content.find_child("LeaderboardLoading", true, false)
		if loading != null:
			loading.queue_free()
	_show_toast(message)

func _render_leaderboard_snapshot() -> void:
	if _leaderboard_results == null or not is_instance_valid(_leaderboard_results):
		return
	for child in _leaderboard_results.get_children():
		_leaderboard_results.remove_child(child)
		child.queue_free()
	var snapshot := _leaderboard_snapshot
	if snapshot.is_empty():
		var empty_card := PanelContainer.new()
		empty_card.theme_type_variation = "LeaderboardEmptyCard"
		empty_card.custom_minimum_size.y = 150
		_leaderboard_results.add_child(empty_card)
		var empty := Label.new()
		empty.text = _l("尚无此难度的排行榜缓存\n授予联网权限并刷新后，数据会保存在本机供离线查看。", "No cached ranking for this difficulty yet.\nGrant network access and refresh to save a snapshot for offline viewing.")
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_card.add_child(empty)
		return
	var cached_at := str(snapshot.get("cached_at", ""))
	var source := str(snapshot.get("source", "cache"))
	var snapshot_note := Label.new()
	snapshot_note.text = _l("刚刚获取的在线数据", "Fresh online data") if source == "network" else _l("离线快照 · 上次更新 %s", "Offline snapshot · Last updated %s") % (cached_at if not cached_at.is_empty() else _l("未知", "Unknown"))
	snapshot_note.theme_type_variation = "SettingsNote"
	_leaderboard_results.add_child(snapshot_note)
	_add_section_title(_leaderboard_results, _l("我的排名", "My Ranking"))
	var self_entry: Dictionary = snapshot.get("self_entry", {}) if snapshot.get("self_entry", {}) is Dictionary else {}
	_add_leaderboard_self_card(_leaderboard_results, self_entry)
	_add_section_title(_leaderboard_results, _l("前 100 名", "Top 100"))
	var entries: Array = snapshot.get("entries", []) if snapshot.get("entries", []) is Array else []
	if entries.is_empty():
		var empty_list := Label.new()
		empty_list.text = _l("当前挑战还没有有效成绩", "No valid results for this challenge yet")
		empty_list.theme_type_variation = "SectionSummary"
		_leaderboard_results.add_child(empty_list)
		return
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	_leaderboard_results.add_child(list)
	for index in entries.size():
		_add_leaderboard_row(list, entries[index], index + 1)

func _add_leaderboard_self_card(parent: Container, entry: Dictionary) -> void:
	var card := PanelContainer.new()
	card.theme_type_variation = "LeaderboardSelfCard"
	card.custom_minimum_size.y = 112
	parent.add_child(card)
	if entry.is_empty():
		var empty := Label.new()
		empty.text = _l("暂无我的排位成绩 · 完成排位并联网刷新后显示", "No ranked result yet · Complete a ranked game and refresh online")
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(empty)
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)
	var rank := Label.new()
	rank.text = "#%d" % int(entry.get("rank", 0))
	rank.add_theme_font_size_override("font_size", 34)
	rank.add_theme_color_override("font_color", theme.get_color("accent", "App"))
	row.add_child(rank)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(identity)
	var name := Label.new()
	name.text = str(entry.get("display_name", AppState.profile.get("display_name", "Player")))
	identity.add_child(name)
	var detail := Label.new()
	detail.text = _l("错误 %d · 操作 %d", "%d mistakes · %d moves") % [int(entry.get("mistakes", 0)), int(entry.get("move_count", 0))]
	detail.theme_type_variation = "SectionSummary"
	identity.add_child(detail)
	var time := Label.new()
	time.text = _format_time(int(entry.get("duration_ms", 0)))
	time.add_theme_font_size_override("font_size", 30)
	row.add_child(time)

func _add_leaderboard_row(parent: Container, entry_value: Variant, fallback_rank: int) -> void:
	if not entry_value is Dictionary:
		return
	var entry: Dictionary = entry_value
	var panel := PanelContainer.new()
	panel.theme_type_variation = "LeaderboardRow"
	panel.custom_minimum_size.y = 72
	parent.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var rank := Label.new()
	rank.text = "#%d" % int(entry.get("rank", fallback_rank))
	rank.custom_minimum_size.x = 88
	row.add_child(rank)
	var name := Label.new()
	name.text = str(entry.get("display_name", "Player"))
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name)
	var mistakes := Label.new()
	mistakes.text = _l("错误 %d · 操作 %d", "%d mistakes · %d moves") % [int(entry.get("mistakes", 0)), int(entry.get("move_count", 0))]
	mistakes.theme_type_variation = "SectionSummary"
	row.add_child(mistakes)
	var time := Label.new()
	time.text = _format_time(int(entry.get("duration_ms", 0)))
	row.add_child(time)

func _resume_saved(mode: String, difficulty: int) -> void:
	var saved := AppState.load_session(mode, difficulty)
	if saved == null:
		_show_toast(_l("保存的进度已不可用", "Saved progress is no longer available"))
		return
	if saved.mode == "ranked":
		_show_ranked_briefing(saved.difficulty, saved)
	else:
		game_service.resume_session(saved)
		_show_game()

func _find_latest_saved_game() -> Dictionary:
	var best: Dictionary = {}
	for key in AppState.active_games.get("games", {}):
		var data: Dictionary = AppState.active_games["games"][key]
		if bool(data.get("completed", false)):
			continue
		if best.is_empty() or str(data.get("last_saved_at", "")) > str(best.get("last_saved_at", "")):
			best = {"mode": data.get("mode", "local"), "difficulty": data.get("difficulty", 0), "last_saved_at": data.get("last_saved_at", "")}
	return best

func _save_name(edit: LineEdit) -> void:
	if AppState.set_display_name(edit.text):
		_show_toast(_l("✓ 显示名称已保存", "✓ Display name saved"))
	else:
		_show_toast(_l("名称需为 1–20 个可见字符", "Name must contain 1–20 visible characters"))

func _set_theme_value(value: String) -> void:
	AppState.settings["theme"] = value
	AppState.save_settings()
	_show_settings()

func _set_language_value(value: String) -> void:
	AppState.settings["language"] = value
	AppState.save_settings()
	_build_shell_labels()
	_show_settings()

func _build_shell_labels() -> void:
	if shell_outer == null:
		return
	var top := shell_outer.get_child(0)
	if top is HBoxContainer and top.get_child_count() > 0:
		(top.get_child(0) as Label).text = _l("SUDOKU / 数独", "SUDOKU")
	_on_network_changed(NetworkManager.online)

func _add_choice_picker(parent: Container, labels: Array, values: Array, selected: String, callback: Callable) -> void:
	var selected_index := maxi(0, values.find(selected))
	var button := _icon_button(str(labels[selected_index]), "chevron", str(labels[selected_index]))
	button.theme_type_variation = "PickerButton"
	button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	button.expand_icon = false
	button.custom_minimum_size.y = 72 if not _is_wide_layout() else 68
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_show_choice_sheet.bind(labels, values, selected, callback))
	parent.add_child(button)

func _show_choice_sheet(labels: Array, values: Array, selected: String, callback: Callable) -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.38)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 120
	add_child(overlay)
	var dismiss := Button.new()
	dismiss.flat = true
	dismiss.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dismiss.pressed.connect(_close_overlay.bind(overlay))
	overlay.add_child(dismiss)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var card := PanelContainer.new()
	card.theme_type_variation = "PickerCard"
	card.custom_minimum_size.x = minf(520.0, size.x - 48.0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(card)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)
	var choices := VBoxContainer.new()
	choices.add_theme_constant_override("separation", 6)
	margin.add_child(choices)
	for index in labels.size():
		var label_text := ("✓  " if str(values[index]) == selected else "    ") + str(labels[index])
		var option := _button(label_text)
		option.theme_type_variation = "PickerOptionButton"
		option.alignment = HORIZONTAL_ALIGNMENT_LEFT
		option.pressed.connect(_select_choice.bind(overlay, str(values[index]), callback))
		choices.add_child(option)
	overlay.modulate.a = 0.0
	card.scale = Vector2(0.96, 0.96)
	card.pivot_offset = card.size / 2.0
	if bool(AppState.settings.get("reduce_motion", false)):
		overlay.modulate.a = 1.0
		card.scale = Vector2.ONE
	else:
		var tween := create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tween.tween_property(overlay, "modulate:a", 1.0, 0.20)
		tween.tween_property(card, "scale", Vector2.ONE, 0.24)

func _select_choice(overlay: Control, value: String, callback: Callable) -> void:
	callback.call(value)
	if is_instance_valid(overlay):
		overlay.queue_free()

func _close_overlay(overlay: Control) -> void:
	if not is_instance_valid(overlay):
		return
	if bool(AppState.settings.get("reduce_motion", false)):
		overlay.queue_free()
		return
	var tween := create_tween()
	tween.tween_property(overlay, "modulate:a", 0.0, 0.14)
	tween.tween_callback(overlay.queue_free)

func _set_setting(value: bool, key: String) -> void:
	AppState.settings[key] = value
	AppState.save_settings()

func _reset_data() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.48)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 100
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var card := PanelContainer.new()
	card.theme_type_variation = "ConfirmationCard"
	card.custom_minimum_size = Vector2(520, 300)
	center.add_child(card)
	var card_margin := MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", 28)
	card_margin.add_theme_constant_override("margin_right", 28)
	card_margin.add_theme_constant_override("margin_top", 24)
	card_margin.add_theme_constant_override("margin_bottom", 24)
	card.add_child(card_margin)
	var card_content := VBoxContainer.new()
	card_content.add_theme_constant_override("separation", 16)
	card_margin.add_child(card_content)
	var title := Label.new()
	title.text = _l("重置本地数据？", "Reset local data?")
	title.add_theme_font_size_override("font_size", 32)
	card_content.add_child(title)
	var message := Label.new()
	message.text = _l("这会清除本地游戏进度、统计和设置。随机安装 ID 将保留。\n此操作无法撤销。", "This clears local progress, statistics and settings. The random installation ID is kept.\nThis action cannot be undone.")
	message.add_theme_font_size_override("font_size", 22)
	message.add_theme_color_override("font_color", theme.get_color("muted", "App"))
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_content.add_child(message)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	card_content.add_child(actions)
	var cancel := _button(_l("取消", "Cancel"))
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(overlay.queue_free)
	actions.add_child(cancel)
	var confirm := _button(_l("重置", "Reset"))
	confirm.theme_type_variation = "DestructiveButton"
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.pressed.connect(_perform_reset_data.bind(overlay))
	actions.add_child(confirm)
	cancel.grab_focus()

func _perform_reset_data(overlay: Control) -> void:
	AppState.reset_local_data()
	overlay.queue_free()
	_show_menu()
	_show_toast(_l("本地数据已重置，随机安装 ID 已保留", "Local data reset. The random installation ID was kept."))

func _on_back() -> void:
	if _current_view == "game":
		_confirm_leave_game()
	elif _current_view == "ranked_briefing":
		_show_difficulty(true)
	elif _current_view != "menu":
		_show_menu()

func _navigate(destination: String) -> void:
	if destination == "menu":
		_show_menu()

func _on_network_changed(online: bool) -> void:
	status_label.text = _l("在线", "Online") if online else _l("离线可玩", "Works offline")

func _on_pending_changed(count: int) -> void:
	status_label.text = (_l("在线", "Online") if NetworkManager.online else _l("离线", "Offline")) + (_l(" · 待传 %d", " · %d pending") % count if count > 0 else "")

func _show_toast(message: String) -> void:
	if toast_label == null or toast_panel == null:
		return
	_toast_token += 1
	var translated: String = {
		"puzzle_generation_failed": _l("题目生成失败，请重试", "Puzzle generation failed. Try again."),
		"generation_task_failed": _l("无法启动题目生成任务", "Could not start puzzle generation."),
		"无法读取本地数据，已使用默认设置": _l("无法读取本地数据，已使用默认设置", "Local data could not be read. Default settings are in use."),
		"检测到损坏的本地数据，已安全恢复": _l("检测到损坏的本地数据，已安全恢复", "Damaged local data was detected and recovered safely."),
		"保存失败，请检查可用存储空间": _l("保存失败，请检查可用存储空间", "Save failed. Check available storage."),
		"保存文件替换失败": _l("保存文件替换失败", "The saved file could not be replaced."),
		"离线且没有可用的排行榜缓存": _l("离线且没有可用的排行榜缓存", "You are offline and no cached leaderboard is available."),
		"排行榜联网权限尚未授予": _l("排行榜联网权限尚未授予", "Leaderboard network access has not been granted."),
		"无法获取排位题目": _l("无法获取排位题目", "Could not fetch a ranked puzzle."),
		"网络请求无法启动": _l("网络请求无法启动", "The network request could not start."),
		"服务器返回了无法识别的数据": _l("服务器返回了无法识别的数据", "The server returned unrecognized data."),
		"在线服务尚未配置": _l("在线服务尚未配置", "Online services are not configured yet.")
	}.get(message, message)
	toast_label.text = translated
	toast_panel.visible = not translated.is_empty()
	if not translated.is_empty():
		get_tree().create_timer(3.2).timeout.connect(_dismiss_toast.bind(_toast_token))

func _dismiss_toast(token: int) -> void:
	if token == _toast_token and toast_panel != null:
		toast_panel.visible = false
		toast_label.text = ""

func _add_back_header(title_text: String, subtitle: String) -> void:
	var row := HBoxContainer.new()
	content.add_child(row)
	var back := _icon_button("", "back", _l("返回", "Back"))
	back.custom_minimum_size = Vector2(54, 54)
	back.pressed.connect(_on_back)
	row.add_child(back)
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(labels)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 30)
	labels.add_child(title)
	var sub := Label.new()
	sub.text = subtitle
	sub.add_theme_font_size_override("font_size", 15)
	labels.add_child(sub)

func _add_heading(title_text: String, subtitle: String, kicker_text: String = "", target_parent: Container = null) -> void:
	var parent: Container = target_parent if target_parent != null else content
	if not kicker_text.is_empty():
		var pill_center := CenterContainer.new()
		parent.add_child(pill_center)
		var pill := PanelContainer.new()
		pill.theme_type_variation = "InfoPill"
		pill_center.add_child(pill)
		var kicker := Label.new()
		kicker.text = kicker_text
		kicker.theme_type_variation = "EyebrowLabel"
		pill.add_child(kicker)
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 50)
	parent.add_child(title)
	var sub := Label.new()
	sub.text = subtitle
	sub.theme_type_variation = "HeroSubtitle"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(sub)

func _add_home_section_heading(parent: Container, title_text: String, summary_text: String) -> void:
	var heading := VBoxContainer.new()
	heading.add_theme_constant_override("separation", 6)
	parent.add_child(heading)
	_add_section_title(heading, title_text)
	var summary := Label.new()
	summary.text = summary_text
	summary.theme_type_variation = "SectionSummary"
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_child(summary)

func _home_panel_column(parent: Container) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var inner_margin := MarginContainer.new()
	inner_margin.add_theme_constant_override("margin_left", 28)
	inner_margin.add_theme_constant_override("margin_right", 28)
	inner_margin.add_theme_constant_override("margin_top", 22)
	inner_margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(inner_margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner_margin.add_child(column)
	return column

func _add_home_action(parent: Container, title_text: String, description_text: String, action: Callable, wide: bool) -> void:
	var action_block := VBoxContainer.new()
	action_block.add_theme_constant_override("separation", 12)
	action_block.custom_minimum_size.y = 140 if wide else 116
	action_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_block.size_flags_vertical = Control.SIZE_EXPAND_FILL if wide else Control.SIZE_SHRINK_BEGIN
	action_block.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(action_block)
	var button := _button(title_text)
	button.custom_minimum_size = Vector2(420 if wide else maxf(280.0, size.x - 48.0), 82 if wide else 72)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(action)
	var button_center := CenterContainer.new()
	button_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_center.add_child(button)
	action_block.add_child(button_center)
	var description_margin := MarginContainer.new()
	description_margin.add_theme_constant_override("margin_left", 16)
	description_margin.add_theme_constant_override("margin_right", 16)
	action_block.add_child(description_margin)
	var description := Label.new()
	description.text = description_text
	description.add_theme_font_size_override("font_size", 21)
	description.add_theme_color_override("font_color", theme.get_color("muted", "App"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_margin.add_child(description)

func _add_setting_toggle(parent: Container, key: String, label_text: String, compact: bool = false) -> void:
	var row := PanelContainer.new()
	row.theme_type_variation = "SettingsRow"
	row.custom_minimum_size.y = (88 if _language() == "en" else 76) if compact else 76
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	var row_margin := MarginContainer.new()
	row_margin.add_theme_constant_override("margin_left", 16)
	row_margin.add_theme_constant_override("margin_right", 10)
	row_margin.add_theme_constant_override("margin_top", 10)
	row_margin.add_theme_constant_override("margin_bottom", 10)
	row.add_child(row_margin)
	var row_content := HBoxContainer.new()
	row_content.add_theme_constant_override("separation", 12)
	row_margin.add_child(row_content)
	var label := Label.new()
	label.text = label_text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if compact:
		label.add_theme_font_size_override("font_size", 23)
	row_content.add_child(label)
	var toggle := AppleSwitch.new()
	toggle.set_on(bool(AppState.settings.get(key, true)))
	toggle.toggled.connect(_set_setting.bind(key))
	toggle.toggled.connect(_play_selection_sound.unbind(1))
	row_content.add_child(toggle)

func _add_shortcut_row(parent: Container, action: String) -> void:
	var row := PanelContainer.new()
	row.theme_type_variation = "SettingsRow"
	row.custom_minimum_size.y = 72
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_bottom", 9)
	row.add_child(margin)
	var content_row := HBoxContainer.new()
	content_row.add_theme_constant_override("separation", 10)
	margin.add_child(content_row)
	var label := Label.new()
	label.text = _shortcut_action_label(action)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content_row.add_child(label)
	var binding_button := _button(_shortcut_display(_binding_for(action)))
	binding_button.theme_type_variation = "ShortcutButton"
	binding_button.custom_minimum_size = Vector2(150, 54)
	binding_button.pressed.connect(_begin_shortcut_capture.bind(action, binding_button))
	content_row.add_child(binding_button)

func _add_section_title(parent: Container, title_text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var mark := Panel.new()
	mark.theme_type_variation = "AccentMark"
	mark.custom_minimum_size = Vector2(5, 28)
	row.add_child(mark)
	var title := Label.new()
	title.text = title_text
	title.theme_type_variation = "SectionTitle"
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)

func _add_stat_row(label_text: String, value_text: String, parent: Container = null) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 66
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(parent if parent != null else content).add_child(row)
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var value := Label.new()
	value.text = value_text
	row.add_child(value)

func _add_statistic_metric(parent: Container, label_text: String, value_text: String) -> void:
	var card := PanelContainer.new()
	card.theme_type_variation = "StatMetric"
	card.custom_minimum_size.y = 116
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)
	var body := VBoxContainer.new()
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", 5)
	card.add_child(body)
	var value := Label.new()
	value.text = value_text
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 34)
	value.add_theme_color_override("font_color", theme.get_color("accent", "App"))
	body.add_child(value)
	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.theme_type_variation = "SectionSummary"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(label)

func _add_statistics_record(parent: Container, difficulty_text: String, record_text: String, completed: int, operations: int) -> void:
	var card := PanelContainer.new()
	card.theme_type_variation = "StatsRecordCard"
	card.custom_minimum_size.y = 126
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 3)
	margin.add_child(body)
	var difficulty := Label.new()
	difficulty.text = difficulty_text
	difficulty.theme_type_variation = "EyebrowLabel"
	body.add_child(difficulty)
	var record := Label.new()
	record.text = record_text
	record.add_theme_font_size_override("font_size", 30)
	body.add_child(record)
	var completed_label := Label.new()
	completed_label.text = _l("完成 %d 局 · 操作 %d 次", "%d completed · %d moves") % [completed, operations]
	completed_label.theme_type_variation = "SectionSummary"
	body.add_child(completed_label)

func _add_result_metric(parent: Container, label_text: String, value_text: String) -> void:
	var card := PanelContainer.new()
	card.theme_type_variation = "ResultMetric"
	card.custom_minimum_size.y = 96
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)
	var metric := VBoxContainer.new()
	metric.alignment = BoxContainer.ALIGNMENT_CENTER
	metric.add_theme_constant_override("separation", 3)
	card.add_child(metric)
	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", theme.get_color("muted", "App"))
	metric.add_child(label)
	var value := Label.new()
	value.text = value_text
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 28)
	value.add_theme_color_override("font_color", theme.get_color("accent", "App"))
	metric.add_child(value)

func _button(label: String, tooltip: String = "") -> Button:
	var button := Button.new()
	button.text = label
	button.tooltip_text = tooltip
	button.custom_minimum_size.y = 68 if _is_wide_layout() else 72
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(_play_button_sound)
	return button

func _play_button_sound() -> void:
	if bool(AppState.settings.get("sound", true)):
		ui_sounds.play_tap()

func _play_selection_sound() -> void:
	if bool(AppState.settings.get("sound", true)):
		ui_sounds.play_selection()

func _add_custom_sound_settings(parent: Container, wide: bool) -> void:
	_add_section_title(parent, _l("自定义音效", "Custom Sounds"))
	var disclosure := _icon_button(
		_l("收起音效自定义", "Hide sound customization") if _sound_customization_expanded else _l("配置按键音与错误提示音", "Configure button and mistake sounds"),
		"chevron",
		_l("展开二级音效设置", "Open secondary sound settings")
	)
	disclosure.name = "CustomSoundsDisclosure"
	disclosure.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	disclosure.alignment = HORIZONTAL_ALIGNMENT_LEFT
	disclosure.pressed.connect(_toggle_sound_customization)
	parent.add_child(disclosure)
	if not _sound_customization_expanded:
		var summary := Label.new()
		summary.text = _l("两类音效默认采用系统风格，也可分别导入 MP3、WAV 或 OGG。", "Both sounds use system-style defaults and can be replaced separately with MP3, WAV or OGG.")
		summary.theme_type_variation = "SettingsNote"
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		parent.add_child(summary)
		return
	var secondary := VBoxContainer.new()
	secondary.name = "CustomSoundsSecondaryMenu"
	secondary.add_theme_constant_override("separation", 12)
	secondary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(secondary)
	_add_custom_sound_slot(secondary, "button", _l("按键与落子音", "Button & entry sound"), wide)
	_add_custom_sound_slot(secondary, "error", _l("错误提示音", "Mistake sound"), wide)

func _add_custom_sound_slot(parent: Container, kind: String, title_text: String, wide: bool) -> void:
	var card := PanelContainer.new()
	card.theme_type_variation = "SettingsRow"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	margin.add_child(body)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 23)
	body.add_child(title)
	var custom_name := str(AppState.settings.get(_custom_sound_name_key(kind), ""))
	var current := Label.new()
	current.text = _l("当前：系统默认", "Current: System default") if custom_name.is_empty() else _l("当前：%s", "Current: %s") % custom_name
	current.theme_type_variation = "SettingsNote"
	current.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(current)
	var actions := GridContainer.new()
	actions.columns = 3 if wide else 1
	actions.add_theme_constant_override("h_separation", 10)
	actions.add_theme_constant_override("v_separation", 10)
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(actions)
	var choose := _button(_l("选择音频文件", "Choose audio file"))
	choose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choose.pressed.connect(_choose_custom_sound.bind(kind))
	actions.add_child(choose)
	var preview := _icon_button(_l("试听", "Preview"), "play")
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.pressed.connect(_preview_custom_sound.bind(kind))
	actions.add_child(preview)
	var reset := _button(_l("恢复默认", "Use default"))
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset.disabled = custom_name.is_empty()
	reset.pressed.connect(_reset_custom_sound.bind(kind))
	actions.add_child(reset)

func _toggle_sound_customization() -> void:
	_sound_customization_expanded = not _sound_customization_expanded
	_show_settings()

func _custom_sound_path_key(kind: String) -> String:
	return "custom_error_sound_path" if kind == "error" else "custom_ui_sound_path"

func _custom_sound_name_key(kind: String) -> String:
	return "custom_error_sound_name" if kind == "error" else "custom_ui_sound_name"

func _choose_custom_sound(kind: String = "button") -> void:
	var dialog := FileDialog.new()
	dialog.title = _l("选择错误提示音效", "Choose mistake sound") if kind == "error" else _l("选择按键音效", "Choose button sound")
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.mp3, *.wav, *.ogg ; MP3 / WAV / OGG"])
	dialog.use_native_dialog = true
	dialog.file_selected.connect(_import_custom_sound.bind(dialog, kind))
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered_ratio(0.72)

func _import_custom_sound(source_path: String, dialog: FileDialog, kind: String = "button") -> void:
	if is_instance_valid(dialog):
		dialog.queue_free()
	if not RuntimeAudioLoaderScript.is_supported_path(source_path):
		_show_toast(_l("请选择 MP3、WAV 或 OGG 音频", "Choose an MP3, WAV or OGG audio file"))
		return
	var source := FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		_show_toast(_l("无法读取所选音频文件", "The selected audio file could not be read"))
		return
	var source_size := source.get_length()
	if source_size <= 0 or source_size > MAX_CUSTOM_SOUND_BYTES:
		_show_toast(_l("音频文件需小于 10 MB", "The audio file must be under 10 MB"))
		return
	if RuntimeAudioLoaderScript.load_file(source_path) == null:
		_show_toast(_l("音频格式无效或无法解码", "The audio file is invalid or could not be decoded"))
		return
	var audio_data := source.get_buffer(source_size)
	source.close()
	var extension := source_path.get_extension().to_lower()
	var file_stem := "custom_error_sound" if kind == "error" else "custom_button_sound"
	var destination_path := "user://%s.%s" % [file_stem, extension]
	var destination := FileAccess.open(destination_path, FileAccess.WRITE)
	if destination == null:
		_show_toast(_l("无法保存自定义音效", "The custom sound could not be saved"))
		return
	destination.store_buffer(audio_data)
	destination.close()
	var previous_path := str(AppState.settings.get(_custom_sound_path_key(kind), ""))
	if previous_path.begins_with("user://%s." % file_stem) and previous_path != destination_path and FileAccess.file_exists(previous_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(previous_path))
	AppState.settings[_custom_sound_path_key(kind)] = destination_path
	AppState.settings[_custom_sound_name_key(kind)] = source_path.get_file()
	AppState.save_settings()
	if kind == "button":
		ui_sounds.reload_custom_sound(destination_path)
	_show_settings()
	_show_toast(_l("自定义错误提示音已启用", "Custom mistake sound enabled") if kind == "error" else _l("自定义按键音已启用", "Custom button sound enabled"))

func _reset_custom_sound(kind: String = "button") -> void:
	var file_stem := "custom_error_sound" if kind == "error" else "custom_button_sound"
	var current_path := str(AppState.settings.get(_custom_sound_path_key(kind), ""))
	if current_path.begins_with("user://%s." % file_stem) and FileAccess.file_exists(current_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(current_path))
	AppState.settings[_custom_sound_path_key(kind)] = ""
	AppState.settings[_custom_sound_name_key(kind)] = ""
	AppState.save_settings()
	if kind == "button":
		ui_sounds.reload_custom_sound("")
	_show_settings()
	_show_toast(_l("已恢复系统默认错误提示音", "Default mistake sound restored") if kind == "error" else _l("已恢复系统默认按键音", "Default button sound restored"))

func _preview_custom_sound(kind: String = "button") -> void:
	if not bool(AppState.settings.get("sound", true)):
		_show_toast(_l("请先开启音效", "Turn on Sound first"))
		return
	if kind == "error":
		if not bool(AppState.settings.get("error_sound", true)):
			_show_toast(_l("请先开启错误提示音", "Turn on Mistake sound first"))
			return
		get_tree().create_timer(0.12).timeout.connect(FeedbackManager.play_error_sound)
	else:
		# The button itself plays the tap sound. Follow it with the softer
		# selection sound so the preview verifies both button streams.
		get_tree().create_timer(0.12).timeout.connect(ui_sounds.play_selection)

func _preview_sound() -> void:
	_preview_custom_sound("button")

func _icon_button(label: String, icon_name: String, tooltip: String = "") -> Button:
	var button := _button(label, tooltip)
	button.icon = ICONS[icon_name]
	button.add_theme_constant_override("icon_max_width", 24)
	button.add_theme_constant_override("h_separation", 8)
	return button

func _page_scroll() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.scroll_deadzone = 8
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return scroll

func _clear_content() -> void:
	_transition_token += 1
	content.alignment = BoxContainer.ALIGNMENT_BEGIN
	for child in content.get_children():
		child.queue_free()
	timer_label = null
	mistakes_label = null
	notes_button = null
	pause_button = null
	pause_overlay = null
	pause_blur_layer = null
	_leaderboard_results = null
	mistake_icon = null
	_last_mistake_count = -1
	cell_buttons.clear()
	number_buttons.clear()
	_show_toast("")
	call_deferred("_animate_content", _transition_token)

func _animate_content(token: int) -> void:
	if token != _transition_token or bool(AppState.settings.get("reduce_motion", false)):
		return
	var children := content.get_children()
	for child_index in children.size():
		var child: CanvasItem = children[child_index]
		child.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_interval(minf(child_index * 0.035, 0.18))
		tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tween.tween_property(child, "modulate:a", 1.0, 0.22)

func _format_time(milliseconds: int) -> String:
	var total_seconds := milliseconds / 1000
	return "%02d:%02d" % [total_seconds / 60, total_seconds % 60]
