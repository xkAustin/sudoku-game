class_name GameService
extends Node

const RANKED_SETTING_OVERRIDES := {
	"auto_check": true,
	"auto_clear_notes": false,
	"hide_completed_numbers": false,
	"highlight_same": false,
	"highlight_related": false,
	"show_mistakes": true,
}

signal generation_finished(result: Dictionary)
signal generation_failed(message: String)
signal completed(session: GameSession)
signal failed(session: GameSession)

var session: GameSession
var selected_index := -1
var notes_mode := false
var paused := false
var _generation_thread: Thread
var _generation_difficulty := 0
var _generation_seed := 0

func _process(delta: float) -> void:
	if _generation_thread != null and not _generation_thread.is_alive():
		var result: Dictionary = _generation_thread.wait_to_finish()
		_generation_thread = null
		if result.is_empty():
			generation_failed.emit("puzzle_generation_failed")
		else:
			generation_finished.emit(result)
	if session != null and not paused and not session.completed:
		session.elapsed_ms += int(delta * 1000.0)

func generate_async(difficulty: int, seed_value: int = 0) -> bool:
	if _generation_thread != null:
		return false
	_generation_difficulty = clampi(difficulty, 0, 5)
	_generation_seed = seed_value
	_generation_thread = Thread.new()
	var error := _generation_thread.start(_generate_worker)
	if error != OK:
		_generation_thread = null
		generation_failed.emit("generation_task_failed")
		return false
	return true

func _generate_worker() -> Dictionary:
	if _generation_difficulty == 5:
		return HexadokuGenerator.new().generate(_generation_seed)
	return SudokuGenerator.new().generate(_generation_difficulty, _generation_seed)

func start_session(result: Dictionary) -> void:
	session = GameSession.create(result["puzzle"], result["solution"], int(result["difficulty"]))
	AppState.record_start(session.difficulty)
	AppState.set_session(session)
	selected_index = _first_empty()
	notes_mode = false
	paused = false
	EventBus.session_changed.emit()

func resume_session(saved: GameSession) -> void:
	session = saved
	paused = false
	_apply_background_elapsed()
	AppState.set_session(session)
	selected_index = _first_empty()
	notes_mode = false
	EventBus.session_changed.emit()

func select(index: int) -> void:
	if session != null and index >= 0 and index < session.board.size():
		selected_index = index
		EventBus.session_changed.emit()

func enter_number(value: int) -> void:
	if session == null or paused or selected_index < 0 or session.is_clue(selected_index) or value < 1 or value > session.grid_size:
		return
	if notes_mode:
		_toggle_note(selected_index, value)
	else:
		_set_value(selected_index, value, "input")

func erase() -> void:
	if session == null or paused or selected_index < 0 or session.is_clue(selected_index):
		return
	var record := MoveRecord.new("delete", session.sequence + 1)
	record.add_change(selected_index, session.board[selected_index], 0, session.notes[selected_index], 0)
	_apply_new_record(record)

func hint() -> void:
	if session == null or paused or session.mode == "ranked":
		return
	var target := selected_index
	if target < 0 or session.is_clue(target) or session.board[target] == session.solution[target]:
		target = _first_empty()
	if target >= 0:
		session.hints_used += 1
		_set_value(target, session.solution[target], "hint")

func undo() -> void:
	if session == null or session.undo_stack.is_empty() or paused:
		return
	var record: MoveRecord = session.undo_stack.pop_back()
	for change in record.changes:
		var index := int(change["cell_index"])
		session.board[index] = int(change["old_value"])
		session.notes[index] = int(change["old_notes"])
	session.redo_stack.append(record)
	session.operation_count += 1
	FeedbackManager.input_feedback()
	_state_changed()

func redo() -> void:
	if session == null or session.redo_stack.is_empty() or paused:
		return
	var record: MoveRecord = session.redo_stack.pop_back()
	for change in record.changes:
		var index := int(change["cell_index"])
		session.board[index] = int(change["new_value"])
		session.notes[index] = int(change["new_notes"])
	session.undo_stack.append(record)
	session.operation_count += 1
	FeedbackManager.input_feedback()
	_state_changed()

func move_selection(row_delta: int, column_delta: int) -> void:
	if selected_index < 0:
		selected_index = 0
	else:
		var row := clampi(selected_index / session.grid_size + row_delta, 0, session.grid_size - 1)
		var column := clampi(selected_index % session.grid_size + column_delta, 0, session.grid_size - 1)
		selected_index = row * session.grid_size + column
	EventBus.session_changed.emit()

