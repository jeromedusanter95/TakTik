class_name Main
extends Node
## Composition root: builds what the game needs, hands it out, and switches
## between the home screen and the games. Portrait screens get the phone
## layouts at a 390 by 844 reference size; the rest get the desktop layouts at
## 1440 by 900.

const SETTINGS_PATH: String = "user://settings.cfg"

## One entry per Difficulty, in the order the home screen lists them.
@export var bot_profiles: Array[BotProfile] = []
## The online server's WebSocket origin, such as wss://example.workers.dev.
@export var online_server_url: String = "ws://localhost:8787"

## Remembers the player's choices. Left null, the game keeps them in
## SETTINGS_PATH; tests set their own before the node enters the tree.
var preference_store: PreferenceStore = null

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _preferences: PlayerPreferences = null
var _phone: bool = false
var _fitted: bool = false

@onready var _home: HomeScreen = %HomeScreen
@onready var _local_match: LocalMatch = %LocalMatch
@onready var _online_match: OnlineMatch = %OnlineMatch


func _ready() -> void:
	_rng.randomize()
	if preference_store == null:
		preference_store = ConfigFilePreferenceStore.new(SETTINGS_PATH)
	_preferences = PlayerPreferences.new(
		preference_store, OS.get_locale_language(), DeviceMotion.prefers_reduced_motion()
	)
	_preferences.changed.connect(_on_preferences_changed)
	TranslationServer.set_locale(_preferences.language)
	get_window().theme = TaktikTheme.build()
	_home.configure(online_server_url, _open_socket)
	_home.use_preferences(_preferences)
	_home.show_difficulties(bot_profiles)
	_local_match.use_preferences(_preferences)
	_online_match.use_preferences(_preferences)
	_online_match.configure(online_server_url, _open_socket, _rng, Time.get_ticks_msec)
	_home.two_players_chosen.connect(_on_two_players_chosen)
	_home.bot_chosen.connect(_on_bot_chosen)
	_home.paired.connect(_on_paired)
	_local_match.menu_requested.connect(_show_home)
	_online_match.lobby_requested.connect(_show_home)
	get_window().size_changed.connect(_fit_window)
	_fit_window()
	_show_home()


func _on_two_players_chosen() -> void:
	_show_only(_local_match)
	_local_match.start(func() -> MatchSession: return MatchSession.new(_rng))


func _on_bot_chosen(profile: BotProfile) -> void:
	_show_only(_local_match)
	var bot_name: String = Translated.text(
		&"MENU_BOT_BUTTON", {"difficulty": Translated.text(profile.display_name)}
	)
	_local_match.start(func() -> MatchSession: return _session_against_bot(profile), bot_name)


func _on_paired(seat: PairedSeat, nickname: String) -> void:
	_show_only(_online_match)
	_online_match.play(seat, nickname)


func _on_preferences_changed() -> void:
	TranslationServer.set_locale(_preferences.language)


## The person plays Red and moves first; the Bot plays Green.
func _session_against_bot(profile: BotProfile) -> MatchSession:
	var bots: Dictionary[Side.Id, Bot] = {
		Side.Id.GREEN: Bot.new(profile, Side.Id.GREEN, _rng),
	}
	return MatchSession.new(_rng, bots)


func _open_socket() -> WireSocket:
	return WebSocketWireSocket.new()


func _show_home() -> void:
	_show_only(_home)
	_home.open()


func _show_only(screen: Control) -> void:
	for candidate: Control in [_home, _local_match, _online_match]:
		candidate.visible = candidate == screen


## Portrait windows use the phone layouts, landscape ones the desktop
## layouts, each at its own reference size.
func _fit_window() -> void:
	var window: Window = get_window()
	var portrait: bool = window.size.y > window.size.x
	window.content_scale_size = UiTokens.PHONE_SIZE if portrait else UiTokens.DESKTOP_SIZE
	if _fitted and portrait == _phone:
		return
	_fitted = true
	_phone = portrait
	_home.set_phone(portrait)
	_local_match.set_phone(portrait)
	_online_match.set_phone(portrait)
