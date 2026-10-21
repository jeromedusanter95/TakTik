class_name EnemyBehaviourReader
extends RefCounted
## Reads what an enemy Piece's quiet Moves suggest about its type, the way a
## player would: an opponent who steps next to a Bot Piece it has seen
## probably either beats it or survives its Attack, and one who steps away
## from it probably would not. Types that do not fit become less likely,
## never impossible, since opponents bluff and err.

var _enemies: EnemyTracker
var _exposure: EnemyTracker
var _factor: float


## [param enemies] is the Bot's memory of the enemy Army and [param exposure]
## the opponent's memory of the Bot's Army. A type that does not fit a Move
## has its likelihood divided by [param evidence].
func _init(enemies: EnemyTracker, exposure: EnemyTracker, evidence: float) -> void:
	_enemies = enemies
	_exposure = exposure
	_factor = 1.0 / maxf(evidence, 1.0)


## Call before the trackers observe [param event], while they still describe
## the position the Move was played from.
func read(event: PublicMoveEvent) -> void:
	if event.has_fight or event.mover_side != _enemy_side():
		return
	var enemy: TrackedEnemy = _enemies.enemy_at(event.move.from)
	if enemy.is_known():
		return
	for square: Vector2i in _exposure.enemy_squares():
		var seen: TrackedEnemy = _exposure.enemy_at(square)
		if not seen.is_known():
			continue
		var was_next_to: bool = Board.steps_from(event.move.from).has(square)
		var is_next_to: bool = Board.steps_from(event.move.to).has(square)
		if is_next_to and not was_next_to:
			_weigh_all(enemy, seen.known_type(), _fits_approach)
		elif was_next_to and not is_next_to:
			_weigh_all(enemy, seen.known_type(), _fits_retreat)


func _enemy_side() -> Side.Id:
	return Side.opponent(_exposure.watched_side())


func _weigh_all(enemy: TrackedEnemy, seen: PieceType.Id, fits: Callable) -> void:
	for type: PieceType.Id in PieceType.Id.values():
		if not fits.call(type, seen):
			enemy.weigh(type, _factor)


## Stepping next to [param seen] fits a type that beats it or survives it.
static func _fits_approach(type: PieceType.Id, seen: PieceType.Id) -> bool:
	return _beats(type, seen) or not _beats(seen, type)


## Stepping away from [param seen] fits a type that would not survive it.
static func _fits_retreat(type: PieceType.Id, seen: PieceType.Id) -> bool:
	return _can_attack(seen) and FightOutcome.resolve(seen, type) != FightOutcome.Id.DEFENDER_WINS


static func _beats(attacker: PieceType.Id, defender: PieceType.Id) -> bool:
	return (
		_can_attack(attacker)
		and FightOutcome.resolve(attacker, defender) == FightOutcome.Id.ATTACKER_WINS
	)


static func _can_attack(type: PieceType.Id) -> bool:
	return type != PieceType.Id.MONSTER and type != PieceType.Id.PRINCESS
