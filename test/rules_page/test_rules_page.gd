extends GutTest
## The rules page as a player reads it: the piece cards, the Fight simulator,
## its buttons and the overlay used during a game.

const RulesScreenScene: PackedScene = preload("res://game/rules_page/rules_screen.tscn")
const RulesOverlayScene: PackedScene = preload("res://game/rules_page/rules_overlay.tscn")
const MemoryPreferenceStore: GDScript = preload("res://test/preferences/memory_preference_store.gd")

var _screen: RulesScreen = null
var _preferences: PlayerPreferences = null


func before_each() -> void:
	TranslationServer.set_locale(Languages.ENGLISH)
	var store: MemoryPreferenceStore = MemoryPreferenceStore.new()
	_preferences = PlayerPreferences.new(store, "en", true)
	var instance: Node = RulesScreenScene.instantiate()
	if instance is not RulesScreen:
		fail_test("rules_screen.tscn root should be a RulesScreen")
		return
	_screen = instance
	_screen.theme = TaktikTheme.build()
	add_child_autofree(_screen)
	# Free anchors, so the test can size the page as a screen would be.
	_screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_screen.size = Vector2(1440, 900)
	_screen.use_preferences(_preferences)
	watch_signals(_screen)


func after_all() -> void:
	TranslationServer.set_locale(Languages.ENGLISH)


func test_the_nine_piece_cards_run_from_the_strongest_attack() -> void:
	var grid: GridContainer = _content().get_node("%PieceGrid")
	assert_eq(grid.get_child_count(), 9)
	var first: PieceGuideCard = grid.get_child(0)
	assert_eq(_text(first, "%NameLabel"), "Thief")
	var last: PieceGuideCard = grid.get_child(8)
	assert_eq(_text(last, "%NameLabel"), "Princess")


func test_a_piece_card_shows_count_movement_and_whom_it_beats() -> void:
	var magician: PieceGuideCard = _content().piece_card(PieceType.Id.MAGICIAN)
	assert_eq(_text(magician, "%CountLabel"), "× 2")
	assert_eq(_text(magician, "%MoveLabel"), "1 square")
	assert_eq(_text(magician, "%BeatsLabel"), "Thief, Buffoon, Monster, Princess")


func test_pieces_that_never_attack_say_so() -> void:
	var monster: PieceGuideCard = _content().piece_card(PieceType.Id.MONSTER)
	assert_eq(_text(monster, "%MoveLabel"), "Never moves")
	assert_eq(_text(monster, "%BeatsLabel"), "Never attacks")
	var princess: PieceGuideCard = _content().piece_card(PieceType.Id.PRINCESS)
	assert_eq(_text(princess, "%BeatsLabel"), "Never attacks")


func test_the_knight_and_the_soldier_have_no_note() -> void:
	var knight: PieceGuideCard = _content().piece_card(PieceType.Id.KNIGHT)
	assert_false(_control(knight, "%NoteLabel").visible)


func test_the_simulator_opens_on_a_knight_attacking_a_thief() -> void:
	var simulator: CombatSimulator = _content().simulator()
	assert_eq(_text(simulator, "%VerdictLabel"), "Knight wins")
	assert_eq(_text(simulator, "%ReasonLabel"), "Attack 4 against Defense 0: the attack goes through.")
	assert_false(_control(simulator, "%AttackerSlash").visible)
	assert_true(_control(simulator, "%DefenderSlash").visible)
	assert_false(_control(simulator, "%PrincessPill").visible)


func test_a_monster_picked_as_attacker_starts_no_fight() -> void:
	var simulator: CombatSimulator = _content().simulator()
	simulator.choose_attacker(PieceType.Id.MONSTER)
	assert_eq(simulator.attacker(), PieceType.Id.MONSTER)
	assert_eq(_text(simulator, "%VerdictLabel"), "No fight")
	assert_eq(_text(simulator, "%ReasonLabel"), "Monster never moves, so it cannot attack.")
	assert_false(_control(simulator, "%AttackerSlash").visible)
	assert_false(_control(simulator, "%DefenderSlash").visible)


func test_a_tie_greys_both_pieces() -> void:
	var simulator: CombatSimulator = _content().simulator()
	simulator.choose_defender(PieceType.Id.KNIGHT)
	assert_eq(_text(simulator, "%VerdictLabel"), "Both are eliminated")
	assert_true(_control(simulator, "%AttackerSlash").visible)
	assert_true(_control(simulator, "%DefenderSlash").visible)


