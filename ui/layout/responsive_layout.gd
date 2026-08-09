class_name ResponsiveLayout
extends RefCounted

const WIDE_MIN_WIDTH := 1240.0
const WIDE_MIN_ASPECT := 1.12
const NARROW_SHELL_MAX_WIDTH := 1120.0
const WIDE_SHELL_MAX_WIDTH := 2440.0

static func is_wide(viewport_size: Vector2) -> bool:
	return viewport_size.x >= WIDE_MIN_WIDTH and viewport_size.x > viewport_size.y * WIDE_MIN_ASPECT

static func shell_side_margin(viewport_size: Vector2) -> int:
	return 28 if is_wide(viewport_size) else 24

static func shell_max_width(viewport_size: Vector2) -> float:
	return WIDE_SHELL_MAX_WIDTH if is_wide(viewport_size) else NARROW_SHELL_MAX_WIDTH

static func game_board_side(viewport_size: Vector2, content_width: float) -> float:
	var available_width := maxf(content_width, viewport_size.x - 64.0)
	if not is_wide(viewport_size):
		return minf(viewport_size.x - 40.0, viewport_size.y * 0.54)
	var controls_width := clampf(available_width * 0.34, 500.0, 720.0)
	return clampf(minf(viewport_size.y * 0.68, available_width - controls_width - 48.0), 440.0, 1120.0)

static func responsive_columns(viewport_size: Vector2, wide_columns: int, narrow_columns: int) -> int:
	return wide_columns if is_wide(viewport_size) else narrow_columns
