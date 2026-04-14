extends Node

## --- Unit Tests: Grid.gd ---
## Tests grid logic: cell validation, occupation checks, movement range calculation.
## Does NOT require a running scene — uses Grid as a plain Node.

func _ready() -> void:
	print("=== test_grid.gd ===")
	test_is_valid_cell_boundaries()
	test_is_occupied_reflects_unit_map()
	test_get_valid_move_cells_within_speed()
	test_get_valid_move_cells_excludes_occupied()
	test_get_valid_move_cells_excludes_own_cell()
	test_get_valid_move_cells_excludes_out_of_bounds_near_edge()
	test_register_move_updates_map()
	test_highlight_dicts_populated()
	print("=== All Grid tests passed ===")

## --- Helpers ---

func _make_grid() -> Grid:
	var g := Grid.new()
	# Grid._ready() calls queue_redraw() which is safe on a node not in the tree
	# Units container must exist for place_unit; create it manually
	var units := Node2D.new()
	units.name = "Units"
	g.add_child(units)
	add_child(g)
	return g

func _make_unit_data(speed: int = 3) -> UnitData:
	var d := UnitData.new()
	d.unit_name      = "T"
	d.is_player_unit = true
	d.speed          = speed
	d.hp_max         = 20
	d.energy_max     = 10
	d.energy_regen   = 3
	d.attack         = 10
	d.defense        = 10
	return d

func _make_unit_at(g: Grid, col: int, row: int, speed: int = 3) -> Unit:
	var u := Unit.new()
	var visual := ColorRect.new(); u.add_child(visual)
	var nl     := Label.new();     u.add_child(nl)
	var sl     := Label.new();     u.add_child(sl)
	u.set("visual", visual); u.set("name_label", nl); u.set("stats_label", sl)
	var pos := Vector2i(col, row)
	g.place_unit(u, pos)
	u.data     = _make_unit_data(speed)
	u.grid_pos = pos
	u.current_hp     = 20
	u.current_energy = 10
	u.is_alive       = true
	return u

## --- Tests ---

func test_is_valid_cell_boundaries() -> void:
	var g := _make_grid()
	assert(g.is_valid_cell(Vector2i(0, 0)),   "Top-left corner should be valid")
	assert(g.is_valid_cell(Vector2i(5, 3)),   "Bottom-right corner should be valid")
	assert(not g.is_valid_cell(Vector2i(-1, 0)), "Column -1 is out of bounds")
	assert(not g.is_valid_cell(Vector2i(6, 0)),  "Column 6 is out of bounds (max 5)")
	assert(not g.is_valid_cell(Vector2i(0, 4)),  "Row 4 is out of bounds (max 3)")
	print("  PASS test_is_valid_cell_boundaries")

func test_is_occupied_reflects_unit_map() -> void:
	var g := _make_grid()
	assert(not g.is_occupied(Vector2i(2, 2)), "Cell should be empty initially")
	_make_unit_at(g, 2, 2)
	assert(g.is_occupied(Vector2i(2, 2)),     "Cell should be occupied after place_unit")
	print("  PASS test_is_occupied_reflects_unit_map")

func test_get_valid_move_cells_within_speed() -> void:
	var g := _make_grid()
	var u := _make_unit_at(g, 3, 1, 2)   # speed = 2, placed at (3,1)
	var cells := g.get_valid_move_cells(u)
	# All returned cells must be within Manhattan distance 2
	for cell: Vector2i in cells:
		var dist: int = abs(cell.x - 3) + abs(cell.y - 1)
		assert(dist <= 2, "Cell %s is farther than speed 2 from origin (3,1)" % str(cell))
	print("  PASS test_get_valid_move_cells_within_speed (found %d cells)" % cells.size())

func test_get_valid_move_cells_excludes_occupied() -> void:
	var g := _make_grid()
	var u := _make_unit_at(g, 3, 1, 3)
	_make_unit_at(g, 4, 1)   # blocker at (4,1)
	var cells := g.get_valid_move_cells(u)
	assert(not cells.has(Vector2i(4, 1)), "Occupied cell (4,1) should not be a valid move")
	print("  PASS test_get_valid_move_cells_excludes_occupied")

func test_get_valid_move_cells_excludes_own_cell() -> void:
	var g := _make_grid()
	var u := _make_unit_at(g, 2, 2, 3)
	var cells := g.get_valid_move_cells(u)
	assert(not cells.has(Vector2i(2, 2)), "Unit's own cell should never appear in move list")
	print("  PASS test_get_valid_move_cells_excludes_own_cell")

func test_get_valid_move_cells_excludes_out_of_bounds_near_edge() -> void:
	var g := _make_grid()
	var u := _make_unit_at(g, 0, 0, 3)   # top-left corner, speed 3
	var cells := g.get_valid_move_cells(u)
	for cell: Vector2i in cells:
		assert(g.is_valid_cell(cell), "Move cell %s is out of grid bounds" % str(cell))
	print("  PASS test_get_valid_move_cells_excludes_out_of_bounds_near_edge")

func test_register_move_updates_map() -> void:
	var g := _make_grid()
	var u := _make_unit_at(g, 1, 1)
	g.register_move(u, Vector2i(1, 1), Vector2i(2, 1))
	assert(not g.is_occupied(Vector2i(1, 1)), "Old cell should be freed after register_move")
	assert(g.is_occupied(Vector2i(2, 1)),     "New cell should be occupied after register_move")
	assert(g.get_unit_at(Vector2i(2, 1)) == u, "unit_map should reference the moved unit")
	print("  PASS test_register_move_updates_map")

func test_highlight_dicts_populated() -> void:
	var g := _make_grid()
	var cells: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 2)]
	g.show_move_highlights(cells)
	assert(g.highlighted_cells.has(Vector2i(1, 1)), "Highlighted cells should contain (1,1)")
	assert(g.highlighted_cells[Vector2i(1, 1)] == "move", "Type should be 'move'")
	g.show_attack_highlights(cells)
	assert(g.highlighted_cells[Vector2i(2, 2)] == "attack", "Type should be 'attack' after switch")
	g.clear_highlights()
	assert(g.highlighted_cells.is_empty(), "Highlights should be empty after clear")
	print("  PASS test_highlight_dicts_populated")
