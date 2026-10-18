class_name MatchScreen
extends Control
## The game screen both local and online games drive: the top bar, the two
## players, the selected Piece or the last Fight, the Board, the chat, and
## the overlays (turn banner, end of game, menu, dialogs). It only shows what
## it is told and reports what the player asks for.
##
## Large screens get three columns: players on the left, the Board in the
## middle, the chat on the right. Phones stack strips around the Board and
## move the chat into a bottom sheet.

signal square_pressed(square: Vector2i)
signal board_cancelled
signal shuffle_pressed
## The gold button under the Board: Ready during Setup, Pass the device on a
## shared device.
signal action_pressed
signal resign_confirmed
signal quit_requested
## The end of game modal's first button (Rematch or New game).
signal rematch_pressed
## The end of game modal's second button (Back to the Lobby or Menu).
signal leave_pressed
signal quick_chat_chosen(message: String)
signal connection_retry_pressed
signal connection_leave_pressed
## Reduced motion or adapted colours changed: redraw what depends on them.
signal display_changed

## Which player a card or strip shows.
enum Slot {
	OPPONENT,
	YOU,
	NONE,
}

## What the Board is for.
enum Phase {
	SETUP,
	PLAY,
	OVER,
}

const BOARD_DIM: float = 0.4
const PHONE_MAX_CELL: float = 64.0
const PHONE_MIN_CELL: float = 48.0

var _preferences: PlayerPreferences = null
var _sound: SoundOutput = null
var _phone: bool = false
var _has_chat: bool = true
var _resign_allowed: bool = false
var _phase: Phase = Phase.SETUP
var _unread: int = 0

@onready var _top_bar: TopBar = %TopBar
@onready var _body: MarginContainer = %Body
@onready var _columns: HBoxContainer = %Columns
@onready var _left_column: VBoxContainer = %LeftColumn
@onready var _right_column: VBoxContainer = %RightColumn
@onready var _opponent_card: PlayerCard = %OpponentCard
@onready var _you_card: PlayerCard = %YouCard
@onready var _opponent_strip: PlayerStrip = %OpponentStrip
@onready var _you_strip: PlayerStrip = %YouStrip
@onready var _selected_card: SelectedPieceCard = %SelectedPieceCard
@onready var _fight_card: FightCard = %FightCard
@onready var _fight_strip: PanelContainer = %FightStrip
@onready var _fight_strip_label: Label = %FightStripLabel
@onready var _board_view: BoardView = %BoardView
@onready var _setup_buttons: HBoxContainer = %SetupButtons
@onready var _shuffle_button: Button = %ShuffleButton
@onready var _action_button: Button = %ActionButton
@onready var _chat_panel: ChatPanel = %ChatPanel
@onready var _chat_bar: Button = %ChatBar
@onready var _chat_bar_margin: MarginContainer = %ChatBarMargin
@onready var _turn_banner: TurnBanner = %TurnBanner
@onready var _result_modal: ResultModal = %ResultModal
@onready var _chat_sheet: ChatSheet = %ChatSheet
@onready var _game_menu: GameMenu = %GameMenu
@onready var _resign_dialog: VeilDialog = %ResignDialog
@onready var _connection_dialog: VeilDialog = %ConnectionDialog


func _ready() -> void:
	_board_view.square_pressed.connect(_on_square_pressed)
	_board_view.cancel_pressed.connect(_on_board_cancelled)
	_shuffle_button.pressed.connect(_on_shuffle_pressed)
	_action_button.pressed.connect(_on_action_pressed)
	_top_bar.menu_pressed.connect(_on_menu_pressed)
	_top_bar.resign_pressed.connect(_ask_to_resign)
	_top_bar.chat_pressed.connect(_open_chat_sheet)
	_chat_bar.pressed.connect(_open_chat_sheet)
	_game_menu.resign_pressed.connect(_ask_to_resign)
	_game_menu.quit_pressed.connect(_on_quit_pressed)
	_resign_dialog.primary_pressed.connect(_on_resign_confirmed)
	_connection_dialog.primary_pressed.connect(_on_connection_retry)
	_connection_dialog.secondary_pressed.connect(_on_connection_leave)
	_result_modal.primary_pressed.connect(_on_rematch_pressed)
	_result_modal.secondary_pressed.connect(_on_leave_pressed)
	_chat_panel.quick_chat_chosen.connect(_on_quick_chat_chosen)
	_chat_panel.message_added.connect(_on_message_added)
	_chat_sheet.closed.connect(_on_chat_sheet_closed)
	_top_bar.timer_beat.connect(_play.bind(SoundCue.Id.TICK))
	_apply_layout()


