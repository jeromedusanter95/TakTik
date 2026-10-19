class_name RulesContent
extends VBoxContainer
## The rules of the game in five sections, read from the game's own rules:
## two ways to win, a game in three steps, Fights with a simulator, the nine
## Piece Types and the end of a game. Shown as a page from the home screen
## and as an overlay during a game.

## The closing "practice game" button was pressed.
signal practice_pressed

const PieceGuideCardScene: PackedScene = preload("res://game/rules_page/piece_guide_card.tscn")
## Below this width, cards that sit side by side are stacked.
const STACK_BELOW: float = 940.0
## Below this width, the zone labels go under the small Board.
const BOARD_ROW_STACK_BELOW: float = 480.0
## The narrowest a piece card gets before the grid drops a column.
const PIECE_CARD_MIN_WIDTH: float = 330.0
const MAX_PIECE_COLUMNS: int = 3

var _adapted: bool = false
var _piece_cards: Dictionary[PieceType.Id, PieceGuideCard] = {}

@onready var _win_cards: BoxContainer = %WinCards
@onready var _step_cards: BoxContainer = %StepCards
@onready var _combat_columns: BoxContainer = %CombatColumns
@onready var _board_columns: BoxContainer = %BoardColumns
@onready var _piece_grid: GridContainer = %PieceGrid
@onready var _simulator: CombatSimulator = %Simulator
@onready var _board_row: BoxContainer = %BoardRow
@onready var _mini_board: MiniBoard = %MiniBoard
@onready var _enemy_zone_rule: ColorRect = %EnemyZoneRule
@onready var _middle_zone_rule: ColorRect = %MiddleZoneRule
@onready var _own_zone_rule: ColorRect = %OwnZoneRule
@onready var _practice_button: Button = %PracticeButton


func _ready() -> void:
	for type: PieceType.Id in PieceGuide.by_attack():
		var instance: Node = PieceGuideCardScene.instantiate()
		if instance is not PieceGuideCard:
			push_error("piece_guide_card.tscn root must be a PieceGuideCard")
			return
		var card: PieceGuideCard = instance
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_piece_grid.add_child(card)
		_piece_cards[type] = card
	_own_zone_rule.color = UiTokens.RED_400
	_middle_zone_rule.color = UiTokens.BORDER_3
	_enemy_zone_rule.color = _mini_board.enemy_colour()
	_practice_button.pressed.connect(_on_practice_pressed)
	_show_pieces()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_show_pieces()
		_simulator.refresh()


## Draws the green Army blue instead, everywhere on the page.
func set_adapted(adapted: bool) -> void:
	_adapted = adapted
	for card: WinCard in _win_cards.get_children():
		card.set_adapted(adapted)
	_simulator.set_adapted(adapted)
	_mini_board.set_adapted(adapted)
	_enemy_zone_rule.color = _mini_board.enemy_colour()
	_show_pieces()


func set_reduced_motion(reduced: bool) -> void:
	_simulator.reduced_motion = reduced


## Offers the closing practice game; hidden during a game.
func show_practice(shown: bool) -> void:
	_practice_button.visible = shown


## Lays the page out for [param width], the room its parent gives it: cards
## side by side on wide pages, stacked on narrow ones, and as many piece
## columns as fit. The parent decides, because side by side cards would
## otherwise keep the page wide.
func fit_width(width: float) -> void:
	var stacked: bool = width < STACK_BELOW
	for box: BoxContainer in [_win_cards, _step_cards, _combat_columns, _board_columns]:
		box.vertical = stacked
	_board_row.vertical = width < BOARD_ROW_STACK_BELOW
	var gap: float = _piece_grid.get_theme_constant(&"h_separation")
	var fitting: int = floori((width + gap) / (PIECE_CARD_MIN_WIDTH + gap))
	_piece_grid.columns = clampi(fitting, 1, MAX_PIECE_COLUMNS)


func simulator() -> CombatSimulator:
	return _simulator


func piece_card(type: PieceType.Id) -> PieceGuideCard:
	return _piece_cards[type]


func _show_pieces() -> void:
	for type: PieceType.Id in _piece_cards:
		_piece_cards[type].show_piece(type, _adapted)


func _on_practice_pressed() -> void:
	practice_pressed.emit()
