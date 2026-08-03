extends Node

const PRODUCT_NAME := "Sudoku Game"
const PACKAGE_ID := "io.github.xkaustin.sudokugame"
const APP_VERSION := "1.0.0"
const API_VERSION := "v1"
const ALGORITHM_VERSION := 1
const LOCAL_CLIENT_CONFIG := "res://config/client.env"

# Debug 专用：编辑器运行和 Debug 导出为 true，Release 导出会由 Godot 自动设为 false。
var DEBUG: bool = OS.is_debug_build()
var development_mode: bool = DEBUG and not OS.get_cmdline_user_args().has("--no-development-mode")

# Public client configuration only. Values are loaded from the ignored local
# config file or process environment and are never committed to source control.
var supabase_url: String = ""
var supabase_anon_key: String = ""

func _ready() -> void:
	_load_local_config()
	var environment_url := OS.get_environment("SUPABASE_URL").strip_edges()
	var environment_key := OS.get_environment("SUPABASE_KEY").strip_edges()
	if environment_key.is_empty():
		environment_key = OS.get_environment("SUPABASE_ANON_KEY").strip_edges()
	if not environment_url.is_empty():
		supabase_url = environment_url
	if not environment_key.is_empty():
		supabase_anon_key = environment_key

func online_configured() -> bool:
	return supabase_project_url().begins_with("https://") and not supabase_anon_key.is_empty()

func debug_log(message: String) -> void:
	# Debug 专用：正式发布构建不会输出开发日志。
	if development_mode:
		print("[Development] " + message)

func supabase_project_url() -> String:
	var value := supabase_url.strip_edges().trim_suffix("/")
	if value.ends_with("/rest/v1"):
		value = value.trim_suffix("/rest/v1")
	return value

func supabase_rest_url() -> String:
	var project_url := supabase_project_url()
	return project_url + "/rest/v1" if not project_url.is_empty() else ""

func _load_local_config() -> void:
	if not FileAccess.file_exists(LOCAL_CLIENT_CONFIG):
		return
	var file := FileAccess.open(LOCAL_CLIENT_CONFIG, FileAccess.READ)
	if file == null:
		return
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#") or not line.contains("="):
			continue
		var separator := line.find("=")
		var key := line.substr(0, separator).strip_edges()
		var value := _unquote(line.substr(separator + 1).strip_edges())
		match key:
			"SUPABASE_URL":
				supabase_url = value
			"SUPABASE_KEY", "SUPABASE_ANON_KEY":
				supabase_anon_key = value
	file.close()

func _unquote(value: String) -> String:
	if value.length() >= 2 and ((value.begins_with("\"") and value.ends_with("\"")) or (value.begins_with("'") and value.ends_with("'"))):
		return value.substr(1, value.length() - 2)
	return value
