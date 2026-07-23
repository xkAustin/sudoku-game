class_name UniquenessChecker
extends RefCounted

static func has_unique_solution(board: PackedInt32Array) -> bool:
	return SudokuSolver.new().count_solutions(board, 2) == 1
