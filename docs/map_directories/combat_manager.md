# System: Combat Manager

> Last updated: 2026-04-15 (Session 7 — AoE shapes, TRAVEL/FORCE implementation, stat effects, hover previews)

---

## What This System Owns

Owns the entire combat encounter. Responsible for the turn state machine, all player input routing, the ability targeting flow (including AoE shapes and hover previews), effect application, enemy AI, and win/lose conditions. Builds every other system node at scene start — it is the scene root.

Does **NOT** own: grid math (see `grid_system.md`), unit visuals/HP state (see `unit_system.md`), QTE execution (see `qte_system.md`), UI display (see `hud_system.md`).

---

## Core Files

| File | Scene | Role |
|------|-------|------|
| `scripts/combat/CombatManager3D.gd` | `scenes/combat/CombatScene3D.tscn` | **Active** — 3D state machine |
| `scripts/combat/CombatManager.gd` | `scenes/combat/CombatScene.tscn` | Legacy 2D — reference only |

`CombatScene3D.tscn` is the active entry point. `main.tscn` loads it.

---

## Where NOT to Look

- **Damage calculation is NOT in Unit3D** — `_apply_effects()` in CombatManager3D owns all effect math; Unit3D only exposes `take_damage()` and `heal()`.
- **Ability definitions are NOT here** — see `AbilityLibrary.gd` and `combatant_data.md`.
- **Grid highlighting is NOT here** — `Grid3D.set_highlight()` / `Grid3D.clear_highlights()` are called from here but the logic lives in `Grid3D`.
- **QTE timing/display is NOT here** — `QTEBar.gd` owns that; CM3D only calls `start_qte()` and listens for `qte_resolved`.

---

## Dependencies

| System | How it's used |
|--------|--------------|
| **Grid3D** | Cell queries (`is_valid`, `is_occupied`, `get_unit_at`), move range, highlights, world↔grid math |
| **Unit3D** | HP/energy reads, `take_damage()`, `heal()`, `move_to()`, `play_attack_anim()`, `reset_turn()`, `add_stat_effect()`, signal subscriptions |
| **QTEBar** | `start_qte()` call; listens for `qte_resolved(accuracy)` signal |
| **CameraController** | Built by CM3D; `trigger_shake()` called on successful hit |
| **UnitInfoBar** | `show_for(unit)` on single-click; `refresh(unit)` after damage; `hide_bar()` on deselect |
| **StatPanel** | `show_for(unit)` on double-click; `hide_panel()` on deselect / combat end |
| **ActionMenu** | `open_for(unit)` on player unit selection; listens for `ability_selected(id)` and `consumable_selected()` |
| **ArchetypeLibrary** | `create(archetype_id, name, is_player)` to build all units at scene start |
| **AbilityLibrary** | `get_ability(id)` to resolve `_pending_ability` before targeting |

---

## State Machine

### Top-level phase

```
PLAYER_TURN
  └─[all player units acted]─→ ENEMY_TURN
  └─[Space confirm]──────────→ ENEMY_TURN

ENEMY_TURN
  └─[all enemies processed]─→ PLAYER_TURN
                            └─→ WIN / LOSE

WIN / LOSE → status label update; no further input accepted
```

### PlayerMode sub-state (during PLAYER_TURN)

```
IDLE
  └─[left-click player unit]──────→ STRIDE_MODE

STRIDE_MODE
  └─[click move tile]─────────────→ IDLE (unit moved; re-select to act)
  └─[ActionMenu: ability]─────────→ ABILITY_TARGET_MODE
  └─[ActionMenu: consumable]──────→ IDLE (consumable used)
  └─[click elsewhere]─────────────→ IDLE

ABILITY_TARGET_MODE  (purple highlights; _selected_unit + _pending_ability set)
  └─[SELF shape]──────────────────→ QTE_RUNNING (skips target pick)
  └─[click valid SINGLE target]───→ QTE_RUNNING
  └─[click valid AoE cell]────────→ QTE_RUNNING  (_aoe_origin stored)
  └─[ESC / invalid click]─────────→ STRIDE_MODE (cancel)
  └─[mouse motion, CONE/ARC/RADIAL]→ _handle_shape_hover() updates preview

QTE_RUNNING  (blocks all input until qte_resolved fires)
  └─[qte_resolved(accuracy)]──────→ _on_qte_resolved:
        TRAVEL effect?  → TRAVEL_DESTINATION
        AoE?            → STRIDE_MODE / IDLE (after shape effects applied)
        Single?         → STRIDE_MODE / IDLE (after effects applied)

TRAVEL_DESTINATION  (blue tiles; player picks where to land)
  └─[click valid tile]────────────→ IDLE (unit repositioned)
  └─[ESC / invalid click]─────────→ IDLE (cancelled)
```

