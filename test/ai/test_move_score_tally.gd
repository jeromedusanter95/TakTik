extends GutTest
## Adding up each Move's scores over the imagined worlds.


func test_without_a_cap_scores_add_up_as_searched() -> void:
	var tally: MoveScoreTally = MoveScoreTally.new([0, 0], 0)
	tally.add_world([10, 20])
	tally.add_world([10_000, -5])
	assert_eq(tally.best_indexes(), [0])


func test_a_cap_stops_one_lucky_world_from_outweighing_all_the_others() -> void:
	var tally: MoveScoreTally = MoveScoreTally.new([0, 0], 300)
	tally.add_world([-9_990, 120])
	for world: int in 3:
		tally.add_world([150, 0])
	assert_eq(tally.best_indexes(), [0], "won material in three worlds, lost in one")


func test_a_penalty_is_paid_once_per_world() -> void:
	var tally: MoveScoreTally = MoveScoreTally.new([0, 15], 0)
	tally.add_world([10, 20])
	assert_eq(tally.best_indexes(), [0])


func test_equal_totals_are_all_best() -> void:
	var tally: MoveScoreTally = MoveScoreTally.new([0, 0, 0], 0)
	tally.add_world([5, 7, 7])
	assert_eq(tally.best_indexes(), [1, 2])
