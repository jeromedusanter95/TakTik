extends GutTest
## Drives the composition root: the menu starts each kind of game and the
## match screen leads back to the menu.

const MainScene: PackedScene = preload("res://main.tscn")

var _main: Main = null


func before_each() -> void:
	var instance: Node = MainScene.instantiate()
	if instance is not Main:
		fail_test("main.tscn root should be a Main")
		return
	_main = instance
	add_child_autofree(_main)


func test_the_game_opens_on_the_menu_with_three_difficulties() -> void:
	assert_true(_menu().visible)
	assert_false(_match().visible)
	assert_eq(_menu().get_node("%BotChoices").get_child_count(), 3)


func test_two_players_opens_the_hot_seat_handoff() -> void:
	_button("%TwoPlayersButton", _menu()).pressed.emit()
	assert_true(_match().visible)
	assert_false(_menu().visible)
	assert_true(_handoff().visible)


func test_a_difficulty_opens_a_game_against_the_bot_without_handoff() -> void:
	var first: Node = _menu().get_node("%BotChoices").get_child(0)
	assert_true(first is Button)
	var easy: Button = first
	easy.pressed.emit()
	assert_true(_match().visible)
	assert_false(_handoff().visible)
	assert_eq(_label("%StatusLabel").text, "Red: arrange your Army")


func test_the_menu_button_leads_back_to_the_menu() -> void:
	_button("%TwoPlayersButton", _menu()).pressed.emit()
	_button("%MenuButton", _match()).pressed.emit()
	assert_true(_menu().visible)
	assert_false(_match().visible)


func _menu() -> MainMenu:
	var node: Node = _main.get_node("%MainMenu")
	assert_true(node is MainMenu)
	return node


func _match() -> LocalMatch:
	var node: Node = _main.get_node("%LocalMatch")
	assert_true(node is LocalMatch)
	return node


func _handoff() -> HandoffScreen:
	var node: Node = _match().get_node("%HandoffScreen")
	assert_true(node is HandoffScreen)
	return node


func _label(path: String) -> Label:
	var node: Node = _match().get_node(path)
	assert_true(node is Label, path)
	return node


func _button(path: String, owner_node: Node) -> Button:
	var node: Node = owner_node.get_node(path)
	assert_true(node is Button, path)
	return node
