# System: Camera System

> Last updated: 2026-04-26 (Camera overhaul — elevation Q/E, right-click drag rotation)

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

| Input | Action |
|-------|--------|
| `Q` | Increase elevation by 10° (more top-down), clamped to 80° |
| `E` | Decrease elevation by 10° (more horizon-facing), clamped to 15° |
| `Right-click drag` | Rotate orbit horizontally; yaw tracks `event.relative.x * DRAG_SENSITIVITY` |
| `ScrollUp` | Zoom in (decrease distance) |
| `ScrollDown` | Zoom out (increase distance) |

Elevation, drag rotation, and zoom still respond during a QTE — the focus tween moves the pivot but doesn't lock input.

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
- During a QTE focus tween, the player can still Q/E, drag, and scroll — those calls `_apply_transform()` directly and are additive on top of the moving pivot.
