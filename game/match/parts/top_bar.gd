class_name TopBar
extends PanelContainer
## The bar across the top of a game: the logo and who plays whom on the
## left, whose turn it is with the timer in the middle, and Resign and Menu
## on the right. On phones it keeps Menu, the turn and the timer, and adds
## the chat button with its unread count.

signal menu_pressed
signal resign_pressed
signal chat_pressed
## The timer ring beat in one of its last seconds.
signal timer_beat

@onready var _logo: Label = %Logo
@onready var _divider: VSeparator = %Divider
@onready var _subtitle: Label = %Subtitle
@onready var _status_dot: StatusDot = %StatusDot
@onready var _status_icon: UiIcon = %StatusIcon
@onready var _status_label: Label = %StatusLabel
@onready var _timer_ring: TimerRing = %TimerRing
@onready var _resign_button: Button = %ResignButton
@onready var _chat_button: Button = %ChatButton
@onready var _unread_badge: PanelContainer = %UnreadBadge
@onready var _unread_label: Label = %UnreadLabel
@onready var _menu_button: Button = %MenuButton
@onready var _phone_menu_button: Button = %PhoneMenuButton
@onready var _sound_toggle: SoundToggle = %SoundToggle

var _phone: bool = false
var _resign_allowed: bool = false
var _has_chat: bool = false


func _ready() -> void:
	_menu_button.pressed.connect(_on_menu_pressed)
	_phone_menu_button.pressed.connect(_on_menu_pressed)
	_resign_button.pressed.connect(_on_resign_pressed)
	_chat_button.pressed.connect(_on_chat_pressed)
	_timer_ring.beat.connect(_on_timer_beat)
	show_unread(0)
	hide_timer()
	_refresh()


func show_subtitle(text: String) -> void:
	_subtitle.text = text


## [param text] in the middle, after a [param dot] of that colour when it is
## not transparent.
func show_status(text: String, dot: Color = Color.TRANSPARENT, pulsing: bool = false) -> void:
	_status_label.text = text
	_status_dot.visible = dot.a > 0.0
	_status_dot.show_dot(dot, pulsing)
	_status_icon.visible = false


## [param text] after a crown, once the game is over.
func show_finished(text: String) -> void:
	show_status(text)
	_status_icon.visible = true


func show_timer(seconds_left: int, total_seconds: int, colour: Color) -> void:
	_timer_ring.visible = true
	_timer_ring.colour = colour
	_timer_ring.show_time(seconds_left, total_seconds)


func hide_timer() -> void:
	_timer_ring.visible = false


func show_resign(allowed: bool) -> void:
	_resign_allowed = allowed
	_refresh()


func show_chat_button(has_chat: bool) -> void:
	_has_chat = has_chat
	_refresh()


## How many messages the player has not read yet, shown on the chat button.
func show_unread(count: int) -> void:
	_unread_badge.visible = count > 0
	_unread_label.text = str(mini(count, 9)) + ("+" if count > 9 else "")


func set_phone(phone: bool) -> void:
	_phone = phone
	custom_minimum_size.y = UiTokens.TOPBAR_PHONE if phone else UiTokens.TOPBAR_DESKTOP
	var ring_size: float = 40.0 if phone else 52.0
	_timer_ring.custom_minimum_size = Vector2(ring_size, ring_size)
	_status_label.theme_type_variation = &"TitleS" if phone else &"TitleM"
	var style: StyleBox = get_theme_stylebox(&"panel", &"TopBar").duplicate()
	var padding: int = UiTokens.SPACE_M if phone else UiTokens.SPACE_2XL
	style.content_margin_left = padding
	style.content_margin_right = padding
	add_theme_stylebox_override(&"panel", style)
	_refresh()


func use_preferences(preferences: PlayerPreferences) -> void:
	_sound_toggle.use_preferences(preferences)


func set_reduced_motion(reduced: bool) -> void:
	_timer_ring.reduced_motion = reduced
	_status_dot.reduced_motion = reduced


func _refresh() -> void:
	_logo.visible = not _phone
	_divider.visible = not _phone
	_subtitle.visible = not _phone
	_phone_menu_button.visible = _phone
	_menu_button.visible = not _phone
	_sound_toggle.visible = not _phone
	_resign_button.visible = _resign_allowed and not _phone
	_chat_button.visible = _phone and _has_chat


func _on_menu_pressed() -> void:
	menu_pressed.emit()


func _on_resign_pressed() -> void:
	resign_pressed.emit()


func _on_chat_pressed() -> void:
	chat_pressed.emit()


func _on_timer_beat() -> void:
	timer_beat.emit()
