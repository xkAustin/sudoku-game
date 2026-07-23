extends Node

const SETTINGS_FILE := "settings.json"
const PROFILE_FILE := "profile.json"
const GAMES_FILE := "active_games.json"
const STATS_FILE := "statistics.json"
const INSTALLATION_FILE := "installation.json"

var settings: Dictionary = {}
var profile: Dictionary = {}
var statistics: Dictionary = {}
var active_games: Dictionary = {}
var installation_id := ""
var current_session: GameSession
var _save_due_ms := 0

func _ready() -> void:
	settings = SaveManager.read_json(SETTINGS_FILE, _default_settings())
	profile = SaveManager.read_json(PROFILE_FILE, {"data_version": 1, "display_name": "Player"})
	statistics = SaveManager.read_json(STATS_FILE, _default_statistics())
	if _migrate_statistics():
		SaveManager.write_json(STATS_FILE, statistics)
	active_games = SaveManager.read_json(GAMES_FILE, {"data_version": 1, "games": {}})
	var installation: Dictionary = SaveManager.read_json(INSTALLATION_FILE, {})
	installation_id = str(installation.get("installation_id", ""))
	if installation_id.is_empty():
		installation_id = _uuid_v4()
		SaveManager.write_json(INSTALLATION_FILE, {"data_version": 1, "installation_id": installation_id})
	_apply_theme()

func _process(_delta: float) -> void:
	if _save_due_ms > 0 and Time.get_ticks_msec() >= _save_due_ms:
		_save_due_ms = 0
		save_session_now()

func set_session(session: GameSession) -> void:
	current_session = session
	EventBus.session_changed.emit()
	request_save()

func request_save() -> void:
	_save_due_ms = Time.get_ticks_msec() + 600

func save_session_now() -> void:
	if current_session == null:
		return
	var key := current_session.mode + "_" + str(current_session.difficulty)
	active_games["games"][key] = current_session.to_dict()
	SaveManager.write_json(GAMES_FILE, active_games)

func load_session(mode: String, difficulty: int) -> GameSession:
	var key := mode + "_" + str(difficulty)
	var data: Variant = active_games.get("games", {}).get(key)
	if data is Dictionary:
		return GameSession.from_dict(data)
	return null

func clear_session(mode: String, difficulty: int) -> void:
	active_games.get("games", {}).erase(mode + "_" + str(difficulty))
	if current_session != null and current_session.mode == mode and current_session.difficulty == difficulty:
		current_session = null
		_save_due_ms = 0
	SaveManager.write_json(GAMES_FILE, active_games)

func save_settings() -> void:
	SaveManager.write_json(SETTINGS_FILE, settings)
	_apply_theme()
	EventBus.settings_changed.emit()

func set_display_name(value: String) -> bool:
	var normalized := " ".join(value.strip_edges().split(" ", false))
	if normalized.length() < 1 or normalized.length() > 20:
		return false
	for character in normalized:
		if character.unicode_at(0) < 32:
			return false
	profile["display_name"] = normalized
	SaveManager.write_json(PROFILE_FILE, profile)
	return true

func record_completion(session: GameSession) -> bool:
	var key := str(session.difficulty)
	var item: Dictionary = statistics["by_difficulty"].get(key, {"started": 0, "completed": 0, "best_ms": 0, "operations": 0})
	item["completed"] = int(item.get("completed", 0)) + 1
	item["operations"] = int(item.get("operations", 0)) + session.operation_count
	var previous_best := int(item.get("best_ms", 0))
	var is_new_best := previous_best == 0 or session.elapsed_ms < previous_best
	if is_new_best:
		item["best_ms"] = session.elapsed_ms
	statistics["by_difficulty"][key] = item
	statistics["completed"] = int(statistics.get("completed", 0)) + 1
	statistics["operations"] = int(statistics.get("operations", 0)) + session.operation_count
	statistics["current_streak"] = int(statistics.get("current_streak", 0)) + 1
	statistics["longest_streak"] = maxi(int(statistics.get("longest_streak", 0)), int(statistics["current_streak"]))
	SaveManager.write_json(STATS_FILE, statistics)
	return is_new_best

func record_start(difficulty: int) -> void:
	var key := str(clampi(difficulty, 0, 5))
	var item: Dictionary = statistics["by_difficulty"].get(key, {"started": 0, "completed": 0, "best_ms": 0, "operations": 0})
	item["started"] = int(item.get("started", 0)) + 1
	statistics["by_difficulty"][key] = item
	statistics["started"] = int(statistics.get("started", 0)) + 1
	SaveManager.write_json(STATS_FILE, statistics)

func reset_local_data() -> void:
	settings = _default_settings()
	profile = {"data_version": 1, "display_name": "Player"}
	statistics = _default_statistics()
	active_games = {"data_version": 1, "games": {}}
	SaveManager.write_json(SETTINGS_FILE, settings)
	SaveManager.write_json(PROFILE_FILE, profile)
	SaveManager.write_json(STATS_FILE, statistics)
	SaveManager.write_json(GAMES_FILE, active_games)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_session_now()

func _apply_theme() -> void:
	var theme_mode := str(settings.get("theme", "system"))
	var dark := theme_mode == "dark" or (theme_mode == "system" and DisplayServer.is_dark_mode_supported() and DisplayServer.is_dark_mode())
	RenderingServer.set_default_clear_color(Color("0e1521") if dark else Color("eef3f8"))

func _default_settings() -> Dictionary:
	return {"data_version": 8, "theme": "system", "language": "system", "sound": true, "error_sound": true, "vibration": true,
		"auto_check": true, "auto_clear_notes": true, "highlight_same": true,
		"highlight_related": true, "hide_completed_numbers": true, "show_timer": true, "show_mistakes": true,
		"high_contrast": false, "reduce_motion": false, "ui_scale": 1.0,
		"leaderboard_network_allowed": false, "leaderboard_auto_refresh": false, "ranked_auto_upload": false,
		"custom_ui_sound_path": "", "custom_ui_sound_name": "",
		"custom_error_sound_path": "", "custom_error_sound_name": "",
		"shortcut_platform": OS.get_name(), "shortcuts": {}}

func _default_statistics() -> Dictionary:
	return {"data_version": 2, "started": 0, "completed": 0, "operations": 0, "current_streak": 0, "longest_streak": 0,
		"by_difficulty": {"0": {}, "1": {}, "2": {}, "3": {}, "4": {}, "5": {}}}

func _migrate_statistics() -> bool:
	var changed := false
	if not statistics.has("operations"):
		statistics["operations"] = 0
		changed = true
	if not statistics.get("by_difficulty", {}) is Dictionary:
		statistics["by_difficulty"] = {}
		changed = true
	var by_difficulty: Dictionary = statistics["by_difficulty"]
	for difficulty in 6:
		var key := str(difficulty)
		var item: Dictionary = by_difficulty.get(key, {})
		if not item.has("operations"):
			item["operations"] = 0
			changed = true
		by_difficulty[key] = item
	if int(statistics.get("data_version", 1)) < 2:
		statistics["data_version"] = 2
		changed = true
	return changed

func _uuid_v4() -> String:
	var crypto := Crypto.new()
	var bytes := crypto.generate_random_bytes(16)
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]
