class_name PlayerCard
extends PlayerBadge
## A player as a card in the side column of large screens.

@onready var _avatar: Avatar = %Avatar
@onready var _name_label: Label = %NameLabel
@onready var _detail_label: Label = %DetailLabel
@onready var _you_pill: PanelContainer = %YouPill
@onready var _status_label: Label = %StatusLabel
@onready var _turn_bar: ProgressBar = %TurnBar
@onready var _tray: GraveyardTray = %Tray


func show_status(text: String) -> void:
	_status_label.text = text
	_status_label.visible = not text.is_empty()


func show_graveyard(types: Array[PieceType.Id]) -> void:
	_tray.show_graveyard(types, _side, _adapted)
	_detail_label.text = _army_detail(types.size())


func last_loss_rect() -> Rect2:
	return PlayerBadge._last_slot(_tray)


func pulse_tray() -> void:
	PlayerBadge._flash(_tray)


func _show_identity(name: String) -> void:
	_name_label.text = name
	_avatar.show_player(name, UiTokens.army_fill(_side, _adapted), UiTokens.army_colour(_side, _adapted))
	_you_pill.visible = _is_you
	_detail_label.text = _army_detail(0)


func _show_turn_bar(shown: bool, fraction: float) -> void:
	_turn_bar.visible = shown
	_turn_bar.value = fraction


func _look_name(is_you: bool, active: bool) -> StringName:
	if active:
		return &"CardSelfActive" if is_you else &"CardActive"
	return &"CardSelf" if is_you else &"Card"
