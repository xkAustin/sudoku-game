class_name SudokuCellButton
extends Button

var cell_index := 0
var clue := false
var cell_value := 0
var notes_mask := 0
var highlighted_notes_mask := 0
var selected := false
var related := false
var same_value := false
var conflict := false
var grid_size := 9
var box_size := 3
var completion_glow := 0.0
var completion_pulse_count := 0

func configure(index: int, size_value: int = 9, box_value: int = 3) -> void:
	cell_index = index
	grid_size = size_value
	box_size = box_value
	custom_minimum_size = Vector2(30, 30) if grid_size == 16 else Vector2(48, 48)
	focus_mode = Control.FOCUS_ALL
	clip_text = true

func update_state(value: int, notes: int, is_clue: bool, is_selected: bool, is_related: bool, is_same: bool, is_conflict: bool, note_highlights: int = 0) -> void:
	clue = is_clue
	cell_value = value
	notes_mask = notes
	highlighted_notes_mask = note_highlights
	selected = is_selected
	related = is_related
	same_value = is_same
	conflict = is_conflict
	# Notes are painted directly in fixed sub-cells. Keeping them out of Button.text
	# prevents their line count and glyph count from changing the grid's minimum size.
	text = value_label(value) if value != 0 else ""
	tooltip_text = ""
	_apply_background(value)
	queue_redraw()

func _draw() -> void:
	var accent := get_theme_color("accent", "App")
	if completion_glow > 0.001:
		var glow := StyleBoxFlat.new()
		glow.bg_color = Color(accent, completion_glow * 0.24)
		glow.set_corner_radius_all(0)
		_apply_board_corner_radius(glow, 18)
		glow.anti_aliasing = true
		draw_style_box(glow, Rect2(Vector2.ZERO, size))
	if cell_value == 0 and notes_mask != 0:
		_draw_notes()
	elif cell_value != 0 and not clue:
		var marker_color := Color.WHITE if selected else Color(accent, 0.72)
		var marker_width := clampf(size.x * 0.22, 5.0, 14.0)
		draw_line(
			Vector2((size.x - marker_width) * 0.5, size.y * 0.78),
			Vector2((size.x + marker_width) * 0.5, size.y * 0.78),
			marker_color,
			2.0,
			true
		)
	if conflict:
		draw_style_box(_conflict_outline_style(), Rect2(Vector2(3, 3), size - Vector2(6, 6)))
	var row := cell_index / grid_size
	var column := cell_index % grid_size
	var separator := get_theme_color("separator", "App")
	var text_color := get_theme_color("text", "App")
	var thin := Color(separator, 0.72)
	var major := Color(accent.lerp(text_color, 0.58), 0.84)
	if row > 0:
		draw_line(Vector2(0, 0), Vector2(size.x, 0), major if row % box_size == 0 else thin, 2 if row % box_size == 0 else 1)
	if column > 0:
		draw_line(Vector2(0, 0), Vector2(0, size.y), major if column % box_size == 0 else thin, 2 if column % box_size == 0 else 1)

