class_name MatchNarrator
extends RefCounted
## Turns game events into the sentences players read, in the current language.

const _REASON_KEYS: Dictionary[GameResult.Reason, StringName] = {
	GameResult.Reason.PRINCESS_CAPTURED: &"REASON_PRINCESS_CAPTURED",
	GameResult.Reason.PRINCESS_REACHED_HOME_ROW: &"REASON_PRINCESS_REACHED_HOME_ROW",
	GameResult.Reason.BLOCKED: &"REASON_BLOCKED",
	GameResult.Reason.NO_FIGHT_LIMIT: &"REASON_NO_FIGHT_LIMIT",
}


static func describe_move(record: MoveRecord) -> String:
	var values: Dictionary[String, Variant] = {
		"side": PieceNames.side_name(record.mover.side),
		"from": BoardNotation.format_square(record.move.from),
		"to": BoardNotation.format_square(record.move.to),
	}
	if record.fight == null:
		return Translated.text(&"NARRATE_MOVE", values)
	values["fight"] = describe_fight(record.fight)
	return Translated.text(&"NARRATE_ATTACK", values)


static func describe_fight(fight: Fight) -> String:
	var attacker: String = PieceNames.display_name(fight.attacker.type)
	var defender: String = PieceNames.display_name(fight.defender.type)
	var clash: String = Translated.text(&"NARRATE_CLASH", {
		"attacker_side": PieceNames.side_name(fight.attacker.side),
		"attacker": attacker,
		"attack": PieceType.attack_strength(fight.attacker.type),
		"defender_side": PieceNames.side_name(fight.defender.side),
		"defender": defender,
		"defense": PieceType.defense_strength(fight.defender.type),
	})
	match fight.outcome:
		FightOutcome.Id.ATTACKER_WINS:
			return clash + Translated.text(&"FIGHT_WINS", {"piece": attacker})
		FightOutcome.Id.DEFENDER_WINS:
			return clash + Translated.text(&"FIGHT_WINS", {"piece": defender})
		_:
			return clash + Translated.text(&"FIGHT_BOTH_ELIMINATED")


static func describe_result(result: GameResult) -> String:
	var reason: String = (
		Translated.text(_REASON_KEYS[result.reason]) if _REASON_KEYS.has(result.reason) else ""
	)
	match result.status:
		GameResult.Status.RED_WINS:
			return _win_text(Side.Id.RED, reason)
		GameResult.Status.GREEN_WINS:
			return _win_text(Side.Id.GREEN, reason)
		GameResult.Status.DRAW:
			return Translated.text(&"RESULT_DRAW", {"reason": reason})
		_:
			return ""


static func describe_piece(type: PieceType.Id) -> String:
	return Translated.text(&"PIECE_DESCRIPTION", {
		"piece": PieceNames.display_name(type),
		"attack": PieceType.attack_strength(type),
		"defense": PieceType.defense_strength(type),
	})


static func describe_graveyard(side: Side.Id, types: Array[PieceType.Id]) -> String:
	var pieces: String = Translated.text(&"GRAVEYARD_NOTHING")
	if not types.is_empty():
		var names: PackedStringArray = []
		for type: PieceType.Id in types:
			names.append(PieceNames.display_name(type))
		pieces = ", ".join(names)
	return Translated.text(&"GRAVEYARD", {"side": PieceNames.side_name(side), "pieces": pieces})


static func _win_text(winner: Side.Id, reason: String) -> String:
	return Translated.text(&"RESULT_WINS", {"side": PieceNames.side_name(winner), "reason": reason})
