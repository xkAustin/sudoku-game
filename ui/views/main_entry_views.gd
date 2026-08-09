class_name MainEntryViews
extends RefCounted

static func build_menu(host, content: VBoxContainer, wide: bool) -> void:
	content.alignment = BoxContainer.ALIGNMENT_CENTER if wide else BoxContainer.ALIGNMENT_BEGIN
	var menu_parent: Container = content
	if not wide:
		var menu_scroll: ScrollContainer = host._page_scroll()
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
	host._add_heading(host._l("今天，解一道数独", "Make time for a Sudoku"), host._l("选择模式开始；未完成的进度会自动保存在本机。", "Choose a mode to begin. Your progress is saved on this device."), host._l("离线优先 · 隐私友好", "OFFLINE FIRST · PRIVATE"), hero_body)
	var continue_info: Dictionary = host._find_latest_saved_game()
	var primary_parent: Container = menu_parent
	var quick_parent: Container = menu_parent
	if wide:
		var dashboard := HBoxContainer.new()
		dashboard.add_theme_constant_override("separation", 36)
		dashboard.custom_minimum_size.y = 600
		dashboard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		menu_parent.add_child(dashboard)
		primary_parent = host._home_panel_column(dashboard)
		quick_parent = host._home_panel_column(dashboard)
	host._add_home_section_heading(primary_parent, host._l("游戏模式", "Play"), host._l("选择你此刻想要的挑战方式", "Choose the challenge that feels right"))
	if not continue_info.is_empty():
		host._add_home_action(
			primary_parent,
			host._l("继续上次游戏", "Continue game"),
			host._l("%s难度 · 恢复上次未完成的棋盘", "%s · Resume your unfinished board") % host._difficulty_name(int(continue_info["difficulty"])),
			Callable(host, "_resume_saved").bind(str(continue_info["mode"]), int(continue_info["difficulty"])),
			wide
		)
	host._add_home_action(primary_parent, host._l("新建本地游戏", "New local game"), host._l("六档难度 · 支持 9×9 与 16×16 · 完全离线", "Six levels · 9×9 and 16×16 · Fully offline"), Callable(host, "_show_difficulty").bind(false), wide)
	host._add_home_action(primary_parent, host._l("排位挑战", "Ranked challenge"), host._l("六档难度 · 离线可玩 · 完成后自行选择是否上传", "Six levels · Play offline · Choose whether to upload after completion"), Callable(host, "_show_difficulty").bind(true), wide)
	host._add_home_section_heading(quick_parent, host._l("记录与设置", "Progress & Settings"), host._l("查看进度，调整你的游戏体验", "Review progress and tailor your experience"))
	host._add_home_action(quick_parent, host._l("个人统计", "Statistics"), host._l("完成局数、胜率、连胜与各难度时间纪录", "Games, win rate, streaks and time records"), Callable(host, "_show_statistics"), wide)
	host._add_home_action(quick_parent, host._l("排行榜", "Leaderboard"), host._l("查看缓存排名；联网时可获取最新成绩", "View cached rankings or refresh online"), Callable(host, "_show_leaderboard"), wide)
	host._add_home_action(quick_parent, host._l("偏好设置", "Settings"), host._l("主题、语言、辅助功能、显示名称与本地数据", "Theme, language, accessibility, profile and data"), Callable(host, "_show_settings"), wide)
	var privacy := Label.new()
	privacy.text = host._l("本地唯一解 · 自动保存 · 无广告 · 无追踪", "Unique puzzles · Auto-save · No ads · No tracking")
	privacy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	privacy.add_theme_font_size_override("font_size", 20)
	privacy.add_theme_color_override("font_color", host.theme.get_color("muted", "App"))
	menu_parent.add_child(privacy)

static func build_difficulty(host, content: VBoxContainer, ranked: bool, wide: bool) -> void:
	var difficulty_scroll: ScrollContainer = host._page_scroll()
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
	intro_text.text = host._l(
		"选择后将先显示公平规则；排位累计 3 次错误会结束本局，六档挑战均可离线缓存。" if ranked else "从轻松入门到 16×16 终极棋盘，选择适合当前节奏的一局。",
		"Review the fair-play rules before starting; 3 mistakes end a ranked game, and all six challenges support offline caching." if ranked else "Choose a pace from a relaxed introduction through the 16×16 Ultimate board."
	)
	intro_text.theme_type_variation = "HeroSubtitle"
	intro_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_margin.add_child(intro_text)
	var difficulty_grid := GridContainer.new()
	difficulty_grid.name = "DifficultyGrid"
	difficulty_grid.columns = ResponsiveLayout.responsive_columns(host.size, 3, 1)
	difficulty_grid.add_theme_constant_override("h_separation", 16)
	difficulty_grid.add_theme_constant_override("v_separation", 16)
	difficulty_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	difficulty_body.add_child(difficulty_grid)
	var descriptions := [
		host._l("直接候选，适合初次体验", "Straightforward candidates for first-time play"),
		host._l("基础排除，节奏轻松", "Gentle elimination and a relaxed pace"),
		host._l("候选组合，需要专注", "Candidate combinations that need focus"),
		host._l("高级排除，挑战推理", "Advanced elimination and deeper reasoning"),
		host._l("深层逻辑与有限搜索", "Layered logic with limited search"),
		host._l("16×16 棋盘 · 使用 1–9 与 A–G", "16×16 board · Uses 1–9 and A–G"),
	]
	for index in 6:
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
		meta.text = (host._l("16×16 · 终极棋盘", "16×16 · Ultimate grid") if index == 5 else host._l("9×9 · 第 %d 档", "9×9 · Level %d") % (index + 1))
		meta.theme_type_variation = "EyebrowLabel"
		card_body.add_child(meta)
		var button: Button = host._button(host._difficulty_name(index), descriptions[index])
		button.theme_type_variation = "DifficultyButton"
		button.custom_minimum_size.y = 70 if wide else 72
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(Callable(host, "_choose_difficulty").bind(index, ranked))
		card_body.add_child(button)
		var description := Label.new()
		description.text = descriptions[index]
		description.theme_type_variation = "SectionSummary"
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_body.add_child(description)
