class_name PlayerStrip
extends PlayerBadge
## A player as a 52 px strip above or below the Board on phones.

@onready var _avatar: Avatar = %Avatar
@onready var _name_label: Label = %NameLabel
@onready var _status_label: Label = %StatusLabel
@onready var _turn_bar: ProgressBar = %TurnBar
@onready var _tray: GraveyardTray = %Tray


func show_status(text: String) -> void:
	_status_label.text = text
	_status_label.visible = not text.is_empty()


func show_graveyard(types: Array[PieceType.Id]) -> void:
	_tray.show_graveyard(types, _side, _adapted)


func last_loss_rect() -> Rect2:
	return PlayerBadge._last_slot(_tray)


func pulse_tray() -> void:
	PlayerBadge._flash(_tray)


func _show_identity(name: String) -> void:
	_name_label.text = name
	_avatar.show_player(name, UiTokens.army_fill(_side, _adapted), UiTokens.army_colour(_side, _adapted))


func _show_turn_bar(shown: bool, fraction: float) -> void:
	_turn_bar.visible = shown
	_turn_bar.value = fraction


func _look_name(is_you: bool, active: bool) -> StringName:
	if active:
		return &"StripSelfActive" if is_you else &"StripActive"
	return &"StripSelf" if is_you else &"Strip"
