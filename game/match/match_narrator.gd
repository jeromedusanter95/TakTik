class_name MatchNarrator
extends RefCounted
## Turns game events into the sentences players read, in the current language.

const _REASON_KEYS: Dictionary[GameResult.Reason, StringName] = {
	GameResult.Reason.PRINCESS_CAPTURED: &"REASON_PRINCESS_CAPTURED",
	GameResult.Reason.PRINCESS_REACHED_HOME_ROW: &"REASON_PRINCESS_REACHED_HOME_ROW",
	GameResult.Reason.BLOCKED: &"REASON_BLOCKED",
	GameResult.Reason.NO_FIGHT_LIMIT: &"REASON_NO_FIGHT_LIMIT",
	GameResult.Reason.RESIGNED: &"REASON_RESIGNED",
	GameResult.Reason.FORFEITED: &"REASON_FORFEITED",
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
	return _describe_clash(
		fight.attacker.side, fight.attacker.type, fight.defender.side, fight.defender.type, fight.outcome
	)


## A Move as both players saw it online: its Squares and, after a Fight, the
## Reveal.
static func describe_event(event: PublicMoveEvent) -> String:
	var values: Dictionary[String, Variant] = {
		"side": PieceNames.side_name(event.mover_side),
		"from": BoardNotation.format_square(event.move.from),
		"to": BoardNotation.format_square(event.move.to),
	}
	if not event.has_fight:
		return Translated.text(&"NARRATE_MOVE", values)
	values["fight"] = describe_event_fight(event)
	return Translated.text(&"NARRATE_ATTACK", values)


## The Reveal of the Fight [param event] caused, which must have one.
static func describe_event_fight(event: PublicMoveEvent) -> String:
	return _describe_clash(
		event.mover_side,
		event.attacker_type,
		Side.opponent(event.mover_side),
		event.defender_type,
		event.outcome,
	)


static func describe_result(result: GameResult) -> String:
	match result.status:
		GameResult.Status.RED_WINS:
			return _win_text(Side.Id.RED, result.reason)
		GameResult.Status.GREEN_WINS:
			return _win_text(Side.Id.GREEN, result.reason)
		GameResult.Status.DRAW:
			return Translated.text(&"RESULT_DRAW", {"reason": _reason_text(result.reason, {})})
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


static func _win_text(winner: Side.Id, reason: GameResult.Reason) -> String:
	var loser: Dictionary[String, Variant] = {"loser": PieceNames.side_name(Side.opponent(winner))}
	return Translated.text(&"RESULT_WINS", {
		"side": PieceNames.side_name(winner),
		"reason": _reason_text(reason, loser),
	})


## Why the game ended; [param values] fill the reasons that name the loser.
static func _reason_text(reason: GameResult.Reason, values: Dictionary[String, Variant]) -> String:
	return Translated.text(_REASON_KEYS[reason], values) if _REASON_KEYS.has(reason) else ""


static func _describe_clash(
		attacker_side: Side.Id,
		attacker_type: PieceType.Id,
		defender_side: Side.Id,
		defender_type: PieceType.Id,
		outcome: FightOutcome.Id,
) -> String:
	var attacker: String = PieceNames.display_name(attacker_type)
	var defender: String = PieceNames.display_name(defender_type)
	var clash: String = Translated.text(&"NARRATE_CLASH", {
		"attacker_side": PieceNames.side_name(attacker_side),
		"attacker": attacker,
		"attack": PieceType.attack_strength(attacker_type),
		"defender_side": PieceNames.side_name(defender_side),
		"defender": defender,
		"defense": PieceType.defense_strength(defender_type),
	})
	match outcome:
		FightOutcome.Id.ATTACKER_WINS:
			return clash + Translated.text(&"FIGHT_WINS", {"piece": attacker})
		FightOutcome.Id.DEFENDER_WINS:
			return clash + Translated.text(&"FIGHT_WINS", {"piece": defender})
		_:
			return clash + Translated.text(&"FIGHT_BOTH_ELIMINATED")
