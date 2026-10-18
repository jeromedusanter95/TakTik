class_name HomeScreen
extends Control
## The first screen: the name players are seen by, a Quick Match, a game
## against a Bot or on one device, and on the right everyone online, ready to
## be challenged. A Guest appears online as soon as their name is set.

signal two_players_chosen
signal bot_chosen(profile: BotProfile)
## The Lobby paired this Guest, by Quick Match or Challenge.
signal paired(seat: PairedSeat, nickname: String)

## How long a received Challenge waits for an answer before it is declined.
const CHALLENGE_SECONDS: float = 30.0

var _server_url: String = ""
## Returns a new WireSocket for each connection.
var _open_socket: Callable = Callable()
var _preferences: PlayerPreferences = null
var _profiles: Array[BotProfile] = []
var _lobby: LobbyClient = null
## A Quick Match asked for while the Lobby was still being entered.
var _quick_match_pending: bool = false
## Seconds left on each received Challenge, by challenger id.
var _challenge_seconds: Dictionary[String, float] = {}
var _phone: bool = false
var _showing_online_tab: bool = false
var _active: bool = false

@onready var _margin: MarginContainer = %Margin
@onready var _phone_tabs: SegmentedControl = %PhoneTabs
@onready var _columns: HBoxContainer = %Columns
@onready var _left_scroll: ScrollContainer = %LeftScroll
@onready var _logo: Label = %Logo
@onready var _name_edit: LineEdit = %NameEdit
@onready var _name_error: Label = %NameError
@onready var _quick_match_button: Button = %QuickMatchButton
@onready var _quick_match_title: Label = %QuickMatchTitle
@onready var _quick_match_detail: Label = %QuickMatchDetail
@onready var _modes: VBoxContainer = %Modes
@onready var _mode_cards: BoxContainer = %ModeCards
@onready var _difficulty: SegmentedControl = %Difficulty
@onready var _bot_button: Button = %BotButton
@onready var _two_players_button: Button = %TwoPlayersButton
@onready var _illustration: HomeIllustration = %Illustration
@onready var _online_panel: OnlinePanel = %OnlinePanel
@onready var _language_switch: SegmentedControl = %LanguageSwitch
@onready var _top_right: HBoxContainer = %TopRight


func _ready() -> void:
	_name_edit.max_length = Nickname.MAX_LENGTH
	_name_edit.text_submitted.connect(_on_name_submitted)
	_name_edit.focus_exited.connect(_commit_name)
	_name_edit.text_changed.connect(_on_name_changed)
	_quick_match_button.pressed.connect(_on_quick_match_pressed)
	_bot_button.pressed.connect(_on_bot_pressed)
	_two_players_button.pressed.connect(_on_two_players_pressed)
	_difficulty.option_chosen.connect(_on_difficulty_chosen)
	_language_switch.show_options(["FR", "EN"], 0)
	_language_switch.option_chosen.connect(_on_language_chosen)
	_phone_tabs.show_options(["HOME_TAB_PLAY", "HOME_TAB_ONLINE"], 0)
	_phone_tabs.option_chosen.connect(_on_phone_tab_chosen)
	_online_panel.challenge_requested.connect(_on_challenge_requested)
	_online_panel.withdraw_requested.connect(_on_withdraw_requested)
	_online_panel.answer_requested.connect(_on_answer_requested)
	_online_panel.retry_requested.connect(_enter_lobby)
	_apply_layout()
	_show_quick_match()


func _process(delta: float) -> void:
	if _lobby != null:
		_lobby.poll()
	_count_down_challenges(delta)


## [param server_url] is the server's WebSocket origin; [param open_socket]
## returns a new WireSocket each time it is called.
func configure(server_url: String, open_socket: Callable) -> void:
	_server_url = server_url
	_open_socket = open_socket


func use_preferences(preferences: PlayerPreferences) -> void:
	_preferences = preferences
	_preferences.changed.connect(_show_preferences)
	_name_edit.text = preferences.nickname
	_show_preferences()


## Adds one Difficulty option per Bot profile, in the order given.
func show_difficulties(profiles: Array[BotProfile]) -> void:
	_profiles = profiles
	var names: PackedStringArray = []
	for profile: BotProfile in profiles:
		names.append(String(profile.display_name))
	var chosen: int = _preferences.difficulty if _preferences != null else 1
	_difficulty.show_options(names, clampi(chosen, 0, maxi(0, profiles.size() - 1)))