func use_preferences(preferences: PlayerPreferences) -> void:
	_preferences = preferences
	_game_menu.use_preferences(preferences)
	_top_bar.use_preferences(preferences)
	_preferences.changed.connect(_on_preferences_changed)
	_apply_motion()


## Where the game's sound cues go; without one the screen stays silent.
func use_sound(sound: SoundOutput) -> void:
	_sound = sound


## Whether the colour-blind palette is on.
func adapted_colours() -> bool:
	return _preferences != null and _preferences.adapted_colours


## Online games have a chat; games on this device do not, and centre the
## Board in two columns.
func set_chat_enabled(has_chat: bool) -> void:
	_has_chat = has_chat
	_top_bar.show_chat_button(has_chat)
	_apply_layout()


func set_resign_allowed(allowed: bool) -> void:
	_resign_allowed = allowed
	_top_bar.show_resign(allowed)


func set_phase(phase: Phase) -> void:
	_phase = phase
	_selected_card.visible = phase == Phase.SETUP
	_fight_card.visible = phase != Phase.SETUP
	_board_view.modulate.a = BOARD_DIM if phase == Phase.OVER and _result_modal.visible else 1.0
	_apply_board_size()


func set_phone(phone: bool) -> void:
	if phone == _phone:
		return
	_phone = phone
	_apply_layout()


func is_phone() -> bool:
	return _phone


# The top bar.

func show_subtitle(text: String) -> void:
	_top_bar.show_subtitle(text)


func show_status(text: String, dot: Color = Color.TRANSPARENT, pulsing: bool = false) -> void:
	_top_bar.show_status(text, dot, pulsing)


func show_finished(text: String) -> void:
	_top_bar.show_finished(text)


func show_timer(seconds_left: int, total_seconds: int, colour: Color) -> void:
	_top_bar.show_timer(seconds_left, total_seconds, colour)


func hide_timer() -> void:
	_top_bar.hide_timer()


# The players.

func show_player(slot: Slot, name: String, side: Side.Id, is_you: bool) -> void:
	for badge: PlayerBadge in _badges(slot):
		badge.show_player(name, side, is_you, adapted_colours())


func show_player_status(slot: Slot, text: String) -> void:
	for badge: PlayerBadge in _badges(slot):
		badge.show_status(text)


## Outlines the player of [param active] as the one to move, with
## [param fraction] of their Turn Timer left, or a negative fraction.
func show_turn(active: Slot, fraction: float) -> void:
	for slot: Slot in [Slot.OPPONENT, Slot.YOU]:
		for badge: PlayerBadge in _badges(slot):
			badge.show_turn(slot == active, fraction)


func show_graveyard(slot: Slot, types: Array[PieceType.Id]) -> void:
	for badge: PlayerBadge in _badges(slot):
		badge.show_graveyard(types)


# Beside the Board.

func show_selected_piece(type: PieceType.Id, side: Side.Id, square: Vector2i) -> void:
	_selected_card.show_piece(type, side, square, adapted_colours())


func show_no_selected_piece() -> void:
	_selected_card.show_none()


func show_last_fight(event: PublicMoveEvent) -> void:
	_fight_card.show_fight(event, adapted_colours())
	_fight_strip_label.text = "%s · %s" % [
		Translated.text(&"FIGHT_TITLE"), FightCard.result_text(event),
	]
	_fight_strip.visible = _phone and _phase != Phase.SETUP


func show_no_fight() -> void:
	_fight_card.show_none()
	_fight_strip.visible = false


# The Board.

