extends SceneTree

var failures := 0
var assertions := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_solver()
	_test_validator()
	_test_generator()
	_test_session_roundtrip()
	_test_save_manager_recovery()
	_test_background_timing()
	_test_hexadoku()
	_test_online_leaderboard()
	print("GDScript tests: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures > 0 else 0)

func _test_solver() -> void:
	var puzzle := SudokuValidator.string_to_board("530070000600195000098000060800060003400803001700020006060000280000419005000080079")
	var expected := "534678912672195348198342567859761423426853791713924856961537284287419635345286179"
	var copy := puzzle.duplicate()
	var solver := SudokuSolver.new()
	_assert(SudokuValidator.board_to_string(solver.solve(puzzle)) == expected, "known puzzle solves")
	_assert(puzzle == copy, "solver does not mutate input")
	_assert(solver.count_solutions(puzzle, 2) == 1, "known puzzle is unique")
	var completed := SudokuValidator.string_to_board(expected)
	_assert(solver.solve(completed) == completed, "completed board remains complete")
	var invalid := puzzle.duplicate()
	invalid[1] = 5
	_assert(not solver.is_valid_board(invalid), "row conflict rejected")
	invalid = puzzle.duplicate()
	invalid[18] = 5
	_assert(not solver.is_valid_board(invalid), "column conflict rejected")
	invalid = puzzle.duplicate()
	invalid[10] = 5
	_assert(not solver.is_valid_board(invalid), "box conflict rejected")
	_assert(not solver.is_valid_board(PackedInt32Array([1, 2, 3])), "wrong length rejected")
	var empty := PackedInt32Array()
	empty.resize(81)
	empty.fill(0)
	_assert(solver.count_solutions(empty, 2) == 2, "multiple solution count stops at limit")

func _test_validator() -> void:
	var board := SudokuValidator.string_to_board("534678912672195348198342567859761423426853791713924856961537284287419635345286179")
	_assert(SudokuValidator.is_complete(board), "complete valid board accepted")
	board[0] = 0
	_assert(not SudokuValidator.is_complete(board), "incomplete board rejected")
	_assert(SudokuValidator.string_to_board("bad").is_empty(), "bad board string rejected")

func _test_generator() -> void:
	var generator := SudokuGenerator.new()
	if OS.get_environment("SUDOKU_INSPECT") == "1":
		for fallback_index in SudokuGenerator.FALLBACKS.size():
			var fallback_board := SudokuValidator.string_to_board(SudokuGenerator.FALLBACKS[fallback_index])
			print("fallback %d analysis: %s" % [fallback_index, DifficultyAnalyzer.new().analyze(fallback_board)])
	var signatures: Dictionary = {}
	var stress_count := 100 if OS.get_environment("SUDOKU_STRESS") == "1" else 2
	for difficulty in 5:
		for sample in stress_count:
			var result := generator.generate(difficulty, 100000 + difficulty * 1000 + sample, 8000)
			if OS.get_environment("SUDOKU_INSPECT") == "1" and sample == 0:
				print("difficulty %d analysis: %s" % [difficulty, result["analysis"]])
			var puzzle: PackedInt32Array = result["puzzle"]
			_assert(puzzle.size() == 81, "generated board has 81 cells")
			_assert(SudokuSolver.new().is_valid_board(puzzle), "generated puzzle is legal")
			_assert(SudokuSolver.new().count_solutions(puzzle, 2) == 1, "generated puzzle is unique")
			_assert(int(result["analysis"].get("level", -1)) == difficulty, "generated puzzle matches requested difficulty")
			signatures[SudokuValidator.board_to_string(puzzle)] = true
	_assert(signatures.size() >= 5, "generation produces variety")

func _test_session_roundtrip() -> void:
	var puzzle := SudokuValidator.string_to_board("530070000600195000098000060800060003400803001700020006060000280000419005000080079")
	var solution := SudokuSolver.new().solve(puzzle)
	var session := GameSession.create(puzzle, solution, 1)
	var record := MoveRecord.new("input", 1)
	record.add_change(2, 0, 4, 0, 0)
	session.undo_stack.append(record)
	session.board[2] = 4
	session.operation_count = 3
	session.offline_ranked = true
	var restored := GameSession.from_dict(session.to_dict())
	_assert(restored != null and restored.board == session.board, "session board round trip")
	_assert(restored.undo_stack.size() == 1, "undo stack round trip")
	_assert(restored.operation_count == 3 and restored.offline_ranked, "session operation count and offline ranked state round trip")

func _test_save_manager_recovery() -> void:
	var save_manager := root.get_node("SaveManager")
	var file_name := "test-save-manager-%d.json" % Time.get_ticks_usec()
	var path := "user://" + file_name
	save_manager.remove_json(file_name)
	_assert(save_manager.write_json(file_name, {"revision": 1}), "save manager writes initial JSON")
	_assert(save_manager.write_json(file_name, {"revision": 2}), "save manager rotates a previous JSON backup")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var backup_recovery: Dictionary = save_manager.read_json(file_name, {})
	_assert(int(backup_recovery.get("revision", 0)) == 1, "save manager restores a valid backup when the main file is missing")
	_assert(FileAccess.file_exists(path), "backup recovery promotes a new main file")
	save_manager.remove_json(file_name)
	var temporary := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	temporary.store_string(JSON.stringify({"revision": 3}))
	temporary.close()
	var temporary_recovery: Dictionary = save_manager.read_json(file_name, {})
	_assert(int(temporary_recovery.get("revision", 0)) == 3, "save manager restores a valid temporary file")
	_assert(FileAccess.file_exists(path), "temporary recovery promotes a new main file")
	save_manager.remove_json(file_name)
	_assert(save_manager.write_json(file_name, {"revision": 4}), "save manager prepares a corruption recovery baseline")
	_assert(save_manager.write_json(file_name, {"revision": 5}), "save manager preserves a backup before corruption")
	var corrupt_main := FileAccess.open(path, FileAccess.WRITE)
	corrupt_main.store_string("{not valid json")
	corrupt_main.close()
	var corrupt_recovery: Dictionary = save_manager.read_json(file_name, {})
	_assert(int(corrupt_recovery.get("revision", 0)) == 4, "save manager restores the backup when the main JSON is corrupt")
	save_manager.remove_json(file_name)

func _test_background_timing() -> void:
	var puzzle := SudokuValidator.string_to_board("530070000600195000098000060800060003400803001700020006060000280000419005000080079")
	var solution := SudokuSolver.new().solve(puzzle)
	var service: Node = load("res://core/services/game_service.gd").new()
	service.session = GameSession.create(puzzle, solution, 1, "ranked")
	service.session.elapsed_ms = 500
	service.session.backgrounded_at_unix_ms = 1000
	service._apply_background_elapsed(2500)
	_assert(service.session.elapsed_ms == 2000, "ranked background time is added after resume")
	_assert(service.session.backgrounded_at_unix_ms == 0, "ranked background marker is cleared after resume")
	service.session.mode = "local"
	service.session.elapsed_ms = 500
	service.session.backgrounded_at_unix_ms = 1000
	service._apply_background_elapsed(2500)
	_assert(service.session.elapsed_ms == 500, "local games do not count background time")
	service.free()

func _test_hexadoku() -> void:
	var result := HexadokuGenerator.new().generate(160016)
	var puzzle: PackedInt32Array = result["puzzle"]
	var solution: PackedInt32Array = result["solution"]
	var solver := GridSolver.new(16, 4)
	_assert(puzzle.size() == 256, "hexadoku puzzle has 256 cells")
	_assert(solution.size() == 256 and solver.is_valid_board(solution), "hexadoku solution is legal")
	_assert(solver.count_solutions(puzzle, 2) == 1, "hexadoku puzzle is unique")
	_assert(solver.solve(puzzle) == solution, "hexadoku puzzle solves to generated solution")
	var session := GameSession.create(puzzle, solution, 5)
	session.notes[0] = 1 << 16
	var restored := GameSession.from_dict(session.to_dict())
	_assert(restored != null and restored.grid_size == 16 and restored.box_size == 4, "hexadoku session retains dimensions")
	_assert(restored != null and restored.board == puzzle and restored.notes[0] == 1 << 16, "hexadoku session round trip")
	var encoded := SudokuValidator.board_to_string(solution)
	_assert(encoded.length() == 256 and encoded.contains("A") and encoded.contains("G"), "hexadoku serializes with single-character symbols")
	_assert(SudokuValidator.string_to_board(encoded) == solution, "hexadoku string round trip")
	_assert(SudokuValidator.is_complete(solution), "hexadoku completed board validates")
	_assert(SudokuValidator.respects_clues(puzzle, solution), "hexadoku solution respects clues")

func _test_online_leaderboard() -> void:
	var baseline := {
		"difficulty": 2,
		"duration_ms": 180000,
		"mistakes": 1,
		"hints_used": 0,
		"move_count": 90,
	}
	var baseline_score := OnlineLeaderboard.score_from_submission(baseline)
	var faster := baseline.duplicate()
	faster["duration_ms"] = 120000
	var cleaner := baseline.duplicate()
	cleaner["mistakes"] = 0
	var harder := baseline.duplicate()
	harder["difficulty"] = 3
	_assert(OnlineLeaderboard.score_from_submission(faster) > baseline_score, "faster ranked completion earns more leaderboard points")
	_assert(OnlineLeaderboard.score_from_submission(cleaner) > baseline_score, "fewer mistakes earn more leaderboard points")
	_assert(OnlineLeaderboard.score_from_submission(harder) > baseline_score, "higher difficulty earns a larger leaderboard base")
	var snapshot := OnlineLeaderboard.normalize_snapshot({
		"entries": [{"rank": 1, "player_name": "Player One", "score": 2500000, "created_at": "2026-07-23T00:00:00Z"}],
		"self_entry": {"rank": 4, "display_name": "Player", "score": 2100000},
	})
	_assert(snapshot.get("entries", []).size() == 1 and int(snapshot["entries"][0].get("score", 0)) == 2500000, "Data API leaderboard rows normalize")
	_assert(int(snapshot.get("self_entry", {}).get("rank", 0)) == 4, "Data API snapshot preserves the player's global rank")
	var app_config: Variant = load("res://config/app_config.gd").new()
	app_config.supabase_url = "https://example.supabase.co/rest/v1/"
	_assert(app_config.supabase_project_url() == "https://example.supabase.co", "Data API URL normalizes to the project root")
	_assert(app_config.supabase_rest_url() == "https://example.supabase.co/rest/v1", "Data API URL restores the REST endpoint")
	app_config.free()

func _assert(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
