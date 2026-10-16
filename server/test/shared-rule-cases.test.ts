import { describe, expect, it } from "vitest";
import {
	formatBoard,
	formatSquare,
	letterOf,
	parseBoard,
	parseMove,
	parseSetup,
	parseSquare,
} from "../src/rules/board-notation";
import { Game, type MoveAttempt } from "../src/rules/game";
import {
	EXPECTATION_KEYS,
	isSetupCase,
	loadCaseFiles,
	type PlayCase,
	type PlayExpectations,
	type SetupCase,
} from "./rule-case-files";

describe.each(loadCaseFiles())("$fileName", ({ cases }) => {
	it("holds cases", () => {
		expect(cases.length).toBeGreaterThan(0);
	});

	it.each(cases)("$name", (ruleCase) => {
		if (isSetupCase(ruleCase)) {
			checkSetupCase(ruleCase);
		} else {
			checkPlayCase(ruleCase);
		}
	});
});

function checkSetupCase(setupCase: SetupCase): void {
	expect(parseSetup(setupCase.side, setupCase.rows).isValid()).toBe(setupCase.valid);
}

function checkPlayCase(playCase: PlayCase): void {
	expectOnlyKnownExpectations(playCase.expect);
	const game = startGame(playCase);
	const lastAttempt = playAll(game, playCase.moves ?? []);
	checkLegalMoves(game, playCase.expect);
	checkIllegalMoves(game, playCase.expect);
	checkBoard(game, playCase.expect);
	checkFight(lastAttempt, playCase.expect);
	checkResult(game, playCase.expect);
}

/** An expectation this runner does not know would otherwise pass silently. */
function expectOnlyKnownExpectations(expectations: PlayExpectations): void {
	const unknownKeys = Object.keys(expectations).filter(
		(key) => !(EXPECTATION_KEYS as readonly string[]).includes(key),
	);
	expect(unknownKeys, "expectation keys this runner does not check").toEqual([]);
}

function startGame(playCase: PlayCase): Game {
	const board = parseBoard(playCase.board);
	expect(formatBoard(board), "the board should read back").toEqual(playCase.board);
	return new Game({
		board,
		sideToMove: playCase.to_move,
		pliesWithoutFight: playCase.plies_without_fight ?? 0,
	});
}

function playAll(game: Game, moves: readonly string[]): MoveAttempt | undefined {
	let lastAttempt: MoveAttempt | undefined;
	for (const moveText of moves) {
		lastAttempt = game.tryPlay(parseMove(moveText));
		expect(lastAttempt.accepted, `move ${moveText} should be legal`).toBe(true);
	}
	return lastAttempt;
}

function checkLegalMoves(game: Game, expectations: PlayExpectations): void {
	for (const [fromText, expected] of Object.entries(expectations.legal_moves ?? {})) {
		const actual = game.legalDestinations(parseSquare(fromText)).map(formatSquare);
		expect(actual.toSorted(), `legal moves from ${fromText}`).toEqual(expected.toSorted());
	}
}

function checkIllegalMoves(game: Game, expectations: PlayExpectations): void {
	for (const moveText of expectations.illegal_moves ?? []) {
		const before = snapshotOf(game);
		expect(game.tryPlay(parseMove(moveText)).accepted, `${moveText} should be rejected`).toBe(false);
		expect(snapshotOf(game), `rejecting ${moveText} changes nothing`).toEqual(before);
	}
}

function snapshotOf(game: Game): object {
	return {
		board: formatBoard(game.board),
		sideToMove: game.sideToMove,
		pliesWithoutFight: game.pliesWithoutFight,
		result: game.result,
	};
}

function checkBoard(game: Game, expectations: PlayExpectations): void {
	if (expectations.board !== undefined) {
		expect(formatBoard(game.board), "board after the moves").toEqual(expectations.board);
	}
}

function checkFight(lastAttempt: MoveAttempt | undefined, expectations: PlayExpectations): void {
	if (expectations.fight === undefined) {
		return;
	}
	const fight = lastAttempt?.accepted ? lastAttempt.record.fight : undefined;
	expect(fight, "the last move should cause a Fight").toBeDefined();
	expect({
		attacker: fight && letterOf(fight.attacker),
		defender: fight && letterOf(fight.defender),
		outcome: fight?.outcome,
	}).toEqual(expectations.fight);
}

function checkResult(game: Game, expectations: PlayExpectations): void {
	if (expectations.status !== undefined) {
		expect(game.result.status, "status").toBe(expectations.status);
	}
	if (expectations.reason !== undefined) {
		expect(game.result.reason, "reason").toBe(expectations.reason);
	}
}