---

## Signals Listened To

| Signal | Source | Handler |
|--------|--------|---------|
| `qte_resolved(accuracy)` | QTEBar | `_on_qte_resolved(accuracy)` |
| `ability_selected(ability_id)` | ActionMenu | `_on_ability_selected(ability_id)` |
| `consumable_selected()` | ActionMenu | `_on_consumable_selected()` |

*(CM3D emits no external signals — it is the scene root.)*

---

## Public Methods

None — CombatManager3D is the scene root. All other systems signal up to it.

---

## Key Internal Methods

| Method | Purpose |
|--------|---------|
| `_ready()` | Builds entire scene: env → camera → grid → units → UI |
| `_unhandled_input(event)` | All player input. `_unhandled_input` so GUI nodes consume events first. StatPanel open: swallows all except ESC. Mouse motion in AoE target mode: calls `_handle_shape_hover()`. |
| `_handle_left_click()` | Raycast cell → delegates to `_try_select_unit`, `_try_move`, `_try_ability_target`, or `_try_travel_destination` based on mode |
| `_handle_double_click()` | Opens StatPanel for any clicked unit |
| `_on_ability_selected(id)` | Resolves ability via AbilityLibrary; enters ABILITY_TARGET_MODE; highlights based on TargetShape |
| `_try_ability_target(cell)` | SINGLE → `_initiate_action`; AoE shapes → store `_aoe_origin`, call `_initiate_aoe_action` |
| `_initiate_action(attacker, target)` | Stores `_attack_target`; starts QTE |
| `_initiate_aoe_action(attacker, origin_world)` | Sets `_attack_target = null`; starts QTE for AoE paths |
| `_on_qte_resolved(accuracy)` | Detects TRAVEL → enters TRAVEL_DESTINATION; detects AoE → `_get_shape_cells` + `_get_units_in_cells` + `_apply_effects`; single → `_apply_effects` |
| `_apply_effects(ability, caster, target, accuracy, blast_origin)` | Loops `ability.effects`; dispatches by EffectType. `blast_origin` passed from `_aoe_origin` for FORCE/RADIAL direction. |
| `_apply_stat_delta(unit, stat, delta)` | Modifies `unit.data.<stat>`, clamps [0,5], calls `unit.add_stat_effect()` to record named status |
| `_apply_force(caster, target, effect, blast_origin)` | Slides target along computed direction for `base_value` tiles; stops at wall/unit. Direction from `effect.force_type` (PUSH/PULL/LEFT/RIGHT/RADIAL). |
| `_get_shape_cells(caster_pos, origin_pos, ability)` | Returns all cells in the ability's AoE footprint, respecting `passthrough` for CONE and RADIAL |
| `_get_units_in_cells(cells, applicable_to)` | Filters cell list to living units matching ALLY/ENEMY/ANY |
| `_handle_shape_hover()` | On mouse motion in ABILITY_TARGET_MODE: updates highlights live for CONE, ARC, RADIAL. RADIAL shows blast footprint at hovered cell; CONE/ARC shows directional shape at direction root. |
| `_highlight_travel_destinations(unit, effect)` | FREE → Manhattan ≤ base_value unoccupied cells; LINE → straight cardinal unoccupied cells |
| `_try_travel_destination(cell)` | Moves unit to chosen cell, updates occupancy, tweens position |
| `_request_end_player_turn()` | Space key: confirm dialog if any unit can still act |
| `_check_auto_end_turn()` | After each action: auto-ends turn when no player can still act |
| `_run_enemy_turn()` | Iterates enemy units; simulates QTE via `qte_resolution`; 0.65s delay between enemies |
| `_check_win_lose()` | All-dead check on either side; transitions to WIN/LOSE |
| `_unit_can_still_act(unit)` | True if alive, has_acted=false, energy ≥ lowest affordable ability cost |

