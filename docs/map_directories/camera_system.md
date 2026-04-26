# System: Camera System

> Last updated: 2026-04-26 (WASD/arrow-key camera pan with yaw-relative direction and XZ clamping)

---

## Purpose

The Camera System provides a **DOS2-style isometric orbit camera** for the 3D combat scene. It handles:
- Variable-elevation orbit around a pivot point (normally grid center)
- Q/E keys adjust camera elevation (pitch), clamped 15°–80°
- Right-click drag rotates the camera horizontally (yaw)
- Mouse scroll wheel zoom
- Procedural camera shake on combat events (hit feedback)
- **Smooth QTE focus** — pivots to the attacker's world position before a QTE starts, then restores

The camera is built and owned by `CombatManager3D`. No `.tscn` — it's instantiated entirely in code.
- WASD / arrow keys pan the orbit pivot in yaw-relative XZ space (BG3-style), clamped to a generous world boundary

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
| `focus_on` | `(world_pos: Vector3) -> Tween` | Smoothly tweens the orbit pivot to `world_pos` over 0.5s. Returns the Tween so callers can `await tween.finished`. Kills any in-progress pivot tween first. |
| `restore` | `() -> void` | Fire-and-forget tween back to `_home_position` (grid center) over 0.45s. Kills any in-progress pivot tween first. |

---

## Camera Parameters

| Constant | Value | Meaning |
|----------|-------|---------|
| `DEFAULT_DISTANCE` | 16.0 | Default orbit radius |
| `MIN_DISTANCE` | 8.0 | Minimum zoom distance |
| `MAX_DISTANCE` | 28.0 | Maximum zoom distance |
| `DEFAULT_ELEVATION` | 52.0° | Starting camera pitch |
| `MIN_ELEVATION` | 15.0° | Lowest allowed pitch (near-horizon) |
| `MAX_ELEVATION` | 80.0° | Highest allowed pitch (near-top-down) |
| `DEFAULT_YAW` | 225.0° | Starting yaw angle |
| `ELEVATION_STEP` | 10.0° | Q/E elevation increment per press |
| `ZOOM_STEP` | 2.0 | Scroll wheel zoom increment |
| `DRAG_SENSITIVITY` | 0.4 | Yaw degrees per pixel of horizontal drag |
| `SHAKE_DURATION` | 0.22 s | Duration of shake effect |
| `SHAKE_MAGNITUDE` | 0.18 | Max displacement per shake tick |
| `PAN_SPEED` | 10.0 | Pivot units/second for WASD / arrow-key pan |
| `PAN_MIN` | −5.0 | Minimum X and Z clamp for the orbit pivot |
| `PAN_MAX` | 25.0 | Maximum X and Z clamp for the orbit pivot |

---

## Key Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `_yaw` | `float` | `225.0` | Current horizontal orbit angle (degrees) |
| `_elevation` | `float` | `52.0` | Current camera pitch in degrees; clamped to MIN/MAX_ELEVATION |
| `_distance` | `float` | `16.0` | Current orbit radius |
| `_dragging` | `bool` | `false` | True while right mouse button is held; gates horizontal drag input |
| `_shake_timer` | `float` | `0.0` | Countdown for shake; set by `trigger_shake()` |
| `_shake_offset` | `Vector3` | `ZERO` | Additive shake displacement applied to Camera3D |
| `_camera` | `Camera3D` | `null` | Child Camera3D; created in `_ready()` |
| `_home_position` | `Vector3` | `ZERO` | Grid center pivot; captured from `position` in `_ready()` |
| `_pivot_tween` | `Tween` | `null` | Tracks the active focus/restore tween; killed before starting a new one |

---

## Input Handling

