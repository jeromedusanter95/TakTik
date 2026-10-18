class_name OnlinePanel
extends PanelContainer
## The right column of the home screen: who is online, the Challenge this
## Guest received, and a Challenge button on every other Guest. It only shows
## what it is told and reports what the Guest asks for.

signal challenge_requested(guest_id: String)
signal withdraw_requested
signal answer_requested(guest_id: String, accept: bool)
signal retry_requested
## A Challenge card appeared for a new challenger.
signal challenge_shown

const CARD_IN_TIME: float = 0.3
const CARD_OUT_TIME: float = 0.2

var reduced_motion: bool = false

## The Guest ids already on screen, to animate only newcomers.
var _shown_ids: Array[String] = []
var _challenger_id: String = ""
var _card_tween: Tween = null
## True while the "entering" line shows, which the first listing replaces.
var _entering: bool = false

@onready var _count_label: Label = %CountLabel
@onready var _count_dot: StatusDot = %CountDot
@onready var _challenge_card: PanelContainer = %ChallengeCard
@onready var _challenger_avatar: Avatar = %ChallengerAvatar
@onready var _challenge_title: Label = %ChallengeTitle
@onready var _challenge_expiry: Label = %ChallengeExpiry
@onready var _challenge_bar: ProgressBar = %ChallengeBar
@onready var _accept_button: Button = %AcceptButton
@onready var _decline_button: Button = %DeclineButton
@onready var _more_label: Label = %MoreLabel
@onready var _message_label: Label = %MessageLabel
@onready var _retry_button: Button = %RetryButton
@onready var _rows: VBoxContainer = %Rows
@onready var _empty_state: VBoxContainer = %EmptyState


func _ready() -> void:
	_accept_button.pressed.connect(_on_answer_pressed.bind(true))
	_decline_button.pressed.connect(_on_answer_pressed.bind(false))
	_retry_button.pressed.connect(_on_retry_pressed)
	_challenge_card.visible = false
	_count_dot.show_dot(UiTokens.GREEN_400, true)
	show_offline("")


## Not in the Lobby: [param message] says why, and offers to try again when
## [param can_retry].
func show_offline(message: String, can_retry: bool = false) -> void:
	_entering = false
	_clear_rows()
	_shown_ids.clear()
	_count_label.text = OnlinePanel.player_count(0)
	_message_label.text = message
	_message_label.visible = not message.is_empty()
	_retry_button.visible = can_retry
	_empty_state.visible = false
	hide_challenge()


func show_connecting() -> void:
	show_offline(Translated.text(&"LOBBY_ENTERING"))
	_entering = true


## The Guests, this Guest first, then those who challenged them, those
## available, and those searching, alphabetically inside each group.
func show_guests(
		you: ListedGuest,
		you_searching: bool,
		guests: Array[ListedGuest],
		challenger_ids: Array[String],
		challenged_id: String,
) -> void:
	_retry_button.visible = false
	if _entering:
		_entering = false
		show_message("")
	_count_label.text = OnlinePanel.player_count(guests.size() + 1)
	# The empty state invites a Quick Match, which needs someone free.
	var anyone_free: bool = guests.any(func(guest: ListedGuest) -> bool: return not guest.in_game)
	var ordered: Array[ListedGuest] = guests.duplicate()
	ordered.sort_custom(func(a: ListedGuest, b: ListedGuest) -> bool:
		var rank_a: int = _rank(a, challenger_ids)
		var rank_b: int = _rank(b, challenger_ids)
		if rank_a != rank_b:
			return rank_a < rank_b
		return a.nickname.naturalnocasecmp_to(b.nickname) < 0
	)
	_clear_rows()
	var own_status: LobbyRow.Status = LobbyRow.Status.SEARCHING if you_searching else LobbyRow.Status.AVAILABLE
	_add_row(you, own_status, true, false, false)
	var arrivals: int = 0
	var first_load: bool = _shown_ids.is_empty()
	var shown: Array[String] = [you.guest_id]
	for guest: ListedGuest in ordered:
		var status: LobbyRow.Status = LobbyRow.Status.AVAILABLE
		if guest.guest_id in challenger_ids:
			status = LobbyRow.Status.CHALLENGED_YOU
		elif guest.in_game:
			status = LobbyRow.Status.IN_GAME
		elif guest.waiting:
			status = LobbyRow.Status.SEARCHING
		var is_new: bool = not guest.guest_id in _shown_ids
		var row: LobbyRow = _add_row(
			guest, status, false, guest.guest_id == challenged_id, challenged_id.is_empty()
		)
		if is_new:
			row.play_join(0.06 * arrivals if first_load else 0.0, reduced_motion)
			arrivals += 1
		shown.append(guest.guest_id)
	_shown_ids = shown
	_empty_state.visible = not anyone_free