func test_beating_the_princess_announces_the_victory() -> void:
	var simulator: CombatSimulator = _content().simulator()
	simulator.choose_defender(PieceType.Id.PRINCESS)
	assert_true(_control(simulator, "%PrincessPill").visible)


func test_the_page_follows_the_language() -> void:
	TranslationServer.set_locale("fr")
	var magician: PieceGuideCard = _content().piece_card(PieceType.Id.MAGICIAN)
	assert_eq(_text(magician, "%NameLabel"), "Magicien")
	assert_eq(_text(_content().simulator(), "%VerdictLabel"), "Chevalier l'emporte")


func test_home_and_both_practice_buttons_report_their_press() -> void:
	_button(_screen, "%HomeButton").pressed.emit()
	assert_signal_emitted(_screen, "home_pressed")
	_button(_screen, "%PracticeButton").pressed.emit()
	_button(_content(), "%PracticeButton").pressed.emit()
	assert_signal_emit_count(_screen, "practice_pressed", 2)


func test_wide_pages_lay_cards_side_by_side_in_three_columns() -> void:
	await wait_process_frames(2)
	var grid: GridContainer = _content().get_node("%PieceGrid")
	assert_eq(grid.columns, 3)
	var wins: BoxContainer = _content().get_node("%WinCards")
	assert_false(wins.vertical)


func test_phone_pages_stack_everything_in_one_column() -> void:
	_screen.size = Vector2(390, 844)
	_screen.set_layout(ScreenLayout.Id.PHONE)
	await wait_process_frames(2)
	var grid: GridContainer = _content().get_node("%PieceGrid")
	assert_eq(grid.columns, 1)
	var wins: BoxContainer = _content().get_node("%WinCards")
	assert_true(wins.vertical)
	assert_eq(_button(_screen, "%PracticeButton").text, "", "phones keep the icon only")
	var layout: Control = _screen.get_node("Layout")
	var widest: float = layout.get_combined_minimum_size().x
	assert_lte(widest, 390.0, "nothing forces the page wider than the phone")


func test_adapted_colours_draw_the_enemy_zone_blue() -> void:
	_preferences.set_adapted_colours(true)
	var rule: ColorRect = _content().get_node("%EnemyZoneRule")
	assert_eq(rule.color, UiTokens.BLUE_400)


func test_the_overlay_hides_the_practice_game_and_closes_from_its_button() -> void:
	var overlay: RulesOverlay = _overlay()
	overlay.open()
	assert_true(overlay.visible)
	assert_false(_control(overlay.content(), "%PracticeButton").visible)
	_button(overlay, "%CloseButton").pressed.emit()
	assert_false(overlay.visible)


func test_a_tap_outside_the_overlay_panel_closes_it() -> void:
	var overlay: RulesOverlay = _overlay()
	overlay.open()
	var tap: InputEventMouseButton = InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	var veil: Control = overlay.get_node("%Veil")
	veil.gui_input.emit(tap)
	assert_false(overlay.visible)


func test_the_overlay_fills_a_phone_screen() -> void:
	var overlay: RulesOverlay = _overlay()
	overlay.set_phone(true)
	var panel: Control = overlay.get_node("%Panel")
	assert_eq(panel.anchor_left, 0.0)
	assert_eq(panel.offset_left, 0.0)


func _content() -> RulesContent:
	return _screen.content()


func _overlay() -> RulesOverlay:
	var instance: Node = RulesOverlayScene.instantiate()
	if instance is not RulesOverlay:
		fail_test("rules_overlay.tscn root should be a RulesOverlay")
		return null
	var overlay: RulesOverlay = instance
	overlay.theme = TaktikTheme.build()
	add_child_autofree(overlay)
	overlay.use_preferences(_preferences)
	return overlay


func _text(owner_node: Node, path: String) -> String:
	var node: Node = owner_node.get_node(path)
	if node is not Label:
		fail_test("%s should be a Label" % path)
		return ""
	var label: Label = node
	return label.text


func _control(owner_node: Node, path: String) -> Control:
	var node: Node = owner_node.get_node(path)
	if node is not Control:
		fail_test("%s should be a Control" % path)
		return null
	var control: Control = node
	return control


func _button(owner_node: Node, path: String) -> Button:
	var node: Node = owner_node.get_node(path)
	if node is not Button:
		fail_test("%s should be a Button" % path)
		return null
	var button: Button = node
	return button
