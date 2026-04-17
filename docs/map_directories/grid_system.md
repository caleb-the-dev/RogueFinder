# System: Grid System

> Last updated: 2026-04-17 (Session 11 — BFS pathfinding via find_path(); movement reservation with remaining_move)

---

## Purpose

The Grid is the **spatial authority** for combat. It owns:
- The canonical map of which cells exist and which are occupied
- All coordinate conversion math (world ↔ grid)
- Per-cell color highlighting (move range, attack targets, default)
- Mouse-to-cell input translation (3D: math raycast against Y=0 plane; 2D: pixel math)

Two versions: `Grid3D.gd` (active, 3D) and `Grid.gd` (legacy 2D).

---

## Core Nodes / Scripts

| File | Scene | Role |
|------|-------|------|
| `scripts/combat/Grid3D.gd` | `scenes/combat/Grid3D.tscn` | **Active** — 3D tile floor |
| `scripts/combat/Grid.gd` | `scenes/combat/Grid.tscn` | Legacy 2D — `_draw()` + click input |

`.tscn` files are minimal (root + script). All tile meshes are built in `_ready()`.

---

## Dependencies

| System | How it's used |
|--------|--------------|
| **Unit3D / Unit** | Stored in `_occupied` dict; `get_unit_at()` returns the Unit object |
| **CombatManager3D** | Calls all Grid methods — Grid itself has no direct dependency on CM |

Grid has **no dependency** on Camera, HUD, QTE, or UnitData.

---

## Constants

| Constant | 3D Value | 2D Value | Meaning |
|----------|----------|----------|---------|
| `COLS` | 10 | 6 | Grid width in cells |
| `ROWS` | 10 | 4 | Grid height in cells |
| `CELL_SIZE` | 2.0 | 80 | World units (3D) / pixels (2D) per cell |
| `CELL_GAP` | 0.08 | — | Visual gap between tiles in 3D |

## Enum: CellType (3D only)

| Value | Int | Meaning |
|-------|-----|---------|
| `NORMAL` | 0 | Default walkable cell |
| `WALL` | 1 | Impassable; `is_occupied()` returns true; renders a warm stone-colored box mesh |
| `HAZARD` | 2 | Walkable; deals 2 damage on entry **and** at start of each turn; renders as orange floor |

---

## Signals Emitted

| Signal | When |
|--------|------|
| `cell_clicked(grid_pos: Vector2i)` | **2D only** — emitted from `_input()`. In 3D, CM3D calls `get_clicked_cell()` directly instead. |

---

## Public Methods

### Coordinate Math

| Method | Signature | Purpose |
|--------|-----------|---------|
| `grid_to_world` | `(pos: Vector2i) -> Vector3` | Cell center in 3D world space |
| `world_to_grid` | `(local_pos: Vector3) -> Vector2i` | World position → nearest cell (clamps to bounds) |
| `get_clicked_cell` | `(camera: Camera3D, viewport: Viewport) -> Vector2i` | Raycasts from mouse through Y=0 plane; returns `(-1,-1)` on miss |

### Occupancy

| Method | Signature | Purpose |
|--------|-----------|---------|
| `is_valid` | `(pos: Vector2i) -> bool` | Cell is within grid bounds |
| `is_occupied` | `(pos: Vector2i) -> bool` | Cell has a unit registered **or is a wall** |
| `get_unit_at` | `(pos: Vector2i) -> Object` | Returns unit or `null` (walls return null — not in `_occupied`) |
| `set_occupied` | `(pos: Vector2i, unit: Object) -> void` | Registers a unit in the dict |
| `clear_occupied` | `(pos: Vector2i) -> void` | Removes unit registration |

### Cell Types (3D only)

| Method | Signature | Purpose |
|--------|-----------|---------|
| `set_cell_type` | `(cell: Vector2i, type: CellType) -> void` | Sets type; HAZARD also updates floor tile color to orange |
| `get_cell_type` | `(cell: Vector2i) -> CellType` | Returns type; absent key = NORMAL |
| `is_wall` | `(cell: Vector2i) -> bool` | True for WALL cells |
| `is_hazard` | `(cell: Vector2i) -> bool` | True for HAZARD cells |
| `build_walls` | `(cells: Array[Vector2i]) -> void` | Bulk register walls: sets type, darkens floor, spawns box mesh obstacles |

