extends Node

func _ready() -> void:
	print("=== test_lane_board.gd ===")
	test_init_empty()
	test_place_unit()
	test_lane_full()
	test_remove_unit()
	test_get_opposite()
	test_adjacent_lanes()
	print("=== All LaneBoard tests passed ===")

func test_init_empty() -> void:
	var board := LaneBoard.new()
	for lane in 3:
		assert(board.get_unit(lane, "ally") == null, "ally lane %d should be empty" % lane)
		assert(board.get_unit(lane, "enemy") == null, "enemy lane %d should be empty" % lane)
	print("  PASS test_init_empty")

func test_place_unit() -> void:
	var board := LaneBoard.new()
	var d := CombatantData.new()
	d.character_name = "TestUnit"
	board.place(d, 1, "ally")
	assert(board.get_unit(1, "ally") == d, "ally lane 1 should hold the placed unit")
	assert(board.get_unit(0, "ally") == null, "ally lane 0 should still be empty")
	print("  PASS test_place_unit")

func test_lane_full() -> void:
	var board := LaneBoard.new()
	var d1 := CombatantData.new()
	var d2 := CombatantData.new()
	board.place(d1, 1, "ally")
	# Second placement on same lane+side overwrites (last-write-wins)
	board.place(d2, 1, "ally")
	assert(board.get_unit(1, "ally") == d2, "second placement should overwrite (last-write-wins)")
	print("  PASS test_lane_full")

func test_remove_unit() -> void:
	var board := LaneBoard.new()
	var d := CombatantData.new()
	board.place(d, 0, "enemy")
	board.remove(0, "enemy")
	assert(board.get_unit(0, "enemy") == null, "removed lane should be empty")
	print("  PASS test_remove_unit")

func test_get_opposite() -> void:
	var board := LaneBoard.new()
	var ally := CombatantData.new()
	var enemy := CombatantData.new()
	board.place(ally, 1, "ally")
	board.place(enemy, 1, "enemy")
	assert(board.get_opposite(ally) == enemy, "opposite of ally lane 1 is enemy lane 1")
	print("  PASS test_get_opposite")

func test_adjacent_lanes() -> void:
	var board := LaneBoard.new()
	var enemies: Array[CombatantData] = [CombatantData.new(), CombatantData.new(), CombatantData.new()]
	for i in 3:
		board.place(enemies[i], i, "enemy")
	# Adjacent to lane 1 = lanes 0 + 2
	var adj := board.get_adjacent_lane_units(1, "enemy")
	assert(adj.size() == 2, "adjacent to lane 1 should yield 2 enemies, got %d" % adj.size())
	# Adjacent to lane 0 = lane 1 only (no lane -1)
	var adj0 := board.get_adjacent_lane_units(0, "enemy")
	assert(adj0.size() == 1, "adjacent to lane 0 should yield 1 enemy")
	print("  PASS test_adjacent_lanes")
