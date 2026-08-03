class_name DevelopmentConfig
extends Node

# Debug 专用：集中管理可在运行时热加载的开发参数。
signal config_reloaded(values: Dictionary)

const DEFAULT_VALUES := {
	"default_difficulty": 1,
	"test_seed": 20260803,
	"test_elapsed_ms": 95000,
	"test_mistakes": 0,
	"mock_player_count": 12,
	"panel_refresh_seconds": 0.5,
	"log_output": true,
}

@export_file("*.json") var config_path := "res://debug/development_config.json"
@export_range(0.2, 10.0, 0.1) var reload_interval_seconds := 0.75

var values: Dictionary = DEFAULT_VALUES.duplicate(true)
var _elapsed_seconds := 0.0
var _last_source_text := ""

func _ready() -> void:
	set_process(_development_mode_enabled())
	if _development_mode_enabled():
		reload_if_changed(true)

func _process(delta: float) -> void:
	_elapsed_seconds += delta
	if _elapsed_seconds < reload_interval_seconds:
		return
	_elapsed_seconds = 0.0
	reload_if_changed()

func reload_if_changed(force: bool = false) -> bool:
	if not _development_mode_enabled() or not FileAccess.file_exists(config_path):
		return false
	var file := FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		return false
	var source_text := file.get_as_text()
	file.close()
	if not force and source_text == _last_source_text:
		return false
	var parsed: Variant = JSON.parse_string(source_text)
	if not parsed is Dictionary:
		push_warning("Development config is not valid JSON: " + config_path)
		return false
	_last_source_text = source_text
	values = _sanitize(parsed)
	config_reloaded.emit(values.duplicate(true))
	return true

func value(key: String, fallback: Variant = null) -> Variant:
	return values.get(key, fallback)

func _sanitize(source: Dictionary) -> Dictionary:
	var result := DEFAULT_VALUES.duplicate(true)
	result["default_difficulty"] = clampi(int(source.get("default_difficulty", result["default_difficulty"])), 0, 5)
	result["test_seed"] = int(source.get("test_seed", result["test_seed"]))
	result["test_elapsed_ms"] = clampi(int(source.get("test_elapsed_ms", result["test_elapsed_ms"])), 0, 86400000)
	result["test_mistakes"] = clampi(int(source.get("test_mistakes", result["test_mistakes"])), 0, 2)
	result["mock_player_count"] = clampi(int(source.get("mock_player_count", result["mock_player_count"])), 1, 100)
	result["panel_refresh_seconds"] = clampf(float(source.get("panel_refresh_seconds", result["panel_refresh_seconds"])), 0.1, 5.0)
	result["log_output"] = bool(source.get("log_output", result["log_output"]))
	return result

func _development_mode_enabled() -> bool:
	var app_config := get_node_or_null("/root/AppConfig")
	return app_config != null and bool(app_config.get("development_mode"))
