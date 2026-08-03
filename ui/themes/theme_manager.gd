class_name ThemeManager
extends RefCounted

static func build(dark: bool, high_contrast: bool = false) -> Theme:
	var theme := Theme.new()
	var background := Color("07111f") if dark else Color("eaf4ff")
	var surface := Color(0.075, 0.13, 0.22, 0.90 if high_contrast else 0.72) if dark else Color(1.0, 1.0, 1.0, 0.92 if high_contrast else 0.70)
	var control := Color(0.12, 0.20, 0.32, 0.92 if high_contrast else 0.64) if dark else Color(0.91, 0.96, 1.0, 0.94 if high_contrast else 0.62)
	var text := Color("f7fbff") if dark else Color("13243a")
	var muted := Color("b9c9dc") if dark else Color("52677f")
	var separator := Color(0.72, 0.84, 1.0, 0.46 if high_contrast else 0.24) if dark else Color(1.0, 1.0, 1.0, 0.96 if high_contrast else 0.78)
	var accent := (Color("7ce7ff") if dark else Color("005bd8")) if high_contrast else (Color("52c7ff") if dark else Color("087cf0"))
	var glass_edge := Color(0.86, 0.94, 1.0, 0.62 if high_contrast else 0.34) if dark else Color(1.0, 1.0, 1.0, 0.98 if high_contrast else 0.84)
	var glass_shadow := Color(0.0, 0.02, 0.08, 0.34 if dark else 0.13)
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
	var normal := _glass_box(control, 20, glass_edge, 1, glass_shadow, 8, 3)
	var hover := _glass_box(control.lerp(accent, 0.16), 20, Color(accent, 0.78), 1, glass_shadow, 12, 4)
	var pressed := _glass_box(Color(accent, 0.92), 20, accent.lightened(0.12), 1, glass_shadow, 5, 2)
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("focus", "Button", hover)
	theme.set_stylebox("normal", "LineEdit", _glass_box(control, 18, glass_edge, 1, glass_shadow, 7, 3))
	theme.set_stylebox("focus", "LineEdit", _glass_box(control.lerp(accent, 0.08), 18, accent, 2, glass_shadow, 10, 3))
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
	theme.set_stylebox("panel", "PopupMenu", _glass_box(surface, 22, glass_edge, 1, glass_shadow, 16, 6))
	theme.set_stylebox("hover", "PopupMenu", _box(control.lerp(accent, 0.18), 12, Color(accent, 0.54), 1))
	var group_panel := _glass_box(surface, 28, glass_edge, 1, glass_shadow, 16, 6)
	group_panel.content_margin_left = 0
	group_panel.content_margin_right = 0
	group_panel.content_margin_top = 0
	group_panel.content_margin_bottom = 0
	theme.set_stylebox("panel", "PanelContainer", group_panel)
	theme.set_type_variation("TopBarGlass", "PanelContainer")
	var top_bar_fill := surface.lerp(control, 0.20)
	top_bar_fill.a = 0.90 if dark else 0.94
	var top_bar := _glass_box(top_bar_fill, 20, Color(accent, 0.24), 1, glass_shadow, 8, 2)
	top_bar.content_margin_left = 18
	top_bar.content_margin_right = 18
	top_bar.content_margin_top = 9
	top_bar.content_margin_bottom = 9
	theme.set_stylebox("panel", "TopBarGlass", top_bar)
	theme.set_type_variation("TopBarBrand", "Label")
	theme.set_color("font_color", "TopBarBrand", text)
	theme.set_font_size("font_size", "TopBarBrand", 17)
	for status_style in ["TopBarOnlineStatusPill", "TopBarOfflineStatusPill"]:
		theme.set_type_variation(status_style, "PanelContainer")
	var online_pill := _glass_box(control.lerp(accent, 0.16), 14, Color(accent, 0.48), 1, Color(glass_shadow, 0.46), 2, 1)
	var offline_pill := _glass_box(Color(control, 0.74), 14, Color(glass_edge, 0.72), 1, Color(glass_shadow, 0.30), 1, 0)
	for status_pill in [online_pill, offline_pill]:
		status_pill.content_margin_left = 10
		status_pill.content_margin_right = 10
		status_pill.content_margin_top = 4
		status_pill.content_margin_bottom = 4
	theme.set_stylebox("panel", "TopBarOnlineStatusPill", online_pill)
	theme.set_stylebox("panel", "TopBarOfflineStatusPill", offline_pill)
	theme.set_type_variation("TopBarOnlineStatus", "Label")
	theme.set_color("font_color", "TopBarOnlineStatus", accent.lightened(0.12) if dark else accent.darkened(0.08))
	theme.set_font_size("font_size", "TopBarOnlineStatus", 13)
	theme.set_type_variation("TopBarOfflineStatus", "Label")
	theme.set_color("font_color", "TopBarOfflineStatus", muted)
	theme.set_font_size("font_size", "TopBarOfflineStatus", 13)
	theme.set_type_variation("HomeHero", "PanelContainer")
	var home_hero := _glass_box(surface.lerp(accent, 0.075), 30, Color(accent, 0.42), 1, glass_shadow, 22, 8)
	home_hero.content_margin_left = 0
	home_hero.content_margin_right = 0
	home_hero.content_margin_top = 0
	home_hero.content_margin_bottom = 0
	theme.set_stylebox("panel", "HomeHero", home_hero)
	theme.set_type_variation("DifficultyIntro", "PanelContainer")
	var difficulty_intro := _glass_box(surface.lerp(accent, 0.07), 24, Color(accent, 0.38), 1, glass_shadow, 12, 4)
	difficulty_intro.content_margin_left = 0
	difficulty_intro.content_margin_right = 0
	difficulty_intro.content_margin_top = 0
	difficulty_intro.content_margin_bottom = 0
	theme.set_stylebox("panel", "DifficultyIntro", difficulty_intro)
	theme.set_type_variation("DifficultyCard", "PanelContainer")
	var difficulty_card := _glass_box(surface, 24, glass_edge, 1, glass_shadow, 14, 5)
	difficulty_card.content_margin_left = 0
	difficulty_card.content_margin_right = 0
	difficulty_card.content_margin_top = 0
	difficulty_card.content_margin_bottom = 0
	theme.set_stylebox("panel", "DifficultyCard", difficulty_card)
	theme.set_type_variation("DifficultyButton", "Button")
	theme.set_stylebox("normal", "DifficultyButton", _glass_box(control.lerp(accent, 0.10), 18, Color(accent, 0.50), 1, glass_shadow, 7, 2))
	theme.set_stylebox("hover", "DifficultyButton", _glass_box(control.lerp(accent, 0.22), 18, accent, 2, glass_shadow, 12, 4))
	theme.set_stylebox("pressed", "DifficultyButton", _glass_box(Color(accent, 0.94), 18, accent.lightened(0.12), 2, glass_shadow, 5, 2))
	theme.set_stylebox("focus", "DifficultyButton", _glass_box(control.lerp(accent, 0.22), 18, accent, 2, glass_shadow, 12, 4))
	theme.set_type_variation("RankedBriefingCard", "PanelContainer")
	var ranked_briefing := _glass_box(surface, 32, Color(accent, 0.54), 1, glass_shadow, 24, 9)
	ranked_briefing.content_margin_left = 0
	ranked_briefing.content_margin_right = 0
	ranked_briefing.content_margin_top = 0
	ranked_briefing.content_margin_bottom = 0
	theme.set_stylebox("panel", "RankedBriefingCard", ranked_briefing)
	theme.set_type_variation("RankedNotice", "PanelContainer")
	var ranked_notice := _glass_box(control.lerp(accent, 0.15), 18, Color(accent, 0.44), 1, glass_shadow, 6, 2)
	ranked_notice.content_margin_left = 18
	ranked_notice.content_margin_right = 18
	ranked_notice.content_margin_top = 11
	ranked_notice.content_margin_bottom = 11
	theme.set_stylebox("panel", "RankedNotice", ranked_notice)
	theme.set_type_variation("StatsHero", "PanelContainer")
	var stats_hero := _glass_box(surface.lerp(accent, 0.08), 28, Color(accent, 0.42), 1, glass_shadow, 18, 6)
	stats_hero.content_margin_left = 0
	stats_hero.content_margin_right = 0
	stats_hero.content_margin_top = 0
	stats_hero.content_margin_bottom = 0
	theme.set_stylebox("panel", "StatsHero", stats_hero)
	theme.set_type_variation("StatMetric", "PanelContainer")
	theme.set_stylebox("panel", "StatMetric", _glass_box(surface, 21, Color(accent, 0.34), 1, glass_shadow, 8, 3))
	theme.set_type_variation("StatsRecordCard", "PanelContainer")
	var stats_record := _glass_box(surface, 21, glass_edge, 1, glass_shadow, 9, 3)
	stats_record.content_margin_left = 0
	stats_record.content_margin_right = 0
	stats_record.content_margin_top = 0
	stats_record.content_margin_bottom = 0
	theme.set_stylebox("panel", "StatsRecordCard", stats_record)
	theme.set_type_variation("LeaderboardControlCard", "PanelContainer")
	var leaderboard_control := _glass_box(surface.lerp(accent, 0.07), 28, Color(accent, 0.40), 1, glass_shadow, 16, 6)
	leaderboard_control.content_margin_left = 0
	leaderboard_control.content_margin_right = 0
	leaderboard_control.content_margin_top = 0
	leaderboard_control.content_margin_bottom = 0
	theme.set_stylebox("panel", "LeaderboardControlCard", leaderboard_control)
	theme.set_type_variation("LeaderboardEmptyCard", "PanelContainer")
	theme.set_stylebox("panel", "LeaderboardEmptyCard", _glass_box(surface, 22, glass_edge, 1, glass_shadow, 10, 4))
	theme.set_type_variation("LeaderboardSelfCard", "PanelContainer")
	theme.set_stylebox("panel", "LeaderboardSelfCard", _glass_box(control.lerp(accent, 0.17), 22, Color(accent, 0.68), 2, glass_shadow, 12, 4))
	theme.set_type_variation("LeaderboardRow", "PanelContainer")
	theme.set_stylebox("panel", "LeaderboardRow", _glass_box(surface, 16, glass_edge, 1, glass_shadow, 6, 2))
	theme.set_type_variation("GameBoardPanel", "PanelContainer")
	# The surface is drawn below the square cells. The blue stroke is a separate
	# topmost overlay so cell backgrounds cannot cut holes in its curved corners.
	var board_panel := _glass_box(surface, 24, Color.TRANSPARENT, 0, glass_shadow, 18, 6)
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
	theme.set_stylebox("panel", "GameControlsPanel", _glass_box(surface, 28, glass_edge, 1, glass_shadow, 18, 6))
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
	var pause_card := _glass_box(Color(control, 0.92), 22, Color(accent, 0.62), 1, glass_shadow, 18, 6)
	pause_card.content_margin_left = 24
	pause_card.content_margin_right = 24
	pause_card.content_margin_top = 20
	pause_card.content_margin_bottom = 20
	theme.set_stylebox("panel", "PauseMessageCard", pause_card)
	theme.set_type_variation("RecordPanel", "PanelContainer")
	var record_panel := _glass_box(control.lerp(accent, 0.20), 22, Color(accent, 0.72), 1, glass_shadow, 12, 4)
	record_panel.content_margin_left = 22
	record_panel.content_margin_right = 22
	record_panel.content_margin_top = 16
	record_panel.content_margin_bottom = 16
	theme.set_stylebox("panel", "RecordPanel", record_panel)
	theme.set_type_variation("ResultCard", "PanelContainer")
	var result_card := _glass_box(surface, 32, glass_edge, 1, glass_shadow, 24, 9)
	result_card.content_margin_left = 32
	result_card.content_margin_right = 32
	result_card.content_margin_top = 28
	result_card.content_margin_bottom = 28
	theme.set_stylebox("panel", "ResultCard", result_card)
	theme.set_type_variation("ResultMetric", "PanelContainer")
	var result_metric := _glass_box(control, 20, Color(accent, 0.34), 1, glass_shadow, 7, 2)
	result_metric.content_margin_left = 12
	result_metric.content_margin_right = 12
	result_metric.content_margin_top = 12
	result_metric.content_margin_bottom = 12
	theme.set_stylebox("panel", "ResultMetric", result_metric)
	theme.set_type_variation("CompletionMark", "PanelContainer")
	var completion_mark := _glass_box(control.lerp(accent, 0.20), 30, Color(accent, 0.56), 1, glass_shadow, 10, 3)
	completion_mark.content_margin_left = 12
	completion_mark.content_margin_right = 12
	completion_mark.content_margin_top = 12
	completion_mark.content_margin_bottom = 12
	theme.set_stylebox("panel", "CompletionMark", completion_mark)
	theme.set_type_variation("PrimaryActionButton", "Button")
	var primary_action := _glass_box(Color(accent, 0.94), 20, accent.lightened(0.20), 1, glass_shadow, 14, 5)
	var primary_hover := _glass_box(accent.lightened(0.10), 20, accent.lightened(0.26), 1, glass_shadow, 18, 6)
	theme.set_stylebox("normal", "PrimaryActionButton", primary_action)
	theme.set_stylebox("hover", "PrimaryActionButton", primary_hover)
	theme.set_stylebox("pressed", "PrimaryActionButton", _glass_box(accent.darkened(0.08), 20, accent, 1, glass_shadow, 6, 2))
	theme.set_stylebox("focus", "PrimaryActionButton", primary_hover)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(color_name, "PrimaryActionButton", Color.WHITE)
	for color_name in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		theme.set_color(color_name, "PrimaryActionButton", Color.WHITE)
	theme.set_type_variation("TooltipPanel", "PanelContainer")
	var tooltip_box := _glass_box(Color(surface, minf(1.0, surface.a + 0.12)), 14, Color(accent, 0.64), 1, glass_shadow, 12, 4)
	tooltip_box.content_margin_left = 16
	tooltip_box.content_margin_right = 16
	tooltip_box.content_margin_top = 10
	tooltip_box.content_margin_bottom = 10
	theme.set_stylebox("panel", "TooltipPanel", tooltip_box)
	theme.set_color("font_color", "TooltipLabel", text)
	theme.set_font_size("font_size", "TooltipLabel", 22)
	theme.set_type_variation("InfoPill", "PanelContainer")
	var info_pill := _glass_box(control.lerp(accent, 0.16), 15, Color(accent, 0.50), 1, glass_shadow, 5, 2)
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
	theme.set_type_variation("HeroTitle", "Label")
	theme.set_color("font_color", "HeroTitle", text)
	theme.set_font_size("font_size", "HeroTitle", 48)
	theme.set_type_variation("PageHeaderTitle", "Label")
	theme.set_color("font_color", "PageHeaderTitle", text)
	theme.set_font_size("font_size", "PageHeaderTitle", 32)
	theme.set_type_variation("PageHeaderSubtitle", "Label")
	theme.set_color("font_color", "PageHeaderSubtitle", muted)
	theme.set_font_size("font_size", "PageHeaderSubtitle", 16)
	theme.set_type_variation("SectionSummary", "Label")
	theme.set_color("font_color", "SectionSummary", muted)
	theme.set_font_size("font_size", "SectionSummary", 19)
	theme.set_type_variation("SettingsNote", "Label")
	theme.set_color("font_color", "SettingsNote", muted)
	theme.set_font_size("font_size", "SettingsNote", 18)
	theme.set_type_variation("SectionTitle", "Label")
	theme.set_color("font_color", "SectionTitle", text)
	theme.set_font_size("font_size", "SectionTitle", 27)
	theme.set_type_variation("AccentMark", "Panel")
	var accent_mark := _box(accent.lightened(0.12), 3, accent, 0)
	accent_mark.content_margin_left = 0
	accent_mark.content_margin_right = 0
	accent_mark.content_margin_top = 0
	accent_mark.content_margin_bottom = 0
	theme.set_stylebox("panel", "AccentMark", accent_mark)
	theme.set_type_variation("SettingsRow", "PanelContainer")
	theme.set_stylebox("panel", "SettingsRow", _glass_box(control, 20, glass_edge, 1, Color(glass_shadow, 0.68), 3, 1))
	theme.set_type_variation("SoundActionButton", "Button")
	var sound_action := _glass_box(control.lerp(accent, 0.06), 18, glass_edge, 1, Color(glass_shadow, 0.55), 4, 1)
	var sound_action_hover := _glass_box(control.lerp(accent, 0.16), 18, Color(accent, 0.64), 1, Color(glass_shadow, 0.65), 7, 2)
	var sound_action_disabled := _glass_box(Color(control, 0.58), 18, Color(glass_edge, 0.56), 1, Color(glass_shadow, 0.25), 2, 0)
	theme.set_stylebox("normal", "SoundActionButton", sound_action)
	theme.set_stylebox("hover", "SoundActionButton", sound_action_hover)
	theme.set_stylebox("pressed", "SoundActionButton", sound_action_hover)
	theme.set_stylebox("focus", "SoundActionButton", sound_action_hover)
	theme.set_stylebox("disabled", "SoundActionButton", sound_action_disabled)
	theme.set_color("font_color", "SoundActionButton", text)
	theme.set_color("font_hover_color", "SoundActionButton", text)
	theme.set_color("font_pressed_color", "SoundActionButton", text)
	theme.set_color("font_disabled_color", "SoundActionButton", muted)
	theme.set_color("icon_normal_color", "SoundActionButton", text)
	theme.set_color("icon_disabled_color", "SoundActionButton", muted)
	theme.set_type_variation("ToastPanel", "PanelContainer")
	var toast_box := _glass_box(Color(control.lerp(accent, 0.16), 0.94), 19, Color(accent, 0.84), 1, glass_shadow, 16, 5)
	toast_box.content_margin_left = 22
	toast_box.content_margin_right = 22
	toast_box.content_margin_top = 10
	toast_box.content_margin_bottom = 10
	theme.set_stylebox("panel", "ToastPanel", toast_box)
	theme.set_type_variation("ToastLabel", "Label")
	theme.set_color("font_color", "ToastLabel", text)
	theme.set_type_variation("ErrorToastPanel", "PanelContainer")
	var error_toast := _glass_box(Color("7a1824") if dark else Color("fff0f1"), 19, Color("ff453a"), 2, glass_shadow, 0, 0)
	error_toast.content_margin_left = 22
	error_toast.content_margin_right = 22
	error_toast.content_margin_top = 10
	error_toast.content_margin_bottom = 10
	theme.set_stylebox("panel", "ErrorToastPanel", error_toast)
	theme.set_type_variation("ErrorToastLabel", "Label")
	theme.set_color("font_color", "ErrorToastLabel", Color("ffd7da") if dark else Color("9f1725"))
	theme.set_type_variation("ConfirmationCard", "PanelContainer")
	theme.set_stylebox("panel", "ConfirmationCard", _glass_box(surface, 28, glass_edge, 1, glass_shadow, 22, 8))
	theme.set_type_variation("DestructiveButton", "Button")
	var destructive := _glass_box(Color("ff3b30") if not dark else Color("ff453a"), 18, Color("ff8a84"), 1, glass_shadow, 10, 3)
	var destructive_hover := _glass_box(Color("ff6961"), 18, Color("ffb0ab"), 1, glass_shadow, 14, 4)
	theme.set_stylebox("normal", "DestructiveButton", destructive)
	theme.set_stylebox("hover", "DestructiveButton", destructive_hover)
	theme.set_stylebox("pressed", "DestructiveButton", destructive_hover)
	theme.set_stylebox("focus", "DestructiveButton", destructive_hover)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(color_name, "DestructiveButton", Color.WHITE)
	theme.set_type_variation("NumberPadButton", "Button")
	var number_normal := _glass_box(control.lerp(accent, 0.15), 18, Color(accent, 0.62), 1, glass_shadow, 7, 2)
	var number_hover := _glass_box(control.lerp(accent, 0.26), 18, accent, 2, glass_shadow, 12, 4)
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
	var active_tool := _glass_box(control.lerp(accent, 0.28), 18, accent, 3, glass_shadow, 9, 3)
	theme.set_stylebox("normal", "ActiveToolButton", active_tool)
	theme.set_stylebox("hover", "ActiveToolButton", _glass_box(control.lerp(accent, 0.36), 18, accent.lightened(0.12), 3, glass_shadow, 12, 4))
	theme.set_stylebox("pressed", "ActiveToolButton", active_tool)
	theme.set_stylebox("focus", "ActiveToolButton", active_tool)
	theme.set_color("font_color", "ActiveToolButton", accent.lightened(0.20) if dark else accent.darkened(0.08))
	theme.set_color("icon_normal_color", "ActiveToolButton", accent.lightened(0.20) if dark else accent.darkened(0.08))
	theme.set_type_variation("NotesActiveButton", "Button")
	var notes_active := _glass_box(control.lerp(accent, 0.20), 18, Color(accent, 0.76), 2, glass_shadow, 8, 3)
	var notes_hover := _glass_box(control.lerp(accent, 0.28), 18, accent, 2, glass_shadow, 12, 4)
	theme.set_stylebox("normal", "NotesActiveButton", notes_active)
	theme.set_stylebox("hover", "NotesActiveButton", notes_hover)
	theme.set_stylebox("pressed", "NotesActiveButton", notes_active)
	theme.set_stylebox("focus", "NotesActiveButton", notes_hover)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(color_name, "NotesActiveButton", accent.lightened(0.16) if dark else accent.darkened(0.10))
	for color_name in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		theme.set_color(color_name, "NotesActiveButton", accent.lightened(0.16) if dark else accent.darkened(0.10))
	theme.set_type_variation("ShortcutButton", "Button")
	var shortcut_normal := _glass_box(surface, 14, Color(accent, 0.46), 1, glass_shadow, 6, 2)
	var shortcut_hover := _glass_box(control.lerp(accent, 0.16), 14, accent, 1, glass_shadow, 9, 3)
	theme.set_stylebox("normal", "ShortcutButton", shortcut_normal)
	theme.set_stylebox("hover", "ShortcutButton", shortcut_hover)
	theme.set_stylebox("pressed", "ShortcutButton", _box(control.lerp(accent, 0.20), 12, accent, 2))
	theme.set_stylebox("focus", "ShortcutButton", _box(control.lerp(accent, 0.12), 12, accent, 2))
	theme.set_color("font_color", "ShortcutButton", accent.lightened(0.10) if dark else accent.darkened(0.08))
	theme.set_color("font_hover_color", "ShortcutButton", accent.lightened(0.18) if dark else accent.darkened(0.12))
	theme.set_font_size("font_size", "ShortcutButton", 22)
	theme.set_type_variation("PickerButton", "Button")
	theme.set_stylebox("normal", "PickerButton", _glass_box(control, 18, glass_edge, 1, glass_shadow, 7, 2))
	theme.set_stylebox("hover", "PickerButton", _glass_box(control.lerp(accent, 0.14), 18, accent, 1, glass_shadow, 11, 4))
	theme.set_stylebox("pressed", "PickerButton", _glass_box(control.lerp(accent, 0.22), 18, accent, 2, glass_shadow, 6, 2))
	theme.set_stylebox("focus", "PickerButton", _glass_box(control.lerp(accent, 0.14), 18, accent, 2, glass_shadow, 11, 4))
	theme.set_type_variation("PickerCard", "PanelContainer")
	theme.set_stylebox("panel", "PickerCard", _glass_box(surface, 30, glass_edge, 1, glass_shadow, 24, 9))
	theme.set_type_variation("PickerOptionButton", "Button")
	theme.set_stylebox("normal", "PickerOptionButton", _box(surface, 14, surface, 0))
	theme.set_stylebox("hover", "PickerOptionButton", _box(control.lerp(accent, 0.12), 14, accent, 0))
	theme.set_stylebox("pressed", "PickerOptionButton", _box(control.lerp(accent, 0.20), 14, accent, 0))
	theme.set_stylebox("focus", "PickerOptionButton", _box(control.lerp(accent, 0.12), 14, accent, 1))
	var toggle_normal := _glass_box(control, 18, glass_edge, 1, glass_shadow, 6, 2)
	var toggle_pressed := _glass_box(control.lerp(accent, 0.14), 18, accent, 1, glass_shadow, 8, 3)
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
	theme.set_color("glass_edge", "App", glass_edge)
	theme.set_color("glass_shadow", "App", glass_shadow)
	return theme

static func _box(color: Color, radius: int, border: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	box.corner_detail = 12
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box

static func _glass_box(color: Color, radius: int, border: Color, width: int, _shadow: Color, _shadow_size: int, _shadow_y: int) -> StyleBoxFlat:
	var box := _box(color, radius, border, width)
	# StyleBoxFlat draws an external rectangular shadow that does not preserve the
	# rounded outline at every scale. Glass depth therefore comes from the edge
	# highlight and translucent layers, keeping every control silhouette exact.
	box.shadow_color = Color.TRANSPARENT
	box.shadow_size = 0
	box.shadow_offset = Vector2.ZERO
	return box
