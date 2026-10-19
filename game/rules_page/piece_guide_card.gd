class_name PieceGuideCard
extends PanelContainer
## One Piece Type on the rules page: its token and name, how many an Army
## holds, how it moves, its strengths as pips and whom it beats when it
## attacks.

const _NOTE_KEYS: Dictionary[PieceType.Id, StringName] = {
	PieceType.Id.THIEF: &"RULES_NOTE_THIEF",
	PieceType.Id.KING: &"RULES_NOTE_KING",
	PieceType.Id.EXECUTIONER: &"RULES_NOTE_EXECUTIONER",
	PieceType.Id.MAGICIAN: &"RULES_NOTE_MAGICIAN",
	PieceType.Id.BUFFOON: &"RULES_NOTE_BUFFOON",
	PieceType.Id.MONSTER: &"RULES_NOTE_MONSTER",
	PieceType.Id.PRINCESS: &"RULES_NOTE_PRINCESS",
}

const _REACH_KEYS: Dictionary[MovementRule.Reach, StringName] = {
	MovementRule.Reach.NONE: &"RULES_MOVE_NONE",
	MovementRule.Reach.ONE_SQUARE: &"RULES_MOVE_ONE",
	MovementRule.Reach.ANY_SQUARES: &"RULES_MOVE_ANY",
}

@onready var _picture: PiecePicture = %Picture
@onready var _name_label: Label = %NameLabel
@onready var _count_label: Label = %CountLabel
@onready var _move_label: Label = %MoveLabel
@onready var _note_label: Label = %NoteLabel
@onready var _attack_pips: PipBar = %AttackPips
@onready var _defense_pips: PipBar = %DefensePips
@onready var _attack_value: Label = %AttackValue
@onready var _defense_value: Label = %DefenseValue
@onready var _beats_label: Label = %BeatsLabel


func show_piece(type: PieceType.Id, adapted: bool = false) -> void:
	_picture.show_piece(type, Side.Id.RED, false, adapted)
	_name_label.text = PieceNames.display_name(type)
	_count_label.text = Translated.text(&"RULES_COUNT", {"count": PieceType.army_count(type)})
	_move_label.text = Translated.text(_REACH_KEYS[MovementCatalog.rule_for(type).reach()])
	_note_label.visible = _NOTE_KEYS.has(type)
	_note_label.text = Translated.text(_NOTE_KEYS[type]) if _NOTE_KEYS.has(type) else ""
	_attack_pips.show_value(PieceType.attack_strength(type))
	_defense_pips.show_value(PieceType.defense_strength(type))
	_attack_value.text = str(PieceType.attack_strength(type))
	_defense_value.text = str(PieceType.defense_strength(type))
	_beats_label.text = _beaten_text(type)


func _beaten_text(type: PieceType.Id) -> String:
	var beaten: Array[PieceType.Id] = PieceGuide.beaten_by(type)
	if beaten.is_empty():
		return Translated.text(&"RULES_BEATS_NOBODY")
	var names: PackedStringArray = []
	for defender: PieceType.Id in beaten:
		names.append(PieceNames.display_name(defender))
	return ", ".join(names)
