class_name SudokuSolver
extends RefCounted

const SIZE := 81
const FULL_MASK := 0x3FE

var _randomize := false
var _rng := RandomNumberGenerator.new()
var last_search_nodes := 0
var last_max_depth := 0

func solve(board: PackedInt32Array, randomize: bool = false, seed_value: int = 0) -> PackedInt32Array:
	if not is_valid_board(board):
		return PackedInt32Array()
	var work := board.duplicate()
	_randomize = randomize
	_rng.seed = seed_value
	last_search_nodes = 0
	last_max_depth = 0
	if _solve_recursive(work, 0):
		return work
	return PackedInt32Array()

func count_solutions(board: PackedInt32Array, limit: int = 2) -> int:
	if limit < 1 or not is_valid_board(board):
		return 0
	var work := board.duplicate()
	last_search_nodes = 0
	last_max_depth = 0
	return _count_recursive(work, limit, 0)

func is_valid_board(board: PackedInt32Array) -> bool:
	if board.size() != SIZE:
		return false
	var work := board.duplicate()
	for index in SIZE:
		var value := work[index]
		if value < 0 or value > 9:
			return false
		if value != 0:
			work[index] = 0
			var legal := _can_place(work, index, value)
			work[index] = value
			if not legal:
				return false
	return true

func get_candidates(board: PackedInt32Array, index: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	if board.size() != SIZE or index < 0 or index >= SIZE or board[index] != 0:
		return result
	var mask := _candidate_mask(board, index)
	for value in range(1, 10):
		if mask & (1 << value):
			result.append(value)
	return result

func _solve_recursive(board: PackedInt32Array, depth: int) -> bool:
	last_search_nodes += 1
	last_max_depth = maxi(last_max_depth, depth)
	var target := _find_best_empty(board)
	if target == -1:
		return true
	var candidates := get_candidates(board, target)
	if candidates.is_empty():
		return false
	if _randomize:
		_shuffle(candidates)
	for value in candidates:
		board[target] = value
		if _solve_recursive(board, depth + 1):
			return true
		board[target] = 0
	return false

func _count_recursive(board: PackedInt32Array, remaining_limit: int, depth: int) -> int:
	last_search_nodes += 1
	last_max_depth = maxi(last_max_depth, depth)
	var target := _find_best_empty(board)
	if target == -1:
		return 1
	var count := 0
	for value in get_candidates(board, target):
		board[target] = value
		count += _count_recursive(board, remaining_limit - count, depth + 1)
		board[target] = 0
		if count >= remaining_limit:
			break
	return count

func _find_best_empty(board: PackedInt32Array) -> int:
	var best_index := -1
	var best_count := 10
	for index in SIZE:
		if board[index] != 0:
			continue
		var count := _bit_count(_candidate_mask(board, index))
		if count < best_count:
			best_count = count
			best_index = index
			if count <= 1:
				break
	return best_index

func _candidate_mask(board: PackedInt32Array, index: int) -> int:
	var used := 0
	var row := index / 9
	var column := index % 9
	for cursor in 9:
		used |= 1 << board[row * 9 + cursor]
		used |= 1 << board[cursor * 9 + column]
	var box_row := (row / 3) * 3
	var box_column := (column / 3) * 3
	for row_offset in 3:
		for column_offset in 3:
			used |= 1 << board[(box_row + row_offset) * 9 + box_column + column_offset]
	return FULL_MASK & ~used

func _can_place(board: PackedInt32Array, index: int, value: int) -> bool:
	return (_candidate_mask(board, index) & (1 << value)) != 0

func _bit_count(value: int) -> int:
	var count := 0
	while value != 0:
		value &= value - 1
		count += 1
	return count

func _shuffle(values: PackedInt32Array) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, index)
		var temporary := values[index]
		values[index] = values[swap_index]
		values[swap_index] = temporary
