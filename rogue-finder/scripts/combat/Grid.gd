class_name Grid
extends Node2D

## --- Grid ---
## Owns the 6×4 combat grid: cell drawing, unit placement, and movement validation.
## Draws cells via _draw() so highlights require only a queue_redraw() call.
## Mouse clicks are translated to grid coords and emitted as cell_clicked.

## --- Signals ---
signal cell_clicked(grid_pos: Vector2i)

## --- Constants ---
const COLS: int = 6
const ROWS: int = 4
const CELL_SIZE: int = 80
const BORDER: int   = 2

## --- Cell Colors ---
const COLOR_NORMAL   := Color(0.17, 0.17, 0.20)
const COLOR_MOVE     := Color(0.20, 0.55, 0.90, 0.65)
const COLOR_ATTACK   := Color(0.90, 0.22, 0.18, 0.65)
const COLOR_BORDER   := Color(0.40, 0.40, 0.46)

## Maps Vector2i grid position → Unit (absent key = empty cell).
var unit_map: Dictionary = {}

## Cells flagged for highlight: Vector2i → "move" | "attack"
var highlighted_cells: Dictionary = {}

## Container node where Unit scenes are added at runtime.
@onready var units_container: Node2D = $Units

func _ready() -> void:
	queue_redraw()

## --- Drawing ---

func _draw() -> void:
	for row: int in range(ROWS):
		for col: int in range(COLS):
			var pos := Vector2i(col, row)
			var rect := Rect2(
				col * CELL_SIZE + BORDER,
				row * CELL_SIZE + BORDER,
				CELL_SIZE - BORDER * 2,
				CELL_SIZE - BORDER * 2,
			)
			# Choose fill color based on active highlight state
			var fill: Color = COLOR_NORMAL
			if pos in highlighted_cells:
				fill = COLOR_MOVE if highlighted_cells[pos] == "move" else COLOR_ATTACK
			draw_rect(rect, fill)
			draw_rect(rect, COLOR_BORDER, false, 1.0)

## --- Input ---

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		# Convert global mouse to this node's local space
		var local: Vector2 = to_local(get_global_mouse_position())
		var gp: Vector2i = _pixel_to_grid(local)
		if is_valid_cell(gp):
			cell_clicked.emit(gp)

## --- Public API ---

func is_valid_cell(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < COLS and pos.y >= 0 and pos.y < ROWS

func is_occupied(pos: Vector2i) -> bool:
	return unit_map.has(pos)

func get_unit_at(pos: Vector2i) -> Unit:
	return unit_map.get(pos, null)

## Adds a unit to the grid at the given position.
func place_unit(unit: Unit, pos: Vector2i) -> void:
	unit_map[pos] = unit
	units_container.add_child(unit)
	# Unit.position is relative to units_container, which is local to Grid
	unit.position = Vector2(pos.x * CELL_SIZE, pos.y * CELL_SIZE)

## Syncs unit_map after a unit moves. Unit.move_to() handles the visual position.
func register_move(unit: Unit, old_pos: Vector2i, new_pos: Vector2i) -> void:
	unit_map.erase(old_pos)
	unit_map[new_pos] = unit

## Returns all empty cells within the unit's speed (Manhattan distance).
## Ignores pathfinding for Stage 1 — any reachable empty cell is valid.
func get_valid_move_cells(unit: Unit) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for row: int in range(ROWS):
		for col: int in range(COLS):
			var pos := Vector2i(col, row)
			var dist: int = abs(pos.x - unit.grid_pos.x) + abs(pos.y - unit.grid_pos.y)
			# Must be within speed, not the unit's current cell, and not occupied
			if dist > 0 and dist <= unit.data.speed and not is_occupied(pos):
				cells.append(pos)
	return cells

func show_move_highlights(cells: Array[Vector2i]) -> void:
	highlighted_cells.clear()
	for cell: Vector2i in cells:
		highlighted_cells[cell] = "move"
	queue_redraw()

func show_attack_highlights(cells: Array[Vector2i]) -> void:
	highlighted_cells.clear()
	for cell: Vector2i in cells:
		highlighted_cells[cell] = "attack"
	queue_redraw()

func clear_highlights() -> void:
	highlighted_cells.clear()
	queue_redraw()

## --- Private Helpers ---

func _pixel_to_grid(local_pixel: Vector2) -> Vector2i:
	# Integer divide to map pixel offset to column/row
	return Vector2i(int(local_pixel.x) / CELL_SIZE, int(local_pixel.y) / CELL_SIZE)
