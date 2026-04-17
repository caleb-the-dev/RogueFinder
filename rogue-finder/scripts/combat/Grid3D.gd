class_name Grid3D
extends Node3D

## --- Grid3D ---
## 6x4 floor grid rendered as PlaneMesh tiles.
## Each cell has its own StandardMaterial3D so colors update independently.
## Mouse clicks are resolved via a Y=0 plane raycast (no physics bodies needed).

signal cell_clicked(grid_pos: Vector2i)

const COLS: int        = 10
const ROWS: int        = 10
const CELL_SIZE: float = 2.0
const CELL_GAP: float  = 0.08  # gap between tiles for readability

enum CellType { NORMAL = 0, WALL = 1, HAZARD = 2 }

const COLOR_DEFAULT:      Color = Color(0.22, 0.22, 0.26, 1.0)
const COLOR_MOVE:         Color = Color(0.18, 0.45, 0.90, 0.85)
const COLOR_ATTACK:       Color = Color(0.85, 0.22, 0.22, 0.85)
const COLOR_SELECTED:     Color = Color(0.90, 0.78, 0.10, 0.90)
const COLOR_ABILITY_TARGET: Color = Color(0.65, 0.20, 0.90, 0.85)  # purple
const COLOR_HAZARD:       Color = Color(0.85, 0.40, 0.05, 1.0)
const COLOR_MOVE_HAZARD:  Color = Color(0.90, 0.52, 0.05, 0.88)   # amber — reachable but dangerous
const COLOR_WALL:         Color = Color(0.52, 0.50, 0.46, 1.0)    # warm stone — visible against dark grid

# highlighted_cells: Vector2i -> "move" | "attack" | "selected"
var highlighted_cells: Dictionary = {}

# Per-cell materials indexed by (row * COLS + col)
var _cell_materials: Array[StandardMaterial3D] = []

# Occupancy map: Vector2i -> Unit3D (stored as Object to avoid circular typing)
var _occupied: Dictionary = {}

# Cell type map: Vector2i -> CellType (absent = NORMAL)
var _cell_types: Dictionary = {}

func _ready() -> void:
	_build_floor()

## --- Floor Construction ---

func _build_floor() -> void:
	for row in range(ROWS):
		for col in range(COLS):
			var tile := MeshInstance3D.new()
			var plane := PlaneMesh.new()
			plane.size = Vector2(CELL_SIZE - CELL_GAP, CELL_SIZE - CELL_GAP)
			tile.mesh     = plane
			# Sink tiles slightly below y=0 so units stand cleanly on top
			tile.position = Vector3(
				float(col) * CELL_SIZE,
				-0.01,
				float(row) * CELL_SIZE
			)

			var mat := StandardMaterial3D.new()
			mat.shading_mode  = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color  = COLOR_DEFAULT
			mat.transparency  = BaseMaterial3D.TRANSPARENCY_ALPHA
			tile.material_override = mat
			_cell_materials.append(mat)
			add_child(tile)

## --- Coordinate Helpers ---

func grid_to_world(pos: Vector2i) -> Vector3:
	return Vector3(float(pos.x) * CELL_SIZE, 0.0, float(pos.y) * CELL_SIZE)

func world_to_grid(local_pos: Vector3) -> Vector2i:
	return Vector2i(roundi(local_pos.x / CELL_SIZE), roundi(local_pos.z / CELL_SIZE))

func is_valid(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < COLS and pos.y >= 0 and pos.y < ROWS

## --- Occupancy ---

func is_occupied(pos: Vector2i) -> bool:
	return _occupied.has(pos) or is_wall(pos)

func get_unit_at(pos: Vector2i) -> Object:
	return _occupied.get(pos, null)

func set_occupied(pos: Vector2i, unit: Object) -> void:
	_occupied[pos] = unit

func clear_occupied(pos: Vector2i) -> void:
	_occupied.erase(pos)

## --- Cell Types ---

func set_cell_type(cell: Vector2i, type: CellType) -> void:
	_cell_types[cell] = type
	if type == CellType.HAZARD:
		var idx: int = cell.y * COLS + cell.x
		if idx < _cell_materials.size():
			_cell_materials[idx].albedo_color = COLOR_HAZARD

func get_cell_type(cell: Vector2i) -> CellType:
	return _cell_types.get(cell, CellType.NORMAL)

func is_wall(cell: Vector2i) -> bool:
	return _cell_types.get(cell, CellType.NORMAL) == CellType.WALL

func is_hazard(cell: Vector2i) -> bool:
	return _cell_types.get(cell, CellType.NORMAL) == CellType.HAZARD

## Registers wall cells: sets type, darkens the floor tile, and spawns a box mesh obstacle.
func build_walls(cells: Array[Vector2i]) -> void:
	for cell in cells:
		_cell_types[cell] = CellType.WALL
		var idx: int = cell.y * COLS + cell.x
		if idx < _cell_materials.size():
			_cell_materials[idx].albedo_color = Color(0.14, 0.13, 0.11, 1.0)
		var box_mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.7, 1.6, 0.7)
		box_mesh.mesh     = box
		box_mesh.position = Vector3(float(cell.x) * CELL_SIZE, 0.8, float(cell.y) * CELL_SIZE)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = COLOR_WALL
		box_mesh.material_override = mat
		add_child(box_mesh)