## The home screen is on screen again: show up online when named.
func open() -> void:
	_active = true
	_show_quick_match()
	if _lobby == null and _preferences != null and not _preferences.nickname.is_empty():
		_enter_lobby()
	elif _lobby == null:
		_online_panel.show_offline(Translated.text(&"LOBBY_NAME_FIRST"))


## Leaves the Lobby, for a game on this device.
func close() -> void:
	_active = false
	_leave_lobby()


func set_phone(phone: bool) -> void:
	if phone == _phone:
		return
	_phone = phone
	_apply_layout()


func _enter_lobby() -> void:
	_leave_lobby()
	if _preferences == null or _preferences.nickname.is_empty():
		return
	var socket: Variant = _open_socket.call()
	if socket is not WireSocket:
		push_error("open_socket must return a WireSocket")
		return
	var wire: WireSocket = socket
	_lobby = LobbyClient.new(wire)
	_lobby.changed.connect(_on_lobby_changed)
	_lobby.paired.connect(_on_paired)
	_lobby.failed.connect(_on_lobby_failed)
	_lobby.challenge_ended.connect(_on_challenge_ended)
	_lobby.enter(_server_url, _preferences.nickname)
	_online_panel.show_connecting()
	_show_quick_match()


func _leave_lobby() -> void:
	_quick_match_pending = false
	_challenge_seconds.clear()
	if _lobby != null:
		_lobby.leave()
		_lobby = null
	_show_quick_match()


func _commit_name() -> void:
	if _preferences == null:
		return
	var text: String = _name_edit.text
	if Nickname.cleaned(text).is_empty():
		_show_name_error(not text.strip_edges().is_empty())
		return
	_show_name_error(false)
	var before: String = _preferences.nickname
	_preferences.set_nickname(text)
	_name_edit.text = _preferences.nickname
	var renamed: bool = before != _preferences.nickname
	if _active and (renamed or _lobby == null):
		_enter_lobby()


func _show_name_error(shown: bool) -> void:
	_name_error.visible = shown
	_name_edit.theme_type_variation = &"LineEditInvalid" if shown else &""


func _show_preferences() -> void:
	_language_switch.select(PreferenceRows.LANGUAGE_CODES.find(_preferences.language))
	_difficulty.select(_preferences.difficulty)
	var reduced: bool = _preferences.reduced_motion
	_online_panel.reduced_motion = reduced
	_illustration.set_floating(not reduced and not _phone)


func _show_quick_match() -> void:
	var waiting: bool = _lobby != null and _lobby.is_waiting()
	_quick_match_title.text = Translated.text(&"HOME_SEARCHING" if waiting else &"LOBBY_QUICK_MATCH")
	_quick_match_detail.text = Translated.text(&"HOME_SEARCHING_CANCEL" if waiting else &"HOME_QUICK_MATCH_DETAIL")


func _refresh_lobby() -> void:
	if _lobby == null or not _lobby.has_entered():
		return
	var you: ListedGuest = ListedGuest.new(_lobby.own_id(), _preferences.nickname, _lobby.is_waiting())
	var challenger_ids: Array[String] = []
	for challenger: ListedGuest in _lobby.challengers():
		challenger_ids.append(challenger.guest_id)
		if not _challenge_seconds.has(challenger.guest_id):
			_challenge_seconds[challenger.guest_id] = CHALLENGE_SECONDS
	for guest_id: String in _challenge_seconds.keys():
		if not guest_id in challenger_ids:
			_challenge_seconds.erase(guest_id)
	var challenged: ListedGuest = _lobby.challenged_guest()
	_online_panel.show_guests(
		you, _lobby.is_waiting(), _lobby.guests(), challenger_ids,
		challenged.guest_id if challenged != null else ""
	)
	_show_challenge()
	_show_quick_match()


## The oldest Challenge received, with its countdown.
func _show_challenge() -> void:
	if _lobby == null:
		_online_panel.hide_challenge()
		return
	var challengers: Array[ListedGuest] = _lobby.challengers()
	if challengers.is_empty():
		_online_panel.hide_challenge()
		return
	var first: ListedGuest = challengers[0]
	var seconds_left: float = _challenge_seconds.get(first.guest_id, CHALLENGE_SECONDS)
	_online_panel.show_challenge(first, seconds_left, CHALLENGE_SECONDS, challengers.size() - 1)


func _count_down_challenges(delta: float) -> void:
	if _lobby == null or _challenge_seconds.is_empty():
		return
	for guest_id: String in _challenge_seconds.keys():
		_challenge_seconds[guest_id] -= delta
		if _challenge_seconds[guest_id] <= 0.0:
			_challenge_seconds.erase(guest_id)
			_lobby.answer_challenge(guest_id, false)
	_show_challenge()


