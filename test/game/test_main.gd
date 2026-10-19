extends GutTest
## Drives the composition root: the home screen starts each kind of game and
## each game leads back to the home screen.

const MainScene: PackedScene = preload("res://main.tscn")
const MemoryPreferenceStore: GDScript = preload("res://test/preferences/memory_preference_store.gd")

var _main: Main = null
var _store: MemoryPreferenceStore = null


func before_each() -> void:
	_store = MemoryPreferenceStore.new()
	_store.values = {"language": "en"}
	_start_main()


func after_all() -> void:
	TranslationServer.set_locale(Languages.ENGLISH)


func test_the_game_opens_on_the_home_screen_with_three_difficulties() -> void:
	assert_true(_home().visible)
	assert_false(_match().visible)
	var difficulty: SegmentedControl = _home().get_node("%Difficulty")
	assert_eq(difficulty.option(2).text, "DIFFICULTY_HARD")


func test_every_screen_gets_the_theme() -> void:
	for screen: Control in [_home(), _match(), _rules()]:
		assert_not_null(screen.theme)
		assert_true(screen.theme.has_stylebox(&"normal", &"GoldButton"))


func test_two_players_opens_the_hot_seat_handoff() -> void:
	_button("%TwoPlayersButton", _home()).pressed.emit()
	assert_true(_match().visible)
	assert_false(_home().visible)
	assert_true(_handoff().visible)


func test_play_against_the_bot_opens_a_game_without_handoff() -> void:
	_button("%BotButton", _home()).pressed.emit()
	assert_true(_match().visible)
	assert_false(_handoff().visible)
	assert_eq(_status(), "Arrange your Army")
	assert_eq(_subtitle(), "Against Medium Bot", "Medium is the default Difficulty")


func test_the_chosen_difficulty_is_remembered() -> void:
	var difficulty: SegmentedControl = _home().get_node("%Difficulty")
	difficulty.option(0).pressed.emit()
	var saved: String = _store.values.get("difficulty", "")
	assert_eq(saved, "0")
	_button("%BotButton", _home()).pressed.emit()
	assert_eq(_subtitle(), "Against Easy Bot")


func test_the_rules_open_from_home_and_lead_back_home() -> void:
	_button("%RulesButton", _home()).pressed.emit()
	assert_true(_rules().visible)
	assert_false(_home().visible)
	_button("%HomeButton", _rules()).pressed.emit()
	assert_true(_home().visible)
	assert_false(_rules().visible)


func test_the_rules_practice_game_plays_the_last_chosen_difficulty() -> void:
	var difficulty: SegmentedControl = _home().get_node("%Difficulty")
	difficulty.option(2).pressed.emit()
	_button("%RulesButton", _home()).pressed.emit()
	_button("%PracticeButton", _rules()).pressed.emit()
	assert_true(_match().visible)
	assert_false(_rules().visible)
	assert_eq(_subtitle(), "Against Hard Bot")


func test_quitting_a_game_leads_back_home() -> void:
	_button("%TwoPlayersButton", _home()).pressed.emit()
	var menu: Node = _screen().get_node("%GameMenu")
	_button("%QuitButton", menu).pressed.emit()
	assert_true(_home().visible)
	assert_false(_match().visible)


func test_the_game_opens_in_the_saved_language() -> void:
	_main.free()
	_store.values = {"language": "fr"}
	_start_main()
	assert_eq(TranslationServer.get_locale(), "fr")


func test_the_language_switch_changes_and_remembers_the_language() -> void:
	var switch: SegmentedControl = _home().get_node("%LanguageSwitch")
	switch.option(0).pressed.emit()
	assert_eq(TranslationServer.get_locale(), "fr")
	var saved: String = _store.values["language"]
	assert_eq(saved, "fr")
	_button("%BotButton", _home()).pressed.emit()
	assert_eq(_status(), "Disposez votre Armée")
	TranslationServer.set_locale(Languages.ENGLISH)


func _start_main() -> void:
	var instance: Node = MainScene.instantiate()
	if instance is not Main:
		fail_test("main.tscn root should be a Main")
		return
	_main = instance
	_main.preference_store = _store
	add_child_autofree(_main)


func _home() -> HomeScreen:
	var node: Node = _main.get_node("%HomeScreen")
	assert_true(node is HomeScreen)
	return node


func _match() -> LocalMatch:
	var node: Node = _main.get_node("%LocalMatch")
	assert_true(node is LocalMatch)
	return node


func _rules() -> RulesScreen:
	var node: Node = _main.get_node("%RulesScreen")
	assert_true(node is RulesScreen)
	return node


func _screen() -> MatchScreen:
	var node: Node = _match().get_node("%MatchScreen")
	assert_true(node is MatchScreen)
	return node


func _handoff() -> HandoffScreen:
	var node: Node = _match().get_node("%HandoffScreen")
	assert_true(node is HandoffScreen)
	return node


func _status() -> String:
	var label: Label = _screen().get_node("%TopBar").get_node("%StatusLabel")
	return label.text


func _subtitle() -> String:
	var label: Label = _screen().get_node("%TopBar").get_node("%Subtitle")
	return label.text


func _button(path: String, owner_node: Node) -> Button:
	var node: Node = owner_node.get_node(path)
	assert_true(node is Button, path)
	return node
