import { respectsClues, validCompletedBoard } from "../functions/_shared/sudoku.ts";

function assertEquals(actual: unknown, expected: unknown): void {
  if (actual !== expected) throw new Error(`Expected ${expected}, received ${actual}`);
}

const puzzle = "530070000600195000098000060800060003400803001700020006060000280000419005000080079";
const solution = "534678912672195348198342567859761423426853791713924856961537284287419635345286179";

Deno.test("accepts the valid solution", () => {
  assertEquals(validCompletedBoard(solution), true);
  assertEquals(respectsClues(puzzle, solution), true);
});

Deno.test("rejects duplicate values and changed clues", () => {
  assertEquals(validCompletedBoard(`5${solution.slice(0, 80)}`), false);
  assertEquals(respectsClues(puzzle, `1${solution.slice(1)}`), false);
});