func _apply_layout() -> void:
	_phone_tabs.visible = _phone
	_illustration.visible = not _phone
	_logo.theme_type_variation = &"LogoPhone" if _phone else &"DisplayXL"
	var side: int = UiTokens.SPACE_L if _phone else 80
	_margin.add_theme_constant_override("margin_left", side)
	_margin.add_theme_constant_override("margin_right", UiTokens.SPACE_L if _phone else 40)
	_margin.add_theme_constant_override("margin_top", 72 if _phone else 56)
	_margin.add_theme_constant_override("margin_bottom", UiTokens.SPACE_L if _phone else 44)
	# Beside the left column on large screens; in the corner on phones.
	_top_right.offset_left = -136.0 - (UiTokens.SPACE_L if _phone else 508.0)
	_top_right.offset_right = -(UiTokens.SPACE_L if _phone else 508.0)
	_top_right.offset_top = UiTokens.SPACE_L if _phone else 28.0
	_mode_cards.vertical = _phone
	_modes.custom_minimum_size.x = 0.0 if _phone else 560.0
	_modes.size_flags_horizontal = Control.SIZE_FILL if _phone else Control.SIZE_SHRINK_BEGIN
	_show_tab()
	if _preferences != null:
		_show_preferences()


func _show_tab() -> void:
	_left_scroll.visible = not _phone or not _showing_online_tab
	_online_panel.visible = not _phone or _showing_online_tab
	_online_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _phone else Control.SIZE_FILL


func _on_name_submitted(_text: String) -> void:
	_commit_name()
	_name_edit.release_focus()


func _on_name_changed(_text: String) -> void:
	if _name_error.visible and not Nickname.cleaned(_name_edit.text).is_empty():
		_show_name_error(false)


func _on_quick_match_pressed() -> void:
	if _lobby != null and _lobby.is_waiting():
		_lobby.stop_waiting()
		return
	if _preferences == null or _preferences.nickname.is_empty():
		_commit_name()
		if _preferences == null or _preferences.nickname.is_empty():
			_show_name_error(true)
			_name_edit.grab_focus()
			return
	if _lobby == null:
		_enter_lobby()
	if _lobby == null:
		return
	if not _lobby.has_entered():
		_quick_match_pending = true
		return
	_lobby.join_quick_match()


func _on_bot_pressed() -> void:
	var index: int = clampi(_difficulty.selected(), 0, _profiles.size() - 1)
	if _profiles.is_empty():
		return
	close()
	bot_chosen.emit(_profiles[index])


func _on_two_players_pressed() -> void:
	close()
	two_players_chosen.emit()


func _on_difficulty_chosen(index: int) -> void:
	if _preferences != null:
		_preferences.set_difficulty(index)


func _on_language_chosen(index: int) -> void:
	if _preferences != null:
		_preferences.set_language(PreferenceRows.LANGUAGE_CODES[index])


func _on_phone_tab_chosen(index: int) -> void:
	_showing_online_tab = index == 1
	_show_tab()


func _on_lobby_changed() -> void:
	if _lobby == null:
		return
	if _quick_match_pending and _lobby.has_entered():
		_quick_match_pending = false
		_lobby.join_quick_match()
	_refresh_lobby()


func _on_paired(seat: PairedSeat) -> void:
	_lobby = null
	_challenge_seconds.clear()
	_active = false
	paired.emit(seat, _preferences.nickname)


func _on_lobby_failed(reason: String) -> void:
	_lobby = null
	_challenge_seconds.clear()
	_online_panel.show_offline(OnlineMatchTexts.lobby_failure(reason), reason != "invalid_nickname")
	if reason == "invalid_nickname":
		_show_name_error(true)
	_show_quick_match()


func _on_challenge_ended(nickname: String, reason: String) -> void:
	_online_panel.show_message(OnlineMatchTexts.challenge_end(nickname, reason))


func _on_challenge_requested(guest_id: String) -> void:
	if _lobby != null:
		_online_panel.show_message("")
		_lobby.challenge(guest_id)


func _on_withdraw_requested() -> void:
	if _lobby != null:
		_lobby.withdraw_challenge()


func _on_answer_requested(guest_id: String, accept: bool) -> void:
	if _lobby == null or guest_id.is_empty():
		return
	_challenge_seconds.erase(guest_id)
	_lobby.answer_challenge(guest_id, accept)
	_refresh_lobby()
