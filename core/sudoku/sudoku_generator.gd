class_name SudokuGenerator
extends RefCounted

const TARGET_REMOVALS := [36, 46, 48, 52, 56]
const MAX_ATTEMPTS := 6
const FALLBACKS := [
	"000260701680070090190004500820100040004602900050003028009300074040050036703018000",
	"530070000600195000098000060800060003400803001700020006060000280000419005000080079",
	"300000000005009000200504000020000700160000058704310600000890100000067080000005437",
	"000000907000420180000705026100904000050000040000507009920108000034059000507000000",
	"005300000800000020070010500400005300010070006003200080060500009004000030000009700"
]

func generate(difficulty: int, seed_value: int = 0, timeout_ms: int = 4500) -> Dictionary:
	difficulty = clampi(difficulty, 0, 4)
	var started := Time.get_ticks_msec()
	var base_seed := seed_value if seed_value != 0 else int(Time.get_unix_time_from_system() * 1000.0)
	for attempt in MAX_ATTEMPTS:
		if Time.get_ticks_msec() - started > timeout_ms:
			break
		var solver := SudokuSolver.new()
		var empty := PackedInt32Array()
		empty.resize(81)
		empty.fill(0)
		var solution := solver.solve(empty, true, base_seed + attempt * 7919)
		if solution.is_empty():
			continue
		var puzzle := _remove_values(solution, TARGET_REMOVALS[difficulty], base_seed + attempt * 104729, started, timeout_ms)
		if SudokuSolver.new().count_solutions(puzzle, 2) == 1:
			var candidate := _result(puzzle, solution, difficulty, base_seed, false)
			if int(candidate["analysis"].get("level", -1)) == difficulty:
				return candidate
	var fallback := SudokuValidator.string_to_board(FALLBACKS[difficulty])
	var fallback_solution := SudokuSolver.new().solve(fallback)
	return _result(fallback, fallback_solution, difficulty, base_seed, true)

func _remove_values(solution: PackedInt32Array, target: int, seed_value: int, started: int, timeout_ms: int) -> PackedInt32Array:
	var puzzle := solution.duplicate()
	var indices := PackedInt32Array()
	for index in 81:
		indices.append(index)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for cursor in range(indices.size() - 1, 0, -1):
		var other := rng.randi_range(0, cursor)
		var temporary := indices[cursor]
		indices[cursor] = indices[other]
		indices[other] = temporary
	var removed := 0
	for index in indices:
		if removed >= target or Time.get_ticks_msec() - started > timeout_ms:
			break
		var old_value := puzzle[index]
		puzzle[index] = 0
		if SudokuSolver.new().count_solutions(puzzle, 2) == 1:
			removed += 1
		else:
			puzzle[index] = old_value
	return puzzle

func _result(puzzle: PackedInt32Array, solution: PackedInt32Array, requested: int, seed_value: int, fallback: bool) -> Dictionary:
	return {
		"puzzle": puzzle, "solution": solution, "difficulty": requested,
		"analysis": DifficultyAnalyzer.new().analyze(puzzle), "seed": seed_value,
		"algorithm_version": AppConfig.ALGORITHM_VERSION, "fallback": fallback
	}
