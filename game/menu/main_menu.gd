class_name MainMenu
extends Control
## The first screen: choose two people on one device, an online game, or a Bot
## Difficulty, and the language.

signal two_players_chosen
signal online_chosen
signal bot_chosen(profile: BotProfile)
signal language_switch_requested

const ChoiceButtonScene: PackedScene = preload("res://game/menu/choice_button.tscn")

var _difficulty_buttons: Dictionary[Button, BotProfile] = {}

@onready var _two_players_button: Button = %TwoPlayersButton
@onready var _online_button: Button = %OnlineButton
@onready var _bot_choices: VBoxContainer = %BotChoices
@onready var _language_button: Button = %LanguageButton


func _ready() -> void:
	_two_players_button.pressed.connect(_on_two_players_pressed)
	_online_button.pressed.connect(_on_online_pressed)
	_language_button.pressed.connect(_on_language_pressed)


## Relabels the Difficulty buttons, which auto translation cannot reach
## because their text is built in code.
func _notification(what: int) -> void:
	if what != NOTIFICATION_TRANSLATION_CHANGED:
		return
	for button: Button in _difficulty_buttons:
		button.text = _difficulty_text(_difficulty_buttons[button])


## Adds one button per Difficulty, in the order given.
func show_difficulties(profiles: Array[BotProfile]) -> void:
	for profile: BotProfile in profiles:
		var instance: Node = ChoiceButtonScene.instantiate()
		if instance is not Button:
			push_error("choice_button.tscn root should be a Button")
			instance.free()
			return
		var button: Button = instance
		button.text = _difficulty_text(profile)
		button.pressed.connect(_on_difficulty_pressed.bind(profile))
		_difficulty_buttons[button] = profile
		_bot_choices.add_child(button)


## Labels the language button with the language a press switches to, written
## in that language.
func show_language_switch(next_language_name: String) -> void:
	_language_button.text = next_language_name


func _difficulty_text(profile: BotProfile) -> String:
	var difficulty: String = Translated.text(profile.display_name)
	return Translated.text(&"MENU_BOT_BUTTON", {"difficulty": difficulty})


func _on_two_players_pressed() -> void:
	two_players_chosen.emit()


func _on_online_pressed() -> void:
	online_chosen.emit()


func _on_difficulty_pressed(profile: BotProfile) -> void:
	bot_chosen.emit(profile)


func _on_language_pressed() -> void:
	language_switch_requested.emit()