| Input | Handler | Action |
|-------|---------|--------|
| `Q` | `_unhandled_input` | Increase elevation by 10° (more top-down), clamped to 80° |
| `E` | `_unhandled_input` | Decrease elevation by 10° (more horizon-facing), clamped to 15° |
| `Right-click drag` | `_unhandled_input` | Rotate orbit horizontally; yaw tracks `event.relative.x * DRAG_SENSITIVITY` |
| `ScrollUp` | `_unhandled_input` | Zoom in (decrease distance) |
| `ScrollDown` | `_unhandled_input` | Zoom out (increase distance) |
| `W / Up` | `_process` | Pan pivot forward (yaw-relative, toward camera's SW at default yaw) |
| `S / Down` | `_process` | Pan pivot backward |
| `A / Left` | `_process` | Pan pivot left (strafe) |
| `D / Right` | `_process` | Pan pivot right (strafe) |

One-shot events (Q/E, scroll, right-click) use `_unhandled_input`. Continuous held-key panning uses `Input.is_key_pressed()` polling in `_process`.

Elevation, drag rotation, and zoom still respond during a QTE. Pan is **suppressed while `_pivot_tween` is running** (focus / restore tweens) to avoid fighting the tween.

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

`focus_on(world_pos)` and `restore()` both tween `position` (the orbit pivot) using `_set_pivot()` as the tween method. `_set_pivot()` sets `position` **and** calls `_apply_transform()` each step, so the Camera3D repositions and re-points itself every frame of the tween.

Both methods kill `_pivot_tween` before starting a new one — tweens never stack.

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
- `DEFAULT_ELEVATION` of 52° gives a near-isometric look — readable 3D battlefield without true 45° projection. Player can pitch up to 80° (top-down) or down to 15° (low horizon) via Q/E.
- Right-click drag is used for yaw rotation because left-click is claimed by CombatManager3D for unit selection. Middle-click was considered but right-click is more ergonomic for orbit cameras.
- `focus_on` / `restore` call `_set_pivot()` → `_apply_transform()` each frame, so they correctly maintain whatever `_elevation` and `_yaw` the player has set during the tween.
- During a QTE focus tween, the player can still Q/E, drag, and scroll — those call `_apply_transform()` directly and are additive on top of the moving pivot. WASD pan is suppressed while `_pivot_tween` is running.
- **Known limitation:** `restore()` always tweens back to `_home_position` (grid center), not to where the player was panning. After a QTE fires mid-pan, the camera returns to grid center. This is acceptable until playtesting reveals it feels jarring — if so, save pre-focus pivot position in `focus_on` and restore to it instead.

---

## Recent Changes

| Date | What changed |
|------|-------------|
| 2026-04-26 | **WASD/arrow pan.** `_process_pan(delta)` added — polls WASD + arrow keys each frame, computes yaw-relative forward/right vectors, slides pivot on XZ, clamps to `PAN_MIN`/`PAN_MAX`. Pan suppressed while `_pivot_tween` is running. Added `PAN_SPEED`, `PAN_MIN`, `PAN_MAX` constants. 3 new headless tests (direction math + constant sanity). |
| 2026-04-26 | **Camera overhaul.** Q/E now control `_elevation` (pitch, 10°/press, clamped 15°–80°) instead of snapped yaw. Right-click drag rotates yaw continuously (`DRAG_SENSITIVITY = 0.4°/px`). Cursor captured (`MOUSE_MODE_CAPTURED`) on right-click down, restored to `MOUSE_MODE_VISIBLE` on release. `DEFAULT_ELEVATION` constant promoted to `_elevation: float` variable. Removed `ROTATE_STEP`; added `MIN_ELEVATION`, `MAX_ELEVATION`, `ELEVATION_STEP`, `DRAG_SENSITIVITY`, `_dragging`. `_apply_transform()` now reads `_elevation` instead of the constant. `test_camera_controls.gd` added (3 headless assertions). |
| 2026-04-26 | **QTE camera focus / restore added.** `focus_on(world_pos)`, `restore()`, `_set_pivot()`, `_home_position`, `_pivot_tween` added. Camera smoothly tweens to attacker before each QTE (0.5 s), returns to grid center after (0.45 s, fire-and-forget). |
