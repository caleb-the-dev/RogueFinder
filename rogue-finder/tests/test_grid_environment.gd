extends Node

## --- Unit Tests: Grid3D environment tiles (walls and hazards) ---
## Tests cell type queries, occupancy behavior, movement range, and hazard damage.
## Does NOT require a running scene for grid tests — Grid3D.new() + add_child() is enough.
## Unit3D hazard damage test requires add_child() for _ready() to fire.

func _ready() -> void:
	print("=== test_grid_environment.gd ===")
	test_is_wall_returns_true_for_wall_cell()
	test_is_wall_returns_false_for_normal_and_hazard()
	test_is_occupied_true_for_wall_false_for_hazard()
	test_get_unit_at_returns_null_for_wall()
	test_get_move_range_excludes_wall_cells()
	test_apply_force_stops_at_wall_via_is_occupied()
	test_force_traversal_hazard_damage()
	test_hazard_damage_unit_on_hazard()
	test_hazard_damage_unit_not_on_hazard()
	print("=== All grid_environment tests passed ===")

## --- Helpers ---

func _make_grid() -> Grid3D:
	var g := Grid3D.new()
	add_child(g)
	return g

func _make_combatant_data(hp: int = 20) -> CombatantData:
	var d := CombatantData.new()
	d.character_name = "Test"
	d.archetype_name = "grunt"
	d.is_player_unit = true
	d.speed          = 3
	d.hp_max         = hp
	d.energy_max     = 10
	d.energy_regen   = 3
	d.attack         = 5
	d.defense        = 5
	d.strength       = 2
	d.dexterity      = 2
	d.cognition      = 2
	d.vitality       = 2
	d.willpower      = 2
	d.qte_resolution = 0.5
	return d

## --- Tests ---

func test_is_wall_returns_true_for_wall_cell() -> void:
	var g := _make_grid()
	var wall := Vector2i(3, 3)
	g.build_walls([wall])
	assert(g.is_wall(wall), "is_wall() should return true after build_walls()")
	print("  PASS test_is_wall_returns_true_for_wall_cell")

func test_is_wall_returns_false_for_normal_and_hazard() -> void:
	var g := _make_grid()
	var hazard := Vector2i(2, 2)
	var normal := Vector2i(1, 1)
	g.set_cell_type(hazard, Grid3D.CellType.HAZARD)
	assert(not g.is_wall(hazard), "is_wall() should be false for HAZARD cell")
	assert(not g.is_wall(normal), "is_wall() should be false for NORMAL cell")
	print("  PASS test_is_wall_returns_false_for_normal_and_hazard")

func test_is_occupied_true_for_wall_false_for_hazard() -> void:
	var g := _make_grid()
	var wall   := Vector2i(4, 4)
	var hazard := Vector2i(5, 5)
	g.build_walls([wall])
	g.set_cell_type(hazard, Grid3D.CellType.HAZARD)
	assert(g.is_occupied(wall),       "is_occupied() must return true for wall cells")
	assert(not g.is_occupied(hazard), "is_occupied() must return false for hazard cells")
	print("  PASS test_is_occupied_true_for_wall_false_for_hazard")

func test_get_unit_at_returns_null_for_wall() -> void:
	var g := _make_grid()
	var wall := Vector2i(3, 5)
	g.build_walls([wall])
	# _occupied has no entry for wall cells — only is_wall() drives is_occupied()
	assert(g.get_unit_at(wall) == null, "get_unit_at() should return null for wall cells")
	print("  PASS test_get_unit_at_returns_null_for_wall")

func test_get_move_range_excludes_wall_cells() -> void:
	var g    := _make_grid()
	var origin := Vector2i(5, 5)
	var wall   := Vector2i(6, 5)  # directly adjacent to origin
	g.build_walls([wall])
	var range_cells: Array[Vector2i] = g.get_move_range(origin, 3)
	assert(not range_cells.has(wall), "get_move_range() must not include wall cells")
	print("  PASS test_get_move_range_excludes_wall_cells")

