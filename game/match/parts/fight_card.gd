class_name FightCard
extends PanelContainer
## The last Fight: both Pieces revealed with their strengths, the loser grey
## and slashed, and who won.

@onready var _fight_row: HBoxContainer = %FightRow
@onready var _attacker_picture: PiecePicture = %AttackerPicture
@onready var _attacker_slash: LoserSlash = %AttackerSlash
@onready var _attack_label: Label = %AttackLabel
@onready var _defender_picture: PiecePicture = %DefenderPicture
@onready var _defender_slash: LoserSlash = %DefenderSlash
@onready var _defense_label: Label = %DefenseLabel
@onready var _result_label: Label = %ResultLabel
@onready var _empty_label: Label = %EmptyLabel


## Shows the Fight [param event] caused, which must have one.
func show_fight(event: PublicMoveEvent, adapted: bool = false) -> void:
	var defender_side: Side.Id = Side.opponent(event.mover_side)
	var attacker_lost: bool = event.outcome != FightOutcome.Id.ATTACKER_WINS
	var defender_lost: bool = event.outcome != FightOutcome.Id.DEFENDER_WINS
	_attacker_picture.show_piece(event.attacker_type, event.mover_side, attacker_lost, adapted)
	_defender_picture.show_piece(event.defender_type, defender_side, defender_lost, adapted)
	_attacker_slash.visible = attacker_lost
	_defender_slash.visible = defender_lost
	_attack_label.text = Translated.text(
		&"FIGHT_ATTACK", {"value": PieceType.attack_strength(event.attacker_type)}
	)
	_defense_label.text = Translated.text(
		&"FIGHT_DEFENSE", {"value": PieceType.defense_strength(event.defender_type)}
	)
	_result_label.text = FightCard.result_text(event)
	_fight_row.visible = true
	_result_label.visible = true
	_empty_label.visible = false


## No Fight has happened yet.
func show_none() -> void:
	_fight_row.visible = false
	_result_label.visible = false
	_empty_label.visible = true


## Who won [param event]'s Fight, in a few words.
static func result_text(event: PublicMoveEvent) -> String:
	match event.outcome:
		FightOutcome.Id.ATTACKER_WINS:
			return Translated.text(&"FIGHT_RESULT_WINS", {"piece": PieceNames.display_name(event.attacker_type)})
		FightOutcome.Id.DEFENDER_WINS:
			return Translated.text(&"FIGHT_RESULT_HOLDS", {"piece": PieceNames.display_name(event.defender_type)})
		_:
			return Translated.text(&"FIGHT_RESULT_BOTH")
