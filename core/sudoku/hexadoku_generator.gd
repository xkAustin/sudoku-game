class_name HexadokuGenerator
extends RefCounted

const SIZE := 16
const BOX := 4

func generate(seed_value: int = 0) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	var solution := _make_solution(rng)
	var puzzle := solution.duplicate()
	var order: Array[int] = []
	for index in SIZE * SIZE / 2:
		order.append(index)
	_shuffle(order, rng)
	var removed := 0
	var solver := GridSolver.new(SIZE, BOX)
	for index in order:
		if removed >= 128:
			break
		var mirror := SIZE * SIZE - 1 - index
		var first := puzzle[index]
		var second := puzzle[mirror]
		puzzle[index] = 0
		puzzle[mirror] = 0
		if solver.count_solutions(puzzle, 2) == 1:
			removed += 2
		else:
			puzzle[index] = first
			puzzle[mirror] = second
	return {"puzzle": puzzle, "solution": solution, "difficulty": 5, "grid_size": SIZE, "box_size": BOX}

func _make_solution(rng: RandomNumberGenerator) -> PackedInt32Array:
	var bands := [0, 1, 2, 3]
	var stacks := [0, 1, 2, 3]
	_shuffle(bands, rng)
	_shuffle(stacks, rng)
	var rows: Array[int] = []
	var columns: Array[int] = []
	for band in bands:
		var within := [0, 1, 2, 3]
		_shuffle(within, rng)
		for offset in within:
			rows.append(band * BOX + offset)
	for stack in stacks:
		var within := [0, 1, 2, 3]
		_shuffle(within, rng)
		for offset in within:
			columns.append(stack * BOX + offset)
	var symbols: Array[int] = []
	for value in range(1, SIZE + 1):
		symbols.append(value)
	_shuffle(symbols, rng)
	var board := PackedInt32Array()
	board.resize(SIZE * SIZE)
	for visual_row in SIZE:
		for visual_column in SIZE:
			var pattern := (rows[visual_row] * BOX + rows[visual_row] / BOX + columns[visual_column]) % SIZE
			board[visual_row * SIZE + visual_column] = symbols[pattern]
	return board

func _shuffle(values: Array, rng: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var target := rng.randi_range(0, index)
		var temp: Variant = values[index]
		values[index] = values[target]
		values[target] = temp
