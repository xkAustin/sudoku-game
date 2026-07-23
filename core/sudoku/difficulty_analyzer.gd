class_name DifficultyAnalyzer
extends RefCounted

const NAMES := ["入门", "简单", "中等", "困难", "专家"]
const THRESHOLDS := [85, 130, 220, 620]

func analyze(input_board: PackedInt32Array) -> Dictionary:
	if not SudokuSolver.new().is_valid_board(input_board):
		return {"valid": false, "level": -1, "score": -1}
	var board := input_board.duplicate()
	var naked_singles := 0
	var hidden_singles := 0
	var rounds := 0
	var max_candidates := 0
	while board.has(0):
		rounds += 1
		var progress := false
		for index in 81:
			if board[index] != 0:
				continue
			var candidates := SudokuSolver.new().get_candidates(board, index)
			max_candidates = maxi(max_candidates, candidates.size())
			if candidates.size() == 1:
				board[index] = candidates[0]
				naked_singles += 1
				progress = true
		if progress:
			continue
		var hidden := _find_hidden_single(board)
		if hidden.size() == 2:
			board[hidden[0]] = hidden[1]
			hidden_singles += 1
			continue
		break
	var solver := SudokuSolver.new()
	var solved := solver.solve(board)
	if solved.is_empty():
		return {"valid": false, "level": -1, "score": -1}
	var unresolved := 0
	for value in board:
		if value == 0:
			unresolved += 1
	# Weighted logic plus measured search complexity; clue count is deliberately absent.
	var score := naked_singles + hidden_singles * 3 + rounds * 4 + max_candidates * 7
	score += unresolved * 5 + solver.last_search_nodes * 2 + solver.last_max_depth * 8
	var level := 0
	while level < THRESHOLDS.size() and score >= THRESHOLDS[level]:
		level += 1
	return {
		"valid": true, "level": level, "name": NAMES[level], "score": score,
		"steps": naked_singles + hidden_singles, "naked_singles": naked_singles,
		"hidden_singles": hidden_singles, "max_candidates": max_candidates,
		"search_nodes": solver.last_search_nodes, "max_backtrack_depth": solver.last_max_depth
	}

func _find_hidden_single(board: PackedInt32Array) -> PackedInt32Array:
	for unit_type in 3:
		for unit in 9:
			var positions: Array[Array] = []
			positions.resize(10)
			for value in range(1, 10):
				positions[value] = []
			for offset in 9:
				var index := _unit_index(unit_type, unit, offset)
				if board[index] == 0:
					for candidate in SudokuSolver.new().get_candidates(board, index):
						positions[candidate].append(index)
			for value in range(1, 10):
				if positions[value].size() == 1:
					return PackedInt32Array([positions[value][0], value])
	return PackedInt32Array()

func _unit_index(unit_type: int, unit: int, offset: int) -> int:
	if unit_type == 0:
		return unit * 9 + offset
	if unit_type == 1:
		return offset * 9 + unit
	return ((unit / 3) * 3 + offset / 3) * 9 + (unit % 3) * 3 + offset % 3
