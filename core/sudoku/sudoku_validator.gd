class_name SudokuValidator
extends RefCounted

static func string_to_board(value: String) -> PackedInt32Array:
	var board := PackedInt32Array()
	if value.length() not in [81, 256]:
		return board
	for character in value:
		if character >= "0" and character <= "9":
			board.append(character.to_int())
		elif value.length() == 256 and character >= "A" and character <= "G":
			board.append(character.unicode_at(0) - 55)
		else:
			return PackedInt32Array()
	return board

static func board_to_string(board: PackedInt32Array) -> String:
	if board.size() not in [81, 256]:
		return ""
	var output := ""
	for value in board:
		if value < 0 or value > (16 if board.size() == 256 else 9):
			return ""
		output += str(value) if value <= 9 else char(55 + value)
	return output

static func is_complete(board: PackedInt32Array) -> bool:
	if board.size() not in [81, 256] or board.has(0):
		return false
	return SudokuSolver.new().is_valid_board(board) if board.size() == 81 else GridSolver.new(16, 4).is_valid_board(board)

static func conflicts(board: PackedInt32Array) -> PackedInt32Array:
	var result := PackedInt32Array()
	if board.size() != 81:
		return result
	for index in 81:
		var value := board[index]
		if value == 0:
			continue
		var copy := board.duplicate()
		copy[index] = 0
		if not copy[index] == value and not SudokuSolver.new().get_candidates(copy, index).has(value):
			result.append(index)
	return result

static func respects_clues(puzzle: PackedInt32Array, final_board: PackedInt32Array) -> bool:
	if puzzle.size() not in [81, 256] or final_board.size() != puzzle.size():
		return false
	for index in puzzle.size():
		if puzzle[index] != 0 and puzzle[index] != final_board[index]:
			return false
	return true
