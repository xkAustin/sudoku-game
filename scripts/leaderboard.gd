class_name OnlineLeaderboard
extends Node

signal loaded(snapshot: Dictionary)
signal failed(message: String)

const CACHE_FILE := "leaderboard_cache.json"
const DIFFICULTY_BASES := [1000000, 2000000, 3000000, 5000000, 8000000, 13000000]

var _request_id := ""

func _ready() -> void:
	var client := get_node_or_null("/root/SupabaseClient")
	if client != null and not client.is_connected("request_completed", _on_request_completed):
		client.connect("request_completed", _on_request_completed)

func fetch(_difficulty: int = 0, player_id: String = "") -> void:
	var app_state := get_node_or_null("/root/AppState")
	var settings: Dictionary = app_state.get("settings") if app_state != null else {}
	if not bool(settings.get("leaderboard_network_allowed", false)):
		call_deferred("_emit_cached_or_failed")
		return
	var client := get_node_or_null("/root/SupabaseClient")
	if client == null:
		call_deferred("_emit_cached_or_failed")
		return
	_request_id = str(client.call("call_rpc", "get_leaderboard", {
		"p_player_id": player_id if not player_id.is_empty() else null,
	}))

func cached_snapshot(_difficulty: int = 0) -> Dictionary:
	var save_manager := get_node_or_null("/root/SaveManager")
	if save_manager == null:
		return {}
	var cached: Dictionary = save_manager.call("read_json", CACHE_FILE, {"data_version": 3, "global": {}})
	if int(cached.get("data_version", 0)) != 3:
		return {}
	var snapshot: Variant = cached.get("global", {})
	if not snapshot is Dictionary or snapshot.is_empty():
		return {}
	var result: Dictionary = snapshot.duplicate(true)
	result["source"] = "cache"
	return result

func cached_entries(_difficulty: int = 0) -> Array:
	return cached_snapshot().get("entries", [])

func has_cached_snapshot(_difficulty: int = 0) -> bool:
	return not cached_snapshot().is_empty()

func _emit_cached_or_failed() -> void:
	var fallback := cached_snapshot()
	if not fallback.is_empty():
		loaded.emit(fallback)
	else:
		failed.emit("排行榜联网权限尚未授予")

func _on_request_completed(request_id: String, success: bool, data: Variant, _status: int) -> void:
	if request_id != _request_id:
		return
	_request_id = ""
	if success and data is Dictionary:
		var snapshot := normalize_snapshot(data)
		if not snapshot.is_empty():
			snapshot["cached_at"] = Time.get_datetime_string_from_system(true)
			snapshot["source"] = "network"
			var save_manager := get_node_or_null("/root/SaveManager")
			if save_manager != null:
				save_manager.call("write_json", CACHE_FILE, {
					"data_version": 3,
					"global": snapshot.duplicate(true),
				})
			loaded.emit(snapshot)
			return
	var fallback := cached_snapshot()
	if not fallback.is_empty():
		loaded.emit(fallback)
	else:
		failed.emit("网络请求失败，且没有可用的排行榜缓存")

static func normalize_snapshot(value: Dictionary) -> Dictionary:
	if not value.get("entries", []) is Array:
		return {}
	var entries: Array = []
	for row_value in value.get("entries", []):
		if not row_value is Dictionary:
			continue
		var row: Dictionary = row_value
		entries.append({
			"rank": maxi(1, int(row.get("rank", entries.size() + 1))),
			"display_name": str(row.get("display_name", row.get("player_name", "Player"))),
			"score": maxi(0, int(row.get("score", 0))),
			"submitted_at": str(row.get("submitted_at", row.get("created_at", ""))),
		})
	var self_entry: Dictionary = {}
	var raw_self: Variant = value.get("self_entry", {})
	if raw_self is Dictionary and not raw_self.is_empty():
		self_entry = {
			"rank": maxi(1, int(raw_self.get("rank", 1))),
			"display_name": str(raw_self.get("display_name", raw_self.get("player_name", "Player"))),
			"score": maxi(0, int(raw_self.get("score", 0))),
			"submitted_at": str(raw_self.get("submitted_at", raw_self.get("created_at", ""))),
		}
	return {
		"entries": entries,
		"self_entry": self_entry,
	}

static func score_from_submission(submission: Dictionary) -> int:
	var difficulty := clampi(int(submission.get("difficulty", 1)), 1, 6)
	var elapsed_ms := clampi(int(submission.get("duration_ms", 0)), 0, 86400000)
	var mistakes := clampi(int(submission.get("mistakes", 0)), 0, 3)
	var hints := clampi(int(submission.get("hints_used", 0)), 0, 100)
	var moves := clampi(int(submission.get("move_count", 0)), 0, 10000)
	var speed_bonus := maxi(0, 1000000 - elapsed_ms)
	var accuracy_bonus := maxi(0, 3 - mistakes) * 25000
	var efficiency_bonus := maxi(0, 500 - moves) * 100
	var hint_penalty := hints * 100000
	return maxi(1, int(DIFFICULTY_BASES[difficulty - 1]) + speed_bonus + accuracy_bonus + efficiency_bonus - hint_penalty)
