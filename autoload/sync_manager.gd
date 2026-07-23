extends Node

const QUEUE_FILE := "pending_submissions.json"
const MAX_RETRIES := 5

signal flush_completed(success: bool)

var queue: Array = []
var _active_request := ""
var _retry_at_ms := 0
var _flush_requested := false

func _ready() -> void:
	var saved: Variant = SaveManager.read_json(QUEUE_FILE, {"data_version": 1, "items": []})
	queue = saved.get("items", []) if saved is Dictionary else []
	NetworkManager.request_completed.connect(_on_request_completed)
	EventBus.network_changed.connect(_on_network_changed)
	EventBus.pending_count_changed.emit(queue.size())
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
	queue.append(submission)
	_save()
	return str(submission["idempotency_key"])

func has_pending() -> bool:
	return not queue.is_empty()

func flush_now() -> void:
	if queue.is_empty():
		call_deferred("_finish_flush", true)
		return
	if not NetworkManager.online or not AppConfig.online_configured():
		call_deferred("_finish_flush", false)
		return
	_flush_requested = true
	_retry_at_ms = 0

func _submit_front() -> void:
	_active_request = NetworkManager.request_json(HTTPClient.METHOD_POST, "submit-score", queue[0])

func _on_request_completed(request_id: String, success: bool, data: Variant, status_code: int) -> void:
	if request_id != _active_request:
		return
	_active_request = ""
	if queue.is_empty():
		return
	if success or status_code == 409:
		queue.pop_front()
		_retry_at_ms = 0
		_save()
		if queue.is_empty():
			_finish_flush(true)
		return
	var item: Dictionary = queue[0]
	item["retry_count"] = int(item.get("retry_count", 0)) + 1
	if int(item["retry_count"]) >= MAX_RETRIES and status_code >= 400 and status_code < 500:
		item["failed_permanently"] = true
		queue.pop_front()
		queue.append(item)
		_retry_at_ms = Time.get_ticks_msec() + 3600000
	else:
		var delay_seconds := mini(60, 1 << mini(int(item["retry_count"]), 6))
		_retry_at_ms = Time.get_ticks_msec() + delay_seconds * 1000
	_save()
	if _flush_requested:
		_finish_flush(false)

func _on_network_changed(value: bool) -> void:
	if value:
		_retry_at_ms = 0

func _finish_flush(success: bool) -> void:
	_flush_requested = false
	flush_completed.emit(success)

func _save() -> void:
	SaveManager.write_json(QUEUE_FILE, {"data_version": 1, "items": queue})
	EventBus.pending_count_changed.emit(queue.size())

func _uuid_v4() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]
