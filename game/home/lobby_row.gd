class_name LobbyRow
extends PanelContainer
## One Guest in the online panel: their avatar, name, status dot and words,
## and what this Guest can do with them.

signal challenge_pressed(guest_id: String)
signal withdraw_pressed

enum Status {
	CHALLENGED_YOU,
	AVAILABLE,
	SEARCHING,
	IN_GAME,
}

const ROW_HEIGHT: float = 66.0
const JOIN_TIME: float = 0.25
const FLASH_TIME: float = 1.0

var guest_id: String = ""

var _base_look: StringName = &"Row"

var _avatar: Avatar = Avatar.new()
var _name_label: Label = Label.new()
var _dot: StatusDot = StatusDot.new()
var _status_label: Label = Label.new()
var _actions: HBoxContainer = HBoxContainer.new()


func _init() -> void:
	custom_minimum_size = Vector2(0, ROW_HEIGHT)
	theme_type_variation = &"Row"
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	_avatar.custom_minimum_size = Vector2(42, 42)
	_avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_avatar)
	var names: VBoxContainer = VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	names.add_theme_constant_override("separation", 2)
	row.add_child(names)
	_name_label.theme_type_variation = &"LabelStrong"
	_name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_label.clip_text = true
	names.add_child(_name_label)
	var status_row: HBoxContainer = HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 6)
	_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status_row.add_child(_dot)
	_status_label.theme_type_variation = &"Caption"
	_status_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	status_row.add_child(_status_label)
	names.add_child(status_row)
	_actions.add_theme_constant_override("separation", 8)
	_actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_actions)


## Shows [param guest] with [param status]; [param is_you] marks this Guest's
## own row. [param challenge_sent] is true for the Guest this Guest
## challenged; [param can_challenge] is false while another Challenge is
## pending.
func show_guest(
		guest: ListedGuest, status: Status, is_you: bool, challenge_sent: bool, can_challenge: bool
) -> void:
	guest_id = guest.guest_id
	_name_label.text = guest.nickname
	_avatar.show_player(guest.nickname, UiTokens.neutral_avatar(guest.guest_id))
	_base_look = &"RowSelf" if is_you else &"Row"
	theme_type_variation = _base_look
	_show_status(status, challenge_sent)
	_clear_actions()
	if is_you:
		_actions.add_child(_pill(Translated.text(&"PLAYER_YOU")))
	elif status == Status.CHALLENGED_YOU or status == Status.IN_GAME:
		# A Challenge card holds the answer; a Guest in a game cannot be
		# challenged.
		pass
	elif challenge_sent:
		_actions.add_child(_button(Translated.text(&"LOBBY_WITHDRAW"), &"GhostButton", _on_withdraw_pressed))
	else:
		var challenge: Button = _button(Translated.text(&"LOBBY_CHALLENGE"), &"OutlineButton", _on_challenge_pressed)
		challenge.disabled = not can_challenge
		_actions.add_child(challenge)


func set_reduced_motion(reduced: bool) -> void:
	_dot.reduced_motion = reduced


## Fades in with a short highlight, for a Guest who just arrived.
func play_join(delay: float, reduced_motion: bool) -> void:
	if reduced_motion:
		return
	modulate.a = 0.0
	theme_type_variation = &"RowNewest"
	var tween: Tween = create_tween()
	tween.tween_interval(delay)
	tween.tween_property(self, "modulate:a", 1.0, JOIN_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(FLASH_TIME)
	tween.tween_callback(func() -> void: theme_type_variation = _base_look)


func _show_status(status: Status, challenge_sent: bool) -> void:
	var colour: Color = UiTokens.GREEN_400
	var key: StringName = &"LOBBY_STATUS_AVAILABLE"
	match status:
		Status.CHALLENGED_YOU:
			colour = UiTokens.GOLD_500
			key = &"LOBBY_STATUS_CHALLENGED_YOU"
		Status.SEARCHING:
			colour = UiTokens.DEF_400
			key = &"LOBBY_STATUS_SEARCHING"
		Status.IN_GAME:
			colour = UiTokens.AMBER_400
			key = &"LOBBY_STATUS_IN_GAME"
	if challenge_sent:
		colour = UiTokens.GOLD_500
		key = &"LOBBY_STATUS_CHALLENGE_SENT"
	_dot.show_dot(colour, status == Status.AVAILABLE)
	_status_label.text = Translated.text(key)
	_status_label.theme_type_variation = &"CaptionFaint" if status == Status.IN_GAME else &"Caption"


func _clear_actions() -> void:
	for child: Node in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()


func _button(text: String, look: StringName, on_pressed: Callable) -> Button:
	var button: Button = Button.new()
	button.theme_type_variation = look
	button.text = text
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.custom_minimum_size = Vector2(0, 42)
	button.pressed.connect(on_pressed)
	button.add_child(PressScaleFeedback.new())
	return button


func _pill(text: String) -> PanelContainer:
	var pill: PanelContainer = PanelContainer.new()
	pill.theme_type_variation = &"PillSelf"
	var label: Label = Label.new()
	label.theme_type_variation = &"CaptionStrong"
	label.text = text
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	pill.add_child(label)
	return pill


func _on_challenge_pressed() -> void:
	challenge_pressed.emit(guest_id)


func _on_withdraw_pressed() -> void:
	withdraw_pressed.emit()
