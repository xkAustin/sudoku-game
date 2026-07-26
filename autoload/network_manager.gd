extends Node

signal request_completed(request_id: String, success: bool, data: Variant, status_code: int)

var online := true
var _requests: Dictionary = {}

func _ready() -> void:
	online = AppConfig.online_configured()
	EventBus.network_changed.emit(online)

func request_json(method: HTTPClient.Method, endpoint: String, body: Dictionary = {}) -> String:
	var request_id := _uuid_v4()
	if not AppConfig.online_configured():
		call_deferred("_emit_unconfigured", request_id)
		return request_id
	var request := HTTPRequest.new()
	request.timeout = 12.0
	request.accept_gzip = true
	add_child(request)
	_requests[request_id] = request
	request.request_completed.connect(_on_request_completed.bind(request_id))
	var headers := PackedStringArray([
		"Authorization: Bearer " + AppConfig.supabase_anon_key,
		"apikey: " + AppConfig.supabase_anon_key,
		"Content-Type: application/json",
		"X-Client-Version: " + AppConfig.APP_VERSION
	])
	var url := AppConfig.supabase_project_url() + "/functions/v1/" + endpoint.trim_prefix("/")
	var payload := JSON.stringify(body) if method != HTTPClient.METHOD_GET else ""
	var error := request.request(url, headers, method, payload)
	if error != OK:
		_requests.erase(request_id)
		request.queue_free()
		_set_online(false)
		call_deferred("_emit_result", request_id, false, {"error": {"code": "NETWORK_ERROR", "message": "网络请求无法启动"}}, 0)
	return request_id

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, request_id: String) -> void:
	var request: HTTPRequest = _requests.get(request_id)
	_requests.erase(request_id)
	if request != null:
		request.queue_free()
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if parsed == null:
		parsed = {"error": {"code": "INVALID_RESPONSE", "message": "服务器返回了无法识别的数据"}}
	var success := result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300
	_set_online(result == HTTPRequest.RESULT_SUCCESS)
	request_completed.emit(request_id, success, parsed, response_code)

func _emit_unconfigured(request_id: String) -> void:
	_emit_result(request_id, false, {"error": {"code": "OFFLINE", "message": "在线服务尚未配置"}}, 0)

func _emit_result(request_id: String, success: bool, data: Variant, status: int) -> void:
	request_completed.emit(request_id, success, data, status)

func _set_online(value: bool) -> void:
	if online != value:
		online = value
		EventBus.network_changed.emit(online)

func report_connectivity(value: bool) -> void:
	_set_online(value)

func _uuid_v4() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]
