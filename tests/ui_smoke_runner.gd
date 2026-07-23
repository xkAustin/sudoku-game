extends SceneTree

var main: Control

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1500, 900)
	main = load("res://ui/scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var app_state := root.get_node("AppState")
	main._show_settings()
	await process_frame
	if not main.ui_sounds.is_ready_to_play():
		push_error("UI smoke: generated UI audio streams are not ready")
		quit(1)
		return
	var tooltip_style := main.theme.get_stylebox("panel", "TooltipPanel") as StyleBoxFlat
	if tooltip_style == null or tooltip_style.corner_radius_top_left != 14 or tooltip_style.shadow_size != 12:
		push_error("UI smoke: Apple-style tooltip theme is missing")
		quit(1)
		return
	var scroll_grabber := main.theme.get_stylebox("grabber", "VScrollBar") as StyleBoxFlat
	if scroll_grabber == null or scroll_grabber.corner_radius_top_left != 4 \
		or main.theme.get_constant("minimum_grab_thickness", "VScrollBar") < 54:
		push_error("UI smoke: compact rounded scrollbar theme is missing")
		quit(1)
		return
	var setting_grids: Array[Node] = main.content.find_children("*", "GridContainer", true, false)
	if setting_grids.is_empty() or (setting_grids[0] as GridContainer).columns != 2:
		push_error("UI smoke: desktop settings should balance gameplay switches across two columns")
		quit(1)
		return
	if not bool(app_state.settings.get("hide_completed_numbers", true)):
		push_error("UI smoke: completed number hiding should be enabled by default")
		quit(1)
		return
	if not app_state.settings.has("leaderboard_auto_refresh") or not app_state.settings.has("leaderboard_network_allowed") \
			or not app_state.settings.has("ranked_auto_upload") \
			or not app_state.settings.has("error_sound") or not app_state.settings.has("custom_error_sound_path"):
		push_error("UI smoke: leaderboard and error-sound settings were not migrated")
		quit(1)
		return
	if bool(app_state._default_settings().get("ranked_auto_upload", true)):
		push_error("UI smoke: automatic ranked-result upload should be off by default")
		quit(1)
		return
	var ranked_upload_setting_labels: Array[Node] = main.content.find_children("*", "Label", true, false).filter(
		func(node: Node) -> bool: return (node as Label).text in ["自动上传所有排位完成成绩", "Automatically upload every completed ranked game"]
	)
	if ranked_upload_setting_labels.size() != 1:
		push_error("UI smoke: ranked automatic-upload setting is missing")
		quit(1)
		return
	if not main._is_mobile_device("Android") or not main._is_mobile_device("iOS") or main._is_mobile_device("macOS"):
		push_error("UI smoke: mobile-only controls do not use platform detection")
		quit(1)
		return
	var desktop_haptic_labels: Array[Node] = main.content.find_children("*", "Label", true, false).filter(
		func(node: Node) -> bool: return (node as Label).text.contains("震动") or (node as Label).text.contains("Haptics")
	)
	if not desktop_haptic_labels.is_empty():
		push_error("UI smoke: desktop settings should not show the mobile haptics control")
		quit(1)
		return
	var custom_sound_titles: Array[Node] = main.content.find_children("*", "Label", true, false).filter(
		func(node: Node) -> bool: return (node as Label).text in ["自定义音效", "Custom Sounds"]
	)
	var sound_disclosure := main.content.find_child("CustomSoundsDisclosure", true, false) as Button
	if custom_sound_titles.size() != 1 or sound_disclosure == null \
			or not main.RuntimeAudioLoaderScript.is_supported_path("button.mp3") or main.RuntimeAudioLoaderScript.is_supported_path("button.m4a"):
		push_error("UI smoke: first-level custom sound settings or format validation is missing")
		quit(1)
		return
	main._toggle_sound_customization()
	await process_frame
	if main.content.find_child("CustomSoundsSecondaryMenu", true, false) == null:
		push_error("UI smoke: button and mistake sounds should live in an expandable secondary menu")
		quit(1)
		return
	var custom_audio_test_path := "/tmp/sudoku-ui-smoke-custom"
	if main.ui_sounds._tap_stream.save_to_wav(custom_audio_test_path) != OK:
		push_error("UI smoke: could not create a temporary custom WAV")
		quit(1)
		return
	var loaded_custom_stream: AudioStream = main.RuntimeAudioLoaderScript.load_file(custom_audio_test_path + ".wav")
	DirAccess.remove_absolute(custom_audio_test_path + ".wav")
	if loaded_custom_stream == null:
		push_error("UI smoke: runtime WAV loading failed")
		quit(1)
		return
	main.ui_sounds.set_custom_stream(loaded_custom_stream)
	if not main.ui_sounds.has_custom_stream():
		push_error("UI smoke: custom button audio stream was not accepted")
		quit(1)
		return
	main.ui_sounds.reload_custom_sound("")
	main.ui_sounds.play_tap()
	if not main.ui_sounds.is_any_player_active():
		push_error("UI smoke: tap sound was not sent to an active audio player")
		quit(1)
		return
	main.ui_sounds.play_selection()
	app_state.settings["sound"] = true
	app_state.settings["error_sound"] = true
	var feedback_manager := root.get_node("FeedbackManager")
	feedback_manager.error_feedback()
	if not feedback_manager.is_error_player_active():
		push_error("UI smoke: mistake feedback did not reach the dedicated audio player")
		quit(1)
		return
	var undo_event := InputEventKey.new()
	undo_event.keycode = KEY_Z
	undo_event.meta_pressed = OS.get_name() == "macOS"
	undo_event.ctrl_pressed = OS.get_name() != "macOS"
	if not main._event_matches_shortcut(undo_event, "undo"):
		push_error("UI smoke: undo does not use the platform-default modifier")
		quit(1)
		return
	var mac_defaults: Dictionary = main._default_shortcuts("macOS")
	var windows_defaults: Dictionary = main._default_shortcuts("Windows")
	var linux_defaults: Dictionary = main._default_shortcuts("Linux")
	if not bool(mac_defaults["undo"]["meta"]) or bool(mac_defaults["undo"]["ctrl"]) \
		or int(mac_defaults["redo"]["keycode"]) != KEY_Z or not bool(mac_defaults["redo"]["shift"]) \
		or int(mac_defaults["erase"]["keycode"]) != KEY_BACKSPACE:
		push_error("UI smoke: macOS shortcuts do not match Command-based conventions")
		quit(1)
		return
	if not bool(windows_defaults["undo"]["ctrl"]) or bool(windows_defaults["undo"]["meta"]) \
		or int(windows_defaults["redo"]["keycode"]) != KEY_Y or bool(windows_defaults["redo"]["shift"]) \
		or int(windows_defaults["erase"]["keycode"]) != KEY_DELETE:
		push_error("UI smoke: Windows shortcuts do not match Control-based conventions")
		quit(1)
		return
	if not bool(linux_defaults["redo"]["ctrl"]) or not bool(linux_defaults["redo"]["shift"]) \
		or int(linux_defaults["redo"]["keycode"]) != KEY_Z \
		or int(linux_defaults["settings"]["keycode"]) != KEY_COMMA:
		push_error("UI smoke: Linux shortcuts do not match GNOME conventions")
		quit(1)
		return
	var settings_shortcut: String = main._shortcut_display(main._binding_for("settings"))
	if settings_shortcut.contains("Comma") or not settings_shortcut.contains(","):
		push_error("UI smoke: Open Settings shortcut should use a compact comma glyph")
		quit(1)
		return
	main._show_choice_sheet(["System", "Light", "Dark"], ["system", "light", "dark"], "system", Callable(main, "_set_theme_value"))
	await process_frame
	var overlays := main.get_children().filter(func(child: Node) -> bool: return child is ColorRect and child.z_index == 120)
	if not overlays.is_empty():
		overlays[0].queue_free()
	main._set_language_value("en")
	await process_frame
	main._show_difficulty(true)
	await process_frame
	var wide_difficulty_cards: Array[Node] = main.content.find_children("*", "PanelContainer", true, false).filter(
		func(node: Node) -> bool: return (node as Control).theme_type_variation == "DifficultyCard"
	)
	var wide_difficulty_grid := main.content.find_child("DifficultyGrid", true, false) as GridContainer
	if wide_difficulty_cards.size() != 6 or wide_difficulty_grid == null or wide_difficulty_grid.columns != 3:
		push_error("UI smoke: desktop difficulty selection should use six information cards in a compact three-column grid")
		quit(1)
		return
	main._choose_difficulty(2, true)
	await process_frame
	if main._current_view != "ranked_briefing" or main.content.find_child("RankedBriefingCard", true, false) == null:
		push_error("UI smoke: ranked play should show fair-play rules before fetching a challenge")
		quit(1)
		return
	main._begin_ranked_challenge(0)
	for attempt in 400:
		if main._current_view == "game":
			break
		await create_timer(0.01).timeout
	if main._current_view != "game" or main.game_service.session == null or main.game_service.session.mode != "ranked":
		push_error("UI smoke: ranked play should enter a game even when online services and cached challenges are unavailable")
		quit(1)
		return
	var nine_puzzle := SudokuValidator.string_to_board("530070000600195000098000060800060003400803001700020006060000280000419005000080079")
	var nine_solution := SudokuSolver.new().solve(nine_puzzle)
	main.game_service.start_session({"puzzle": nine_puzzle, "solution": nine_solution, "difficulty": 1})
	main._show_game()
	await process_frame
	if main.cell_buttons.size() != 81 or main.cell_buttons[0].text != "5":
		push_error("UI smoke: 9x9 board did not refresh clue values")
		quit(1)
		return
	for column in 9:
		var row_index := column
		if row_index != 2 and main.game_service.session.board[row_index] == 0:
			main.game_service.session.board[row_index] = nine_solution[row_index]
	main._refresh_game()
	main.game_service.select(2)
	main.game_service.enter_number(nine_solution[2])
	await process_frame
	var completion_pulses := 0
	for column in 9:
		completion_pulses += main.cell_buttons[column].completion_pulse_count
	if completion_pulses < 9:
		push_error("UI smoke: completing a local row should animate every cell in that row")
		quit(1)
		return
	main.game_service.start_session({"puzzle": nine_puzzle, "solution": nine_solution, "difficulty": 1})
	main._show_game()
	await process_frame
	main.game_service.select(0)
	main._refresh_game()
	var selected_corner_style := main.cell_buttons[0].get_theme_stylebox("normal") as StyleBoxFlat
	if selected_corner_style == null or selected_corner_style.corner_radius_top_left != 18:
		push_error("UI smoke: selected corner cell should follow the rounded board corner")
		quit(1)
		return
	var conflict_corner_style := main.cell_buttons[0]._conflict_outline_style() as StyleBoxFlat
	var conflict_inner_style := main.cell_buttons[1]._conflict_outline_style() as StyleBoxFlat
	if conflict_corner_style == null or conflict_corner_style.corner_radius_top_left != 15 \
			or conflict_inner_style == null or conflict_inner_style.corner_radius_top_left != 0:
		push_error("UI smoke: a corner-cell mistake outline should follow the rounded board edge")
		quit(1)
		return
	main.game_service.select(2)
	main._refresh_game()
	var related_corner_style := main.cell_buttons[0].get_theme_stylebox("normal") as StyleBoxFlat
	if not main.cell_buttons[0].related or related_corner_style == null or related_corner_style.corner_radius_top_left != 18 \
			or related_corner_style.corner_detail < 16:
		push_error("UI smoke: related row/column shading should follow the rounded board corner")
		quit(1)
		return
	main.game_service.select(14)
	main._refresh_game()
	var matching_corner_style := main.cell_buttons[0].get_theme_stylebox("normal") as StyleBoxFlat
	if not main.cell_buttons[0].same_value or matching_corner_style == null or matching_corner_style.corner_radius_top_left != 18:
		push_error("UI smoke: matching-value highlight should follow a rounded board corner")
		quit(1)
		return
	var cell_style := main.cell_buttons[1].get_theme_stylebox("normal") as StyleBoxFlat
	if cell_style == null or cell_style.corner_radius_top_left != 0:
		push_error("UI smoke: Sudoku cells should remain square inside the rounded board")
		quit(1)
		return
	var board_panels: Array = main.content.find_children("*", "PanelContainer", true, false).filter(
		func(node: Node) -> bool: return (node as Control).theme_type_variation == "GameBoardPanel"
	)
	if board_panels.size() != 1:
		push_error("UI smoke: rounded game board frame is missing")
		quit(1)
		return
	var board_style := (board_panels[0] as Control).get_theme_stylebox("panel") as StyleBoxFlat
	if board_style == null or board_style.corner_radius_top_left != 24:
		push_error("UI smoke: game board surface does not have rounded corners")
		quit(1)
		return
	var board_outline := (board_panels[0] as Node).get_node_or_null("BoardOutline") as Control
	var outline_style := board_outline.get_theme_stylebox("panel") as StyleBoxFlat if board_outline != null else null
	if outline_style == null or outline_style.corner_radius_top_left != 24 or outline_style.border_width_top != 2 or board_outline.z_index != 20:
		push_error("UI smoke: topmost rounded blue board outline is missing")
		quit(1)
		return
	var notes_preview: String = main.cell_buttons[0]._notes_text(1 << 1)
	if notes_preview.contains("·") or not notes_preview.contains("1"):
		push_error("UI smoke: notes should use blank unmarked slots and visible marked values")
		quit(1)
		return
	var note_cell: SudokuCellButton = main.cell_buttons[2]
	note_cell.update_state(0, 1 << 1, false, false, false, false, false, 0)
	var single_note_minimum: Vector2 = note_cell.get_combined_minimum_size()
	note_cell.update_state(0, (1 << 10) - 2, false, false, false, false, false, 0)
	var many_notes_minimum: Vector2 = note_cell.get_combined_minimum_size()
	if not single_note_minimum.is_equal_approx(many_notes_minimum) or not note_cell.text.is_empty():
		push_error("UI smoke: note count must not change a Sudoku cell's minimum size")
		quit(1)
		return
	var clue_color: Color = main.cell_buttons[0].get_theme_color("font_color")
	main.game_service.session.board[2] = nine_solution[2]
	main._refresh_game()
	var player_color: Color = main.cell_buttons[2].get_theme_color("font_color")
	if clue_color.is_equal_approx(player_color) or main.cell_buttons[2].get_theme_font_size("font_size") <= main.cell_buttons[0].get_theme_font_size("font_size"):
		push_error("UI smoke: clue and player-entered digits should have distinct visual hierarchy")
		quit(1)
		return
	main.game_service.session.board[2] = 0
	main.game_service.session.notes[2] = 1 << 4
	main.game_service.session.notes[3] = (1 << 4) | (1 << 7)
	main.game_service.select(2)
	main._refresh_game()
	if main.cell_buttons[3].highlighted_notes_mask != (1 << 4) or not main.cell_buttons[3].text.is_empty():
		push_error("UI smoke: matching notes should highlight within the low-priority note style")
		quit(1)
		return
	for index in nine_solution.size():
		if nine_solution[index] == 1:
			main.game_service.session.board[index] = 1
	main._refresh_game()
	var completed_number_button := main.number_buttons[1] as Button
	if main.number_buttons.size() != 9 or not completed_number_button.visible or not completed_number_button.disabled \
		or not completed_number_button.text.is_empty() or completed_number_button.theme_type_variation != "NumberPadPlaceholder":
		push_error("UI smoke: a fully placed value should leave a fixed blank number slot")
		quit(1)
		return
	app_state.settings["hide_completed_numbers"] = false
	main._refresh_game()
	if not completed_number_button.visible or completed_number_button.disabled or completed_number_button.text != "1":
		push_error("UI smoke: completed numbers should remain visible when the setting is disabled")
		quit(1)
		return
	app_state.settings["hide_completed_numbers"] = true
	main.game_service.select(2)
	main._toggle_notes()
	main.game_service.enter_number(5)
	main._refresh_game()
	if main.notes_button.text != "Notes" or main.notes_button.theme_type_variation != "NotesActiveButton":
		push_error("UI smoke: active Notes control should keep a clean fixed label and dedicated style")
		quit(1)
		return
	if not main.cell_buttons[2].text.is_empty() or main.cell_buttons[2].notes_mask == 0:
		push_error("UI smoke: notes should be drawn independently without becoming button text")
		quit(1)
		return
	main._toggle_notes()
	var previous_mistakes: int = main.game_service.session.mistakes
	app_state.settings["auto_check"] = false
	main.game_service.enter_number(5)
	main._refresh_game()
	if main.game_service.session.mistakes != previous_mistakes or main.cell_buttons[2].conflict:
		push_error("UI smoke: disabling automatic checks should suppress both mistake increments and conflict marks")
		quit(1)
		return
	app_state.settings["auto_check"] = true
	main.game_service.erase()
	main.game_service.select(10)
	var right_event := InputEventKey.new()
	right_event.keycode = KEY_RIGHT
	right_event.pressed = true
	main._input(right_event)
	if main.game_service.selected_index != 11:
		push_error("UI smoke: Right Arrow did not move the selected cell")
		quit(1)
		return
	main.game_service.session.mistakes = 3
	main._refresh_game()
	if main.mistake_icon == null or not main.mistake_icon.texture.resource_path.ends_with("warning.svg"):
		push_error("UI smoke: the third mistake did not activate the warning icon")
		quit(1)
		return
	main._toggle_pause()
	await process_frame
	if main.pause_overlay == null or not main.pause_overlay.visible or not main.cell_buttons[0].disabled:
		push_error("UI smoke: pause overlay is not covering and disabling the board")
		quit(1)
		return
	if main.pause_blur_layer == null or not main.pause_blur_layer.material is ShaderMaterial or not (main.pause_blur_layer.material as ShaderMaterial).shader.code.contains("textureLod"):
		push_error("UI smoke: pause overlay should include a real screen-texture blur shader")
		quit(1)
		return
	var pause_material := main.pause_blur_layer.material as ShaderMaterial
	var pause_tint: Color = pause_material.get_shader_parameter("tint_color")
	if float(pause_material.get_shader_parameter("blur_lod")) < 5.5 or pause_tint.a < 0.35:
		push_error("UI smoke: paused cells should be strongly blurred and obscured")
		quit(1)
		return
	var pause_margin := main.pause_overlay.get_parent() as MarginContainer
	var pause_style := main.pause_overlay.get_theme_stylebox("panel") as StyleBoxFlat
	if pause_margin == null or pause_margin.get_theme_constant("margin_left") != 0 or pause_margin.get_theme_constant("margin_top") != 0 \
			or pause_style == null or pause_style.content_margin_left != 0 or pause_style.corner_radius_top_left != 24 \
			or not main.pause_blur_layer.size.is_equal_approx(main.pause_overlay.size):
		push_error("UI smoke: pause blur should cover the complete interior of the board outline")
		quit(1)
		return
	main._toggle_pause()
	main.game_service.session.new_best = true
	main._show_result(main.game_service.session)
	await process_frame
	var record_panels: Array[Node] = main.content.find_children("*", "PanelContainer", true, false).filter(
		func(node: Node) -> bool: return (node as Control).theme_type_variation == "RecordPanel"
	)
	if record_panels.size() != 1:
		push_error("UI smoke: a personal-best completion should show the record congratulations panel")
		quit(1)
		return
	var result_cards: Array[Node] = main.content.find_children("ResultCard", "PanelContainer", true, false)
	if result_cards.size() != 1 or (result_cards[0] as Control).custom_minimum_size.x > 760:
		push_error("UI smoke: completion screen should use one compact centered result card")
		quit(1)
		return
	var result_subtitles: Array[Node] = main.content.find_children("*", "Label", true, false).filter(
		func(node: Node) -> bool: return (node as Label).text == "Difficulty: Easy · Completed"
	)
	if result_subtitles.size() != 1:
		push_error("UI smoke: completion difficulty subtitle is malformed")
		quit(1)
		return
	var ranked_result := GameSession.create(nine_puzzle, nine_solution, 1, "ranked")
	ranked_result.board = nine_solution.duplicate()
	ranked_result.offline_ranked = true
	ranked_result.completed = true
	ranked_result.elapsed_ms = 95_000
	ranked_result.operation_count = 64
	app_state.settings["ranked_auto_upload"] = false
	main._on_game_completed(ranked_result)
	await process_frame
	var ranked_upload_panel: Node = main.content.find_child("RankedUploadChoice", true, false)
	var ranked_upload_button: Node = main.content.find_child("RankedUploadButton", true, false)
	var ranked_decline_button: Node = main.content.find_child("RankedDeclineButton", true, false)
	var ranked_payload: Dictionary = main._build_ranked_submission(ranked_result)
	if ranked_upload_panel == null or ranked_upload_button == null or ranked_decline_button == null \
			or ranked_payload.get("source") != "offline" or ranked_payload.get("difficulty") != 2 \
			or str(ranked_payload.get("puzzle", "")).length() != 81:
		push_error("UI smoke: completed offline ranked games should offer upload and build an offline payload")
		quit(1)
		return
	main._decline_ranked_upload()
	await process_frame
	if main.content.find_child("RankedUploadButton", true, false) != null \
			or main.content.find_child("RankedDeclineButton", true, false) != null:
		push_error("UI smoke: declining a ranked upload should leave the result local without prompting again")
		quit(1)
		return
	main._show_statistics()
	await process_frame
	var stats_heroes: Array[Node] = main.content.find_children("*", "PanelContainer", true, false).filter(
		func(node: Node) -> bool: return (node as Control).theme_type_variation == "StatsHero"
	)
	var stat_metrics: Array[Node] = main.content.find_children("*", "PanelContainer", true, false).filter(
		func(node: Node) -> bool: return (node as Control).theme_type_variation == "StatMetric"
	)
	var stat_records: Array[Node] = main.content.find_children("*", "PanelContainer", true, false).filter(
		func(node: Node) -> bool: return (node as Control).theme_type_variation == "StatsRecordCard"
	)
	if stats_heroes.size() != 1 or stat_metrics.size() != 5 or stat_records.size() != 6:
		push_error("UI smoke: statistics should use the shared card-based visual system")
		quit(1)
		return
	app_state.settings["leaderboard_network_allowed"] = false
	app_state.settings["leaderboard_auto_refresh"] = false
	main._show_leaderboard()
	await process_frame
	var leaderboard_refresh := main.content.find_child("LeaderboardRefreshButton", true, false) as Button
	if leaderboard_refresh == null or leaderboard_refresh.text != "Allow network & refresh" or not main.leaderboard_service._request_id.is_empty():
		push_error("UI smoke: leaderboard should remain cache-only until the user grants network access")
		quit(1)
		return
	main._show_leaderboard_snapshot({
		"source": "cache", "cached_at": "2026-07-22T08:00:00Z",
		"self_entry": {"rank": 17, "display_name": "Player", "duration_ms": 94000, "mistakes": 1, "move_count": 82},
		"entries": [{"rank": 1, "display_name": "Fast Player", "duration_ms": 42000, "mistakes": 0, "move_count": 61}]
	})
	await process_frame
	var self_cards: Array[Node] = main.content.find_children("*", "PanelContainer", true, false).filter(
		func(node: Node) -> bool: return (node as Control).theme_type_variation == "LeaderboardSelfCard"
	)
	var leaderboard_rows: Array[Node] = main.content.find_children("*", "PanelContainer", true, false).filter(
		func(node: Node) -> bool: return (node as Control).theme_type_variation == "LeaderboardRow"
	)
	if self_cards.size() != 1 or leaderboard_rows.size() != 1:
		push_error("UI smoke: cached leaderboard should show both the user's position and ranked entries")
		quit(1)
		return
	main._show_difficulty(true)
	await process_frame
	var difficulty_buttons: Array[Node] = main.content.find_children("*", "Button", true, false).filter(
		func(node: Node) -> bool: return (node as Button).text in main.DIFFICULTY_EN
	)
	if difficulty_buttons.size() != 6:
		push_error("UI smoke: local and ranked modes should both expose all six difficulties")
		quit(1)
		return
	var ranked_session := GameSession.create(nine_puzzle, nine_solution, 1, "ranked")
	for key in ["auto_check", "auto_clear_notes", "hide_completed_numbers", "highlight_same", "highlight_related", "show_mistakes"]:
		app_state.settings[key] = true
	main.game_service.resume_session(ranked_session)
	main._show_game()
	await process_frame
	var ranked_notice: Node = main.content.find_child("RankedGameNotice", true, false)
	var ranked_core_buttons: Array[Node] = main.content.find_children("*", "Button", true, false).filter(
		func(node: Node) -> bool: return (node as Button).text in ["Undo", "Redo", "Notes", "Pause"]
	)
	var all_core_controls_available := ranked_core_buttons.size() == 4
	for core_button in ranked_core_buttons:
		all_core_controls_available = all_core_controls_available and not (core_button as Button).disabled
	if ranked_notice == null or not all_core_controls_available \
			or not main.game_service.effective_setting("auto_check", false) \
			or not main.game_service.effective_setting("show_mistakes", false) \
			or main.game_service.effective_setting("highlight_related", true) or main.game_service.effective_setting("hide_completed_numbers", true):
		push_error("UI smoke: ranked play should keep core controls and mistake checking while locking puzzle assistance")
		quit(1)
		return
	if main.mistake_icon == null or main.mistakes_label == null \
			or main.mistake_icon.modulate.a > 0.01 or main.mistakes_label.text != "0 / 3 errors" \
			or main.mistake_icon.custom_minimum_size.x < 24 or main.mistakes_label.custom_minimum_size.x < 92:
		push_error("UI smoke: ranked mistake warning should reserve stable space before the first mistake")
		quit(1)
		return
	main._toggle_notes()
	main.game_service.enter_number(4)
	if not main.game_service.notes_mode or main.game_service.session.notes[main.game_service.selected_index] == 0 \
			or not bool(app_state.settings["highlight_related"]):
		push_error("UI smoke: ranked notes should work without mutating global assistance preferences")
		quit(1)
		return
	main.game_service.undo()
	if main.game_service.session.notes[main.game_service.selected_index] != 0:
		push_error("UI smoke: ranked undo should restore the prior note state")
		quit(1)
		return
	main.game_service.redo()
	if main.game_service.session.notes[main.game_service.selected_index] == 0:
		push_error("UI smoke: ranked redo should restore the note")
		quit(1)
		return
	main._toggle_pause()
	await process_frame
	if not main.game_service.paused or main.pause_overlay == null or not main.pause_overlay.visible:
		push_error("UI smoke: ranked pause should stop and obscure the board")
		quit(1)
		return
	main._toggle_pause()
	main._toggle_notes()
	main.game_service.enter_number(1)
	if main.game_service.session.mistakes != 1 or main.mistakes_label.text != "1 / 3 errors" \
			or not main.mistake_icon.texture.resource_path.ends_with("error.svg") \
			or not main.mistake_icon.modulate.is_equal_approx(Color("ff9f0a")):
		push_error("UI smoke: the first ranked mistake should show the lower-level amber warning")
		quit(1)
		return
	main.game_service.undo()
	main.game_service.redo()
	main.game_service.enter_number(2)
	if main.game_service.session.mistakes != 2 or main.mistakes_label.text != "2 / 3 errors" \
			or not main.mistake_icon.texture.resource_path.ends_with("warning.svg") \
			or not main.mistake_icon.modulate.is_equal_approx(Color("ff6b35")):
		push_error("UI smoke: the second ranked mistake should escalate to an orange warning")
		quit(1)
		return
	main.game_service.enter_number(3)
	await process_frame
	var failure_card: Node = main.content.find_child("RankedFailureCard", true, false)
	if main._current_view != "ranked_failed" or failure_card == null \
			or main.game_service.session.mistakes != 3 or not main.game_service.session.completed \
			or app_state.load_session("ranked", 1) != null:
		push_error("UI smoke: the third ranked mistake should end the game, clear its save and show a failure prompt")
		quit(1)
		return
	var result := HexadokuGenerator.new().generate(20260718)
	main.game_service.start_session(result)
	main._show_game()
	await process_frame
	main._toggle_notes()
	main._toggle_pause()
	await process_frame
	if main.pause_overlay == null or not main.pause_overlay.visible:
		push_error("UI smoke: hexadoku pause overlay is missing")
		quit(1)
		return
	main._toggle_pause()
	main.game_service.enter_number(16)
	await process_frame
	if main.cell_buttons.size() != 256:
		push_error("UI smoke: expected 256 hexadoku cells")
		quit(1)
		return
	if main.notes_button == null or main.pause_button == null:
		push_error("UI smoke: game controls missing")
		quit(1)
		return
	root.size = Vector2i(430, 900)
	await process_frame
	await process_frame
	main._show_difficulty(false)
	await process_frame
	var narrow_difficulty_grids: Array[Node] = main.content.find_children("*", "GridContainer", true, false)
	if narrow_difficulty_grids.is_empty() or (narrow_difficulty_grids[0] as GridContainer).columns != 1:
		push_error("UI smoke: mobile difficulty layout should collapse to one column")
		quit(1)
		return
	var narrow_difficulty_buttons: Array[Node] = main.content.find_children("*", "Button", true, false).filter(
		func(node: Node) -> bool: return (node as Button).text in main.DIFFICULTY_EN
	)
	if narrow_difficulty_buttons.is_empty() or (narrow_difficulty_buttons[0] as Button).custom_minimum_size.y < 72:
		push_error("UI smoke: mobile difficulty buttons should match the shared button height")
		quit(1)
		return
	main._show_menu()
	await process_frame
	var home_hero := main.content.find_child("HomeHero", true, false) as PanelContainer
	var mobile_home_buttons: Array[Node] = main.content.find_children("*", "Button", true, false).filter(
		func(node: Node) -> bool: return (node as Button).text == "New local game"
	)
	if home_hero == null or mobile_home_buttons.size() != 1 \
		or (mobile_home_buttons[0] as Button).custom_minimum_size.x < 380 \
		or (mobile_home_buttons[0] as Button).custom_minimum_size.y < 72:
		push_error("UI smoke: mobile home hierarchy or full-width buttons are not applied")
		quit(1)
		return
	main.game_service.start_session({"puzzle": nine_puzzle, "solution": nine_solution, "difficulty": 1})
	main._show_game()
	await process_frame
	var mobile_scrolls: Array[Node] = main.content.find_children("*", "ScrollContainer", true, false)
	if mobile_scrolls.is_empty():
		push_error("UI smoke: compact game layout should scroll instead of leaving or clipping excess vertical space")
		quit(1)
		return
	var sample_button: Button = main._button("Spacing")
	if sample_button.custom_minimum_size.y < 72:
		push_error("UI smoke: shared buttons should use the roomier vertical rhythm")
		quit(1)
		return
	sample_button.free()
	print("UI smoke: completion text, ranked upload choice, local unit animation, staged mistake warnings, and prior coverage passed")
	main.queue_free()
	await process_frame
	await process_frame
	quit(0)
