class_name OnlineMatchTexts
extends RefCounted
## The sentences the online match screen shows for where a session stands.


static func status(session: OnlineSession) -> String:
	match session.phase():
		OnlineSession.Phase.CONNECTING:
			return Translated.text(&"ONLINE_CONNECTING")
		OnlineSession.Phase.ARRANGING:
			var arrange: String = Translated.text(&"ONLINE_ARRANGE")
			return _with_presence(session, arrange, &"ONLINE_OPPONENT_AWAY_SETUP")
		OnlineSession.Phase.WAITING_FOR_OPPONENT_SETUP:
			var waiting: String = Translated.text(
				&"ONLINE_WAITING_SETUP", {"opponent": session.opponent()}
			)
			return _with_presence(session, waiting, &"ONLINE_OPPONENT_AWAY_SETUP")
		OnlineSession.Phase.PLAYING:
			return _with_presence(session, _turn_text(session), &"ONLINE_OPPONENT_AWAY")
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


## Why the Lobby was left, for the server's [param reason].
static func lobby_failure(reason: String) -> String:
	match reason:
		LobbyClient.CONNECTION_LOST:
			return Translated.text(&"ONLINE_FAILED_CONNECTION")
		"invalid_nickname":
			return Translated.text(&"ONLINE_FAILED_NICKNAME", {"max": Nickname.MAX_LENGTH})
		_:
			return Translated.text(&"ONLINE_FAILED_OTHER")


## The Rematch button: ask, accept the Opponent's ask, or wait for theirs.
static func rematch_button(session: OnlineSession) -> String:
	if session.has_asked_for_rematch():
		return Translated.text(&"ONLINE_REMATCH_WAITING", {"opponent": session.opponent()})
	if session.opponent_wants_rematch():
		return Translated.text(&"ONLINE_REMATCH_ACCEPT", {"opponent": session.opponent()})
	return Translated.text(&"ONLINE_REMATCH")


## What a Guest reads when a Challenge with [param nickname] ends.
static func challenge_end(nickname: String, reason: String) -> String:
	match reason:
		"declined":
			return Translated.text(&"LOBBY_DECLINED", {"nickname": nickname})
		"withdrawn":
			return Translated.text(&"LOBBY_WITHDRAWN", {"nickname": nickname})
		_:
			return Translated.text(&"LOBBY_GONE", {"nickname": nickname})


## [param text], followed while the Opponent is disconnected by the
## [param away_key] notice.
static func _with_presence(session: OnlineSession, text: String, away_key: StringName) -> String:
	if session.is_opponent_connected():
		return text
	var away: String = Translated.text(away_key, {"opponent": session.opponent()})
	return away if text.is_empty() else "%s\n%s" % [text, away]


## Whose turn it is; empty on the Opponent's turn while they are
## disconnected, since they are not playing.
static func _turn_text(session: OnlineSession) -> String:
	if session.is_awaiting_answer():
		return Translated.text(&"ONLINE_SENDING")
	if session.is_own_turn():
		return Translated.text(&"ONLINE_YOUR_TURN")
	if not session.is_opponent_connected():
		return ""
	return Translated.text(&"ONLINE_OPPONENT_TURN", {"opponent": session.opponent()})
