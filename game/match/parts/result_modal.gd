class_name ResultModal
extends Control
## The end of a game, over the dimmed Board: the winner's King (or the
## player's lost Princess), the title, why it ended, the last Fight, what
## each side lost, and the next step.

signal primary_pressed
signal secondary_pressed

const RISE: float = 40.0
const RISE_TIME: float = 0.6
const POP_DELAY: float = 0.2
const POP_TIME: float = 0.5
const FLOAT_HEIGHT: float = 6.0
const FLOAT_PERIOD: float = 4.0

var reduced_motion: bool = false

var _tweens: Array[Tween] = []

@onready var _rays: SunRays = %Rays
@onready var _stack: VBoxContainer = %Stack
@onready var _hero: PiecePicture = %Hero
@onready var _sparkles: Array[Sparkle] = [%SparkleA, %SparkleB, %SparkleC]
@onready var _title_label: Label = %TitleLabel
@onready var _reason_label: Label = %ReasonLabel
@onready var _final_fight: PanelContainer = %FinalFight
@onready var _fight_attacker: PiecePicture = %FightAttacker
@onready var _fight_defender: PiecePicture = %FightDefender
@onready var _fight_label: Label = %FightLabel
@onready var _red_loss_title: Label = %RedLossTitle
@onready var _red_tray: GraveyardTray = %RedTray
@onready var _green_loss_title: Label = %GreenLossTitle
@onready var _green_tray: GraveyardTray = %GreenTray
@onready var _notice: PanelContainer = %Notice
@onready var _notice_label: Label = %NoticeLabel
@onready var _primary_button: Button = %PrimaryButton
@onready var _secondary_button: Button = %SecondaryButton


func _ready() -> void:
	_primary_button.pressed.connect(_on_primary_pressed)
	_secondary_button.pressed.connect(_on_secondary_pressed)
	hide()


func present(view: MatchResultView, adapted: bool = false) -> void:
	var victory: bool = view.mood == MatchResultView.Mood.VICTORY
	_title_label.text = view.title
	_title_label.theme_type_variation = &"DisplayL" if victory else &"DisplayLPrimary"
	_reason_label.text = view.reason
	_hero.show_piece(view.hero_type, view.hero_side, view.mood == MatchResultView.Mood.DEFEAT, adapted)
	_final_fight.visible = view.final_fight != null
	if view.final_fight != null:
		var fight: PublicMoveEvent = view.final_fight
		_fight_attacker.show_piece(fight.attacker_type, fight.mover_side, fight.outcome != FightOutcome.Id.ATTACKER_WINS, adapted)
		_fight_defender.show_piece(
			fight.defender_type, Side.opponent(fight.mover_side), fight.outcome != FightOutcome.Id.DEFENDER_WINS, adapted
		)
		_fight_label.text = FightCard.result_text(fight)
	_red_loss_title.text = view.red_loss_title
	_red_tray.show_graveyard(view.red_losses, Side.Id.RED, adapted)
	_green_loss_title.text = view.green_loss_title
	_green_tray.show_graveyard(view.green_losses, Side.Id.GREEN, adapted)
	_primary_button.text = view.primary_label
	_secondary_button.text = view.secondary_label
	show_notice("")
	_rays.visible = victory
	for sparkle: Sparkle in _sparkles:
		sparkle.visible = victory
	show()
	_animate_in(victory)


## The Rematch button's text and whether it can be pressed.
func show_primary(text: String, enabled: bool) -> void:
	_primary_button.text = text
	_primary_button.disabled = not enabled


## A green notice above the buttons, such as "Bob wants a Rematch"; empty
## hides it.
func show_notice(text: String) -> void:
	_notice_label.text = text
	_notice.visible = not text.is_empty()


func close() -> void:
	_stop_tweens()
	_rays.stop_turning()
	for sparkle: Sparkle in _sparkles:
		sparkle.stop()
	hide()


func _animate_in(victory: bool) -> void:
	_stop_tweens()
	if reduced_motion:
		_stack.modulate.a = 1.0
		_title_label.scale = Vector2.ONE
		return
	_stack.modulate.a = 0.0
	# The CenterContainer places the stack once it is shown.
	await get_tree().process_frame
	if not visible:
		return
	var rest_y: float = _stack.position.y
	_stack.position.y = rest_y + RISE
	var rise: Tween = create_tween()
	rise.tween_property(_stack, "position:y", rest_y, RISE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rise.parallel().tween_property(_stack, "modulate:a", 1.0, RISE_TIME * 0.6)
	_tweens.append(rise)
	_title_label.pivot_offset_ratio = Vector2(0.5, 0.5)
	_title_label.scale = Vector2.ONE * 0.4
	var pop: Tween = create_tween()
	pop.tween_interval(POP_DELAY)
	pop.tween_property(_title_label, "scale", Vector2.ONE * 1.15, POP_TIME * 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(_title_label, "scale", Vector2.ONE, POP_TIME * 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_tweens.append(pop)
	var hero_rest: float = 0.0
	_hero.position.y = hero_rest
	var float_loop: Tween = create_tween().set_loops()
	float_loop.tween_property(_hero, "position:y", hero_rest - FLOAT_HEIGHT, FLOAT_PERIOD / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	float_loop.tween_property(_hero, "position:y", hero_rest, FLOAT_PERIOD / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tweens.append(float_loop)
	if victory:
		_rays.start_turning()
		for index: int in _sparkles.size():
			_sparkles[index].twinkle(1.6 + index * 0.3, index * 0.4)


func _stop_tweens() -> void:
	for tween: Tween in _tweens:
		tween.kill()
	_tweens.clear()


func _on_primary_pressed() -> void:
	primary_pressed.emit()


func _on_secondary_pressed() -> void:
	secondary_pressed.emit()
