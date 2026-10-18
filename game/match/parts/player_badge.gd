@abstract
class_name PlayerBadge
extends PanelContainer
## One player beside the Board: who they are, what they are doing, whether
## they are to move, and the Pieces they lost. A card on large screens and a
## strip on phones show the same things.

## The Pieces in an Army.
const ARMY_SIZE: int = 18

var _side: Side.Id = Side.Id.RED
var _is_you: bool = false
var _active: bool = false
var _adapted: bool = false


## Shows [param name], playing [param side]; [param is_you] marks the person
## looking at the screen.
func show_player(name: String, side: Side.Id, is_you: bool, adapted: bool = false) -> void:
	_side = side
	_is_you = is_you
	_adapted = adapted
	_show_identity(name)
	_refresh_look()


## A short line under the name, such as "Ready"; empty hides it.
@abstract func show_status(text: String) -> void


## [param active] while this player is to move, with [param fraction] of their
## Turn Timer left, or a negative fraction when no timer runs.
func show_turn(active: bool, fraction: float) -> void:
	_active = active
	_show_turn_bar(active and fraction >= 0.0, clampf(fraction, 0.0, 1.0))
	_refresh_look()


## The Pieces this player lost.
@abstract func show_graveyard(types: Array[PieceType.Id]) -> void


@abstract func _show_identity(name: String) -> void


@abstract func _show_turn_bar(shown: bool, fraction: float) -> void


@abstract func _look_name(is_you: bool, active: bool) -> StringName


func _refresh_look() -> void:
	theme_type_variation = _look_name(_is_you, _active)


## For example "17 Pieces, green Army".
func _army_detail(lost: int) -> String:
	return Translated.text(&"PLAYER_DETAIL", {
		"count": ARMY_SIZE - lost,
		"army": Translated.text(&"ARMY_RED" if _side == Side.Id.RED else &"ARMY_GREEN"),
	})
