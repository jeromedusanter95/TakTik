class_name OnlineMatchTexts
extends RefCounted
## The sentences the online match screen shows for where a session stands.


static func status(session: OnlineSession) -> String:
	match session.phase():
		OnlineSession.Phase.CONNECTING:
			return Translated.text(&"ONLINE_CONNECTING")
		OnlineSession.Phase.ARRANGING:
			return Translated.text(&"ONLINE_ARRANGE")
		OnlineSession.Phase.WAITING_FOR_OPPONENT_SETUP:
			return Translated.text(&"ONLINE_WAITING_SETUP", {"opponent": session.opponent()})
		OnlineSession.Phase.PLAYING:
			return _turn_text(session)
		OnlineSession.Phase.OVER:
			return MatchNarrator.describe_result(session.result())
		_:
			if session.disconnection_reason() == "seat_taken_elsewhere":
				return Translated.text(&"ONLINE_SEAT_TAKEN")
			return Translated.text(&"ONLINE_DISCONNECTED")


## What to read under the Board: the selected Piece, else the last Move,
## else who plays whom.
static func info(session: OnlineSession, selected: Vector2i) -> String:
	if selected != BoardViewState.NO_SQUARE:
		var piece: Piece = session.display_board().piece_at(selected)
		if piece != null and piece.side == session.side():
			return MatchNarrator.describe_piece(piece.type)
	var last: PublicMoveEvent = session.last_event()
	if last != null:
		return MatchNarrator.describe_event(last)
	return Translated.text(&"ONLINE_PLAYING_AGAINST", {
		"side": PieceNames.side_name(session.side()),
		"opponent": session.opponent(),
	})


static func graveyards(session: OnlineSession) -> String:
	if session.position() == null:
		return ""
	return "%s\n%s" % [
		MatchNarrator.describe_graveyard(Side.Id.RED, session.graveyard(Side.Id.RED)),
		MatchNarrator.describe_graveyard(Side.Id.GREEN, session.graveyard(Side.Id.GREEN)),
	]


## The Quick Match failure a Guest reads, for the server's [param reason].
static func search_failure(reason: String) -> String:
	match reason:
		QuickMatchSearch.CONNECTION_LOST:
			return Translated.text(&"ONLINE_FAILED_CONNECTION")
		"invalid_nickname":
			return Translated.text(&"ONLINE_FAILED_NICKNAME", {"max": Nickname.MAX_LENGTH})
		_:
			return Translated.text(&"ONLINE_FAILED_OTHER")


static func _turn_text(session: OnlineSession) -> String:
	if session.is_awaiting_answer():
		return Translated.text(&"ONLINE_SENDING")
	if session.is_own_turn():
		return Translated.text(&"ONLINE_YOUR_TURN")
	return Translated.text(&"ONLINE_OPPONENT_TURN", {"opponent": session.opponent()})
