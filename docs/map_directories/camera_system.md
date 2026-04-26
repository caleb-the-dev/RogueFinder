# System: Camera System

> Last updated: 2026-04-26 (camera pan + full orbit right-click drag + Q/E pivot-Y + QTE zoom)

---

## Purpose

The Camera System provides a **DOS2-style isometric orbit camera** for the 3D combat scene. It handles:
- Full-orbit right-click drag: horizontal movement rotates yaw; vertical movement adjusts elevation (pitch), clamped 15°–80°
- Q / E keys smoothly raise / lower the orbit pivot on the world Y axis (not pitch — vertical slide)
- WASD / arrow keys pan the orbit pivot in yaw-relative XZ space, clamped to world bounds
- Mouse scroll wheel zoom
- Procedural camera shake on combat events (hit feedback)
- **Smooth QTE focus** — pivots to the attacker's position and zooms in before a QTE starts, then restores both position and zoom distance

The camera is built and owned by `CombatManager3D`. No `.tscn` — it's instantiated entirely in code.

---

## Core Nodes / Scripts

| File | Scene | Role |
|------|-------|------|
| `scripts/camera/CameraController.gd` | *(none — built in code)* | Orbit camera + shake + QTE focus |

---

## Dependencies

CameraController has **no knowledge of other game systems** — it is a self-contained `Node3D`.

CombatManager3D uses it as follows:
- `trigger_shake()` — called on combat hit
- `focus_on(world_pos)` — called at the start of every player-defender QTE; result is awaited
- `restore()` — called after `qte_resolved` fires; fire-and-forget
- `get_camera()` — passed to Grid3D for raycasting, and used by QTEBar for world→screen projection

---

## Signals Emitted

None.

---

## Public Methods

| Method | Signature | Purpose |
|--------|-----------|---------|
| `trigger_shake` | `() -> void` | Starts a 0.22s procedural shake (called by CombatManager on hit) |
| `get_forward` | `() -> Vector3` | Returns the camera's XZ forward direction (for 8-dir sprite selection) |
| `get_camera` | `() -> Camera3D` | Returns the child Camera3D node |
| `focus_on` | `(world_pos: Vector3) -> Tween` | Saves `_pre_qte_distance`, then parallel-tweens pivot to `world_pos` (0.5 s) and distance to `QTE_DISTANCE` (0.5 s). Returns the Tween so callers can `await tween.finished`. Kills any in-progress pivot tween first. |
| `restore` | `() -> void` | Fire-and-forget: parallel-tweens pivot back to `_home_position` (0.45 s) and distance back to `_pre_qte_distance` (0.45 s). Kills any in-progress pivot tween first. |

---

## Camera Parameters

| Constant | Value | Meaning |
|----------|-------|---------|
| `DEFAULT_DISTANCE` | 16.0 | Default orbit radius |
| `MIN_DISTANCE` | 8.0 | Minimum zoom distance |
| `MAX_DISTANCE` | 28.0 | Maximum zoom distance |
| `QTE_DISTANCE` | 10.0 | Orbit radius during QTE focus zoom-in |
| `DEFAULT_ELEVATION` | 52.0° | Starting camera pitch |
| `MIN_ELEVATION` | 15.0° | Lowest allowed pitch (near-horizon) |
| `MAX_ELEVATION` | 80.0° | Highest allowed pitch (near-top-down) |
| `DEFAULT_YAW` | 225.0° | Starting yaw angle |
| `ZOOM_STEP` | 2.0 | Scroll wheel zoom increment |
| `DRAG_SENSITIVITY` | 0.2 | Degrees per pixel for both yaw (horizontal drag) and elevation (vertical drag) |
| `SHAKE_DURATION` | 0.22 s | Duration of shake effect |
| `SHAKE_MAGNITUDE` | 0.18 | Max displacement per shake tick |
| `PAN_SPEED` | 10.0 | Pivot units/second for WASD / arrow-key pan |
| `PAN_MIN` | −5.0 | Minimum X and Z clamp for the orbit pivot |
| `PAN_MAX` | 25.0 | Maximum X and Z clamp for the orbit pivot |
| `PIVOT_Y_SPEED` | 5.0 | World units/second while Q / E held (vertical pivot slide) |
| `PIVOT_Y_MIN` | −3.0 | Lowest world Y the orbit pivot can reach |
| `PIVOT_Y_MAX` | 8.0 | Highest world Y the orbit pivot can reach |

