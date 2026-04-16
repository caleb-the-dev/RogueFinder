# System: Unit System

> Last updated: 2026-04-16 (Session 8 — floating combat text: show_floating_text() on take_damage, heal, and stat delta)

---

## Purpose

A Unit is a **stateful game object** representing one combatant. It owns:
- HP and energy values (current and max)
- Turn flags (`has_moved`, `has_acted`)
- Grid position
- Its own visual representation (mesh, selection ring, labels, buff/debuff indicators)
- Attack lunge and hit flash animations
- Active stat effect records (for UI display)

Units do **not** know about the grid or other units. They receive instructions from CombatManager and report back via signals.

Two versions: `Unit3D.gd` (active) and `Unit.gd` (legacy 2D).

---

## Core Nodes / Scripts

| File | Scene | Role |
|------|-------|------|
| `scripts/combat/Unit3D.gd` | `scenes/combat/Unit3D.tscn` | **Active** — 3D box mesh unit |
| `scripts/combat/Unit.gd` | `scenes/combat/Unit.tscn` | Legacy 2D — `ColorRect` + label |

`.tscn` files are minimal. All child nodes are built in `_ready()` / `_build_visuals()`.

---

## Dependencies

| System | How it's used |
|--------|--------------|
| **CombatantData** | Read in `setup()` to initialize all stats and identity |
| **CameraController** | `get_sprite_dir()` takes camera forward vector (future 8-dir sprites) |

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
| `setup` | `(unit_data: CombatantData, pos: Vector2i) -> void` | Initializes all stats and position |

### State Queries

| Method | Signature | Purpose |
|--------|-----------|---------|
| `can_stride` | `() -> bool` | `not has_moved and is_alive` |
| `can_act` | `(energy_cost: int = 3) -> bool` | `not has_acted and current_energy >= energy_cost and is_alive` |

### State Mutations

| Method | Signature | Purpose |
|--------|-----------|---------|
| `take_damage` | `(amount: int) -> void` | Subtracts HP; emits `unit_died` if HP ≤ 0; triggers hit flash |
| `heal` | `(amount: int) -> void` | Adds HP capped at `data.hp_max` |
| `spend_energy` | `(amount: int) -> bool` | Deducts energy; returns `false` if insufficient |
| `regen_energy` | `() -> void` | Adds `energy_regen` to `current_energy`, capped at `energy_max` |
| `reset_turn` | `() -> void` | Clears `has_moved` and `has_acted`; refreshes visuals |
| `move_to` | `(new_pos: Vector2i) -> void` | Updates `grid_pos`, sets `has_moved = true`, emits `unit_moved` |
| `add_stat_effect` | `(display_name: String, stat: int, delta: int) -> void` | Appends to `stat_effects`; refreshes buff/debuff indicators |

### Visual

| Method | Signature | Purpose |
|--------|-----------|---------|
| `set_selected` | `(selected: bool) -> void` | Shows/hides the yellow selection ring |
| `play_attack_anim` | `(target_world: Vector3) -> void` | Lunge coroutine — call with `await` if you need to wait for impact |
| `show_floating_text` | `(text: String, color: Color) -> void` | Spawns a rising, fading Label3D above the unit; fire-and-forget |
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
| `stat_effects` | `Array[Dictionary]` | `[]` | Active buff/debuff records: `{display_name, stat, delta}` |

---

## Visual Details (3D)

| Node | Type | Purpose |
|------|------|---------|
| Box mesh | `MeshInstance3D` | Main body — blue (player), red (enemy), grey (dead), muted (acted) |
| Selection ring | `MeshInstance3D` (CylinderMesh) | Yellow ring shown when `set_selected(true)` |
| Name label | `Label3D` | Billboard above box — character_name or archetype label |
| HP bar | `Label3D` | Billboard between name and box — 8-segment block bar (█░) colored green/yellow/red |
| Buff indicator | `Label3D` | Billboard — green ▲ shown when `stat_effects` contains any positive delta |
| Debuff indicator | `Label3D` | Billboard — red ▼ shown when `stat_effects` contains any negative delta |

**Box dimensions:** `0.7 × 1.6 × 0.7` world units. Base at Y=0 (half-height offset).

### HP Bar Color
- > 66% HP: green `#3EFF59`
- 33–66% HP: yellow `#FFD926`
- < 33% HP: red `#FF3F38`

### Floating Combat Text
`show_floating_text(text, color)` — fire-and-forget coroutine. Spawns a billboard `Label3D` with a small random X jitter, tweens it up 1.5 world units and fades alpha to 0 over 1.5s, then frees itself. Called automatically by:
- `take_damage()` → `-{amount}` in red
- `heal()` → `+{amount}` in green
- `CombatManager3D._apply_stat_delta()` → `+STR`/`-DEX` etc. in green (buff) or orange (debuff)

### Hit Flash
`_play_hit_flash()` — fire-and-forget coroutine inside `take_damage()`:
1. Swaps material to solid white
2. Awaits 0.12s
3. Restores original body material

### Attack Lunge
`play_attack_anim(target_world)`:
1. Tweens 0.7 units toward target over 0.10s
2. Returns caller via `await get_tree().create_timer(0.10).timeout`
3. Tweens back over 0.20s (fire-and-forget)

---

## Stat Effect Tracking

`stat_effects: Array[Dictionary]` is populated by `add_stat_effect()`, called from `CombatManager3D._apply_stat_delta()` after each BUFF/DEBUFF resolves.

Each entry: `{ "display_name": String, "stat": int, "delta": int }`

The buff ▲ and debuff ▼ billboard indicators are refreshed after every `add_stat_effect()` call. Effects are never removed mid-combat (future task: duration/expiry system).

---

## Notes

- `move_to()` does not validate against Grid — CombatManager must verify the cell is free before calling.
- `take_damage()` calls `_play_hit_flash()` as fire-and-forget — damage and `unit_died` signal are not delayed by the animation.
- `stat_effects` is read by `UnitInfoBar._refresh_status()` and `StatPanel._format()` for display; Unit3D only writes to it.
- `has_moved` is set to `true` by `move_to()` — both voluntary movement and FORCE displacement use this method, so forced movement consumes the unit's stride.
