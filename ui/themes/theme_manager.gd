class_name ThemeManager
extends RefCounted

static func build(dark: bool, high_contrast: bool = false) -> Theme:
	var theme := Theme.new()
	var background := Color("000000") if dark else Color("f5f5f7")
	var surface := Color("1c1c1e") if dark else Color("ffffff")
	var control := Color("2c2c2e") if dark else Color("f2f2f7")
	var text := Color("f5f5f7") if dark else Color("1d1d1f")
	var muted := Color("aeaeb2") if dark else Color("6e6e73")
	var separator := Color("38383a") if dark else Color("d1d1d6")
	var accent := (Color("64d2ff") if dark else Color("0066cc")) if high_contrast else (Color("0a84ff") if dark else Color("007aff"))
	theme.set_color("font_color", "Label", text)
	theme.set_color("font_color", "Button", text)
	theme.set_color("font_hover_color", "Button", text)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_focus_color", "Button", text)
	theme.set_color("icon_normal_color", "Button", text)
	theme.set_color("icon_hover_color", "Button", text)
	theme.set_color("icon_pressed_color", "Button", Color.WHITE)
	theme.set_color("icon_focus_color", "Button", text)
	theme.set_color("icon_disabled_color", "Button", muted)
	theme.set_color("font_color", "LineEdit", text)
	theme.set_color("font_placeholder_color", "LineEdit", muted)
	theme.set_color("caret_color", "LineEdit", accent)
	theme.set_color("selection_color", "LineEdit", Color(accent, 0.32))
	theme.set_color("font_selected_color", "LineEdit", text)
	theme.set_font_size("font_size", "Label", 28)
	theme.set_font_size("font_size", "Button", 28)
	theme.set_font_size("font_size", "LineEdit", 28)
	theme.set_constant("outline_size", "Label", 0)
	var normal := _box(control, 18, separator, 1)
	var hover := _box(control.lerp(accent, 0.12), 18, accent, 1)
	var pressed := _box(accent, 18, accent, 1)
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("focus", "Button", hover)
	theme.set_stylebox("normal", "LineEdit", _box(control, 14, separator, 1))
	theme.set_stylebox("focus", "LineEdit", _box(control, 14, accent, 2))
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(color_name, "OptionButton", text)
	theme.set_font_size("font_size", "OptionButton", 28)
	theme.set_stylebox("normal", "OptionButton", normal)
	theme.set_stylebox("hover", "OptionButton", hover)
	theme.set_stylebox("pressed", "OptionButton", pressed)
	theme.set_stylebox("focus", "OptionButton", hover)
	theme.set_color("font_color", "PopupMenu", text)
	theme.set_color("font_hover_color", "PopupMenu", text)
	theme.set_font_size("font_size", "PopupMenu", 26)
	theme.set_stylebox("panel", "PopupMenu", _box(surface, 18, separator, 1))
	theme.set_stylebox("hover", "PopupMenu", _box(control.lerp(accent, 0.14), 10, accent, 0))
	var group_panel := _box(surface, 24, separator, 1)
	group_panel.content_margin_left = 0
	group_panel.content_margin_right = 0
	group_panel.content_margin_top = 0
	group_panel.content_margin_bottom = 0
	theme.set_stylebox("panel", "PanelContainer", group_panel)
	theme.set_type_variation("HomeHero", "PanelContainer")
	var home_hero := _box(surface.lerp(accent, 0.035), 26, Color(accent, 0.28), 1)
	home_hero.shadow_color = Color(0, 0, 0, 0.10 if dark else 0.05)
	home_hero.shadow_size = 10
	home_hero.shadow_offset = Vector2(0, 4)
	home_hero.content_margin_left = 0
	home_hero.content_margin_right = 0
	home_hero.content_margin_top = 0
	home_hero.content_margin_bottom = 0
	theme.set_stylebox("panel", "HomeHero", home_hero)
	theme.set_type_variation("DifficultyIntro", "PanelContainer")
	var difficulty_intro := _box(surface.lerp(accent, 0.045), 22, Color(accent, 0.24), 1)
	difficulty_intro.content_margin_left = 0
	difficulty_intro.content_margin_right = 0
	difficulty_intro.content_margin_top = 0
	difficulty_intro.content_margin_bottom = 0
	theme.set_stylebox("panel", "DifficultyIntro", difficulty_intro)
	theme.set_type_variation("DifficultyCard", "PanelContainer")
	var difficulty_card := _box(surface, 22, separator, 1)
	difficulty_card.content_margin_left = 0
	difficulty_card.content_margin_right = 0
	difficulty_card.content_margin_top = 0
	difficulty_card.content_margin_bottom = 0
	difficulty_card.shadow_color = Color(0, 0, 0, 0.12 if dark else 0.055)
	difficulty_card.shadow_size = 8
	difficulty_card.shadow_offset = Vector2(0, 3)
	theme.set_stylebox("panel", "DifficultyCard", difficulty_card)
	theme.set_type_variation("DifficultyButton", "Button")
	theme.set_stylebox("normal", "DifficultyButton", _box(control.lerp(accent, 0.10), 16, Color(accent, 0.42), 1))
	theme.set_stylebox("hover", "DifficultyButton", _box(control.lerp(accent, 0.18), 16, accent, 2))
	theme.set_stylebox("pressed", "DifficultyButton", _box(accent, 16, accent, 2))
	theme.set_stylebox("focus", "DifficultyButton", _box(control.lerp(accent, 0.18), 16, accent, 2))
	theme.set_type_variation("RankedBriefingCard", "PanelContainer")
	var ranked_briefing := _box(surface, 28, Color(accent, 0.42), 1)
	ranked_briefing.content_margin_left = 0
	ranked_briefing.content_margin_right = 0
	ranked_briefing.content_margin_top = 0
	ranked_briefing.content_margin_bottom = 0
	ranked_briefing.shadow_color = Color(0, 0, 0, 0.20 if dark else 0.10)
	ranked_briefing.shadow_size = 16
	ranked_briefing.shadow_offset = Vector2(0, 7)
	theme.set_stylebox("panel", "RankedBriefingCard", ranked_briefing)
	theme.set_type_variation("RankedNotice", "PanelContainer")
	var ranked_notice := _box(control.lerp(accent, 0.12), 16, Color(accent, 0.34), 1)
	ranked_notice.content_margin_left = 18
	ranked_notice.content_margin_right = 18
	ranked_notice.content_margin_top = 11
	ranked_notice.content_margin_bottom = 11
	theme.set_stylebox("panel", "RankedNotice", ranked_notice)
	theme.set_type_variation("StatsHero", "PanelContainer")
	var stats_hero := _box(surface.lerp(accent, 0.05), 24, Color(accent, 0.28), 1)
	stats_hero.content_margin_left = 0
	stats_hero.content_margin_right = 0
	stats_hero.content_margin_top = 0
	stats_hero.content_margin_bottom = 0
	theme.set_stylebox("panel", "StatsHero", stats_hero)
	theme.set_type_variation("StatMetric", "PanelContainer")
	theme.set_stylebox("panel", "StatMetric", _box(surface, 19, Color(accent, 0.22), 1))
	theme.set_type_variation("StatsRecordCard", "PanelContainer")
	var stats_record := _box(surface, 19, separator, 1)
	stats_record.content_margin_left = 0
	stats_record.content_margin_right = 0
	stats_record.content_margin_top = 0
	stats_record.content_margin_bottom = 0
	theme.set_stylebox("panel", "StatsRecordCard", stats_record)
	theme.set_type_variation("LeaderboardControlCard", "PanelContainer")
	var leaderboard_control := _box(surface.lerp(accent, 0.035), 24, Color(accent, 0.24), 1)
	leaderboard_control.content_margin_left = 0
	leaderboard_control.content_margin_right = 0
	leaderboard_control.content_margin_top = 0
	leaderboard_control.content_margin_bottom = 0
	theme.set_stylebox("panel", "LeaderboardControlCard", leaderboard_control)
	theme.set_type_variation("LeaderboardEmptyCard", "PanelContainer")
	theme.set_stylebox("panel", "LeaderboardEmptyCard", _box(surface, 20, separator, 1))
	theme.set_type_variation("LeaderboardSelfCard", "PanelContainer")
	theme.set_stylebox("panel", "LeaderboardSelfCard", _box(control.lerp(accent, 0.13), 20, Color(accent, 0.55), 2))
	theme.set_type_variation("LeaderboardRow", "PanelContainer")
	theme.set_stylebox("panel", "LeaderboardRow", _box(surface, 14, separator, 1))
	theme.set_type_variation("GameBoardPanel", "PanelContainer")
	# The surface is drawn below the square cells. The blue stroke is a separate
	# topmost overlay so cell backgrounds cannot cut holes in its curved corners.
	var board_panel := _box(surface, 24, Color.TRANSPARENT, 0)
	board_panel.shadow_color = Color(0, 0, 0, 0.20 if dark else 0.10)
	board_panel.shadow_size = 10
	board_panel.shadow_offset = Vector2(0, 4)
	board_panel.content_margin_left = 0
	board_panel.content_margin_right = 0
	board_panel.content_margin_top = 0
	board_panel.content_margin_bottom = 0
	theme.set_stylebox("panel", "GameBoardPanel", board_panel)
	theme.set_type_variation("GameBoardOutline", "Panel")
	var board_outline := _box(Color.TRANSPARENT, 24, Color(accent, 0.92), 2)
	board_outline.content_margin_left = 0
	board_outline.content_margin_right = 0
	board_outline.content_margin_top = 0
	board_outline.content_margin_bottom = 0
	board_outline.anti_aliasing = true
	board_outline.corner_detail = 16
	theme.set_stylebox("panel", "GameBoardOutline", board_outline)
	theme.set_type_variation("GameControlsPanel", "PanelContainer")
	theme.set_stylebox("panel", "GameControlsPanel", _box(surface, 24, separator, 1))
	theme.set_type_variation("PauseBoardOverlay", "PanelContainer")
	# The outline is drawn above this full-board layer, so the blur can reach
	# underneath the blue stroke without hiding or squaring off its corners.
	var pause_overlay := _box(Color(surface, 0.10), 24, Color.TRANSPARENT, 0)
	pause_overlay.content_margin_left = 0
	pause_overlay.content_margin_right = 0
	pause_overlay.content_margin_top = 0
	pause_overlay.content_margin_bottom = 0
	theme.set_stylebox("panel", "PauseBoardOverlay", pause_overlay)
	theme.set_type_variation("PauseMessageCard", "PanelContainer")
	var pause_card := _box(Color(control, 0.94), 20, Color(accent, 0.48), 1)
	pause_card.content_margin_left = 24
	pause_card.content_margin_right = 24
	pause_card.content_margin_top = 20
	pause_card.content_margin_bottom = 20
	pause_card.shadow_color = Color(0, 0, 0, 0.18)
	pause_card.shadow_size = 14
	pause_card.shadow_offset = Vector2(0, 6)
	theme.set_stylebox("panel", "PauseMessageCard", pause_card)
	theme.set_type_variation("RecordPanel", "PanelContainer")
	var record_panel := _box(control.lerp(accent, 0.16), 20, Color(accent, 0.64), 1)
	record_panel.content_margin_left = 22
	record_panel.content_margin_right = 22
	record_panel.content_margin_top = 16
	record_panel.content_margin_bottom = 16
	record_panel.shadow_color = Color(0, 0, 0, 0.14)
	record_panel.shadow_size = 10
	record_panel.shadow_offset = Vector2(0, 4)
	theme.set_stylebox("panel", "RecordPanel", record_panel)
	theme.set_type_variation("ResultCard", "PanelContainer")
	var result_card := _box(surface, 28, separator, 1)
	result_card.content_margin_left = 32
	result_card.content_margin_right = 32
	result_card.content_margin_top = 28
	result_card.content_margin_bottom = 28
	result_card.shadow_color = Color(0, 0, 0, 0.20 if dark else 0.10)
	result_card.shadow_size = 18
	result_card.shadow_offset = Vector2(0, 8)
	theme.set_stylebox("panel", "ResultCard", result_card)
	theme.set_type_variation("ResultMetric", "PanelContainer")
	var result_metric := _box(control, 18, Color(accent, 0.24), 1)
	result_metric.content_margin_left = 12
	result_metric.content_margin_right = 12
	result_metric.content_margin_top = 12
	result_metric.content_margin_bottom = 12
	theme.set_stylebox("panel", "ResultMetric", result_metric)
	theme.set_type_variation("CompletionMark", "PanelContainer")
	var completion_mark := _box(control.lerp(accent, 0.16), 28, Color(accent, 0.44), 1)
	completion_mark.content_margin_left = 12
	completion_mark.content_margin_right = 12
	completion_mark.content_margin_top = 12
	completion_mark.content_margin_bottom = 12
	theme.set_stylebox("panel", "CompletionMark", completion_mark)
	theme.set_type_variation("PrimaryActionButton", "Button")
	var primary_action := _box(accent, 18, accent, 1)
	var primary_hover := _box(accent.lightened(0.10), 18, accent.lightened(0.10), 1)
	theme.set_stylebox("normal", "PrimaryActionButton", primary_action)
	theme.set_stylebox("hover", "PrimaryActionButton", primary_hover)
	theme.set_stylebox("pressed", "PrimaryActionButton", _box(accent.darkened(0.08), 18, accent, 1))
	theme.set_stylebox("focus", "PrimaryActionButton", primary_hover)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(color_name, "PrimaryActionButton", Color.WHITE)
	for color_name in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		theme.set_color(color_name, "PrimaryActionButton", Color.WHITE)
	theme.set_type_variation("TooltipPanel", "PanelContainer")
	var tooltip_box := _box(surface, 14, Color(accent, 0.55), 1)
	tooltip_box.content_margin_left = 16
	tooltip_box.content_margin_right = 16
	tooltip_box.content_margin_top = 10
	tooltip_box.content_margin_bottom = 10
	tooltip_box.shadow_color = Color(0, 0, 0, 0.22 if dark else 0.14)
	tooltip_box.shadow_size = 12
	tooltip_box.shadow_offset = Vector2(0, 4)
	theme.set_stylebox("panel", "TooltipPanel", tooltip_box)
	theme.set_color("font_color", "TooltipLabel", text)
	theme.set_font_size("font_size", "TooltipLabel", 22)
	theme.set_type_variation("InfoPill", "PanelContainer")
	var info_pill := _box(control.lerp(accent, 0.12), 13, Color(accent, 0.38), 1)
	info_pill.content_margin_left = 14
	info_pill.content_margin_right = 14
	info_pill.content_margin_top = 5
	info_pill.content_margin_bottom = 5
	theme.set_stylebox("panel", "InfoPill", info_pill)
	theme.set_type_variation("EyebrowLabel", "Label")
	theme.set_color("font_color", "EyebrowLabel", accent)
	theme.set_font_size("font_size", "EyebrowLabel", 17)
	theme.set_type_variation("HeroSubtitle", "Label")
	theme.set_color("font_color", "HeroSubtitle", muted.lerp(text, 0.34))
	theme.set_font_size("font_size", "HeroSubtitle", 22)
	theme.set_type_variation("SectionSummary", "Label")
	theme.set_color("font_color", "SectionSummary", muted)
	theme.set_font_size("font_size", "SectionSummary", 19)
	theme.set_type_variation("SettingsNote", "Label")
	theme.set_color("font_color", "SettingsNote", muted)
	theme.set_font_size("font_size", "SettingsNote", 18)
	theme.set_type_variation("SectionTitle", "Label")
	theme.set_color("font_color", "SectionTitle", text)
	theme.set_font_size("font_size", "SectionTitle", 29)
	theme.set_type_variation("AccentMark", "Panel")
	var accent_mark := _box(accent, 3, accent, 0)
	accent_mark.content_margin_left = 0
	accent_mark.content_margin_right = 0
	accent_mark.content_margin_top = 0
	accent_mark.content_margin_bottom = 0
	theme.set_stylebox("panel", "AccentMark", accent_mark)
	theme.set_type_variation("SettingsRow", "PanelContainer")
	theme.set_stylebox("panel", "SettingsRow", _box(control, 14, separator, 1))
	theme.set_type_variation("ToastPanel", "PanelContainer")
	var toast_box := _box(control.lerp(accent, 0.12), 16, accent, 1)
	toast_box.content_margin_left = 22
	toast_box.content_margin_right = 22
	toast_box.content_margin_top = 10
	toast_box.content_margin_bottom = 10
	theme.set_stylebox("panel", "ToastPanel", toast_box)
	theme.set_type_variation("ConfirmationCard", "PanelContainer")
	theme.set_stylebox("panel", "ConfirmationCard", _box(surface, 24, separator, 1))
	theme.set_type_variation("DestructiveButton", "Button")
	var destructive := _box(Color("ff3b30") if not dark else Color("ff453a"), 16, Color("ff6961"), 1)
	var destructive_hover := _box(Color("ff6961"), 16, Color("ff6961"), 1)
	theme.set_stylebox("normal", "DestructiveButton", destructive)
	theme.set_stylebox("hover", "DestructiveButton", destructive_hover)
	theme.set_stylebox("pressed", "DestructiveButton", destructive_hover)
	theme.set_stylebox("focus", "DestructiveButton", destructive_hover)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(color_name, "DestructiveButton", Color.WHITE)
	theme.set_type_variation("NumberPadButton", "Button")
	var number_normal := _box(control.lerp(accent, 0.13), 16, Color(accent, 0.72), 1)
	var number_hover := _box(control.lerp(accent, 0.22), 16, accent, 2)
	theme.set_stylebox("normal", "NumberPadButton", number_normal)
	theme.set_stylebox("hover", "NumberPadButton", number_hover)
	theme.set_stylebox("pressed", "NumberPadButton", pressed)
	theme.set_stylebox("focus", "NumberPadButton", number_hover)
	theme.set_color("font_color", "NumberPadButton", accent.lightened(0.12) if dark else accent.darkened(0.06))
	theme.set_color("font_hover_color", "NumberPadButton", accent.lightened(0.22) if dark else accent.darkened(0.10))
	theme.set_color("font_pressed_color", "NumberPadButton", Color.WHITE)
	theme.set_font_size("font_size", "NumberPadButton", 36)
	theme.set_type_variation("NumberPadPlaceholder", "Button")
	var number_placeholder := _box(Color.TRANSPARENT, 16, Color.TRANSPARENT, 0)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		theme.set_stylebox(state, "NumberPadPlaceholder", number_placeholder)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_focus_color"]:
		theme.set_color(color_name, "NumberPadPlaceholder", Color.TRANSPARENT)
	theme.set_type_variation("ActiveToolButton", "Button")
	var active_tool := _box(control.lerp(accent, 0.24), 16, accent, 3)
	theme.set_stylebox("normal", "ActiveToolButton", active_tool)
	theme.set_stylebox("hover", "ActiveToolButton", _box(control.lerp(accent, 0.32), 16, accent, 3))
	theme.set_stylebox("pressed", "ActiveToolButton", active_tool)
	theme.set_stylebox("focus", "ActiveToolButton", active_tool)
	theme.set_color("font_color", "ActiveToolButton", accent.lightened(0.20) if dark else accent.darkened(0.08))
	theme.set_color("icon_normal_color", "ActiveToolButton", accent.lightened(0.20) if dark else accent.darkened(0.08))
	theme.set_type_variation("NotesActiveButton", "Button")
	var notes_active := _box(control.lerp(accent, 0.15), 16, Color(accent, 0.72), 2)
	var notes_hover := _box(control.lerp(accent, 0.22), 16, accent, 2)
	theme.set_stylebox("normal", "NotesActiveButton", notes_active)
	theme.set_stylebox("hover", "NotesActiveButton", notes_hover)
	theme.set_stylebox("pressed", "NotesActiveButton", notes_active)
	theme.set_stylebox("focus", "NotesActiveButton", notes_hover)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(color_name, "NotesActiveButton", accent.lightened(0.16) if dark else accent.darkened(0.10))
	for color_name in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		theme.set_color(color_name, "NotesActiveButton", accent.lightened(0.16) if dark else accent.darkened(0.10))
	theme.set_type_variation("ShortcutButton", "Button")
	var shortcut_normal := _box(surface, 12, Color(accent, 0.42), 1)
	var shortcut_hover := _box(control.lerp(accent, 0.12), 12, accent, 1)
	theme.set_stylebox("normal", "ShortcutButton", shortcut_normal)
	theme.set_stylebox("hover", "ShortcutButton", shortcut_hover)
	theme.set_stylebox("pressed", "ShortcutButton", _box(control.lerp(accent, 0.20), 12, accent, 2))
	theme.set_stylebox("focus", "ShortcutButton", _box(control.lerp(accent, 0.12), 12, accent, 2))
	theme.set_color("font_color", "ShortcutButton", accent.lightened(0.10) if dark else accent.darkened(0.08))
	theme.set_color("font_hover_color", "ShortcutButton", accent.lightened(0.18) if dark else accent.darkened(0.12))
	theme.set_font_size("font_size", "ShortcutButton", 22)
	theme.set_type_variation("PickerButton", "Button")
	theme.set_stylebox("normal", "PickerButton", _box(control, 16, separator, 1))
	theme.set_stylebox("hover", "PickerButton", _box(control.lerp(accent, 0.10), 16, accent, 1))
	theme.set_stylebox("pressed", "PickerButton", _box(control.lerp(accent, 0.16), 16, accent, 2))
	theme.set_stylebox("focus", "PickerButton", _box(control.lerp(accent, 0.10), 16, accent, 2))
	theme.set_type_variation("PickerCard", "PanelContainer")
	theme.set_stylebox("panel", "PickerCard", _box(surface, 26, separator, 1))
	theme.set_type_variation("PickerOptionButton", "Button")
	theme.set_stylebox("normal", "PickerOptionButton", _box(surface, 14, surface, 0))
	theme.set_stylebox("hover", "PickerOptionButton", _box(control.lerp(accent, 0.12), 14, accent, 0))
	theme.set_stylebox("pressed", "PickerOptionButton", _box(control.lerp(accent, 0.20), 14, accent, 0))
	theme.set_stylebox("focus", "PickerOptionButton", _box(control.lerp(accent, 0.12), 14, accent, 1))
	var toggle_normal := _box(control, 14, separator, 1)
	var toggle_pressed := _box(control.lerp(accent, 0.10), 14, accent, 1)
	theme.set_stylebox("normal", "CheckButton", toggle_normal)
	theme.set_stylebox("hover", "CheckButton", hover)
	theme.set_stylebox("pressed", "CheckButton", toggle_pressed)
	theme.set_stylebox("focus", "CheckButton", hover)
	theme.set_color("font_color", "CheckButton", text)
	theme.set_color("font_pressed_color", "CheckButton", text)
	theme.set_color("font_hover_color", "CheckButton", text)
	theme.set_color("icon_normal_color", "CheckButton", muted)
	theme.set_color("icon_pressed_color", "CheckButton", accent)
	theme.set_color("icon_hover_pressed_color", "CheckButton", accent)
	var scroll_track := _box(Color.TRANSPARENT, 5, Color.TRANSPARENT, 0)
	scroll_track.content_margin_left = 4
	scroll_track.content_margin_right = 4
	scroll_track.content_margin_top = 0
	scroll_track.content_margin_bottom = 0
	var scroll_grabber := _box(Color(muted, 0.34), 4, Color.TRANSPARENT, 0)
	scroll_grabber.content_margin_left = 4
	scroll_grabber.content_margin_right = 4
	scroll_grabber.content_margin_top = 0
	scroll_grabber.content_margin_bottom = 0
	var scroll_hover := _box(Color(accent, 0.48), 4, Color.TRANSPARENT, 0)
	scroll_hover.content_margin_left = 4
	scroll_hover.content_margin_right = 4
	scroll_hover.content_margin_top = 0
	scroll_hover.content_margin_bottom = 0
	theme.set_stylebox("scroll", "VScrollBar", scroll_track)
	theme.set_stylebox("grabber", "VScrollBar", scroll_grabber)
	theme.set_stylebox("grabber_highlight", "VScrollBar", scroll_hover)
	theme.set_stylebox("grabber_pressed", "VScrollBar", scroll_hover)
	theme.set_constant("minimum_grab_thickness", "VScrollBar", 54)
	theme.set_color("background", "App", background)
	theme.set_color("surface", "App", surface)
	theme.set_color("control", "App", control)
	theme.set_color("text", "App", text)
	theme.set_color("muted", "App", muted)
	theme.set_color("accent", "App", accent)
	theme.set_color("separator", "App", separator)
	return theme

static func _box(color: Color, radius: int, border: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box
