# System: Unit System

> Last updated: 2026-04-14 (Session 2 — Stage 1.5)

---

## Purpose

A Unit is a **stateful game object** representing one combatant. It owns:
- HP and energy values (current and max)
- Turn flags (`has_moved`, `has_acted`)
- Grid position
- Its own visual representation (mesh, selection ring, label)
- Attack lunge and hit flash animations

Units do **not** know about the grid or other units. They receive instructions from CombatManager and report back via signals.

Two versions: `Unit3D.gd` (active) and `Unit.gd` (legacy 2D).

---

## Core Nodes / Scripts

| File | Scene | Role |
|------|-------|------|
| `scripts/combat/Unit3D.gd` | `scenes/combat/Unit3D.tscn` | **Active** — 3D box mesh unit |
| `scripts/combat/Unit.gd` | `scenes/combat/Unit.tscn` | Legacy 2D — `ColorRect` + label |

`.tscn` files are minimal. All child nodes (mesh, ring, label) are built in `_ready()` / `_build_visuals()`.

---

## Dependencies

| System | How it's used |
|--------|--------------|
| **UnitData** | Read in `setup()` to initialize all stats |
| **CameraController** | `get_sprite_dir()` takes camera forward vector (optional, for future 8-dir sprites) |

Unit has **no dependency** on Grid, CombatManager, QTE, or HUD.

---

## Signals Emitted

| Signal | Arguments | When |
|--------|-----------|------|
| `unit_died` | `unit: Unit3D` | HP drops to 0 in `take_damage()` |
| `unit_moved` | `unit: Unit3D, new_pos: Vector2i` | After a successful `move_to()` |

CombatManager subscribes to both signals on every unit.

---

## Public Methods

### Lifecycle

| Method | Signature | Purpose |
|--------|-----------|---------|
| `setup` | `(unit_data: UnitData, pos: Vector2i) -> void` | Initializes all stats and positions unit in world space |

### State Queries

| Method | Signature | Purpose |
|--------|-----------|---------|
| `can_stride` | `() -> bool` | Returns `not has_moved and is_alive` |
| `can_act` | `(energy_cost: int = 3) -> bool` | Returns `not has_acted and current_energy >= energy_cost and is_alive` |

### State Mutations

| Method | Signature | Purpose |
|--------|-----------|---------|
| `take_damage` | `(amount: int) -> void` | Subtracts HP; emits `unit_died` if HP ≤ 0; triggers hit flash |
| `spend_energy` | `(amount: int) -> bool` | Deducts energy; returns `false` if insufficient |
| `regen_energy` | `() -> void` | Adds `energy_regen` to `current_energy`, capped at `energy_max` |
| `reset_turn` | `() -> void` | Clears `has_moved` and `has_acted`; calls `regen_energy()` |
| `move_to` | `(new_pos: Vector2i) -> void` | Updates `grid_pos`, moves Node3D to world position, emits `unit_moved` |

### Visual

| Method | Signature | Purpose |
|--------|-----------|---------|
| `set_selected` | `(selected: bool) -> void` | Shows/hides the CylinderMesh selection ring |
| `play_attack_anim` | `(target_world: Vector3) -> void` | `await` coroutine: lunge toward target and snap back |
| `get_sprite_dir` | `(camera_forward: Vector3) -> int` | Returns 0–7 for 8-directional sprite selection (future use) |

---

## Internal State

| Field | Type | Default | Meaning |
|-------|------|---------|---------|
| `current_hp` | `int` | `data.hp_max` | Current hit points |
| `current_energy` | `int` | `data.energy_max` | Current action energy |
| `grid_pos` | `Vector2i` | from `setup()` | Current cell on the grid |
| `has_moved` | `bool` | `false` | Stride used this turn |
| `has_acted` | `bool` | `false` | Active action used this turn |
| `is_alive` | `bool` | `true` | False after HP reaches 0 |
| `is_player_unit` | `bool` | from `UnitData` | Determines base color (blue vs red) |

---

## Visual Details (3D)

| Node | Type | Purpose |
|------|------|---------|
| Box mesh | `MeshInstance3D` | Main body — blue for player, red for enemy |
| Selection ring | `MeshInstance3D` (CylinderMesh) | Yellow ring shown when `set_selected(true)` |
| Label | `Label3D` | Billboard showing unit name, HP, energy |

**Box dimensions:** `0.7 × 1.6 × 0.7` world units; base sits at Y=0 (half-height offset applied).

### Hit Flash
`_play_hit_flash()` is a coroutine triggered inside `take_damage()`. It:
1. Sets box material to white (`#ffffff`)
2. Awaits `create_timer(0.15)`
3. Restores the original base color

### Attack Lunge
`play_attack_anim(target_world)` is a coroutine called by CombatManager before QTE resolves. It:
1. Calculates direction toward target
2. Tweens position 0.6 units toward target over 0.12s
3. Tweens back to origin over 0.10s

---

## Notes

- `move_to()` does not validate against Grid — that's CombatManager's job before calling it.
- `take_damage()` calls `_play_hit_flash()` as a fire-and-forget coroutine (no `await`), so damage application is not blocked by the animation.
- `unit_died` fires synchronously inside `take_damage()`, before the flash completes.
