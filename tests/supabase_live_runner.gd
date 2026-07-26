extends SceneTree

var _client: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_client = root.get_node_or_null("SupabaseClient")
	var app_config := root.get_node_or_null("AppConfig")
	if _client == null or app_config == null or not app_config.online_configured():
		push_error("Supabase live: config/client.env is missing or incomplete")
		quit(2)
		return

	var test_player_id := _uuid_v4()
	var test_submission_id := _uuid_v4()
	var submit := await _call_rpc("submit_score", {
			"p_player_id": test_player_id,
		"p_player_name": "Godot Live QA",
		"p_difficulty": 3,
		"p_duration_ms": 120000,
		"p_mistakes": 0,
		"p_hints_used": 0,
		"p_move_count": 120,
			"p_submission_id": test_submission_id,
	})
	if not bool(submit[1]) or int(submit[3]) != 200 \
			or not submit[2] is Dictionary \
			or bool(submit[2].get("duplicate", true)) \
			or not bool(submit[2].get("updated", false)) \
			or int(submit[2].get("score", 0)) != 3993000:
		push_error("Supabase live: Godot submit_score failed: %s" % [submit])
		quit(1)
		return

	var leaderboard := await _call_rpc("get_leaderboard", {"p_player_id": test_player_id})
	if not bool(leaderboard[1]) or int(leaderboard[3]) != 200 \
			or not leaderboard[2] is Dictionary \
			or int(leaderboard[2].get("self_entry", {}).get("rank", 0)) < 1:
		push_error("Supabase live: Godot get_leaderboard failed: %s" % [leaderboard])
		quit(1)
		return

	var direct_write := await _request_json(HTTPClient.METHOD_POST, "scores", {
			"player_id": test_player_id,
		"player_name": "Forbidden",
		"score": 19999999,
	})
	if bool(direct_write[1]) or int(direct_write[3]) != 401:
		push_error("Supabase live: direct table insert was not rejected: %s" % [direct_write])
		quit(1)
		return

	print("Supabase live: Godot submit/read/RLS checks passed")
	print("SUPABASE_TEST_PLAYER_ID=%s" % test_player_id)
	quit(0)

func _call_rpc(function_name: String, body: Dictionary) -> Array:
	var request_id := str(_client.call("call_rpc", function_name, body))
	return await _await_request(request_id)

func _request_json(method: HTTPClient.Method, endpoint: String, body: Dictionary) -> Array:
	var request_id := str(_client.call("request_json", method, endpoint, body))
	return await _await_request(request_id)

func _await_request(request_id: String) -> Array:
	while true:
		var result: Array = await _client.request_completed
		if str(result[0]) == request_id:
			return result
	return []

func _uuid_v4() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [
		hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4),
		hex.substr(16, 4), hex.substr(20, 12)
	]
