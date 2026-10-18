extends GutTest
## Drives the composition root: the menu starts each kind of game and the
## match screen leads back to the menu.

const MainScene: PackedScene = preload("res://main.tscn")

var _main: Main = null
var _store: FakeLanguageStore = null


func before_each() -> void:
	_store = FakeLanguageStore.new(Languages.ENGLISH)
	_start_main()


func after_all() -> void:
	TranslationServer.set_locale(Languages.ENGLISH)


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


func test_the_game_opens_in_the_saved_language() -> void:
	_main.free()
	_store = FakeLanguageStore.new("fr")
	_start_main()
	assert_eq(TranslationServer.get_locale(), "fr")
	assert_eq(_button("%LanguageButton", _menu()).text, "English")


func test_the_language_button_switches_to_french_and_remembers_it() -> void:
	assert_eq(_button("%LanguageButton", _menu()).text, "Français")
	_button("%LanguageButton", _menu()).pressed.emit()
	assert_eq(TranslationServer.get_locale(), "fr")
	assert_eq(_store.saved, "fr")
	assert_eq(_button("%LanguageButton", _menu()).text, "English")
	var first: Node = _menu().get_node("%BotChoices").get_child(0)
	assert_true(first is Button)
	var easy: Button = first
	assert_eq(easy.text, "Bot Facile")
	easy.pressed.emit()
	assert_eq(_label("%StatusLabel").text, "Rouge : disposez votre Armée")


func test_play_online_opens_the_nickname_entry_and_back_returns_to_the_menu() -> void:
	_button("%OnlineButton", _menu()).pressed.emit()
	assert_true(_online().visible)
	assert_false(_menu().visible)
	assert_false(_match().visible)
	var panel: Node = _online().get_node("%FindOpponentPanel")
	assert_true(panel is FindOpponentPanel and (panel as FindOpponentPanel).visible)
	_button("%BackButton", panel).pressed.emit()
	assert_true(_menu().visible)
	assert_false(_online().visible)


func test_pressing_the_language_button_twice_returns_to_english() -> void:
	_button("%LanguageButton", _menu()).pressed.emit()
	_button("%LanguageButton", _menu()).pressed.emit()
	assert_eq(TranslationServer.get_locale(), Languages.ENGLISH)
	assert_eq(_store.saved, Languages.ENGLISH)


func _start_main() -> void:
	var instance: Node = MainScene.instantiate()
	if instance is not Main:
		fail_test("main.tscn root should be a Main")
		return
	_main = instance
	_main.language_store = _store
	add_child_autofree(_main)


func _menu() -> MainMenu:
	var node: Node = _main.get_node("%MainMenu")
	assert_true(node is MainMenu)
	return node


func _match() -> LocalMatch:
	var node: Node = _main.get_node("%LocalMatch")
	assert_true(node is LocalMatch)
	return node


func _online() -> OnlineMatch:
	var node: Node = _main.get_node("%OnlineMatch")
	assert_true(node is OnlineMatch)
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


class FakeLanguageStore:
	extends LanguageStore

	var saved: String = ""


	func _init(initial: String) -> void:
		saved = initial


	func load_language() -> String:
		return saved


	func save_language(code: String) -> void:
		saved = code
