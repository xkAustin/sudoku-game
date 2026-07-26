class_name GameSession
extends RefCounted

const DATA_VERSION := 4

var puzzle := PackedInt32Array()
var solution := PackedInt32Array()
var board := PackedInt32Array()
var notes := PackedInt32Array()
var difficulty := 0
var mode := "local"
var elapsed_ms := 0
var mistakes := 0
var hints_used := 0
var started_at := ""
var last_saved_at := ""
var backgrounded_at_unix_ms := 0
var challenge_id := ""
var challenge_token := ""
var sequence := 0
var operation_count := 0
var offline_ranked := false
var undo_stack: Array[MoveRecord] = []
var redo_stack: Array[MoveRecord] = []
var completed := false
var new_best := false
var grid_size := 9
var box_size := 3

static func create(puzzle_data: PackedInt32Array, solution_data: PackedInt32Array, level: int, game_mode: String = "local") -> GameSession:
	var session := GameSession.new()
	session.puzzle = puzzle_data.duplicate()
	session.solution = solution_data.duplicate()
	session.board = puzzle_data.duplicate()
	session.grid_size = 16 if puzzle_data.size() == 256 else 9
	session.box_size = 4 if session.grid_size == 16 else 3
	session.notes.resize(puzzle_data.size())
	session.notes.fill(0)
	session.difficulty = level
	session.mode = game_mode
	session.started_at = Time.get_datetime_string_from_system(true)
	return session

func is_clue(index: int) -> bool:
	return index >= 0 and index < puzzle.size() and puzzle[index] != 0

func to_dict() -> Dictionary:
	var undo_data: Array[Dictionary] = []
	var redo_data: Array[Dictionary] = []
	for record in undo_stack:
		undo_data.append(record.to_dict())
	for record in redo_stack:
		redo_data.append(record.to_dict())
	return {
		"data_version": DATA_VERSION, "puzzle": Array(puzzle),
		"solution": Array(solution), "board": Array(board), "grid_size": grid_size, "box_size": box_size,
		"notes": Array(notes), "difficulty": difficulty, "mode": mode, "elapsed_ms": elapsed_ms,
		"mistakes": mistakes, "hints_used": hints_used, "started_at": started_at,
		"last_saved_at": Time.get_datetime_string_from_system(true),
		"backgrounded_at_unix_ms": backgrounded_at_unix_ms, "challenge_id": challenge_id,
		"challenge_token": challenge_token, "sequence": sequence, "operation_count": operation_count,
		"offline_ranked": offline_ranked, "undo_stack": undo_data,
		"redo_stack": redo_data, "completed": completed, "client_version": AppConfig.APP_VERSION
	}

static func from_dict(data: Dictionary) -> GameSession:
	var session := GameSession.new()
	session.puzzle = _read_board(data.get("puzzle", ""))
	session.solution = _read_board(data.get("solution", ""))
	session.board = _read_board(data.get("board", ""))
	if session.puzzle.size() not in [81, 256] or session.solution.size() != session.puzzle.size() or session.board.size() != session.puzzle.size():
		return null
	session.grid_size = 16 if session.puzzle.size() == 256 else 9
	session.box_size = 4 if session.grid_size == 16 else 3
	session.notes.resize(session.puzzle.size())
	var saved_notes: Array = data.get("notes", [])
	for index in session.notes.size():
		session.notes[index] = int(saved_notes[index]) if index < saved_notes.size() else 0
	session.difficulty = clampi(int(data.get("difficulty", 0)), 0, 5)
	session.mode = str(data.get("mode", "local"))
	session.elapsed_ms = maxi(0, int(data.get("elapsed_ms", 0)))
	session.mistakes = maxi(0, int(data.get("mistakes", 0)))
	session.hints_used = maxi(0, int(data.get("hints_used", 0)))
	session.started_at = str(data.get("started_at", ""))
	session.last_saved_at = str(data.get("last_saved_at", ""))
	session.backgrounded_at_unix_ms = maxi(0, int(data.get("backgrounded_at_unix_ms", 0)))
	session.challenge_id = str(data.get("challenge_id", ""))
	session.challenge_token = str(data.get("challenge_token", ""))
	session.sequence = int(data.get("sequence", 0))
	session.operation_count = maxi(0, int(data.get("operation_count", session.sequence)))
	session.offline_ranked = bool(data.get("offline_ranked", false))
	session.completed = bool(data.get("completed", false))
	for record in data.get("undo_stack", []):
		session.undo_stack.append(MoveRecord.from_dict(record))
	for record in data.get("redo_stack", []):
		session.redo_stack.append(MoveRecord.from_dict(record))
	return session

static func _read_board(value: Variant) -> PackedInt32Array:
	if value is String:
		return SudokuValidator.string_to_board(value)
	if value is Array:
		var result := PackedInt32Array()
		for item in value:
			result.append(int(item))
		return result
	return PackedInt32Array()
