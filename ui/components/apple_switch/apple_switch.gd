class_name AppleSwitch
extends BaseButton

var _progress := 0.0
var _animation: Tween

func _init() -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(78, 48)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _ready() -> void:
	_progress = 1.0 if button_pressed else 0.0
	toggled.connect(_on_toggled)
	queue_redraw()

func set_on(value: bool) -> void:
	button_pressed = value
	_progress = 1.0 if value else 0.0
	queue_redraw()

func _on_toggled(value: bool) -> void:
	if _animation != null and _animation.is_valid():
		_animation.kill()
	var target := 1.0 if value else 0.0
	if bool(AppState.settings.get("reduce_motion", false)):
		_set_progress(target)
		return
	_animation = create_tween()
	_animation.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_animation.tween_method(_set_progress, _progress, target, 0.16)

func _set_progress(value: float) -> void:
	_progress = value
	queue_redraw()

func _draw() -> void:
	var track_size := Vector2(68, 38)
	var track_position := Vector2((size.x - track_size.x) * 0.5, (size.y - track_size.y) * 0.5)
	var accent := get_theme_color("accent", "App")
	var background := get_theme_color("background", "App")
	var glass_edge := get_theme_color("glass_edge", "App")
	var off_color := Color(0.28, 0.36, 0.48, 0.72) if background.get_luminance() < 0.5 else Color(0.78, 0.86, 0.94, 0.72)
	var track_color := off_color.lerp(accent, _progress)
	var track := StyleBoxFlat.new()
	track.bg_color = track_color
	track.border_color = glass_edge.lerp(accent.lightened(0.18), _progress)
	track.set_border_width_all(1)
	track.set_corner_radius_all(19)
	track.anti_aliasing = true
	if has_focus():
		track.border_color = accent.lightened(0.18)
		track.set_border_width_all(2)
	draw_style_box(track, Rect2(track_position, track_size))
	draw_line(
		track_position + Vector2(12, 5),
		track_position + Vector2(track_size.x - 12, 5),
		Color(1, 1, 1, 0.26),
		1.2,
		true
	)
	var knob_x := lerpf(track_position.x + 19.0, track_position.x + track_size.x - 19.0, _progress)
	var knob_center := Vector2(knob_x, track_position.y + track_size.y * 0.5)
	draw_circle(knob_center + Vector2(0, 1.8), 15.8, Color(0, 0.04, 0.12, 0.26))
	draw_circle(knob_center, 15.0, Color(0.98, 1.0, 1.0, 0.96))
	draw_circle(knob_center - Vector2(3.6, 4.0), 4.6, Color(1, 1, 1, 0.44))

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_RESIZED or what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
		queue_redraw()