func show_board(state: BoardViewState) -> void:
	state.adapted_colours = adapted_colours()
	_board_view.show_state(state)


func play_move(event: PublicMoveEvent) -> void:
	_board_view.play_move(event)
	_play(SoundCue.Id.FIGHT if event.has_fight else SoundCue.Id.MOVE)
	if event.has_fight:
		get_tree().create_timer(BoardMotion.FIGHT_SECONDS).timeout.connect(_play.bind(SoundCue.Id.CAPTURE))


func play_swap(first: Vector2i, second: Vector2i) -> void:
	_board_view.play_swap(first, second)
	_play(SoundCue.Id.SWAP)


## The buttons under the Board: Shuffle when [param shuffle], and the gold
## action with [param action_text] (an empty text hides it).
func show_board_actions(shuffle: bool, action_text: String, enabled: bool) -> void:
	_shuffle_button.visible = shuffle
	_shuffle_button.disabled = not enabled
	_action_button.visible = not action_text.is_empty()
	_action_button.text = action_text
	_action_button.disabled = not enabled
	_setup_buttons.visible = shuffle or not action_text.is_empty()


# The chat.

func clear_chat() -> void:
	_chat_panel.clear()
	_unread = 0
	_top_bar.show_unread(0)
	_chat_bar.text = Translated.text(&"CHAT_OPEN")


func add_chat(author: String, text: String, is_you: bool) -> void:
	_chat_panel.add_chat(author, text, is_you)
	if not is_you:
		_play(SoundCue.Id.CHAT)
	_chat_bar.text = Translated.text(&"CHAT_LINE", {"name": author, "message": text})


func add_system(text: String) -> void:
	_chat_panel.add_system(text)


func add_fight(text: String) -> void:
	_chat_panel.add_fight(text)


func show_journal(lines: PackedStringArray) -> void:
	_chat_panel.show_journal(lines)


func set_chips_enabled(enabled: bool) -> void:
	_chat_panel.set_chips_enabled(enabled)


# Overlays.

func play_turn_banner() -> void:
	_turn_banner.play()
	_play(SoundCue.Id.TURN)


func show_result(view: MatchResultView) -> void:
	_result_modal.present(view, adapted_colours())
	_play(SoundCue.Id.VICTORY if view.mood == MatchResultView.Mood.VICTORY else SoundCue.Id.DEFEAT)
	_board_view.modulate.a = BOARD_DIM


func show_rematch(text: String, enabled: bool) -> void:
	_result_modal.show_primary(text, enabled)


func show_rematch_notice(text: String) -> void:
	_result_modal.show_notice(text)


func hide_result() -> void:
	_result_modal.close()
	_board_view.modulate.a = 1.0


func is_result_shown() -> bool:
	return _result_modal.visible


## A dialog about the connection; an empty button text hides that button.
func show_connection(title: String, detail: String, busy: bool, retry_text: String, leave_text: String) -> void:
	_connection_dialog.present(title, detail, busy, retry_text, leave_text)


func hide_connection() -> void:
	_connection_dialog.hide()


func close_overlays() -> void:
	_game_menu.close()
	_resign_dialog.hide()
	_connection_dialog.hide()
	_chat_sheet.close()
	hide_result()


func _play(cue: SoundCue.Id) -> void:
	if _sound != null:
		_sound.play(cue)


func _badges(slot: Slot) -> Array[PlayerBadge]:
	if slot == Slot.OPPONENT:
		return [_opponent_card, _opponent_strip]
	if slot == Slot.YOU:
		return [_you_card, _you_strip]
	return []


