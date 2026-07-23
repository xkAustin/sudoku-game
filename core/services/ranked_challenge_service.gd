class_name RankedChallengeService
extends Node

signal challenge_received(challenge: Dictionary)
signal challenge_failed(message: String)

const CACHE_FILE := "cached_challenges.json"
var _request_id := ""

func _ready() -> void:
	NetworkManager.request_completed.connect(_on_request_completed)

func fetch(difficulty: int) -> void:
	_request_id = NetworkManager.request_json(HTTPClient.METHOD_GET, "get-ranked-challenge?difficulty=" + str(clampi(difficulty, 0, 5) + 1))

func cached(difficulty: int) -> Dictionary:
	var data: Dictionary = SaveManager.read_json(CACHE_FILE, {"data_version": 1, "challenges": {}})
	return data.get("challenges", {}).get(str(difficulty), {})

func _on_request_completed(request_id: String, success: bool, data: Variant, _status: int) -> void:
	if request_id != _request_id:
		return
	_request_id = ""
	if success and data is Dictionary and str(data.get("puzzle", "")).length() in [81, 256]:
		var difficulty := int(data.get("difficulty", 1)) - 1
		var cache: Dictionary = SaveManager.read_json(CACHE_FILE, {"data_version": 1, "challenges": {}})
		cache["challenges"][str(difficulty)] = data
		SaveManager.write_json(CACHE_FILE, cache)
		challenge_received.emit(data)
	else:
		challenge_failed.emit(str(data.get("error", {}).get("message", "无法获取排位题目")) if data is Dictionary else "无法获取排位题目")
