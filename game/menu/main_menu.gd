class_name MainMenu
extends Control
## The first screen: choose two people on one device, or a Bot Difficulty.

signal two_players_chosen
signal bot_chosen(profile: BotProfile)

const ChoiceButtonScene: PackedScene = preload("res://game/menu/choice_button.tscn")

@onready var _two_players_button: Button = %TwoPlayersButton
@onready var _bot_choices: VBoxContainer = %BotChoices


func _ready() -> void:
	_two_players_button.pressed.connect(_on_two_players_pressed)


## Adds one button per Difficulty, in the order given.
func show_difficulties(profiles: Array[BotProfile]) -> void:
	for profile: BotProfile in profiles:
		var instance: Node = ChoiceButtonScene.instantiate()
		if instance is not Button:
			push_error("choice_button.tscn root should be a Button")
			instance.free()
			return
		var button: Button = instance
		button.text = "%s Bot" % profile.display_name
		button.pressed.connect(_on_difficulty_pressed.bind(profile))
		_bot_choices.add_child(button)


func _on_two_players_pressed() -> void:
	two_players_chosen.emit()


func _on_difficulty_pressed(profile: BotProfile) -> void:
	bot_chosen.emit(profile)