func _apply_layout() -> void:
	_left_column.visible = not _phone
	_right_column.visible = _has_chat and not _phone
	_opponent_strip.visible = _phone
	_you_strip.visible = _phone
	_fight_strip.visible = false
	_chat_bar_margin.visible = _phone and _has_chat
	_top_bar.set_phone(_phone)
	var margin: int = UiTokens.SPACE_M if _phone else UiTokens.SPACE_2XL
	_body.add_theme_constant_override("margin_left", margin)
	_body.add_theme_constant_override("margin_right", margin)
	_body.add_theme_constant_override("margin_top", UiTokens.SPACE_M if _phone else 22)
	_body.add_theme_constant_override("margin_bottom", UiTokens.SPACE_L if _phone else 26)
	_columns.add_theme_constant_override("separation", 10 if _phone else UiTokens.GAP_COLUMNS)
	_turn_banner.rest_y = (UiTokens.TOPBAR_PHONE if _phone else UiTokens.TOPBAR_DESKTOP) + UiTokens.SPACE_L
	# The end of game modal covers the Board side and leaves the chat usable.
	_result_modal.offset_top = UiTokens.TOPBAR_PHONE if _phone else UiTokens.TOPBAR_DESKTOP
	var chat_width: int = UiTokens.COL_RIGHT + UiTokens.SPACE_2XL + UiTokens.GAP_COLUMNS
	_result_modal.offset_right = -chat_width if _has_chat and not _phone else 0
	_result_modal.set_phone(_phone)
	_move_chat()
	_apply_board_size()


## The chat lives in the right column on large screens and in the sheet on
## phones.
func _move_chat() -> void:
	var target: Container = _chat_sheet.body() if _phone else _right_column
	if _chat_panel.get_parent() == target:
		return
	_chat_panel.reparent(target, false)
	# Inside the sheet the chat needs no panel of its own.
	_chat_panel.theme_type_variation = &"Bare" if _phone else &"SidePanel"
	if not _phone:
		_chat_sheet.close()


func _apply_board_size() -> void:
	if _phone:
		_board_view.max_cell = PHONE_MAX_CELL
		_board_view.min_cell = PHONE_MIN_CELL
	else:
		_board_view.max_cell = UiTokens.CELL_PLACEMENT if _phase == Phase.SETUP else UiTokens.CELL_MATCH
		_board_view.min_cell = 40.0
	_board_view.update_minimum_size()
	_board_view.queue_redraw()


func _apply_motion() -> void:
	var reduced: bool = _preferences != null and _preferences.reduced_motion
	_board_view.reduced_motion = reduced
	_turn_banner.reduced_motion = reduced
	_result_modal.reduced_motion = reduced
	_chat_sheet.reduced_motion = reduced
	_top_bar.set_reduced_motion(reduced)


func _open_chat_sheet() -> void:
	if not _phone:
		return
	_unread = 0
	_top_bar.show_unread(0)
	_chat_sheet.open()


func _ask_to_resign() -> void:
	_resign_dialog.present(
		Translated.text(&"ONLINE_RESIGN_TITLE"), Translated.text(&"RESIGN_DETAIL"), false,
		Translated.text(&"ONLINE_RESIGN"), Translated.text(&"MENU_CANCEL"), true
	)


func _on_square_pressed(square: Vector2i) -> void:
	square_pressed.emit(square)


func _on_board_cancelled() -> void:
	board_cancelled.emit()


func _on_shuffle_pressed() -> void:
	shuffle_pressed.emit()


func _on_action_pressed() -> void:
	action_pressed.emit()


func _on_menu_pressed() -> void:
	_game_menu.open(_resign_allowed)


func _on_quit_pressed() -> void:
	quit_requested.emit()


func _on_resign_confirmed() -> void:
	resign_confirmed.emit()


func _on_connection_retry() -> void:
	connection_retry_pressed.emit()


func _on_connection_leave() -> void:
	connection_leave_pressed.emit()


func _on_rematch_pressed() -> void:
	rematch_pressed.emit()


func _on_leave_pressed() -> void:
	leave_pressed.emit()


func _on_quick_chat_chosen(message: String) -> void:
	quick_chat_chosen.emit(message)


func _on_message_added(is_from_opponent: bool) -> void:
	if _phone and is_from_opponent and not _chat_sheet.is_open():
		_unread += 1
		_top_bar.show_unread(_unread)


func _on_chat_sheet_closed() -> void:
	_unread = 0
	_top_bar.show_unread(0)


func _on_preferences_changed() -> void:
	_apply_motion()
	display_changed.emit()
