class_name Main
extends Node
## Composition root: builds what the game needs, hands it out, and switches
## between the home screen and the games, in the layout the screen's width
## calls for (see ScreenLayout).

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
var _layout: ScreenLayout.Id = ScreenLayout.Id.WIDE
var _fitted: bool = false

@onready var _home: HomeScreen = %HomeScreen
@onready var _local_match: LocalMatch = %LocalMatch
@onready var _online_match: OnlineMatch = %OnlineMatch
@onready var _sound: SoundPlayer = %SoundPlayer


func _ready() -> void:
	_rng.randomize()
	if preference_store == null:
		preference_store = ConfigFilePreferenceStore.new(SETTINGS_PATH)
	_preferences = PlayerPreferences.new(
		preference_store, OS.get_locale_language(), DeviceMotion.prefers_reduced_motion()
	)
	_preferences.changed.connect(_on_preferences_changed)
	TranslationServer.set_locale(_preferences.language)
	# Main is a plain Node, which breaks theme inheritance from the window,
	# so each screen gets the Theme itself.
	var theme: Theme = TaktikTheme.build()
	for screen: Control in [_home, _local_match, _online_match]:
		screen.theme = theme
	_sound.use_preferences(_preferences)
	_home.use_sound(_sound)
	_local_match.use_sound(_sound)
	_online_match.use_sound(_sound)
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


## Picks the layout from the screen's width in CSS pixels, and draws the
## window at that layout's reference size.
func _fit_window() -> void:
	var window: Window = get_window()
	var css: Vector2 = ScreenSize.css_size(window)
	var layout: ScreenLayout.Id = ScreenLayout.for_width(css.x)
	window.content_scale_size = ScreenLayout.content_size(layout, css)
	if _fitted and layout == _layout:
		return
	_fitted = true
	_layout = layout
	_home.set_layout(layout)
	_local_match.set_layout(layout)
	_online_match.set_layout(layout)
