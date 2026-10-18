class_name BoardMotion
extends Node
## Plays a Move on the Board as copies of the Pieces on top of it: the Board
## already shows where things ended, hides the Squares involved, and shows
## them again once the copies are done.

signal finished

## A Move: lift, slide, land with a squash, settle.
const LIFT_SCALE: float = 1.12
const LIFT_HEIGHT: float = 10.0
const LIFT_TIME: float = 0.08
const SLIDE_TIME: float = 0.22
const SQUASH: Vector2 = Vector2(1.08, 0.9)
const SQUASH_TIME: float = 0.06
const SETTLE_TIME: float = 0.06
## A Fight: lunge, flip to Reveal, the loser shakes and fades, the winner
## takes the Square.
const LUNGE_DISTANCE: float = 26.0
const LUNGE_TIME: float = 0.15
const FLIP_TIME: float = 0.07
const SHAKE_DISTANCE: float = 6.0
const SHAKE_TIME: float = 0.06
const FADE_TIME: float = 0.3
const LOSER_SCALE: float = 0.5
const WINNER_TIME: float = 0.22
const BURST_TIME: float = 0.12
## A Shuffle: every Piece slides to its new Square, one after another.
const SHUFFLE_TIME: float = 0.22
const SHUFFLE_STAGGER: float = 0.02
## A Setup swap: both Pieces cross along an arc.
const SWAP_TIME: float = 0.26
const SWAP_ARC: float = 16.0
## About how long a Fight plays, until the loser is gone.
const FIGHT_SECONDS: float = 0.9
## With reduced motion, a Move is a short fade and slide.
const REDUCED_TIME: float = 0.15

var reduced_motion: bool = false

var _tween: Tween = null
var _copies: Array[Control] = []


func play_move(event: PublicMoveEvent, board: BoardView) -> void:
	_stop()
	if event.has_fight:
		_play_fight(event, board)
	else:
		_play_glide(event.move, board)


func play_swap(first: Vector2i, second: Vector2i, board: BoardView) -> void:
	_stop()
	var geometry: BoardGeometry = board.geometry()
	var first_copy: PiecePicture = _copy(board, board.picture_of(first), geometry.piece_rect_of(second))
	var second_copy: PiecePicture = _copy(board, board.picture_of(second), geometry.piece_rect_of(first))
	var first_start: Vector2 = second_copy.position
	var second_start: Vector2 = first_copy.position
	_tween = board.create_tween()
	if reduced_motion:
		_tween.tween_interval(REDUCED_TIME)
	else:
		_tween.tween_method(
			func(progress: float) -> void:
				var lift: Vector2 = Vector2(0.0, -SWAP_ARC * sin(PI * progress))
				first_copy.position = first_start.lerp(second_start, progress) + lift
				second_copy.position = second_start.lerp(first_start, progress) - lift,
			0.0, 1.0, SWAP_TIME
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.finished.connect(_finish)


## Every Piece of the viewer slides from where it stood in [param before] to
## where it stands now, one after another.
func play_shuffle(before: Board, board: BoardView) -> void:
	_stop()
	var geometry: BoardGeometry = board.geometry()
	var after: Board = board.state().board
	var viewer: Side.Id = board.state().viewer
	var moves: Array[Move] = BoardMotion.shuffle_moves(before, after, viewer)
	_tween = board.create_tween().set_parallel()
	for index: int in moves.size():
		var move: Move = moves[index]
		var copy: PiecePicture = _copy(board, board.picture_of(move.to), geometry.piece_rect_of(move.from))
		var target: Vector2 = geometry.piece_rect_of(move.to).position
		var duration: float = REDUCED_TIME if reduced_motion else SHUFFLE_TIME
		var delay: float = 0.0 if reduced_motion else SHUFFLE_STAGGER * index
		_tween.tween_property(copy, "position", target, duration).set_delay(delay).set_trans(
			Tween.TRANS_CUBIC
		).set_ease(Tween.EASE_OUT)
	if moves.is_empty():
		_tween.tween_interval(0.0)
	_tween.finished.connect(_finish)


## Where each of [param viewer]'s Pieces went between two arrangements: the
## Pieces of one Type are matched in Square order.
static func shuffle_moves(before: Board, after: Board, viewer: Side.Id) -> Array[Move]:
	var moves: Array[Move] = []
	var targets: Dictionary[PieceType.Id, Array] = {}
	for square: Vector2i in after.squares_of(viewer):
		var type: PieceType.Id = after.piece_at(square).type
		if not targets.has(type):
			targets[type] = []
		targets[type].append(square)
	for square: Vector2i in before.squares_of(viewer):
		var type: PieceType.Id = before.piece_at(square).type
		if not targets.has(type) or targets[type].is_empty():
			continue
		var target: Vector2i = targets[type].pop_front()
		moves.append(Move.new(square, target))
	return moves


func is_playing() -> bool:
	return _tween != null and _tween.is_running()


func _play_glide(move: Move, board: BoardView) -> void:
	var geometry: BoardGeometry = board.geometry()
	var target: Rect2 = geometry.piece_rect_of(move.to)
	var copy: PiecePicture = _copy(board, board.picture_of(move.to), geometry.piece_rect_of(move.from))
	_tween = board.create_tween()
	if reduced_motion:
		copy.modulate.a = 0.3
		_tween.tween_property(copy, "position", target.position, REDUCED_TIME)
		_tween.parallel().tween_property(copy, "modulate:a", 1.0, REDUCED_TIME)
		_tween.finished.connect(_finish)
		return
	copy.pivot_offset = Vector2(copy.size.x * 0.5, copy.size.y * 0.9)
	var lifted: Vector2 = target.position + Vector2(0.0, -LIFT_HEIGHT)
	_tween.tween_property(copy, "scale", Vector2.ONE * LIFT_SCALE, LIFT_TIME).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(copy, "position:y", copy.position.y - LIFT_HEIGHT, LIFT_TIME)
	_tween.tween_property(copy, "position", lifted, SLIDE_TIME).set_trans(
		Tween.TRANS_CUBIC
	).set_ease(Tween.EASE_OUT)
	_tween.tween_property(copy, "position", target.position, SQUASH_TIME)
	_tween.parallel().tween_property(copy, "scale", SQUASH, SQUASH_TIME)
	_tween.tween_property(copy, "scale", Vector2.ONE, SETTLE_TIME).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)
	_tween.finished.connect(_finish)


