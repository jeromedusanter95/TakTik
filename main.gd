class_name Main
extends Node
## Composition root: builds what the game needs and hands it out.

## One entry per Difficulty, in the order the menu lists them.
@export var bot_profiles: Array[BotProfile] = []

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var _main_menu: MainMenu = %MainMenu
@onready var _local_match: LocalMatch = %LocalMatch


func _ready() -> void:
	_rng.randomize()
	_main_menu.show_difficulties(bot_profiles)
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
