extends Node

## --- Unit Tests: Pathfinding + Movement Reservation ---
## Tests find_path() routing, remaining_move deduction, and can_stride() budget gate.
## Does NOT require a running scene — Grid3D.new() + add_child() is sufficient.

func _ready() -> void:
	print("=== test_movement.gd ===")
	test_find_path_straight_line()
	test_find_path_routes_around_wall()
	test_find_path_ignores_moving_unit_own_cell()
	test_remaining_move_decrements_after_stride()
	test_can_stride_false_when_remaining_move_zero()
	test_get_move_range_uses_remaining_move()
	print("=== All movement tests passed ===")

## --- Helpers ---

func _make_grid() -> Grid3D:
	var g := Grid3D.new()
	add_child(g)
	return g

## Creates a unit and overrides remaining_move with the desired value for movement tests.
func _make_unit(speed: int = 6) -> Unit3D:
	var u := Unit3D.new()
	add_child(u)
	var d := CombatantData.new()
	d.character_name  = "Test"
	d.archetype_id    = "grunt"
	d.is_player_unit  = true
	d.vitality        = 2
	d.willpower       = 2
	d.strength        = 2
	d.cognition       = 2
	d.physical_armor  = 3
	d.magic_armor     = 2
	d.qte_resolution  = 0.5
	u.setup(d, Vector2i(0, 0))
	u.remaining_move = speed  # seed desired budget directly; speed formula is independent
	return u

## --- Tests ---

func test_find_path_straight_line() -> void:
	var g := _make_grid()
	var path: Array[Vector2i] = g.find_path(Vector2i(0, 0), Vector2i(0, 3))
	assert(path.size() == 3,
		"straight path (0,0)→(0,3) should have 3 steps, got %d" % path.size())
	assert(path[0] == Vector2i(0, 1), "first step should be (0,1), got %s" % str(path[0]))
	assert(path[1] == Vector2i(0, 2), "second step should be (0,2), got %s" % str(path[1]))
	assert(path[2] == Vector2i(0, 3), "last step should be (0,3), got %s" % str(path[2]))
	print("  PASS test_find_path_straight_line")

func test_find_path_routes_around_wall() -> void:
	var g := _make_grid()
	g.build_walls([Vector2i(1, 2)])
	var path: Array[Vector2i] = g.find_path(Vector2i(0, 2), Vector2i(2, 2))
	assert(not path.is_empty(),
		"should find a path around the wall at (1,2)")
	assert(not path.has(Vector2i(1, 2)),
		"path must not pass through wall at (1,2)")
	assert(path[-1] == Vector2i(2, 2),
		"path must end at destination (2,2), got %s" % str(path[-1]))
	print("  PASS test_find_path_routes_around_wall")

## Verifies that find_path works even when the moving unit is still registered
## in _occupied at its start cell (the ignore_unit parameter allows this).
func test_find_path_ignores_moving_unit_own_cell() -> void:
	var g := _make_grid()
	var u := _make_unit()
	u.grid_pos = Vector2i(1, 1)
	g.set_occupied(Vector2i(1, 1), u)
	var path: Array[Vector2i] = g.find_path(Vector2i(1, 1), Vector2i(3, 1), u)
	assert(not path.is_empty(),
		"path from unit's own registered cell should succeed with ignore_unit")
	assert(path[-1] == Vector2i(3, 1),
		"path must end at destination (3,1), got %s" % str(path[-1]))
	print("  PASS test_find_path_ignores_moving_unit_own_cell")

func test_remaining_move_decrements_after_stride() -> void:
	var u := _make_unit(6)
	assert(u.remaining_move == 6,
		"remaining_move should equal speed (6) after setup, got %d" % u.remaining_move)
	u.remaining_move -= 3
	assert(u.remaining_move == 3,
		"remaining_move should be 3 after moving 3 tiles, got %d" % u.remaining_move)
	print("  PASS test_remaining_move_decrements_after_stride")

func test_can_stride_false_when_remaining_move_zero() -> void:
	var u := _make_unit(6)
	u.remaining_move = 0
	assert(not u.can_stride(),
		"can_stride() must return false when remaining_move is 0")
	print("  PASS test_can_stride_false_when_remaining_move_zero")

func test_get_move_range_uses_remaining_move() -> void:
	var g := _make_grid()
	var origin := Vector2i(5, 5)
	var full_range: Array[Vector2i]    = g.get_move_range(origin, 6)
	var reduced_range: Array[Vector2i] = g.get_move_range(origin, 2)
	assert(reduced_range.size() < full_range.size(),
		"get_move_range with remaining_move=2 should return fewer cells than speed=6 " \
		+ "(got %d vs %d)" % [reduced_range.size(), full_range.size()])
	print("  PASS test_get_move_range_uses_remaining_move")