func set_paused(value: bool) -> void:
	paused = value
	if paused and session != null:
		session.backgrounded_at_unix_ms = 0
	AppState.save_session_now()
	EventBus.session_changed.emit()

func _notification(what: int) -> void:
	if session == null or session.completed:
		return
	if what == NOTIFICATION_APPLICATION_PAUSED:
		if session.mode == "ranked" and not paused:
			session.backgrounded_at_unix_ms = _unix_time_ms()
		else:
			session.backgrounded_at_unix_ms = 0
		AppState.save_session_now()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_apply_background_elapsed()
		AppState.save_session_now()

func effective_setting(key: String, default_value: bool = true) -> bool:
	if session != null and session.mode == "ranked" and RANKED_SETTING_OVERRIDES.has(key):
		return bool(RANKED_SETTING_OVERRIDES[key])
	return bool(AppState.settings.get(key, default_value))

func _set_value(index: int, value: int, move_type: String) -> void:
	var record := MoveRecord.new(move_type, session.sequence + 1)
	record.add_change(index, session.board[index], value, session.notes[index], 0)
	if effective_setting("auto_clear_notes", true):
		var bit := 1 << value
		for peer in _peers(index):
			if session.notes[peer] & bit:
				record.add_change(peer, session.board[peer], session.board[peer], session.notes[peer], session.notes[peer] & ~bit)
	var is_mistake := effective_setting("auto_check", true) and value != session.solution[index]
	if is_mistake:
		session.mistakes += 1
	_apply_new_record(record, is_mistake)

func _toggle_note(index: int, value: int) -> void:
	if session.board[index] != 0:
		return
	var old_notes := session.notes[index]
	var new_notes := old_notes ^ (1 << value)
	var record := MoveRecord.new("note", session.sequence + 1)
	record.add_change(index, 0, 0, old_notes, new_notes)
	_apply_new_record(record)

func _apply_new_record(record: MoveRecord, error_feedback: bool = false) -> void:
	for change in record.changes:
		var index := int(change["cell_index"])
		session.board[index] = int(change["new_value"])
		session.notes[index] = int(change["new_notes"])
	session.sequence = record.sequence_number
	session.operation_count += 1
	session.undo_stack.append(record)
	session.redo_stack.clear()
	if error_feedback:
		FeedbackManager.error_feedback()
	else:
		FeedbackManager.input_feedback()
	_state_changed()
	if session.mode == "ranked" and session.mistakes >= 3:
		session.completed = true
		paused = false
		AppState.record_failure()
		AppState.clear_session(session.mode, session.difficulty)
		failed.emit(session)
		return
	if session.board == session.solution:
		session.completed = true
		FeedbackManager.completion_feedback()
		session.new_best = AppState.record_completion(session)
		AppState.clear_session(session.mode, session.difficulty)
		completed.emit(session)

func _state_changed() -> void:
	AppState.request_save()
	EventBus.session_changed.emit()

func _apply_background_elapsed(now_ms: int = 0) -> void:
	if session == null or session.backgrounded_at_unix_ms <= 0:
		return
	var current_ms := now_ms if now_ms > 0 else _unix_time_ms()
	if session.mode == "ranked" and not paused and current_ms > session.backgrounded_at_unix_ms:
		session.elapsed_ms += current_ms - session.backgrounded_at_unix_ms
	session.backgrounded_at_unix_ms = 0
	EventBus.session_changed.emit()

func _unix_time_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)

func _first_empty() -> int:
	if session == null:
		return -1
	for index in session.board.size():
		if session.board[index] == 0:
			return index
	return -1

func _peers(index: int) -> PackedInt32Array:
	var seen: Dictionary = {}
	var grid_size := session.grid_size
	var box_size := session.box_size
	var row := index / grid_size
	var column := index % grid_size
	for offset in grid_size:
		seen[row * grid_size + offset] = true
		seen[offset * grid_size + column] = true
	var start_row := (row / box_size) * box_size
	var start_column := (column / box_size) * box_size
	for row_offset in box_size:
		for column_offset in box_size:
			seen[(start_row + row_offset) * grid_size + start_column + column_offset] = true
	seen.erase(index)
	var result := PackedInt32Array()
	for peer in seen:
		result.append(int(peer))
	return result