## --- Movement Range ---

func get_move_range(origin: Vector2i, speed: int) -> Array[Vector2i]:
	# Diagonal movement costs 1.5 (straight = 1.0, diagonal = 1.5).
	# Formula: cost = max(dx, dy) + min(dx, dy) * 0.5
	# Example: speed 3 → 3 straight, 2 diagonal, or 1 straight + 1 diagonal (cost 2.5).
	var result: Array[Vector2i] = []
	for row in range(ROWS):
		for col in range(COLS):
			var p := Vector2i(col, row)
			if p == origin:
				continue
			var dx: int   = abs(p.x - origin.x)
			var dy: int   = abs(p.y - origin.y)
			var cost: float = float(maxi(dx, dy)) + float(mini(dx, dy)) * 0.5
			if cost <= float(speed) and not is_occupied(p):
				result.append(p)
	return result

## --- Pathfinding ---

## BFS from `from` to `to`, routing around walls and occupied cells.
## Returns an ordered array of cells (exclusive of `from`, inclusive of `to`).
## `ignore_unit` is skipped in the occupancy check so the moving unit doesn't block itself.
## Returns empty array if no path exists.
func find_path(from: Vector2i, to: Vector2i, ignore_unit: Object = null) -> Array[Vector2i]:
	if from == to:
		return []
	# Straight neighbors first so tie-breaking prefers cardinal movement
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
	]
	var visited: Dictionary = {}
	var parent:  Dictionary = {}
	var queue: Array[Vector2i] = [from]
	visited[from] = true
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if current == to:
			var path: Array[Vector2i] = []
			var node: Vector2i = current
			while node != from:
				path.append(node)
				node = parent[node]
			path.reverse()
			return path
		for dir: Vector2i in dirs:
			var next: Vector2i = current + dir
			if not is_valid(next) or visited.has(next):
				continue
			if is_wall(next):
				continue
			var occupant: Object = _occupied.get(next, null)
			if occupant != null and occupant != ignore_unit:
				continue
			visited[next] = true
			parent[next]  = current
			queue.append(next)
	return []

## --- Highlight ---

func set_highlight(pos: Vector2i, mode: String) -> void:
	highlighted_cells[pos] = mode
	_refresh_cell_color(pos)

func clear_highlights() -> void:
	# Copy keys before iterating to avoid modifying during loop
	var keys: Array = highlighted_cells.keys().duplicate()
	highlighted_cells.clear()
	for pos in keys:
		_refresh_cell_color(pos)

func _refresh_cell_color(pos: Vector2i) -> void:
	if not is_valid(pos):
		return
	var idx: int = pos.y * COLS + pos.x
	if idx >= _cell_materials.size():
		return
	var mat: StandardMaterial3D = _cell_materials[idx]
	match highlighted_cells.get(pos, ""):
		"move":           mat.albedo_color = COLOR_MOVE_HAZARD if is_hazard(pos) else COLOR_MOVE
		"attack":         mat.albedo_color = COLOR_ATTACK
		"selected":       mat.albedo_color = COLOR_SELECTED
		"ability_target": mat.albedo_color = COLOR_ABILITY_TARGET
		_:                mat.albedo_color = COLOR_HAZARD if is_hazard(pos) else COLOR_DEFAULT

## --- Mouse Raycast ---

## Projects a mouse-position ray against the Y=0 plane and returns the grid cell.
## Returns Vector2i(-1, -1) if the ray misses the plane or the resulting cell is invalid.
func get_clicked_cell(camera: Camera3D, viewport: Viewport) -> Vector2i:
	var mouse_pos: Vector2    = viewport.get_mouse_position()
	var origin: Vector3       = camera.project_ray_origin(mouse_pos)
	var direction: Vector3    = camera.project_ray_normal(mouse_pos)

	# Avoid division by zero when ray is nearly horizontal
	if abs(direction.y) < 0.0001:
		return Vector2i(-1, -1)

	# t = distance along the ray to the y=0 plane
	var t: float = -origin.y / direction.y
	if t < 0.0:
		return Vector2i(-1, -1)

	var world_hit: Vector3 = origin + direction * t
	# Convert to this node's local space (handles any Grid3D offset)
	var local_hit: Vector3 = to_local(world_hit)
	var cell: Vector2i     = world_to_grid(local_hit)
	return cell if is_valid(cell) else Vector2i(-1, -1)