---

## Key Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `_yaw` | `float` | `225.0` | Current horizontal orbit angle (degrees) |
| `_elevation` | `float` | `52.0` | Current camera pitch in degrees; clamped to MIN/MAX_ELEVATION; adjusted by right-click vertical drag |
| `_distance` | `float` | `16.0` | Current orbit radius |
| `_dragging` | `bool` | `false` | True while right mouse button is held; gates yaw + elevation drag input |
| `_shake_timer` | `float` | `0.0` | Countdown for shake; set by `trigger_shake()` |
| `_shake_offset` | `Vector3` | `ZERO` | Additive shake displacement applied to Camera3D |
| `_camera` | `Camera3D` | `null` | Child Camera3D; created in `_ready()` |
| `_home_position` | `Vector3` | `ZERO` | Grid center pivot; captured from `position` in `_ready()` |
| `_pivot_tween` | `Tween` | `null` | Tracks the active focus/restore tween; killed before starting a new one |
| `_pre_qte_distance` | `float` | `DEFAULT_DISTANCE` | Distance saved at `focus_on()` time so `restore()` can zoom back out |

---

## Input Handling

| Input | Handler | Action |
|-------|---------|--------|
| `Right-click drag (horizontal)` | `_unhandled_input` | Rotate orbit yaw; `event.relative.x * DRAG_SENSITIVITY` degrees |
| `Right-click drag (vertical)` | `_unhandled_input` | Adjust elevation pitch; drag up increases elevation (more top-down), clamped 15°–80° |
| `ScrollUp` | `_unhandled_input` | Zoom in (decrease distance) |
| `ScrollDown` | `_unhandled_input` | Zoom out (increase distance) |
| `Q` | `_process` | Raise orbit pivot on world Y axis (`PIVOT_Y_SPEED` u/s, clamped to `PIVOT_Y_MAX` = 8) |
| `E` | `_process` | Lower orbit pivot on world Y axis (`PIVOT_Y_SPEED` u/s, clamped to `PIVOT_Y_MIN` = −3) |
| `W / Up` | `_process` | Pan pivot NE (opposite camera-position vector at default yaw) |
| `S / Down` | `_process` | Pan pivot SW |
| `A / Left` | `_process` | Pan pivot left (strafe) |
| `D / Right` | `_process` | Pan pivot right (strafe) |

Right-click drag (yaw + elevation) and scroll use `_unhandled_input`. Q/E pivot-Y and WASD pan use `Input.is_key_pressed()` polling in `_process`.

Right-click drag and scroll still respond during QTE tweens. **Q/E pivot-Y and WASD pan are suppressed while `_pivot_tween` is running** to avoid fighting the tween.

---

## Shake Implementation

`trigger_shake()` sets `_shake_timer = SHAKE_DURATION`. Each `_process()` tick while `_shake_timer > 0`:
1. Generates a random offset within `SHAKE_MAGNITUDE` on X and Y.
2. Applies the offset to the Camera3D's local position.
3. Decrements `_shake_timer` by `delta`.
4. Clears the offset when the timer expires.

Shake is additive on top of the normal orbit transform, computed in `_apply_transform()`.

---

## Focus / Restore (QTE camera)

`focus_on(world_pos)` and `restore()` both use a **parallel tween** (`.set_parallel(true)`) so pivot position and orbit distance animate simultaneously.

- `focus_on`: saves `_pre_qte_distance`, then tweens `position` → `world_pos` via `_set_pivot` and `_distance` → `QTE_DISTANCE` via `_set_distance`, both over 0.5 s.
- `restore`: tweens `position` → `_home_position` via `_set_pivot` and `_distance` → `_pre_qte_distance` via `_set_distance`, both over 0.45 s.

Both tween methods (`_set_pivot`, `_set_distance`) call `_apply_transform()` each step. Both methods kill `_pivot_tween` before starting a new one — tweens never stack.

