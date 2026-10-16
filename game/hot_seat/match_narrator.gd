class_name MatchNarrator
extends RefCounted
## Turns game events into the sentences players read.

const _REASONS: Dictionary[GameResult.Reason, String] = {
	GameResult.Reason.PRINCESS_CAPTURED: "the enemy Princess was captured",
	GameResult.Reason.PRINCESS_REACHED_HOME_ROW: "the Princess reached the enemy Home Row",
	GameResult.Reason.BLOCKED: "the opponent has no legal Move left",
	GameResult.Reason.NO_FIGHT_LIMIT: "50 Rounds passed without a Fight",
}


static func describe_move(record: MoveRecord) -> String:
	var mover: String = PieceNames.side_name(record.mover.side)
	var from: String = BoardNotation.format_square(record.move.from)
	var to: String = BoardNotation.format_square(record.move.to)
	if record.fight == null:
		return "%s moved a Piece from %s to %s." % [mover, from, to]
	return "%s attacked from %s to %s. %s" % [mover, from, to, describe_fight(record.fight)]


static func describe_fight(fight: Fight) -> String:
	var attacker: String = PieceNames.display_name(fight.attacker.type)
	var defender: String = PieceNames.display_name(fight.defender.type)
	var clash: String = "%s %s (attack %d) against %s %s (defense %d): " % [
		PieceNames.side_name(fight.attacker.side), attacker,
		PieceType.attack_strength(fight.attacker.type),
		PieceNames.side_name(fight.defender.side), defender,
		PieceType.defense_strength(fight.defender.type),
	]
	match fight.outcome:
		FightOutcome.Id.ATTACKER_WINS:
			return clash + "the %s wins." % attacker
		FightOutcome.Id.DEFENDER_WINS:
			return clash + "the %s wins." % defender
		_:
			return clash + "both are eliminated."


static func describe_result(result: GameResult) -> String:
	match result.status:
		GameResult.Status.RED_WINS:
			return "Red wins: %s." % _REASONS[result.reason]
		GameResult.Status.GREEN_WINS:
			return "Green wins: %s." % _REASONS[result.reason]
		GameResult.Status.DRAW:
			return "Draw: %s." % _REASONS[result.reason]
		_:
			return ""


static func describe_piece(type: PieceType.Id) -> String:
	return "%s, attack %d, defense %d" % [
		PieceNames.display_name(type),
		PieceType.attack_strength(type),
		PieceType.defense_strength(type),
	]


static func describe_graveyard(side: Side.Id, types: Array[PieceType.Id]) -> String:
	if types.is_empty():
		return "%s lost: nothing" % PieceNames.side_name(side)
	var names: PackedStringArray = []
	for type: PieceType.Id in types:
		names.append(PieceNames.display_name(type))
	return "%s lost: %s" % [PieceNames.side_name(side), ", ".join(names)]
