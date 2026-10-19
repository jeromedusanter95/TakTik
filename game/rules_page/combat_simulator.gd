class_name CombatSimulator
extends PanelContainer
## Pick an attacker and a defender among the nine Piece Types and see how the
## Fight would end, decided by the game's own rule.

const TOKEN_SIZE: Vector2 = Vector2(50, 50)
const DEFAULT_ATTACKER: PieceType.Id = PieceType.Id.KNIGHT
const DEFAULT_DEFENDER: PieceType.Id = PieceType.Id.THIEF
const POP_SECONDS: float = 0.3

## Shows the verdict at once instead of fading it in.
var reduced_motion: bool = false

var _attacker: PieceType.Id = DEFAULT_ATTACKER
var _defender: PieceType.Id = DEFAULT_DEFENDER
var _adapted: bool = false
var _attacker_tokens: Dictionary[PieceType.Id, Button] = {}
var _defender_tokens: Dictionary[PieceType.Id, Button] = {}
var _pop: Tween = null

@onready var _attacker_row: HFlowContainer = %AttackerRow
@onready var _defender_row: HFlowContainer = %DefenderRow
@onready var _result: VBoxContainer = %Result
@onready var _attacker_picture: PiecePicture = %AttackerPicture
@onready var _defender_picture: PiecePicture = %DefenderPicture
@onready var _attacker_slash: LoserSlash = %AttackerSlash
@onready var _defender_slash: LoserSlash = %DefenderSlash
@onready var _verdict_label: Label = %VerdictLabel
@onready var _reason_label: Label = %ReasonLabel
@onready var _princess_pill: PanelContainer = %PrincessPill


func _ready() -> void:
	_attacker_tokens = _add_tokens(_attacker_row, _on_attacker_chosen)
	_defender_tokens = _add_tokens(_defender_row, _on_defender_chosen)
	_attacker_tokens[_attacker].set_pressed_no_signal(true)
	_defender_tokens[_defender].set_pressed_no_signal(true)
	refresh()


func attacker() -> PieceType.Id:
	return _attacker


func defender() -> PieceType.Id:
	return _defender


## Picks [param type] in the attacker row, as a tap on its token does.
func choose_attacker(type: PieceType.Id) -> void:
	_attacker_tokens[type].button_pressed = true


## Picks [param type] in the defender row, as a tap on its token does.
func choose_defender(type: PieceType.Id) -> void:
	_defender_tokens[type].button_pressed = true


## Draws the green Army blue instead.
func set_adapted(adapted: bool) -> void:
	_adapted = adapted
	refresh()


## Draws the tokens and the verdict again, in the current language.
func refresh() -> void:
	for type: PieceType.Id in _attacker_tokens:
		_show_token(_attacker_tokens[type], type, Side.Id.RED)
		_show_token(_defender_tokens[type], type, Side.Id.GREEN)
	_show_verdict()


func _add_tokens(row: HFlowContainer, chosen: Callable) -> Dictionary[PieceType.Id, Button]:
	var tokens: Dictionary[PieceType.Id, Button] = {}
	var group: ButtonGroup = ButtonGroup.new()
	for type: PieceType.Id in PieceGuide.by_attack():
		var token: Button = Button.new()
		token.theme_type_variation = &"SimToken"
		token.custom_minimum_size = TOKEN_SIZE
		token.toggle_mode = true
		token.button_group = group
		token.expand_icon = true
		token.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		token.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		token.toggled.connect(chosen.bind(type))
		tokens[type] = token
		row.add_child(token)
	return tokens


func _show_token(token: Button, type: PieceType.Id, side: Side.Id) -> void:
	token.icon = PieceArt.token(type, side, _adapted)
	token.tooltip_text = PieceNames.display_name(type)


func _show_verdict() -> void:
	var verdict: CombatVerdict = CombatVerdict.judge(_attacker, _defender)
	_attacker_picture.show_piece(_attacker, Side.Id.RED, false, _adapted)
	_defender_picture.show_piece(_defender, Side.Id.GREEN, false, _adapted)
	var both: bool = verdict.kind == CombatVerdict.Kind.BOTH_ELIMINATED
	var attacker_lost: bool = both or verdict.kind == CombatVerdict.Kind.DEFENDER_WINS
	var defender_lost: bool = both or verdict.kind == CombatVerdict.Kind.ATTACKER_WINS
	_attacker_picture.set_grey(1.0 if attacker_lost else 0.0)
	_defender_picture.set_grey(1.0 if defender_lost else 0.0)
	_attacker_slash.visible = attacker_lost
	_defender_slash.visible = defender_lost
	_verdict_label.text = _verdict_text(verdict)
	_reason_label.text = _reason_text(verdict)
	_princess_pill.visible = verdict.princess_captured


func _verdict_text(verdict: CombatVerdict) -> String:
	match verdict.kind:
		CombatVerdict.Kind.NO_FIGHT:
			return Translated.text(&"RULES_VERDICT_NO_FIGHT")
		CombatVerdict.Kind.ATTACKER_WINS:
			return Translated.text(&"RULES_VERDICT_WINS", {"piece": PieceNames.display_name(_attacker)})
		CombatVerdict.Kind.DEFENDER_WINS:
			return Translated.text(&"RULES_VERDICT_WINS", {"piece": PieceNames.display_name(_defender)})
		_:
			return Translated.text(&"RULES_VERDICT_BOTH")


func _reason_text(verdict: CombatVerdict) -> String:
	var attacker_name: Dictionary[String, Variant] = {"piece": PieceNames.display_name(_attacker)}
	var strengths: Dictionary[String, Variant] = {
		"attack": PieceType.attack_strength(_attacker),
		"defense": PieceType.defense_strength(_defender),
	}
	match verdict.reason:
		CombatVerdict.Reason.NEVER_MOVES:
			return Translated.text(&"RULES_REASON_NEVER_MOVES", attacker_name)
		CombatVerdict.Reason.NEVER_ATTACKS:
			return Translated.text(&"RULES_REASON_NEVER_ATTACKS", attacker_name)
		CombatVerdict.Reason.MAGICIAN_KILLS_MONSTER:
			return Translated.text(&"RULES_REASON_MAGICIAN")
		CombatVerdict.Reason.MONSTER_DEFENDS:
			return Translated.text(&"RULES_REASON_MONSTER")
		CombatVerdict.Reason.STRONGER_ATTACK:
			return Translated.text(&"RULES_REASON_STRONGER_ATTACK", strengths)
		CombatVerdict.Reason.STRONGER_DEFENSE:
			return Translated.text(&"RULES_REASON_STRONGER_DEFENSE", strengths)
		_:
			return Translated.text(&"RULES_REASON_EQUAL", strengths)


## Fades the new verdict in, unless motion is reduced.
func _pop_result() -> void:
	if _pop != null:
		_pop.kill()
	_result.modulate.a = 1.0
	if reduced_motion:
		return
	_result.modulate.a = 0.0
	_pop = create_tween()
	_pop.tween_property(_result, "modulate:a", 1.0, POP_SECONDS).set_ease(Tween.EASE_OUT)


func _on_attacker_chosen(on: bool, type: PieceType.Id) -> void:
	if not on:
		return
	_attacker = type
	_show_verdict()
	_pop_result()


func _on_defender_chosen(on: bool, type: PieceType.Id) -> void:
	if not on:
		return
	_defender = type
	_show_verdict()
	_pop_result()
