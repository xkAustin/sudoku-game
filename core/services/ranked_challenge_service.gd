class_name RankedChallengeService
extends Node

signal challenge_received(challenge: Dictionary)
signal challenge_failed(message: String)

const CACHE_FILE := "cached_challenges.json"
var _request_id := ""
var _requested_difficulty := -1

func _ready() -> void:
	var network_manager := get_node_or_null("/root/NetworkManager")
	if network_manager != null:
		network_manager.request_completed.connect(_on_request_completed)

func fetch(difficulty: int) -> void:
	var normalized_difficulty := clampi(difficulty, 0, 5)
	if not _request_id.is_empty() and _requested_difficulty == normalized_difficulty:
		return
	cancel_fetch()
	_requested_difficulty = normalized_difficulty
	var network_manager := get_node_or_null("/root/NetworkManager")
	if network_manager == null:
		_requested_difficulty = -1
		call_deferred("_emit_failure", "在线服务不可用")
		return
	_request_id = str(network_manager.call("request_json", HTTPClient.METHOD_GET, "get-ranked-challenge?difficulty=" + str(normalized_difficulty + 1)))

func cancel_fetch() -> bool:
	if _request_id.is_empty():
		return false
	var request_id := _request_id
	_request_id = ""
	_requested_difficulty = -1
	var network_manager := get_node_or_null("/root/NetworkManager")
	return bool(network_manager.call("cancel_request", request_id)) if network_manager != null else false

func cached(difficulty: int) -> Dictionary:
	var save_manager := get_node_or_null("/root/SaveManager")
	if save_manager == null:
		return {}
	var data: Dictionary = save_manager.call("read_json", CACHE_FILE, {"data_version": 1, "challenges": {}})
	return data.get("challenges", {}).get(str(difficulty), {})

func _on_request_completed(request_id: String, success: bool, data: Variant, _status: int) -> void:
	if request_id != _request_id:
		return
	_request_id = ""
	_requested_difficulty = -1
	if success and data is Dictionary and str(data.get("puzzle", "")).length() in [81, 256]:
		var difficulty := int(data.get("difficulty", 1)) - 1
		var save_manager := get_node_or_null("/root/SaveManager")
		if save_manager != null:
			var cache: Dictionary = save_manager.call("read_json", CACHE_FILE, {"data_version": 1, "challenges": {}})
			cache["challenges"][str(difficulty)] = data
			save_manager.call("write_json", CACHE_FILE, cache)
		challenge_received.emit(data)
	else:
		challenge_failed.emit(str(data.get("error", {}).get("message", "无法获取排位题目")) if data is Dictionary else "无法获取排位题目")

func _emit_failure(message: String) -> void:
	challenge_failed.emit(message)