**Timing in `_run_harm_defenders`:**
```
await _camera_rig.focus_on(caster.global_position).finished   # 0.5 s tween
await get_tree().create_timer(0.25).timeout                    # brief settle
_qte_bar.start_qte(energy_cost, caster)                       # bar appears
...
_camera_rig.restore()                                          # 0.45 s tween back, fire-and-forget
```

---

## Transform Pipeline (`_apply_transform`)

```
1. Compute camera local offset from _yaw, _elevation, and _distance.
2. Set _camera.position to that local offset + _shake_offset.
3. Call _camera.look_at(global_position) so camera always points at the pivot.
```

The pivot (`position` / `global_position`) is normally `Vector3(9, 0, 9)` (grid center), but moves during a focus tween.

---

## Notes

- `_home_position` is captured from `position` in `_ready()`. CM3D sets `_camera_rig.position = Vector3(9.0, 0.0, 9.0)` **before** `add_child()`, so `_ready()` sees the correct value. Do not change this ordering.
- `get_camera()` returns null if called before `_ready()` fires.
- `DEFAULT_ELEVATION` of 52° gives a near-isometric look — readable 3D battlefield without true 45° projection. Player adjusts pitch via right-click vertical drag (clamped 15°–80°).
- Right-click drag is used for full orbit (yaw + elevation) because left-click is claimed by CombatManager3D for unit selection.
- Q/E move the orbit pivot on world Y, **not** camera pitch. This lets you pan the view up/down to see elevated or low terrain without changing the camera angle.
- During a QTE tween, right-click drag and scroll still work (they call `_apply_transform()` immediately, additive with the tween). Q/E pivot-Y and WASD pan are suppressed to avoid fighting the tween.
- **Known limitation:** `restore()` tweens back to `_home_position` (Y=0 of grid center), which resets any Q/E vertical offset. If playtesting reveals this feels disorienting, save the full pre-focus `position` in `focus_on` and restore to it.
- **Known limitation:** `restore()` always returns the pan position to grid center XZ, not to where the player was panning before the QTE. Acceptable until playtesting reveals it feels jarring.

---

## Recent Changes

| Date | What changed |
|------|-------------|
| 2026-04-26 | **Full orbit right-click + Q/E pivot-Y.** Right-click drag now controls both yaw (horizontal) and elevation pitch (vertical; drag up = more top-down, clamped 15°–80°). `DRAG_SENSITIVITY` halved to 0.2. Q/E repurposed: now raise/lower orbit pivot on world Y axis via `_process_pivot_y(delta)` (`PIVOT_Y_SPEED=5` u/s, clamped `PIVOT_Y_MIN=−3` to `PIVOT_Y_MAX=8`). Q/E + pan both suppressed during `_pivot_tween`. Removed `ELEVATION_SPEED`; added `PIVOT_Y_SPEED`, `PIVOT_Y_MIN`, `PIVOT_Y_MAX`. |
| 2026-04-26 | **WASD/arrow pan + W/S reversal + QTE zoom.** `_process_pan(delta)` added — polls WASD + arrow keys, computes yaw-relative forward/right, clamps to `PAN_MIN`/`PAN_MAX`. W/S initially reversed (W was SW at default yaw), corrected to NE. `focus_on` and `restore` upgraded to parallel tweens: pivot position + orbit distance animate simultaneously; `focus_on` saves `_pre_qte_distance` and zooms to `QTE_DISTANCE=10.0`; `restore` zooms back out. `_set_distance()` tween helper added. 6 headless tests total. |
| 2026-04-26 | **Camera overhaul.** Q/E control `_elevation` (pitch, 10°/press, clamped 15°–80°). Right-click drag rotates yaw (`DRAG_SENSITIVITY = 0.4°/px`). Cursor captured while dragging. `DEFAULT_ELEVATION` promoted to `_elevation: float` var. `test_camera_controls.gd` added (3 assertions). |
| 2026-04-26 | **QTE camera focus / restore.** `focus_on(world_pos)`, `restore()`, `_set_pivot()`, `_home_position`, `_pivot_tween` added. Camera tweens to attacker before QTE (0.5 s), returns to grid center after (0.45 s, fire-and-forget). |
