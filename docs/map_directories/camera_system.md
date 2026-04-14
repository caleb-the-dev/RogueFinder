# System: Camera System

> Last updated: 2026-04-14 (Session 2 — Stage 1.5)

---

## Purpose

The Camera System provides a **DOS2-style isometric orbit camera** for the 3D combat scene. It handles:
- Fixed-elevation orbit around a target point
- Q/E key rotation in 45° snapped steps
- Mouse scroll wheel zoom
- Procedural camera shake on combat events (hit feedback)

The camera is built and owned by `CombatManager3D`. No `.tscn` — it's instantiated entirely in code.

---

## Core Nodes / Scripts

| File | Scene | Role |
|------|-------|------|
| `scripts/camera/CameraController.gd` | *(none — built in code)* | Orbit camera + shake |

---

## Dependencies

None. CameraController is a self-contained `Node3D` that builds its own `Camera3D` child. It has no knowledge of other game systems.

CombatManager3D calls `trigger_shake()` on it; Unit3D optionally calls `get_sprite_dir()` passing the camera's forward vector.

---

## Signals Emitted

None.

---

## Public Methods

| Method | Signature | Purpose |
|--------|-----------|---------|
| `trigger_shake` | `() -> void` | Starts a 0.22s procedural shake (called by CombatManager on hit) |
| `get_forward` | `() -> Vector3` | Returns the camera's forward direction (for 8-dir sprite selection) |
| `get_camera` | `() -> Camera3D` | Returns the child Camera3D node (used by Grid3D for raycasting) |

---

## Camera Parameters

| Constant | Value | Meaning |
|----------|-------|---------|
| `DEFAULT_DISTANCE` | 16.0 | Default orbit radius |
| `MIN_DISTANCE` | 8.0 | Minimum zoom distance |
| `MAX_DISTANCE` | 28.0 | Maximum zoom distance |
| `DEFAULT_ELEVATION` | 52.0° | Fixed camera pitch (isometric-style) |
| `DEFAULT_YAW` | 225.0° | Starting yaw angle |
| `ROTATE_STEP` | 45.0° | Q/E rotation increment |
| `ZOOM_STEP` | 2.0 | Scroll wheel zoom increment |
| `SHAKE_DURATION` | 0.22 s | Duration of shake effect |
| `SHAKE_MAGNITUDE` | 0.18 | Max displacement per shake tick |

---

## Input Handling

| Input | Action |
|-------|--------|
| `Q` | Rotate orbit left by 45° |
| `E` | Rotate orbit right by 45° |
| `ScrollUp` | Zoom in (decrease distance) |
| `ScrollDown` | Zoom out (increase distance) |

Panning is not yet implemented — the camera always looks at the grid origin (0, 0, 0).

---

## Shake Implementation

`trigger_shake()` sets `_shake_timer = SHAKE_DURATION`. Each `_process()` tick while `_shake_timer > 0`:
1. Generates a random offset within `SHAKE_MAGNITUDE` on X and Y.
2. Applies the offset to the Camera3D's local position.
3. Decrements `_shake_timer` by `delta`.
4. Clears the offset when the timer expires.

Shake is additive on top of the normal orbit transform, computed in `_apply_transform()`.

---

## Transform Pipeline (`_apply_transform`)

```
1. Build rotation from yaw (Y-axis) and elevation (X-axis).
2. Compute camera offset: rotation * Vector3(0, 0, distance).
3. Set controller position to target + offset.
4. Point controller at target using look_at().
5. Add shake offset to Camera3D local position.
```

---

## Notes

- The Camera3D child is created in `_ready()` — calling `get_camera()` before `_ready()` returns null.
- `DEFAULT_ELEVATION` of 52° matches a near-isometric look without a true 45° projection, which gives a more readable 3D battlefield.
- Rotation steps snap to 45° multiples — there is no smooth rotation tween in Stage 1.5; may be added later.