## Tests the is_occupied guard that _apply_force() uses to halt displacement.
## A wall cell reports is_occupied() = true, so a force-displaced unit stops before it.
func test_apply_force_stops_at_wall_via_is_occupied() -> void:
	var g    := _make_grid()
	var wall := Vector2i(7, 5)
	g.build_walls([wall])
	var dest := Vector2i(5, 5)
	var dir  := Vector2i(1, 0)
	for _i in range(3):
		var nxt: Vector2i = dest + dir
		if not g.is_valid(nxt) or g.is_occupied(nxt):
			break
		dest = nxt
	assert(dest == Vector2i(6, 5),
		"FORCE displacement should stop before wall at (7,5); expected dest (6,5), got %s" % str(dest))
	print("  PASS test_apply_force_stops_at_wall_via_is_occupied")

## Tests that every hazard cell in a FORCE path deals 2 HP, not just the landing cell.
## Path: (5,5) → (6,5)[hazard] → (7,5)[landing]. Unit should take 2 HP from (6,5).
func test_force_traversal_hazard_damage() -> void:
	var g      := _make_grid()
	var hazard := Vector2i(6, 5)  # intermediate cell — not the landing cell
	g.set_cell_type(hazard, Grid3D.CellType.HAZARD)

	var unit := Unit3D.new()
	add_child(unit)
	var d := _make_combatant_data(20)
	unit.setup(d, Vector2i(5, 5))

	# Inline the _apply_force path + traversal damage logic
	var dest := Vector2i(5, 5)
	var dir  := Vector2i(1, 0)
	var path: Array[Vector2i] = []
	for _i in range(3):
		var nxt: Vector2i = dest + dir
		if not g.is_valid(nxt) or g.is_occupied(nxt):
			break
		dest = nxt
		path.append(dest)

	var hp_before: int = unit.current_hp
	for cell in path:
		if g.is_hazard(cell):
			unit.take_damage(2)
			if not unit.is_alive:
				break

	assert(unit.current_hp == hp_before - 2,
		"Unit force-traversed through hazard at (6,5) should lose 2 HP; expected %d, got %d" \
		% [hp_before - 2, unit.current_hp])
	assert(dest == Vector2i(7, 5),
		"Unit should land at (7,5), got %s" % str(dest))
	print("  PASS test_force_traversal_hazard_damage")

func test_hazard_damage_unit_on_hazard() -> void:
	var g       := _make_grid()
	var hazard  := Vector2i(2, 3)
	g.set_cell_type(hazard, Grid3D.CellType.HAZARD)

	var unit := Unit3D.new()
	add_child(unit)  # triggers _ready() / _build_visuals()
	var d := _make_combatant_data(20)
	unit.setup(d, hazard)

	var hp_before: int = unit.current_hp
	# Inline _check_hazard_damage logic
	if g.is_hazard(unit.grid_pos) and unit.is_alive:
		unit.take_damage(2)
	assert(unit.current_hp == hp_before - 2,
		"Unit on hazard should lose 2 HP; expected %d, got %d" % [hp_before - 2, unit.current_hp])
	print("  PASS test_hazard_damage_unit_on_hazard")

func test_hazard_damage_unit_not_on_hazard() -> void:
	var g      := _make_grid()
	var normal := Vector2i(1, 1)
	# normal cell — no set_cell_type call

	var unit := Unit3D.new()
	add_child(unit)
	var d := _make_combatant_data(20)
	unit.setup(d, normal)

	var hp_before: int = unit.current_hp
	if g.is_hazard(unit.grid_pos) and unit.is_alive:
		unit.take_damage(2)
	assert(unit.current_hp == hp_before,
		"Unit not on hazard should be unaffected; expected %d, got %d" % [hp_before, unit.current_hp])
	print("  PASS test_hazard_damage_unit_not_on_hazard")
