export function validCompletedBoard(board: string): boolean {
	const size = board.length === 81 ? 9 : board.length === 256 ? 16 : 0;
	const boxSize = size === 9 ? 3 : size === 16 ? 4 : 0;
	const symbols = size === 9 ? "123456789" : "123456789ABCDEFG";
	if (size === 0 || Array.from(board).some((value) => !symbols.includes(value))) return false;
	for (let unit = 0; unit < size; unit++) {
		if (!validUnit(Array.from({ length: size }, (_, offset) => board[unit * size + offset]), symbols)) return false;
		if (!validUnit(Array.from({ length: size }, (_, offset) => board[offset * size + unit]), symbols)) return false;
		const boxRow = Math.floor(unit / boxSize) * boxSize;
		const boxColumn = (unit % boxSize) * boxSize;
		if (!validUnit(Array.from({ length: size }, (_, offset) => board[(boxRow + Math.floor(offset / boxSize)) * size + boxColumn + offset % boxSize]), symbols)) return false;
	}
	return true;
}

export function respectsClues(puzzle: string, board: string): boolean {
	return puzzle.length === board.length && (puzzle.length === 81 || puzzle.length === 256) &&
		Array.from(puzzle).every((value, index) => value === "0" || value === board[index]);
}

function validUnit(values: string[], symbols: string): boolean {
	return new Set(values).size === symbols.length && values.every((value) => symbols.includes(value));
}
