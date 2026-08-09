extends Node

const QUEUE_FILE := "pending_submissions.json"
const MAX_RETRIES := 5
const TRANSIENT_CLIENT_STATUS_CODES := [408, 425, 429]

signal flush_completed(success: bool)

var queue: Array = []
var failed_items: Array = []
var _active_request := ""
var _retry_at_ms := 0
var _flush_requested := false
var _flush_had_failure := false
var _persistence_enabled := true

func _ready() -> void:
	var saved: Variant = SaveManager.read_json(QUEUE_FILE, {"data_version": 2, "items": [], "failed_items": []})
	var migrated := saved is Dictionary and int(saved.get("data_version", 1)) < 2
	failed_items = saved.get("failed_items", []) if saved is Dictionary else []
	queue = []
	var loaded_items: Array = saved.get("items", []) if saved is Dictionary else []
	for value in loaded_items:
		if not value is Dictionary:
			continue
		var item: Dictionary = value
		if bool(item.get("failed_permanently", false)):
			failed_items.append(item)
			migrated = true
		else:
			queue.append(item)
	SupabaseClient.request_completed.connect(_on_request_completed)
	EventBus.network_changed.connect(_on_network_changed)
	if migrated:
		_save()
	else:
		EventBus.pending_count_changed.emit(queue.size())
	if not queue.is_empty() and bool(queue[0].get("retry_pending", false)) and NetworkManager.online and AppConfig.online_configured():
		_flush_requested = true
	set_process(true)

func _process(_delta: float) -> void:
	if _flush_requested and _active_request.is_empty() and not queue.is_empty() and NetworkManager.online and Time.get_ticks_msec() >= _retry_at_ms:
		_submit_front()

func enqueue(submission: Dictionary) -> String:
	if not submission.has("idempotency_key"):
		submission["idempotency_key"] = _uuid_v4()
	submission["retry_count"] = 0
	for existing in queue:
		if existing.get("idempotency_key") == submission["idempotency_key"]:
			return str(submission["idempotency_key"])
	for existing in failed_items:
		if existing.get("idempotency_key") == submission["idempotency_key"]:
			return str(submission["idempotency_key"])
	queue.append(submission)
	_save()
	return str(submission["idempotency_key"])

func has_pending() -> bool:
	return not queue.is_empty()

func failed_count() -> int:
	return failed_items.size()

func retry_failed(idempotency_key: String = "") -> int:
	var restored := 0
	for index in range(failed_items.size() - 1, -1, -1):
		var item: Dictionary = failed_items[index]
		if idempotency_key.is_empty() or str(item.get("idempotency_key", "")) == idempotency_key:
			item.erase("failed_permanently")
			item["retry_count"] = 0
			queue.append(item)
			failed_items.remove_at(index)
			restored += 1
	_save()
	return restored

func discard_failed(idempotency_key: String = "") -> int:
	var removed := 0
	for index in range(failed_items.size() - 1, -1, -1):
		var item: Dictionary = failed_items[index]
		if idempotency_key.is_empty() or str(item.get("idempotency_key", "")) == idempotency_key:
			failed_items.remove_at(index)
			removed += 1
	_save()
	return removed

func clear_all() -> void:
	queue.clear()
	failed_items.clear()
	_active_request = ""
	_retry_at_ms = 0
	_flush_requested = false
	_flush_had_failure = false
	if _persistence_enabled:
		SaveManager.remove_json(QUEUE_FILE)
	EventBus.pending_count_changed.emit(0)

func flush_now() -> void:
	if queue.is_empty():
		call_deferred("_finish_flush", true)
		return
	_flush_requested = true
	_flush_had_failure = false
	var item: Dictionary = queue[0]
	if int(item.get("retry_count", 0)) >= MAX_RETRIES:
		item["retry_count"] = 0
	item["retry_pending"] = true
	_save()
	if not NetworkManager.online or not AppConfig.online_configured():
		call_deferred("_notify_flush", false)
		return
	_retry_at_ms = 0

func _submit_front() -> void:
	var submission: Dictionary = queue[0]
	_active_request = SupabaseClient.call_rpc("submit_score", _rpc_payload(submission))

func _rpc_payload(submission: Dictionary) -> Dictionary:
	return {
		"p_player_id": str(submission.get("installation_id", "")),
		"p_player_name": str(submission.get("display_name", "Player")),
		"p_difficulty": clampi(int(submission.get("difficulty", 1)), 1, 6),
		"p_duration_ms": maxi(0, int(submission.get("duration_ms", 0))),
		"p_mistakes": maxi(0, int(submission.get("mistakes", 0))),
		"p_hints_used": maxi(0, int(submission.get("hints_used", 0))),
		"p_move_count": maxi(0, int(submission.get("move_count", 0))),
		"p_submission_id": str(submission.get("idempotency_key", "")),
	}

func _on_request_completed(request_id: String, success: bool, _data: Variant, status_code: int) -> void:
	if request_id != _active_request:
		return
	_active_request = ""
	if queue.is_empty():
		return
	if success or status_code == 409:
		queue.pop_front()
		_retry_at_ms = 0
		if not queue.is_empty():
			queue[0]["retry_pending"] = true
		_save()
		if queue.is_empty():
			_finish_flush(not _flush_had_failure)
		return
	var item: Dictionary = queue[0]
	item["retry_count"] = int(item.get("retry_count", 0)) + 1
	if _is_permanent_client_error(status_code):
		item["failed_permanently"] = true
		item.erase("retry_pending")
		queue.pop_front()
		item["failed_at"] = Time.get_datetime_string_from_system(true)
		failed_items.append(item)
		_flush_had_failure = true
		_retry_at_ms = 0
		if not queue.is_empty():
			queue[0]["retry_pending"] = true
		_save()
		if queue.is_empty():
			_finish_flush(false)
		return
	if int(item["retry_count"]) >= MAX_RETRIES:
		item.erase("retry_pending")
		_retry_at_ms = 0
		_save()
		_finish_flush(false)
		return
	item["retry_pending"] = true
	var delay_seconds := 30 if status_code == 429 else mini(60, 1 << mini(int(item["retry_count"]), 6))
	_retry_at_ms = Time.get_ticks_msec() + delay_seconds * 1000
	_save()

func _on_network_changed(value: bool) -> void:
	if value and not queue.is_empty() and bool(queue[0].get("retry_pending", false)):
		_flush_requested = true
		_retry_at_ms = 0

func _is_permanent_client_error(status_code: int) -> bool:
	return status_code >= 400 and status_code < 500 and status_code not in TRANSIENT_CLIENT_STATUS_CODES and status_code != 409

func _finish_flush(success: bool) -> void:
	_flush_requested = false
	_retry_at_ms = 0
	flush_completed.emit(success)

func _notify_flush(success: bool) -> void:
	flush_completed.emit(success)

func _save() -> void:
	if _persistence_enabled:
		SaveManager.write_json(QUEUE_FILE, {"data_version": 2, "items": queue, "failed_items": failed_items})
	EventBus.pending_count_changed.emit(queue.size())

func _uuid_v4() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]
