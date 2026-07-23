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
	_test_hexadoku()
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

func _assert(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
