# System: Grid System

> Last updated: 2026-04-14 (Session 2 — Stage 1.5)

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
| `COLS` | 6 | 6 | Grid width in cells |
| `ROWS` | 4 | 4 | Grid height in cells |
| `CELL_SIZE` | 2.0 | 80 | World units (3D) / pixels (2D) per cell |
| `CELL_GAP` | 0.08 | — | Visual gap between tiles in 3D |

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
| `is_occupied` | `(pos: Vector2i) -> bool` | Cell has a unit registered |
| `get_unit_at` | `(pos: Vector2i) -> Object` | Returns unit or `null` |
| `set_occupied` | `(pos: Vector2i, unit: Object) -> void` | Registers a unit in the dict |
| `clear_occupied` | `(pos: Vector2i) -> void` | Removes unit registration |

### Movement

| Method | Signature | Purpose |
|--------|-----------|---------|
| `get_move_range` | `(origin: Vector2i, speed: int) -> Array[Vector2i]` | BFS flood-fill within Manhattan distance = speed; excludes occupied cells |

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
| `_cell_materials` | `Array[StandardMaterial3D]` | One material per cell (COLS × ROWS), mutated for highlights |
| `highlighted_cells` | `Dictionary` | `Vector2i → String (mode)` — tracks which cells are highlighted |

---

## Highlight Color Reference

| Mode | Color |
|------|-------|
| Base (player side) | Dark blue-gray |
| Base (enemy side) | Dark red-gray |
| `"move"` | Cyan `#00cccc` |
| `"attack"` | Red `#cc2200` |
| `"select"` | Yellow `#cccc00` |

Player side = col 0–2; enemy side = col 3–5 (visual distinction only, not enforced by Grid).

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
