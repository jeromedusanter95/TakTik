class_name Main
extends Node
## Composition root: builds what the game needs and hands it out.

const SETTINGS_PATH: String = "user://settings.cfg"

## One entry per Difficulty, in the order the menu lists them.
@export var bot_profiles: Array[BotProfile] = []

## Remembers the chosen language. Left null, the game keeps it in
## SETTINGS_PATH; tests set their own before the node enters the tree.
var language_store: LanguageStore = null

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _language: String = Languages.ENGLISH

@onready var _main_menu: MainMenu = %MainMenu
@onready var _local_match: LocalMatch = %LocalMatch


func _ready() -> void:
	_rng.randomize()
	if language_store == null:
		language_store = ConfigFileLanguageStore.new(SETTINGS_PATH)
	_use_language(Languages.initial(language_store.load_language(), OS.get_locale_language()))
	_main_menu.show_difficulties(bot_profiles)
	_main_menu.language_switch_requested.connect(_on_language_switch_requested)
	_main_menu.two_players_chosen.connect(_on_two_players_chosen)
	_main_menu.bot_chosen.connect(_on_bot_chosen)
	_local_match.menu_requested.connect(_on_menu_requested)
	_show_menu()


func _on_two_players_chosen() -> void:
	_show_match()
	_local_match.start(func() -> MatchSession: return MatchSession.new(_rng))


func _on_bot_chosen(profile: BotProfile) -> void:
	_show_match()
	_local_match.start(func() -> MatchSession: return _session_against_bot(profile))


func _on_menu_requested() -> void:
	_show_menu()


func _on_language_switch_requested() -> void:
	_use_language(Languages.next(_language))
	language_store.save_language(_language)


func _use_language(code: String) -> void:
	_language = code
	TranslationServer.set_locale(code)
	_main_menu.show_language_switch(Languages.native_name(Languages.next(code)))


## The person plays Red and moves first; the Bot plays Green.
func _session_against_bot(profile: BotProfile) -> MatchSession:
	var bots: Dictionary[Side.Id, Bot] = {
		Side.Id.GREEN: Bot.new(profile, Side.Id.GREEN, _rng),
	}
	return MatchSession.new(_rng, bots)


func _show_menu() -> void:
	_local_match.hide()
	_main_menu.show()


func _show_match() -> void:
	_main_menu.hide()
	_local_match.show()
