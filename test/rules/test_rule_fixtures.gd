extends GutTest
## Runs the shared, language-neutral rule cases of res://spec/rules/ against
## the GDScript rules engine. See spec/rules/README.md for the format.

const SPEC_DIRECTORY: String = "res://spec/rules/"
const STATUS_NAMES: Dictionary[GameResult.Status, String] = {
	GameResult.Status.IN_PROGRESS: "in_progress",
	GameResult.Status.RED_WINS: "red_wins",
	GameResult.Status.GREEN_WINS: "green_wins",
	GameResult.Status.DRAW: "draw",
}
const REASON_NAMES: Dictionary[GameResult.Reason, String] = {
	GameResult.Reason.NONE: "none",
	GameResult.Reason.PRINCESS_CAPTURED: "princess_captured",
	GameResult.Reason.PRINCESS_REACHED_HOME_ROW: "princess_reached_home_row",
	GameResult.Reason.BLOCKED: "blocked",
	GameResult.Reason.NO_FIGHT_LIMIT: "no_fight_limit",
}
const OUTCOME_NAMES: Dictionary[FightOutcome.Id, String] = {
	FightOutcome.Id.ATTACKER_WINS: "attacker_wins",
	FightOutcome.Id.DEFENDER_WINS: "defender_wins",
	FightOutcome.Id.BOTH_ELIMINATED: "both_eliminated",
}


func test_movement_cases() -> void:
	_run_play_cases("movement.json")


func test_fight_cases() -> void:
	_run_play_cases("fights.json")


func test_victory_cases() -> void:
	_run_play_cases("victory.json")


func test_setup_cases() -> void:
	var cases: Array[Dictionary] = _load_cases("setup.json")
	assert_gt(cases.size(), 0, "setup.json should hold cases")
	for case: Dictionary in cases:
		var label: String = case["name"]
		var setup: Setup = BoardNotation.parse_setup(_side(case["side"]), _strings(case["rows"]))
		var valid: bool = case["valid"]
		assert_eq(setup.is_valid(), valid, label)


func _run_play_cases(file_name: String) -> void:
	var cases: Array[Dictionary] = _load_cases(file_name)
	assert_gt(cases.size(), 0, "%s should hold cases" % file_name)
	for case: Dictionary in cases:
		_run_play_case(case)


func _run_play_case(case: Dictionary) -> void:
	var label: String = case["name"]
	var rows: Array[String] = _strings(case["board"])
	var board: Board = BoardNotation.parse_board(rows)
	assert_eq(BoardNotation.format_board(board), rows, "%s: the board should read back" % label)
	var plies_without_fight: float = case.get("plies_without_fight", 0.0)
	var game: Game = Game.new(board, _side(case["to_move"]), roundi(plies_without_fight))
	var last_record: MoveRecord = null
	for move_text: String in _strings(case.get("moves", [])):
		last_record = game.try_play(BoardNotation.parse_move(move_text))
		if last_record == null:
			fail_test("%s: move %s should be legal" % [label, move_text])
			return
	var expect: Dictionary = case["expect"]
	_check_legal_moves(label, game, expect)
	_check_illegal_moves(label, game, expect)
	_check_board(label, game, expect)
	_check_fight(label, last_record, expect)
	_check_result(label, game, expect)


func _check_legal_moves(label: String, game: Game, expect: Dictionary) -> void:
	if not expect.has("legal_moves"):
		return
	var legal_moves: Dictionary = expect["legal_moves"]
	for key: Variant in legal_moves:
		var from_text: String = key
		var expected: Array[String] = _strings(legal_moves[key])
		var actual: Array[String] = []
		for square: Vector2i in game.legal_destinations(BoardNotation.parse_square(from_text)):
			actual.append(BoardNotation.format_square(square))
		expected.sort()
		actual.sort()
		assert_eq(actual, expected, "%s: legal moves from %s" % [label, from_text])


func _check_illegal_moves(label: String, game: Game, expect: Dictionary) -> void:
	for move_text: String in _strings(expect.get("illegal_moves", [])):
		var before: Array[String] = BoardNotation.format_board(game.board())
		var record: MoveRecord = game.try_play(BoardNotation.parse_move(move_text))
		assert_null(record, "%s: %s should be rejected" % [label, move_text])
		assert_eq(
			BoardNotation.format_board(game.board()), before,
			"%s: a rejected move changes nothing" % label
		)


func _check_board(label: String, game: Game, expect: Dictionary) -> void:
	if expect.has("board"):
		assert_eq(
			BoardNotation.format_board(game.board()), _strings(expect["board"]),
			"%s: board after the moves" % label
		)


func _check_fight(label: String, record: MoveRecord, expect: Dictionary) -> void:
	if not expect.has("fight"):
		return
	if record == null or record.fight == null:
		fail_test("%s: the last move should cause a Fight" % label)
		return
	var fight: Dictionary = expect["fight"]
	var attacker: String = fight["attacker"]
	var defender: String = fight["defender"]
	var outcome: String = fight["outcome"]
	assert_eq(BoardNotation.letter_of(record.fight.attacker), attacker, "%s: attacker" % label)
	assert_eq(BoardNotation.letter_of(record.fight.defender), defender, "%s: defender" % label)
	assert_eq(OUTCOME_NAMES[record.fight.outcome], outcome, "%s: outcome" % label)


func _check_result(label: String, game: Game, expect: Dictionary) -> void:
	if expect.has("status"):
		var status: String = expect["status"]
		assert_eq(STATUS_NAMES[game.result().status], status, "%s: status" % label)
	if expect.has("reason"):
		var reason: String = expect["reason"]
		assert_eq(REASON_NAMES[game.result().reason], reason, "%s: reason" % label)


func _load_cases(file_name: String) -> Array[Dictionary]:
	var text: String = FileAccess.get_file_as_string(SPEC_DIRECTORY + file_name)
	var parsed: Variant = JSON.parse_string(text)
	var cases: Array[Dictionary] = []
	if parsed is not Dictionary:
		fail_test("%s is not a JSON object" % file_name)
		return cases
	var root: Dictionary = parsed
	var entries: Array = root.get("cases", [])
	for entry: Variant in entries:
		if entry is Dictionary:
			cases.append(entry)
	return cases


func _strings(value: Variant) -> Array[String]:
	var items: Array = value
	var strings: Array[String] = []
	for item: Variant in items:
		strings.append(str(item))
	return strings


func _side(value: Variant) -> Side.Id:
	return Side.Id.RED if str(value) == "red" else Side.Id.GREEN
