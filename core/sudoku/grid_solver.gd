class_name GridSolver
extends RefCounted

var grid_size: int
var box_size: int
var _full_mask: int

func _init(size_value: int = 16, box_value: int = 4) -> void:
	grid_size = size_value
	box_size = box_value
	_full_mask = (1 << (grid_size + 1)) - 2

func solve(input: PackedInt32Array) -> PackedInt32Array:
	if not is_valid_board(input):
		return PackedInt32Array()
	var board := input.duplicate()
	if _solve_recursive(board):
		return board
	return PackedInt32Array()

func count_solutions(input: PackedInt32Array, limit: int = 2) -> int:
	if limit <= 0 or not is_valid_board(input):
		return 0
	return _count_recursive(input.duplicate(), limit)

func is_valid_board(board: PackedInt32Array) -> bool:
	if board.size() != grid_size * grid_size:
		return false
	for index in board.size():
		var value := board[index]
		if value < 0 or value > grid_size:
			return false
		if value != 0 and not _can_place(board, index, value, true):
			return false
	return true

func conflicts(board: PackedInt32Array) -> Dictionary:
	var result: Dictionary = {}
	if board.size() != grid_size * grid_size:
		return result
	for index in board.size():
		var value := board[index]
		if value != 0 and not _can_place(board, index, value, true):
			result[index] = true
	return result

func _solve_recursive(board: PackedInt32Array) -> bool:
	var choice := _best_empty(board)
	if choice.x < 0:
		return true
	var index := int(choice.x)
	var mask := int(choice.y)
	while mask != 0:
		var bit := mask & -mask
		var value := _bit_to_value(bit)
		board[index] = value
		if _solve_recursive(board):
			return true
		board[index] = 0
		mask &= ~bit
	return false

func _count_recursive(board: PackedInt32Array, limit: int) -> int:
	var choice := _best_empty(board)
	if choice.x < 0:
		return 1
	var total := 0
	var index := int(choice.x)
	var mask := int(choice.y)
	while mask != 0 and total < limit:
		var bit := mask & -mask
		board[index] = _bit_to_value(bit)
		total += _count_recursive(board, limit - total)
		board[index] = 0
		mask &= ~bit
	return total

func _best_empty(board: PackedInt32Array) -> Vector2i:
	var best_index := -1
	var best_mask := 0
	var best_count := grid_size + 1
	for index in board.size():
		if board[index] != 0:
			continue
		var mask := _candidate_mask(board, index)
		var count := _bit_count(mask)
		if count == 0:
			return Vector2i(index, 0)
		if count < best_count:
			best_index = index
			best_mask = mask
			best_count = count
			if count == 1:
				break
	return Vector2i(best_index, best_mask)

func _candidate_mask(board: PackedInt32Array, index: int) -> int:
	var used := 0
	var row := index / grid_size
	var column := index % grid_size
	for offset in grid_size:
		used |= 1 << board[row * grid_size + offset]
		used |= 1 << board[offset * grid_size + column]
	var start_row := (row / box_size) * box_size
	var start_column := (column / box_size) * box_size
	for row_offset in box_size:
		for column_offset in box_size:
			used |= 1 << board[(start_row + row_offset) * grid_size + start_column + column_offset]
	return _full_mask & ~used

func _can_place(board: PackedInt32Array, index: int, value: int, ignore_self: bool) -> bool:
	var row := index / grid_size
	var column := index % grid_size
	for offset in grid_size:
		var row_index := row * grid_size + offset
		var column_index := offset * grid_size + column
		if (not ignore_self or row_index != index) and board[row_index] == value:
			return false
		if (not ignore_self or column_index != index) and board[column_index] == value:
			return false
	var start_row := (row / box_size) * box_size
	var start_column := (column / box_size) * box_size
	for row_offset in box_size:
		for column_offset in box_size:
			var peer := (start_row + row_offset) * grid_size + start_column + column_offset
			if (not ignore_self or peer != index) and board[peer] == value:
				return false
	return true

func _bit_count(value: int) -> int:
	var count := 0
	while value != 0:
		value &= value - 1
		count += 1
	return count

func _bit_to_value(bit: int) -> int:
	var value := 0
	while bit > 1:
		bit >>= 1
		value += 1
	return value