func show_message(message: String) -> void:
	_message_label.text = message
	_message_label.visible = not message.is_empty()


## The Challenge from [param challenger], expiring in [param seconds_left] of
## [param total_seconds]; [param others] more wait behind it.
func show_challenge(challenger: ListedGuest, seconds_left: float, total_seconds: float, others: int) -> void:
	var is_new: bool = challenger.guest_id != _challenger_id or not _challenge_card.visible
	_challenger_id = challenger.guest_id
	_challenger_avatar.show_player(challenger.nickname, UiTokens.neutral_avatar(challenger.guest_id))
	_challenge_title.text = Translated.text(&"LOBBY_CHALLENGED_BY", {"nickname": challenger.nickname})
	_challenge_expiry.text = Translated.text(&"LOBBY_CHALLENGE_EXPIRES", {"time": TimerRing.format(ceili(seconds_left))})
	_challenge_bar.value = clampf(seconds_left / total_seconds, 0.0, 1.0)
	_more_label.visible = others > 0
	_more_label.text = Translated.text(&"LOBBY_MORE_CHALLENGES", {"count": others})
	if is_new:
		_slide_card_in()
		challenge_shown.emit()


func hide_challenge() -> void:
	if not _challenge_card.visible:
		return
	_challenger_id = ""
	if reduced_motion:
		_challenge_card.visible = false
		return
	_kill_card_tween()
	_card_tween = create_tween()
	_card_tween.tween_property(_challenge_card, "modulate:a", 0.0, CARD_OUT_TIME)
	_card_tween.tween_callback(_challenge_card.hide)


## "1 player" or "5 players".
static func player_count(count: int) -> String:
	return Translated.text(&"LOBBY_COUNT_ONE" if count == 1 else &"LOBBY_COUNT", {"count": count})


func row_count() -> int:
	return _rows.get_child_count()


func _slide_card_in() -> void:
	_challenge_card.visible = true
	_kill_card_tween()
	if reduced_motion:
		_challenge_card.modulate.a = 1.0
		return
	_challenge_card.modulate.a = 0.0
	_card_tween = create_tween()
	_card_tween.tween_property(_challenge_card, "modulate:a", 1.0, CARD_IN_TIME).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)


func _kill_card_tween() -> void:
	if _card_tween != null:
		_card_tween.kill()
		_card_tween = null


func _add_row(
		guest: ListedGuest, status: LobbyRow.Status, is_you: bool, challenge_sent: bool, can_challenge: bool
) -> LobbyRow:
	var row: LobbyRow = LobbyRow.new()
	row.set_reduced_motion(reduced_motion)
	row.show_guest(guest, status, is_you, challenge_sent, can_challenge)
	row.challenge_pressed.connect(_on_challenge_pressed)
	row.withdraw_pressed.connect(_on_withdraw_pressed)
	_rows.add_child(row)
	return row


func _rank(guest: ListedGuest, challenger_ids: Array[String]) -> int:
	if guest.guest_id in challenger_ids:
		return 0
	if guest.in_game:
		return 3
	return 2 if guest.waiting else 1


## Removes the rows at once, so a refresh never shows stale ones.
func _clear_rows() -> void:
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()


func _on_challenge_pressed(guest_id: String) -> void:
	challenge_requested.emit(guest_id)


func _on_withdraw_pressed() -> void:
	withdraw_requested.emit()


func _on_answer_pressed(accept: bool) -> void:
	answer_requested.emit(_challenger_id, accept)


func _on_retry_pressed() -> void:
	retry_requested.emit()