---

## Effect Formulas

```
# HARM / MEND
value = max(1, round(accuracy × (base_value + caster.attribute_value)))

# BUFF / DEBUFF
flat base_value applied; accuracy < 0.3 = miss

# FORCE
slides target along ForceType direction; stops at wall or occupied cell
base_value = max tiles to travel; accuracy < 0.3 = miss

# TRAVEL
player picks destination from highlighted tiles; QTE accuracy unused for distance
```

`attribute_value` → `caster.data.strength / dexterity / cognition / vitality / willpower`

---

## AoE Shape Details

| Shape | Highlight step | Footprint |
|-------|---------------|-----------|
| SELF | None (auto) | Caster only |
| SINGLE | Highlights valid units within range | 1 cell |
| ARC | 4 cardinal roots; hover shows 3-cell arc preview | 3 cells at distance 1: left, center, right |
| CONE | 4 cardinal roots; hover shows full shape preview | 9 cells: stem(1) + crossbar(3) + back row(5). Unit at stem blocks crossbar+back if passthrough=false |
| LINE | All cells along 4 cardinal axes up to tile_range | Ray until wall/unit (stops unless passthrough=true) |
| RADIAL | All cells within tile_range of caster | Diamond ≤ 2 Manhattan. Without passthrough, pure cardinal cells at distance 2 blocked by occupied distance-1 neighbors |

---

## Stat Effect Tracking (`STAT_STATUS_NAMES`)

Named status effects are recorded on each unit when `_apply_stat_delta()` fires:

| Attribute | Buff name | Debuff name |
|-----------|-----------|-------------|
| STRENGTH | Empowered | Weakened |
| DEXTERITY | Hasted | Slowed |
| COGNITION | Focused | Muddled |
| VITALITY | Fortified | Vulnerable |
| WILLPOWER | Resolute | Demoralized |

Stored in `unit.stat_effects: Array[Dictionary]` as `{display_name, stat, delta}`. Displayed in UnitInfoBar (colored chips) and StatPanel (full list). Buff/debuff billboard indicators appear above world units.

---

## Key Patterns & Gotchas

- **`_unhandled_input` not `_input`** — must stay `_unhandled_input` or GUI nodes stop capturing clicks. See memory `feedback_godot_input.md`.
- **`_pending_ability` and `_aoe_origin`** — stored between `_on_ability_selected()` and `_on_qte_resolved()`. Both cleared after resolution.
- **Energy deducted before effects resolve** — spent in `_on_qte_resolved()` before `_apply_effects()`. A QTE miss still costs energy.
- **TRAVEL breaks the single-pass flow** — detected in `_on_qte_resolved()` before `_apply_effects()`; enters `TRAVEL_DESTINATION` PlayerMode rather than awaiting inside `_apply_effects()`.
- **`_apply_force` uses `target.move_to()`** — this sets `has_moved = true` on displaced units. Intentional — forced movement counts as their stride.
- **`_calculate_damage()` is dead code** — safe to delete when convenient.
- **Stat changes not reset at combat end** — future task: snapshot base stats at `Unit3D.setup()` and restore post-combat.

---

## Recent Changes

| Date | Change |
|---|---|
| 2026-04-15 | Implemented all AoE TargetShapes (CONE/ARC/LINE/RADIAL) with per-shape `_get_shape_cells()` |
| 2026-04-15 | Added TRAVEL_DESTINATION PlayerMode; `_highlight_travel_destinations` (FREE + LINE); `_try_travel_destination` |
| 2026-04-15 | Implemented FORCE: `_apply_force()` with ForceType (PUSH/PULL/LEFT/RIGHT/RADIAL) |
| 2026-04-15 | Added passthrough for CONE (stem blocks crossbar) and RADIAL (cardinal-only blocking) |
| 2026-04-15 | Added `_handle_shape_hover()` — live blast preview for CONE, ARC, RADIAL on mouse motion |
| 2026-04-15 | Named stat effects: `_apply_stat_delta()` calls `unit.add_stat_effect()` with display name |
| 2026-04-15 | Removed testing_mode (T key + GameState flag) — double-click StatPanel supersedes it |
