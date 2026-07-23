class_name LeaderboardService
extends Node

signal loaded(snapshot: Dictionary)
signal failed(message: String)

const CACHE_FILE := "leaderboard_cache.json"
var _request_id := ""
var _requested_difficulty := 0

func _ready() -> void:
	NetworkManager.request_completed.connect(_on_request_completed)

func fetch(difficulty: int = 0, installation_id: String = "") -> void:
	_requested_difficulty = clampi(difficulty, 0, 5)
	if not bool(AppState.settings.get("leaderboard_network_allowed", false)):
		call_deferred("_emit_cached_or_failed", _requested_difficulty)
		return
	var endpoint := "get-leaderboard?difficulty=%d&limit=100" % (_requested_difficulty + 1)
	if not installation_id.is_empty():
		endpoint += "&installation_id=" + installation_id.uri_encode()
	_request_id = NetworkManager.request_json(HTTPClient.METHOD_GET, endpoint)

func cached_snapshot(difficulty: int = 0) -> Dictionary:
	var cached: Dictionary = SaveManager.read_json(CACHE_FILE, {"data_version": 2, "boards": {}})
	var boards: Dictionary = cached.get("boards", {}) if cached.get("boards", {}) is Dictionary else {}
	var snapshot: Variant = boards.get(str(clampi(difficulty, 0, 5)), {})
	if snapshot is Dictionary and not snapshot.is_empty():
		var result: Dictionary = snapshot.duplicate(true)
		result["source"] = "cache"
		return result
	# Migrate the original single-board cache without losing offline data.
	if difficulty == 0 and cached.get("entries", []) is Array and not cached.get("entries", []).is_empty():
		return {
			"entries": cached.get("entries", []), "self_entry": {},
			"cached_at": str(cached.get("cached_at", "")), "challenge_id": "", "source": "cache"
		}
	return {}

func cached_entries(difficulty: int = 0) -> Array:
	return cached_snapshot(difficulty).get("entries", [])

func has_cached_snapshot(difficulty: int = 0) -> bool:
	return not cached_snapshot(difficulty).is_empty()

func _emit_cached_or_failed(difficulty: int) -> void:
	var fallback := cached_snapshot(difficulty)
	if not fallback.is_empty():
		loaded.emit(fallback)
	else:
		failed.emit("排行榜联网权限尚未授予")

func _on_request_completed(request_id: String, success: bool, data: Variant, _status: int) -> void:
	if request_id != _request_id:
		return
	_request_id = ""
	if success and data is Dictionary and data.get("entries", []) is Array:
		var cached_at := Time.get_datetime_string_from_system(true)
		var self_entry: Dictionary = data.get("self_entry", {}) if data.get("self_entry", {}) is Dictionary else {}
		var snapshot := {
			"entries": data["entries"], "self_entry": self_entry,
			"cached_at": cached_at, "challenge_id": str(data.get("challenge_id", "")), "source": "network"
		}
		var cache: Dictionary = SaveManager.read_json(CACHE_FILE, {"data_version": 2, "boards": {}})
		if not cache.get("boards", {}) is Dictionary:
			cache["boards"] = {}
		cache["data_version"] = 2
		cache["boards"][str(_requested_difficulty)] = snapshot.duplicate(true)
		SaveManager.write_json(CACHE_FILE, cache)
		loaded.emit(snapshot)
	else:
		var fallback := cached_snapshot(_requested_difficulty)
		if not fallback.is_empty():
			loaded.emit(fallback)
		else:
			failed.emit("离线且没有可用的排行榜缓存")
