# System: Unit System

> Last updated: 2026-04-19 (S18 — setup() seeds from data.current_hp/current_energy instead of max)

---

## Purpose

A Unit is a **stateful game object** representing one combatant. It owns:
- HP and energy values (current and max)
- Turn state: `remaining_move` (tiles left this turn), `has_acted` (ability used)
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
| `setup` | `(unit_data: CombatantData, pos: Vector2i) -> void` | Initializes stats and position. Seeds `current_hp` from `data.current_hp` and `current_energy` from `data.current_energy` — **not** from max — so a unit enters combat at its last saved HP/energy. |

### State Queries

| Method | Signature | Purpose |
|--------|-----------|---------|
| `can_stride` | `() -> bool` | `remaining_move > 0 and is_alive` — can be called multiple times per turn until budget is exhausted |
| `can_act` | `(energy_cost: int = 3) -> bool` | `not has_acted and current_energy >= energy_cost and is_alive` |

### State Mutations

| Method | Signature | Purpose |
|--------|-----------|---------|
| `take_damage` | `(amount: int) -> void` | Subtracts HP; emits `unit_died` if HP ≤ 0; triggers hit flash |
| `heal` | `(amount: int) -> void` | Adds HP capped at `data.hp_max` |
| `spend_energy` | `(amount: int) -> bool` | Deducts energy; returns `false` if insufficient |
| `regen_energy` | `() -> void` | Adds `energy_regen` to `current_energy`, capped at `energy_max` |
| `reset_turn` | `() -> void` | Restores `remaining_move` to `data.speed`, clears `has_acted`; refreshes visuals |
| `move_to` | `(new_pos: Vector2i) -> void` | Updates `grid_pos`, emits `unit_moved`. Does NOT touch `remaining_move` — CombatManager deducts the path length directly after traversal |
| `add_stat_effect` | `(display_name: String, stat: int, delta: int) -> void` | Appends to `stat_effects`; refreshes buff/debuff indicators |

### Visual

| Method | Signature | Purpose |
|--------|-----------|---------|
| `set_selected` | `(selected: bool) -> void` | Shows/hides the yellow selection ring |
| `play_attack_anim` | `(target_world: Vector3) -> void` | Lunge coroutine — call with `await` if you need to wait for impact |
| `show_floating_text` | `(text: String, color: Color) -> void` | Spawns a rising, fading Label3D above the unit; fire-and-forget |
| `show_action_text` | `(ability_name: String) -> void` | Spawns a slow-rising cyan Label3D for enemy ability/consumable names; fire-and-forget |
| `get_sprite_dir` | `(camera_forward: Vector3) -> int` | Returns 0–7 for 8-directional sprite selection (future use) |

---

## Internal State

| Field | Type | Default | Meaning |
|-------|------|---------|---------|
| `current_hp` | `int` | `data.current_hp` | Current hit points — seeded from the CombatantData persistent field, not from max |
| `current_energy` | `int` | `data.current_energy` | Current action energy — seeded from persistent field |
| `grid_pos` | `Vector2i` | from `setup()` | Current cell on the grid |
| `remaining_move` | `int` | `data.speed` | Tiles of movement budget remaining this turn; depleted by CombatManager after each stride |
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

### Action Text (enemy-only)
`show_action_text(ability_name)` — fire-and-forget coroutine. Light cyan billboard Label3D at Y+1.9, rises 0.4 units and fades over 2.5s. Called by CombatManager3D after consumable use and before each enemy ability lunge.

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
- `move_to()` does NOT deduct `remaining_move`; CombatManager does that after the full path traversal completes.
- `take_damage()` calls `_play_hit_flash()` as fire-and-forget — damage and `unit_died` signal are not delayed by the animation.
- `stat_effects` is read by `UnitInfoBar._refresh_status()` and `StatPanel._format()` for display; Unit3D only writes to it.
- FORCE displacement calls `move_to()` but does not consume `remaining_move` — forced movement is involuntary and does not reduce the stride budget.
- **`setup()` reads `current_hp`/`current_energy` from the shared `CombatantData` instance** — the same object that lives in `GameState.party`. `CombatManager3D._end_combat()` writes back to it on victory, so the HP a unit enters combat with is what it had when it last left combat.

---

## Recent Changes

| Date | Change |
|---|---|
| 2026-04-19 | `setup()` changed to seed `current_hp` from `data.current_hp` and `current_energy` from `data.current_energy` (was `hp_max` / `energy_max`). Units now enter combat at their last saved HP, not always full. |
