extends Node

signal request_completed(request_id: String, success: bool, data: Variant, status_code: int)

var _requests: Dictionary = {}

func get_rows(table: String, query: String = "") -> String:
	var endpoint := table.uri_encode()
	if not query.is_empty():
		endpoint += "?" + query
	return request_json(HTTPClient.METHOD_GET, endpoint)

func call_rpc(function_name: String, body: Dictionary = {}) -> String:
	return request_json(HTTPClient.METHOD_POST, "rpc/" + function_name.uri_encode(), body)

func request_json(method: HTTPClient.Method, endpoint: String, body: Dictionary = {}) -> String:
	var request_id := _uuid_v4()
	if not AppConfig.online_configured():
		call_deferred("_emit_result", request_id, false, {
			"code": "UNCONFIGURED",
			"message": "Supabase Data API is not configured",
		}, 0)
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
		"Accept: application/json",
		"Content-Type: application/json",
		"X-Client-Version: " + AppConfig.APP_VERSION,
	])
	var url := AppConfig.supabase_rest_url().trim_suffix("/") + "/" + endpoint.trim_prefix("/")
	var payload := JSON.stringify(body) if method != HTTPClient.METHOD_GET else ""
	var error := request.request(url, headers, method, payload)
	if error != OK:
		_requests.erase(request_id)
		request.queue_free()
		NetworkManager.report_connectivity(false)
		call_deferred("_emit_result", request_id, false, {
			"code": "NETWORK_ERROR",
			"message": "The Supabase request could not start",
		}, 0)
	return request_id

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, request_id: String) -> void:
	var request: HTTPRequest = _requests.get(request_id)
	_requests.erase(request_id)
	if request != null:
		request.queue_free()
	var response_text := body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(response_text)
	if parsed == null:
		parsed = {} if response_text.is_empty() else {
			"code": "INVALID_RESPONSE",
			"message": "Supabase returned an unreadable response",
		}
	var transport_ok := result == HTTPRequest.RESULT_SUCCESS
	var success := transport_ok and response_code >= 200 and response_code < 300
	NetworkManager.report_connectivity(transport_ok)
	request_completed.emit(request_id, success, parsed, response_code)

func _emit_result(request_id: String, success: bool, data: Variant, status_code: int) -> void:
	request_completed.emit(request_id, success, data, status_code)

func _uuid_v4() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]
