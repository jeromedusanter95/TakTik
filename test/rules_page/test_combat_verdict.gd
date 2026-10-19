extends GutTest
## The rules page simulator's verdicts, which must match the game's Fights.


func test_a_stronger_attack_wins() -> void:
	var verdict: CombatVerdict = CombatVerdict.judge(PieceType.Id.KNIGHT, PieceType.Id.THIEF)
	assert_eq(verdict.kind, CombatVerdict.Kind.ATTACKER_WINS)
	assert_eq(verdict.reason, CombatVerdict.Reason.STRONGER_ATTACK)
	assert_false(verdict.princess_captured)


func test_a_stronger_defense_wins() -> void:
	var verdict: CombatVerdict = CombatVerdict.judge(PieceType.Id.SOLDIER, PieceType.Id.KING)
	assert_eq(verdict.kind, CombatVerdict.Kind.DEFENDER_WINS)
	assert_eq(verdict.reason, CombatVerdict.Reason.STRONGER_DEFENSE)


func test_equal_strengths_eliminate_both() -> void:
	var verdict: CombatVerdict = CombatVerdict.judge(PieceType.Id.KNIGHT, PieceType.Id.KNIGHT)
	assert_eq(verdict.kind, CombatVerdict.Kind.BOTH_ELIMINATED)
	assert_eq(verdict.reason, CombatVerdict.Reason.EQUAL)


func test_the_monster_beats_even_the_thief() -> void:
	var verdict: CombatVerdict = CombatVerdict.judge(PieceType.Id.THIEF, PieceType.Id.MONSTER)
	assert_eq(verdict.kind, CombatVerdict.Kind.DEFENDER_WINS)
	assert_eq(verdict.reason, CombatVerdict.Reason.MONSTER_DEFENDS)


func test_only_the_magician_kills_a_monster() -> void:
	var verdict: CombatVerdict = CombatVerdict.judge(PieceType.Id.MAGICIAN, PieceType.Id.MONSTER)
	assert_eq(verdict.kind, CombatVerdict.Kind.ATTACKER_WINS)
	assert_eq(verdict.reason, CombatVerdict.Reason.MAGICIAN_KILLS_MONSTER)


func test_a_monster_cannot_attack() -> void:
	var verdict: CombatVerdict = CombatVerdict.judge(PieceType.Id.MONSTER, PieceType.Id.PRINCESS)
	assert_eq(verdict.kind, CombatVerdict.Kind.NO_FIGHT)
	assert_eq(verdict.reason, CombatVerdict.Reason.NEVER_MOVES)
	assert_false(verdict.princess_captured)


func test_a_princess_cannot_attack() -> void:
	var verdict: CombatVerdict = CombatVerdict.judge(PieceType.Id.PRINCESS, PieceType.Id.THIEF)
	assert_eq(verdict.kind, CombatVerdict.Kind.NO_FIGHT)
	assert_eq(verdict.reason, CombatVerdict.Reason.NEVER_ATTACKS)


func test_beating_the_princess_wins_the_game() -> void:
	var verdict: CombatVerdict = CombatVerdict.judge(PieceType.Id.BUFFOON, PieceType.Id.PRINCESS)
	assert_eq(verdict.kind, CombatVerdict.Kind.ATTACKER_WINS)
	assert_true(verdict.princess_captured)


func test_every_fight_agrees_with_the_game() -> void:
	for attacker: PieceType.Id in PieceType.Id.values():
		if not MovementCatalog.rule_for(attacker).can_attack():
			continue
		for defender: PieceType.Id in PieceType.Id.values():
			var verdict: CombatVerdict = CombatVerdict.judge(attacker, defender)
			var outcome: FightOutcome.Id = FightOutcome.resolve(attacker, defender)
			assert_eq(int(verdict.kind), _kind_of(outcome), "%d against %d" % [attacker, defender])


func _kind_of(outcome: FightOutcome.Id) -> int:
	match outcome:
		FightOutcome.Id.ATTACKER_WINS:
			return CombatVerdict.Kind.ATTACKER_WINS
		FightOutcome.Id.DEFENDER_WINS:
			return CombatVerdict.Kind.DEFENDER_WINS
		_:
			return CombatVerdict.Kind.BOTH_ELIMINATED
