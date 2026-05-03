extends Node

func _ready() -> void:
	print("=== test_lane_targeting.gd ===")
	test_same_lane_picks_opposite()
	test_same_lane_falls_back_when_opposite_empty()
	test_adjacent_lane_returns_two()
	test_all_lanes_returns_all_enemies()
	test_self_targets_caster()
	test_all_allies_excludes_enemies()
	print("=== All lane targeting tests passed ===")
	get_tree().quit()

func _make_unit(unit_name: String) -> CombatantData:
	var d := CombatantData.new()
	d.character_name = unit_name
	d.current_hp = 20
	return d

func _make_ability(shape: AbilityData.TargetShape, applicable: AbilityData.ApplicableTo) -> AbilityData:
	var a := AbilityData.new()
	a.target_shape = shape
	a.applicable_to = applicable
	return a

func test_same_lane_picks_opposite() -> void:
	var board := LaneBoard.new()
	var caster := _make_unit("Caster")
	var enemy := _make_unit("Enemy")
	board.place(caster, 1, "ally")
	board.place(enemy, 1, "enemy")
	var ability := _make_ability(AbilityData.TargetShape.SAME_LANE, AbilityData.ApplicableTo.ENEMY)
	var targets := CombatManagerAuto.resolve_targets(caster, ability, board)
	assert(targets.size() == 1, "same_lane should yield 1 target")
	assert(targets[0] == enemy, "should target opposite-lane enemy")
	print("  PASS test_same_lane_picks_opposite")

func test_same_lane_falls_back_when_opposite_empty() -> void:
	var board := LaneBoard.new()
	var caster := _make_unit("Caster")
	var e0 := _make_unit("E0")
	board.place(caster, 1, "ally")
	board.place(e0, 0, "enemy")  # no enemy in lane 1
	var ability := _make_ability(AbilityData.TargetShape.SAME_LANE, AbilityData.ApplicableTo.ENEMY)
	var targets := CombatManagerAuto.resolve_targets(caster, ability, board)
	assert(targets.size() == 1, "should fall back to nearest non-empty lane")
	assert(targets[0] == e0, "should target the only enemy")
	print("  PASS test_same_lane_falls_back_when_opposite_empty")

func test_adjacent_lane_returns_two() -> void:
	var board := LaneBoard.new()
	var caster := _make_unit("Caster")
	var e0 := _make_unit("E0")
	var e1 := _make_unit("E1")
	var e2 := _make_unit("E2")
	board.place(caster, 1, "ally")
	board.place(e0, 0, "enemy")
	board.place(e1, 1, "enemy")
	board.place(e2, 2, "enemy")
	var ability := _make_ability(AbilityData.TargetShape.ADJACENT_LANE, AbilityData.ApplicableTo.ENEMY)
	var targets := CombatManagerAuto.resolve_targets(caster, ability, board)
	# adjacent to lane 1 = lanes 0 + 2 (NOT lane 1 itself)
	assert(targets.size() == 2, "adjacent_lane should yield 2 targets, got %d" % targets.size())
	print("  PASS test_adjacent_lane_returns_two")

func test_all_lanes_returns_all_enemies() -> void:
	var board := LaneBoard.new()
	var caster := _make_unit("Caster")
	var e0 := _make_unit("E0")
	var e1 := _make_unit("E1")
	board.place(caster, 0, "ally")
	board.place(e0, 0, "enemy")
	board.place(e1, 2, "enemy")
	var ability := _make_ability(AbilityData.TargetShape.ALL_LANES, AbilityData.ApplicableTo.ENEMY)
	var targets := CombatManagerAuto.resolve_targets(caster, ability, board)
	assert(targets.size() == 2, "all_lanes should hit both enemies")
	print("  PASS test_all_lanes_returns_all_enemies")

func test_self_targets_caster() -> void:
	var board := LaneBoard.new()
	var caster := _make_unit("Caster")
	board.place(caster, 1, "ally")
	var ability := _make_ability(AbilityData.TargetShape.SELF, AbilityData.ApplicableTo.ANY)
	var targets := CombatManagerAuto.resolve_targets(caster, ability, board)
	assert(targets.size() == 1 and targets[0] == caster, "self should yield caster")
	print("  PASS test_self_targets_caster")

func test_all_allies_excludes_enemies() -> void:
	var board := LaneBoard.new()
	var caster := _make_unit("Caster")
	var ally1 := _make_unit("Ally1")
	var enemy := _make_unit("Enemy")
	board.place(caster, 0, "ally")
	board.place(ally1, 1, "ally")
	board.place(enemy, 0, "enemy")
	var ability := _make_ability(AbilityData.TargetShape.ALL_ALLIES, AbilityData.ApplicableTo.ALLY)
	var targets := CombatManagerAuto.resolve_targets(caster, ability, board)
	assert(targets.size() == 2, "all_allies should yield caster + ally1")
	assert(not targets.has(enemy), "should not include enemy")
	print("  PASS test_all_allies_excludes_enemies")
