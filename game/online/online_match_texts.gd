class_name OnlineMatchTexts
extends RefCounted
## The sentences the online game screen shows for where a session stands.


## The one line in the top bar: what is happening now.
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
			return Translated.text(&"RESULT_GAME_OVER")
		_:
			if session.disconnection_reason() == "seat_taken_elsewhere":
				return Translated.text(&"ONLINE_SEAT_TAKEN")
			return Translated.text(&"ONLINE_DISCONNECTED")


## The line on the Opponent's card: arranging, ready, or gone.
static func opponent_status(session: OnlineSession) -> String:
	if not session.is_opponent_connected():
		var seconds: int = session.opponent_forfeit_seconds_left()
		if seconds != OnlineSession.NO_TIMER:
			return Translated.text(&"PLAYER_AWAY", {"time": TimerRing.format(seconds)})
		return Translated.text(&"PLAYER_DISCONNECTED")
	match session.phase():
		OnlineSession.Phase.ARRANGING, OnlineSession.Phase.WAITING_FOR_OPPONENT_SETUP:
			if session.is_opponent_setup_done():
				return Translated.text(&"PLAYER_READY")
			return Translated.text(&"PLAYER_ARRANGING")
		_:
			return ""


## The line on this Guest's card: ready once their Setup is in.
static func own_status(session: OnlineSession) -> String:
	if session.phase() == OnlineSession.Phase.WAITING_FOR_OPPONENT_SETUP:
		return Translated.text(&"PLAYER_READY")
	return ""


## The Fight of [param event] in one line, for the chat.
static func fight_line(event: PublicMoveEvent) -> String:
	return Translated.text(&"FIGHT_PILL", {
		"attacker": PieceNames.display_name(event.attacker_type),
		"attack": PieceType.attack_strength(event.attacker_type),
		"defender": PieceNames.display_name(event.defender_type),
		"defense": PieceType.defense_strength(event.defender_type),
		"result": FightCard.result_text(event),
	})


## Why the Lobby was left, for the server's [param reason].
static func lobby_failure(reason: String) -> String:
	match reason:
		LobbyClient.CONNECTION_LOST:
			return Translated.text(&"ONLINE_FAILED_CONNECTION")
		"invalid_nickname":
			return Translated.text(&"ONLINE_FAILED_NICKNAME", {"max": Nickname.MAX_LENGTH})
		_:
			return Translated.text(&"ONLINE_FAILED_OTHER")


## The Rematch button: ask, or wait for the Opponent's answer.
static func rematch_button(session: OnlineSession) -> String:
	if session.has_asked_for_rematch():
		return Translated.text(&"ONLINE_REMATCH_WAITING", {"opponent": session.opponent()})
	return Translated.text(&"ONLINE_REMATCH")


## The notice above the buttons once the Opponent asked for a Rematch.
static func rematch_notice(session: OnlineSession) -> String:
	if session.opponent_wants_rematch() and not session.has_asked_for_rematch():
		return Translated.text(&"RESULT_REMATCH_NOTICE", {"opponent": session.opponent()})
	return ""


## What a Guest reads when a Challenge with [param nickname] ends.
static func challenge_end(nickname: String, reason: String) -> String:
	match reason:
		"declined":
			return Translated.text(&"LOBBY_DECLINED", {"nickname": nickname})
		"withdrawn":
			return Translated.text(&"LOBBY_WITHDRAWN", {"nickname": nickname})
		"busy":
			return Translated.text(&"LOBBY_BUSY", {"nickname": nickname})
		_:
			return Translated.text(&"LOBBY_GONE", {"nickname": nickname})


## Whose turn it is.
static func _turn_text(session: OnlineSession) -> String:
	if session.is_awaiting_answer():
		return Translated.text(&"ONLINE_SENDING")
	if session.is_own_turn():
		return Translated.text(&"ONLINE_YOUR_TURN")
	return Translated.text(&"ONLINE_OPPONENT_TURN", {"opponent": session.opponent()})