func _play_fight(event: PublicMoveEvent, board: BoardView) -> void:
	var geometry: BoardGeometry = board.geometry()
	var mover: Side.Id = event.mover_side
	var defender_side: Side.Id = Side.opponent(mover)
	var from: Rect2 = geometry.piece_rect_of(event.move.from)
	var to: Rect2 = geometry.piece_rect_of(event.move.to)
	var attacker: PiecePicture = _copy(board, board.picture_for(event.attacker_type, mover, false), from)
	var defender: PiecePicture = _copy(board, board.picture_for(event.defender_type, defender_side, false), to)
	board.move_child(attacker, -1)
	var attacker_revealed: Texture2D = board.picture_for(event.attacker_type, mover, true)
	var defender_revealed: Texture2D = board.picture_for(event.defender_type, defender_side, true)
	var losers: Array[PiecePicture] = []
	if event.outcome != FightOutcome.Id.ATTACKER_WINS:
		losers.append(attacker)
	if event.outcome != FightOutcome.Id.DEFENDER_WINS:
		losers.append(defender)
	_tween = board.create_tween()
	if not reduced_motion:
		var toward: Vector2 = (to.position - from.position).normalized() * LUNGE_DISTANCE
		_tween.tween_property(attacker, "position", from.position + toward, LUNGE_TIME).set_trans(
			Tween.TRANS_QUAD
		).set_ease(Tween.EASE_IN)
		_tween.tween_callback(_burst.bind(board, from.get_center().lerp(to.get_center(), 0.5)))
	_add_flip(attacker, attacker_revealed)
	_add_flip(defender, defender_revealed)
	if not reduced_motion:
		for loser: PiecePicture in losers:
			_add_shake(loser)
	_tween.tween_interval(0.0)
	for loser: PiecePicture in losers:
		_tween.parallel().tween_method(loser.set_grey, 0.0, 1.0, FADE_TIME)
		_tween.parallel().tween_property(loser, "modulate:a", 0.0, FADE_TIME)
		if not reduced_motion:
			_tween.parallel().tween_property(loser, "scale", Vector2.ONE * LOSER_SCALE, FADE_TIME)
	if event.outcome == FightOutcome.Id.ATTACKER_WINS:
		_tween.tween_property(attacker, "position", to.position, WINNER_TIME).set_trans(
			Tween.TRANS_CUBIC
		).set_ease(Tween.EASE_OUT)
	_tween.finished.connect(_finish)


## Turns [param copy] edge on, swaps in its revealed picture, and back.
func _add_flip(copy: PiecePicture, revealed: Texture2D) -> void:
	if copy.texture == revealed:
		_tween.tween_interval(FLIP_TIME * 2.0)
		return
	_tween.tween_property(copy, "scale:x", 0.0, FLIP_TIME)
	_tween.tween_callback(func() -> void: copy.texture = revealed)
	_tween.tween_property(copy, "scale:x", 1.0, FLIP_TIME)


func _add_shake(copy: PiecePicture) -> void:
	var rest: float = copy.position.x
	for shake: int in 3:
		_tween.tween_property(copy, "position:x", rest + SHAKE_DISTANCE, SHAKE_TIME / 2.0)
		_tween.tween_property(copy, "position:x", rest - SHAKE_DISTANCE, SHAKE_TIME / 2.0)
	_tween.tween_property(copy, "position:x", rest, SHAKE_TIME / 2.0)


func _burst(board: BoardView, centre: Vector2) -> void:
	var burst: StarBurst = StarBurst.new()
	burst.size = Vector2(board.geometry().cell, board.geometry().cell)
	burst.position = centre - burst.size / 2.0
	board.add_child(burst)
	_copies.append(burst)
	burst.play(BURST_TIME * 3.0)


func _copy(board: BoardView, texture: Texture2D, rect: Rect2) -> PiecePicture:
	var copy: PiecePicture = PiecePicture.new()
	copy.texture = texture
	copy.position = rect.position
	copy.size = rect.size
	copy.pivot_offset = rect.size / 2.0
	board.add_child(copy)
	_copies.append(copy)
	return copy


func _stop() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	_clear_copies()


func _finish() -> void:
	_tween = null
	_clear_copies()
	finished.emit()


func _clear_copies() -> void:
	for copy: Control in _copies:
		if is_instance_valid(copy):
			copy.queue_free()
	_copies.clear()