func play_completion_pulse(delay: float = 0.0) -> void:
	completion_pulse_count += 1
	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_method(_set_completion_glow, 0.0, 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_completion_glow, 1.0, 0.0, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _set_completion_glow(value: float) -> void:
	completion_glow = value
	queue_redraw()

func _draw_notes() -> void:
	var font := get_theme_font("font")
	var accent := get_theme_color("accent", "App")
	var muted := get_theme_color("muted", "App")
	var note_color := Color.WHITE if selected else Color(muted, 0.78)
	var highlight_color := Color.WHITE if selected else (accent.lightened(0.10) if accent.get_luminance() < 0.5 else accent.darkened(0.08))
	var slots := box_size
	var slot_size := Vector2(size.x / float(slots), size.y / float(slots))
	var note_font_size := maxi(8, int(minf(slot_size.x, slot_size.y) * (0.60 if grid_size == 9 else 0.54)))
	for value in range(1, grid_size + 1):
		var bit := 1 << value
		if notes_mask & bit == 0:
			continue
		var slot_index := value - 1
		var row := slot_index / slots
		var column := slot_index % slots
		var slot_rect := Rect2(Vector2(column, row) * slot_size, slot_size)
		var highlighted := highlighted_notes_mask & bit != 0
		if highlighted:
			var radius := minf(slot_size.x, slot_size.y) * 0.34
			draw_circle(slot_rect.get_center(), radius, Color(highlight_color, 0.20 if not selected else 0.30), true, -1.0, true)
		var baseline := slot_rect.position.y + (slot_rect.size.y + float(note_font_size) * 0.70) * 0.5
		draw_string(
			font,
			Vector2(slot_rect.position.x, baseline),
			value_label(value),
			HORIZONTAL_ALIGNMENT_CENTER,
			slot_rect.size.x,
			note_font_size,
			highlight_color if highlighted else note_color
		)

func _apply_background(value: int) -> void:
	var accent := get_theme_color("accent", "App")
	var surface := get_theme_color("surface", "App")
	var control := get_theme_color("control", "App")
	var text_color := get_theme_color("text", "App")
	var fill := surface
	if related:
		fill = control
	if same_value:
		fill = surface.lerp(accent, 0.20)
	if selected:
		fill = accent
	elif value != 0 and not clue and not related and not same_value:
		fill = surface.lerp(accent, 0.055)
	var background := StyleBoxFlat.new()
	background.bg_color = fill
	background.set_corner_radius_all(0)
	# Always clip the four outer cells to the board's inner curve. This keeps
	# related-row/column gray fills, selection and same-value fills identical at
	# the corners without rounding any of the internal cell edges.
	var rounded_board_corner := _apply_board_corner_radius(background, 18)
	background.anti_aliasing = rounded_board_corner
	background.corner_detail = 16 if rounded_board_corner else 8
	background.content_margin_left = 0
	background.content_margin_right = 0
	background.content_margin_top = 0
	background.content_margin_bottom = 0
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, background)
	var number_color := Color.WHITE if selected else (Color("ef6b73") if conflict else (text_color if clue else accent))
	if value == 0:
		number_color = Color.TRANSPARENT
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		add_theme_color_override(color_name, number_color)
	add_theme_font_size_override("font_size", (21 if grid_size == 16 else 25) if clue else (23 if grid_size == 16 else 28))
	var needs_outline := value != 0 and (selected or grid_size == 16)
	var outline_color := Color(0.02, 0.12, 0.24, 0.34) if selected else Color(1, 1, 1, 0.22)
	add_theme_color_override("font_outline_color", outline_color if needs_outline else Color.TRANSPARENT)
	add_theme_constant_override("outline_size", 1 if needs_outline else 0)

func _conflict_outline_style() -> StyleBoxFlat:
	var outline := StyleBoxFlat.new()
	outline.bg_color = Color.TRANSPARENT
	outline.border_color = Color("ef6b73")
	outline.set_border_width_all(3)
	outline.set_corner_radius_all(0)
	var rounded_corner := _apply_board_corner_radius(outline, 15)
	outline.anti_aliasing = true
	outline.corner_detail = 12 if rounded_corner else 8
	return outline

func _apply_board_corner_radius(style: StyleBoxFlat, radius: int) -> bool:
	var row := cell_index / grid_size
	var column := cell_index % grid_size
	if row == 0 and column == 0:
		style.corner_radius_top_left = radius
	elif row == 0 and column == grid_size - 1:
		style.corner_radius_top_right = radius
	elif row == grid_size - 1 and column == 0:
		style.corner_radius_bottom_left = radius
	elif row == grid_size - 1 and column == grid_size - 1:
		style.corner_radius_bottom_right = radius
	else:
		return false
	return true

func _notes_text(mask: int) -> String:
	if mask == 0:
		return ""
	var lines: Array[String] = []
	for row in box_size:
		var line := ""
		for column in box_size:
			var value := row * box_size + column + 1
			line += value_label(value) if mask & (1 << value) else " "
			if column < box_size - 1 and grid_size == 9:
				line += " "
		lines.append(line)
	return "\n".join(lines)

static func value_label(value: int) -> String:
	if value <= 9:
		return str(value)
	return char(55 + value)