### Movement

| Method | Signature | Purpose |
|--------|-----------|---------|
| `get_move_range` | `(origin: Vector2i, speed: int) -> Array[Vector2i]` | Returns reachable cells using diagonal cost formula: `max(dx,dy) + min(dx,dy)*0.5 ≤ speed`; excludes occupied cells |
| `find_path` | `(from: Vector2i, to: Vector2i, ignore_unit: Object = null) -> Array[Vector2i]` | BFS pathfinding; returns ordered path from `from` (exclusive) to `to` (inclusive), routing around walls and occupied cells. `ignore_unit` is excluded from occupancy checks so the moving unit doesn't block itself. Returns empty array if no path exists. Uses 8-directional neighbors (matching diagonal movement support in `get_move_range`). |

### Highlighting

| Method | Signature | Purpose |
|--------|-----------|---------|
| `set_highlight` | `(pos: Vector2i, mode: String) -> void` | Modes: `"move"` (cyan), `"attack"` (red), `"select"` (yellow), `""` (clear one) |
| `clear_highlights` | `() -> void` | Resets all highlighted cells to base color |

---

## Internal Data

| Field | Type | Purpose |
|-------|------|---------|
| `_occupied` | `Dictionary` | `Vector2i → Object (Unit3D)` — occupancy map |
| `_cell_types` | `Dictionary` | `Vector2i → CellType` — absent key = NORMAL |
| `_cell_materials` | `Array[StandardMaterial3D]` | One material per cell (COLS × ROWS), mutated for highlights |
| `highlighted_cells` | `Dictionary` | `Vector2i → String (mode)` — tracks which cells are highlighted |

---

## Highlight Color Reference

| Mode / Type | Constant | Color |
|-------------|----------|-------|
| Base (default) | `COLOR_DEFAULT` | Dark blue-gray `Color(0.22, 0.22, 0.26)` |
| WALL box mesh | `COLOR_WALL` | Warm stone `Color(0.52, 0.50, 0.46)` — contrasts clearly against dark grid |
| WALL floor tile | — | Near-black `Color(0.14, 0.13, 0.11)` — darker than default to ground the wall visually |
| HAZARD floor | `COLOR_HAZARD` | Orange `Color(0.85, 0.40, 0.05)` — restored by `_refresh_cell_color` on highlight clear |
| `"move"` on normal cell | `COLOR_MOVE` | Cyan `Color(0.18, 0.45, 0.90, 0.85)` |
| `"move"` on hazard cell | `COLOR_MOVE_HAZARD` | Amber `Color(0.90, 0.52, 0.05, 0.88)` — signals "reachable but dangerous" |
| `"attack"` | `COLOR_ATTACK` | Red `Color(0.85, 0.22, 0.22, 0.85)` |
| `"selected"` | `COLOR_SELECTED` | Yellow `Color(0.90, 0.78, 0.10, 0.90)` |
| `"ability_target"` | `COLOR_ABILITY_TARGET` | Purple `Color(0.65, 0.20, 0.90, 0.85)` |

**Hazard color persistence:** `_refresh_cell_color()` uses `COLOR_HAZARD if is_hazard(pos) else COLOR_DEFAULT` in the default branch, so orange survives `clear_highlights()` calls. During move selection, hazard cells show amber (`COLOR_MOVE_HAZARD`) instead of cyan so the danger is visible while choosing a destination.

---

## 3D Raycast Logic (`get_clicked_cell`)

No physics bodies used. The math:
1. Build a ray from the camera through the mouse position.
2. Intersect the ray with the Y=0 plane (the grid floor).
3. Transform the hit point into the Grid's local space.
4. Call `world_to_grid()` to snap to the nearest cell.
5. Return `(-1, -1)` if the ray is parallel to the plane or the result is out of bounds.

---

## Notes

- Grid does **not** own units. It only stores references in `_occupied`. Unit3D is the source of truth for unit state.
- In 2D, `Grid.gd` also owns placement via `place_unit()` and `register_move()`. In 3D, CM3D manages this directly via `set_occupied()` / `clear_occupied()`.
