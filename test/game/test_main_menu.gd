extends GutTest
## The menu lists one Bot per Difficulty and reports what was chosen.

const MainMenuScene: PackedScene = preload("res://game/menu/main_menu.tscn")

var _menu: MainMenu = null


func before_each() -> void:
	var instance: Node = MainMenuScene.instantiate()
	if instance is not MainMenu:
		fail_test("main_menu.tscn root should be a MainMenu")
		return
	_menu = instance
	add_child_autofree(_menu)
	watch_signals(_menu)


func test_two_players_button_reports_the_choice() -> void:
	_button("%TwoPlayersButton").pressed.emit()
	assert_signal_emitted(_menu, "two_players_chosen")


func test_one_button_per_difficulty_in_order() -> void:
	_menu.show_difficulties([_profile("Easy"), _profile("Hard")])
	var buttons: Array[Button] = _bot_buttons()
	assert_eq(buttons.size(), 2)
	assert_eq(buttons[0].text, "Easy Bot")
	assert_eq(buttons[1].text, "Hard Bot")


func test_every_difficulty_button_gives_press_feedback() -> void:
	_menu.show_difficulties([_profile("Easy")])
	var feedback: Array[Node] = _bot_buttons()[0].find_children("*", "PressScaleFeedback")
	assert_eq(feedback.size(), 1)


func test_a_difficulty_button_reports_its_profile() -> void:
	var hard: BotProfile = _profile("Hard")
	_menu.show_difficulties([_profile("Easy"), hard])
	_bot_buttons()[1].pressed.emit()
	assert_signal_emitted_with_parameters(_menu, "bot_chosen", [hard])


func _profile(display_name: String) -> BotProfile:
	var profile: BotProfile = BotProfile.new()
	profile.display_name = display_name
	return profile


func _bot_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for child: Node in _menu.get_node("%BotChoices").get_children():
		if child is Button:
			buttons.append(child)
	return buttons


func _button(path: String) -> Button:
	var node: Node = _menu.get_node(path)
	assert_true(node is Button, path)
	return node
