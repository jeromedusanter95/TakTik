class_name EnemyTracker
extends RefCounted
## A Bot's memory of the enemy Army, built only from what a player may know:
## the first PlayerView, then every PublicMoveEvent. A Piece Type seen in a
## Reveal stays known, as a human player would remember it.
##
## Built with [method of_own_army], it is instead the opponent's memory of the
## Bot's own Army: what the opponent may know about the Bot's Pieces.

var _enemy_side: Side.Id
var _enemies: Dictionary[Vector2i, TrackedEnemy] = {}
var _graveyard: Array[PieceType.Id] = []


func _init(view: PlayerView) -> void:
	_watch(Side.opponent(view.side), view.enemy_squares())


## What the opponent of [param view]'s side may know about that side's Army.
static func of_own_army(view: PlayerView) -> EnemyTracker:
	var tracker: EnemyTracker = EnemyTracker.new(view)
	tracker._watch(view.side, view.own_squares())
	return tracker


## The side whose Pieces this memory follows.
func watched_side() -> Side.Id:
	return _enemy_side


## The memory of the enemy Piece on [param square]. A Square the tracker has
## no record of yields a fresh, unknown memory.
func enemy_at(square: Vector2i) -> TrackedEnemy:
	if not _enemies.has(square):
		return TrackedEnemy.new()
	return _enemies[square]


func enemy_squares() -> Array[Vector2i]:
	var squares: Array[Vector2i] = []
	for square: Vector2i in _enemies:
		squares.append(square)
	squares.sort()
	return squares


## The Piece Types of the enemy Pieces in the Graveyard.
func graveyard() -> Array[PieceType.Id]:
	return _graveyard.duplicate()


## The Piece Types the enemy Pieces of unknown type are made of: the Army,
## minus the Graveyard, minus the Pieces whose type is known.
func unknown_pool() -> Array[PieceType.Id]:
	var pool: Array[PieceType.Id] = PieceType.army()
	for type: PieceType.Id in _graveyard:
		pool.erase(type)
	for square: Vector2i in _enemies:
		var enemy: TrackedEnemy = _enemies[square]
		if enemy.is_known():
			pool.erase(enemy.known_type())
	return pool


func observe(event: PublicMoveEvent) -> void:
	if event.mover_side == _enemy_side:
		_observe_enemy_move(event)
	else:
		_observe_own_move(event)


func _observe_enemy_move(event: PublicMoveEvent) -> void:
	var enemy: TrackedEnemy = enemy_at(event.move.from)
	_enemies.erase(event.move.from)
	enemy.mark_moved()
	if not event.has_fight:
		if _length_of(event.move) > 1:
			enemy.learn_type(PieceType.Id.BUFFOON)
		_enemies[event.move.to] = enemy
		return
	enemy.learn_type(event.attacker_type)
	if event.outcome == FightOutcome.Id.ATTACKER_WINS:
		_enemies[event.move.to] = enemy
	else:
		_graveyard.append(event.attacker_type)


func _observe_own_move(event: PublicMoveEvent) -> void:
	if not event.has_fight:
		return
	if event.outcome == FightOutcome.Id.DEFENDER_WINS:
		var defender: TrackedEnemy = enemy_at(event.move.to)
		defender.learn_type(event.defender_type)
		_enemies[event.move.to] = defender
		return
	_enemies.erase(event.move.to)
	_graveyard.append(event.defender_type)


func _watch(side: Side.Id, squares: Array[Vector2i]) -> void:
	_enemy_side = side
	_enemies.clear()
	for square: Vector2i in squares:
		_enemies[square] = TrackedEnemy.new()


static func _length_of(move: Move) -> int:
	return absi(move.to.x - move.from.x) + absi(move.to.y - move.from.y)
