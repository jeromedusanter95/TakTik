class_name SelectedPieceCard
extends PanelContainer
## During Setup: the Piece the player picked, where it stands, its strengths
## as pips and what to do next.

@onready var _picture: PiecePicture = %Picture
@onready var _name_label: Label = %NameLabel
@onready var _square_label: Label = %SquareLabel
@onready var _attack_pips: PipBar = %AttackPips
@onready var _defense_pips: PipBar = %DefensePips
@onready var _attack_value: Label = %AttackValue
@onready var _defense_value: Label = %DefenseValue
@onready var _hint_label: Label = %HintLabel
@onready var _details: VBoxContainer = %Details


## Shows [param type] of [param side] standing on [param square].
func show_piece(type: PieceType.Id, side: Side.Id, square: Vector2i, adapted: bool = false) -> void:
	_details.visible = true
	_picture.show_piece(type, side, false, adapted)
	_name_label.text = PieceNames.display_name(type)
	_square_label.text = Translated.text(&"SELECTED_SQUARE", {"square": BoardNotation.format_square(square)})
	_attack_pips.show_value(PieceType.attack_strength(type))
	_defense_pips.show_value(PieceType.defense_strength(type))
	_attack_value.text = str(PieceType.attack_strength(type))
	_defense_value.text = str(PieceType.defense_strength(type))
	_hint_label.text = Translated.text(&"SELECTED_HINT_SWAP")


## Nothing picked yet: only the hint.
func show_none() -> void:
	_details.visible = false
	_hint_label.text = Translated.text(&"SELECTED_HINT_PICK")
