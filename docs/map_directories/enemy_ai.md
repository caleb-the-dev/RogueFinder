# System: Enemy AI

> Last updated: 2026-05-02 (Slice 6 — AutobattlerEnemyAI static module added; priority-list picker for CombatManagerAuto)

---

## Purpose

Role-driven AI system for combatants. Two separate modules serve the two combat systems:

- **`EnemyAI.gd`** — used by `CombatManager3D` (legacy 3D tactical grid). Full within-bucket scoring, geometry helpers, move priority. Retires in Slice 7.
- **`AutobattlerEnemyAI.gd`** — used by `CombatManagerAuto` (autobattler). Simple priority-list pick per role; no scoring, no geometry. Active as of Slice 6.

---

## Build Status

### AutobattlerEnemyAI (CombatManagerAuto — active)

| Slice | Description | Status |
|-------|-------------|--------|
| Slice 6 | AutobattlerEnemyAI — priority-list pick; role prefs from archetype; cooldown + target filters | ✅ Done |

### EnemyAI (CombatManager3D — legacy, retires Slice 7)

| Slice | Description | Status |
|-------|-------------|--------|
| Slice 1 | Role data layer — `ArchetypeData.Role` enum + `archetypes.csv` column + `ArchetypeLibrary._parse_role()` | ✅ Done |
| Slice 2 | EnemyAI module — role preference walk, critical-heal override, last-ability cycling, `last_ability_id` tracker | ✅ Done |
| Slice 3 | Within-bucket scoring — HARM AoE/finishing-blow/best-damage, MEND closest-fit, BUFF/DEBUFF redundancy/stack-cap, role-aware movement stride, buff/debuff tracker fields on Unit3D, move priority sort, FORCE **disabled** | ✅ Done (FORCE disabled) |
| Slice 4 | FORCE multi-step positioning planner — stride-to-align, hazard/edge push scoring re-enabled | ⏳ Deferred (retires with old combat in Slice 7) |

---

## Role Enum

Defined on `ArchetypeData` (`resources/ArchetypeData.gd`). Stored in `archetypes.csv` under the `role` column.

| Role | Int | Design intent |
|------|-----|---------------|
| `ATTACKER` | 0 | Prefers HARM above all else; falls back to displacement then debuff |
| `HEALER` | 1 | Prefers MEND first; buffs second; attacks only as last resort |
| `SUPPORTER` | 2 | Buffs allies first; heals second; attacks only as last resort |
| `DEBUFFER` | 3 | Leads with DEBUFF; HARM second; displacement third |
| `CONTROLLER` | 4 | Leads with FORCE displacement (disabled); debuff second; HARM third |

**Stub fallback:** `ATTACKER`. Any unrecognized `role` string in the CSV falls back to `ATTACKER`.

---

## Key Files

| File | Purpose |
|------|---------|
| `resources/ArchetypeData.gd` | Defines `Role` enum + `role: Role` field |
| `data/archetypes.csv` | `role` column — one of: attacker / healer / supporter / debuffer / controller |
| `scripts/globals/ArchetypeLibrary.gd` | `_parse_role(val)` — case-insensitive string → enum |
| `scripts/combat/AutobattlerEnemyAI.gd` | **Active** — static module for CombatManagerAuto; `pick()` + role prefs table. No instance state. |
| `scripts/combat/EnemyAI.gd` | **Legacy** — static module for CombatManager3D; `choose_action()` + scoring helpers + geometry statics. Retires Slice 7. |
| `scripts/combat/CombatManager3D.gd` | Calls `EnemyAI.choose_action()` inside `_process_enemy_actions()`; sorts enemies by `MOVE_PRIORITY` before processing; sets `enemy.last_ability_id` after each pick; updates buff/debuff tracker fields in `_apply_non_harm_effects()` |
| `scripts/combat/Unit3D.gd` | Holds all transient AI fields for EnemyAI: `ai_override`, `last_ability_id`, `active_buff_ability_ids`, `active_debuff_ability_ids`, `debuff_stat_stacks` |
| `tests/test_autobattler_ai.gd/.tscn` | 4 headless tests — ATTACKER prefers HARM, HEALER prefers MEND, cooldown skip, HARM-fallback |
| `tests/test_archetype_role.gd/.tscn` | 6 headless tests — role CSV parse, stub fallback, reload() |
| `tests/test_enemy_ai.gd` | 10 headless SceneTree tests — affordable filter, consumable trigger, QTE tiers (Slice 1 era) |
| `tests/test_enemy_ai_2.gd/.tscn` | 9 headless tests — Slice 2 behaviors + CONTROLLER FORCE-disabled fallback |
| `tests/test_enemy_ai_scoring.gd/.tscn` | 13 headless tests — all Slice 3 scoring behaviors (see below) |

---

## AutobattlerEnemyAI Module (`scripts/combat/AutobattlerEnemyAI.gd`)

Static `RefCounted`. Called once per unit turn by `CombatManagerAuto._fire_unit_turn()`. Used by **both** ally and enemy units — player units run the same AI in the autobattler (consumable interject is the player's agency, not per-turn ability picking).

### Constants

| Constant | Type | Purpose |
|----------|------|---------|
| `ROLE_PREFS` | `Dictionary` | Maps `ArchetypeData.Role` enum value → ordered `Array[EffectData.EffectType]` |
| `DEFAULT_PREFS` | `Array` | HARM → DEBUFF → BUFF → MEND. Used for units with `archetype_id == ""` or `"generic"`. |

### Role Preference Table

| Role | Effect-type priority order |
|------|---------------------------|
| ATTACKER (0) | HARM → DEBUFF → BUFF → MEND |
| HEALER (1) | MEND → BUFF → HARM → DEBUFF |
| SUPPORTER (2) | BUFF → DEBUFF → MEND → HARM |
| DEBUFFER (3) | DEBUFF → HARM → BUFF → MEND |
| CONTROLLER (4) | DEBUFF → HARM → BUFF → MEND |

### Public API

```gdscript
## Returns {ability: AbilityData, targets: Array[CombatantData], slot: int}.
## ability is null if nothing fires (no off-cooldown ability with a valid target).
static func pick(unit: CombatantData, _allies: Array, _hostiles: Array, board: LaneBoard) -> Dictionary
```

### Decision Flow

1. Look up role prefs from `unit.archetype_id` → `ArchetypeLibrary.get_archetype()` → `arch.role`. Falls back to `DEFAULT_PREFS` for `archetype_id == "" / "generic"` or unknown archetypes.
2. Get available slots via `CountdownTracker.available_slot_indices(unit.cooldowns)`.
3. For each `effect_type` in prefs, for each available slot: check if the ability at that slot has that effect type (via first-effect check). If yes, call `CombatManagerAuto.resolve_targets(unit, ability, board)`. First non-empty result wins.
4. If no valid pick: return `{ability: null, targets: [], slot: -1}` → caller skips turn.

### Gotchas

- **Bucketing by first effect only** — `_has_effect_type()` checks ALL effects in the array, not just the first. An ability with HARM primary + DEBUFF secondary counts for both buckets. This means a mixed-effect ability can be picked when either of its types is preferred.
- **`_allies` and `_hostiles` params are unused** — target resolution goes through `board`. Parameters are kept for future extension (e.g., lowest-HP target selection).
- **Player units use the same AI** — there is no separate player branch. In the autobattler all 6 units run through `pick()`. Player agency comes from consumable interject (Slice 7).
- **Role read from archetype, not unit** — `CombatantData` has no `role` field. Role is looked up from `ArchetypeData` at pick time. Player character uses `archetype_id = "RogueFinder"` (role: ATTACKER) → DEFAULT_PREFS.

---

## EnemyAI Module (`scripts/combat/EnemyAI.gd`)

Static `RefCounted` — mirrors `RewardGenerator` pattern. No instance state.

### Constants

| Constant | Type | Purpose |
|----------|------|---------|
| `CRIT_HEAL_THRESHOLD` | `float = 0.15` | Any ally below this HP fraction triggers the critical-heal global override |
| `MEND_USEFUL_THRESHOLD` | `float = 0.70` | Any ally below this HP fraction is a valid MEND target |
| `ROLE_PREFERENCES` | `Dictionary` | Maps `Role` int → ordered `Array` of `EffectType` ints |
| `MOVE_PRIORITY` | `Dictionary` | Maps `Role` int → processing order (lower = acts first); used by CM3D to sort `_enemy_units` before `_process_enemy_actions()` iterates. HEALER=0, SUPPORTER=1, DEBUFFER=2, ATTACKER=3, CONTROLLER=4 |

### Public API

```gdscript
## Choose a target + ability for the given enemy this turn.
static func choose_action(
    enemy: Unit3D,
    allies: Array[Unit3D],    # living enemy-side units excluding this enemy
    hostiles: Array[Unit3D],  # living player-side units
    grid: Grid3D              # required for AoE origin + FORCE scoring (null only in old Slice 2 tests)
) -> Dictionary               # {"target": Unit3D, "ability": AbilityData}
                              # {"target": null, "ability": null} → caller skips action

## Returns the unit this enemy should stride toward (role-aware).
## HEALER/SUPPORTER: lowest-HP ally below 70% HP if one exists; else nearest hostile.
## All other roles: nearest hostile (Manhattan).
static func pick_stride_target(
    enemy: Unit3D,
    allies: Array[Unit3D],
    hostiles: Array[Unit3D]
) -> Unit3D

## Picks the AoE origin cell that maximizes living hostile hits (random tiebreak).
## Extracted from CombatManager3D._pick_best_aoe_origin; that method now delegates here.
static func pick_best_aoe_origin(
    caster_pos: Vector2i,
    ability: AbilityData,
    grid: Grid3D
) -> Vector2i

## For CONTROLLER role: picks the stride cell that maximizes FORCE push quality.
## DISABLED — kept for Slice 4 re-enable. CM3D does NOT call this in the current build.
## When re-enabled: evaluates current position + all move_cells, returns the cell from which
## FORCE scores best (hazard landing=3 > edge push=2 > isolation gain=1).
static func pick_force_stride_cell(
    enemy: Unit3D,
    hostiles: Array[Unit3D],
    move_cells: Array[Vector2i],
    grid: Grid3D
) -> Vector2i
```

### Decision Flow (in order)

1. **`ai_override` seam** — if `enemy.ai_override == "force_random"`, bypasses role walk. Dormant until future Confused condition sets it.
2. **Critical-heal global override** — if any affordable MEND ability can reach any ally (including self) below **15% HP**, pick that MEND on the lowest-HP qualifying ally. Fires before the role walk regardless of role.
3. **Role preference walk** — look up `ROLE_PREFERENCES[role]`, an ordered list of effect types. For each effect type, call `_try_effect_type()`. Return the first valid result.
4. **Final fallback** — return `{null, null}`. Caller (`CombatManager3D._process_enemy_actions`) skips the action.

### Role Preference Table (`ROLE_PREFERENCES` const)

| Role | Effect-type priority order |
|------|---------------------------|
| ATTACKER (0) | HARM → FORCE → DEBUFF → BUFF → MEND → TRAVEL |
| HEALER (1) | MEND → BUFF → DEBUFF → HARM → FORCE → TRAVEL |
| SUPPORTER (2) | BUFF → MEND → DEBUFF → HARM → FORCE → TRAVEL |
| DEBUFFER (3) | DEBUFF → HARM → FORCE → BUFF → MEND → TRAVEL |
| CONTROLLER (4) | FORCE → DEBUFF → HARM → BUFF → MEND → TRAVEL |

**FORCE is currently disabled** — case 2 in `_try_effect_type()` returns null immediately. CONTROLLER falls through to DEBUFF → HARM.

### Bucketing Rule

An ability's **primary effect type = `ability.effects[0].effect_type`** (first effect wins). An ability with HARM primary and DEBUFF secondary is bucketed as HARM.

### `_try_effect_type()` — Scorer Dispatch (Slice 3)

Collects all affordable abilities matching the effect type, then dispatches to the appropriate per-type scorer:

| Effect type | Scorer | Notes |
|-------------|--------|-------|
| HARM (0) | `_pick_best_harm()` | AoE-2+ → finishing-blow → best expected damage |
| MEND (1) | `_pick_best_mend()` | Lowest-HP target below 70%, closest-fit heal |
| FORCE (2) | `pass` (disabled) | Pending Slice 4 multi-step positioning planner |
| BUFF (4) | `_pick_best_buff()` | Highest-HP non-redundant ally |
| DEBUFF (5) | `_pick_best_debuff()` | Highest-HP non-capped hostile |
| TRAVEL (3) | (not handled) | Enemy TRAVEL undefined; role walk continues |

The old two-pass walk (`_is_situationally_useful()` / `_pick_target()`) is **gone** — replaced by these dedicated scorers.

### Per-Type Scorers (private)

#### `_pick_best_harm(enemy, hostiles, abilities, grid)`
Three-tier priority:
1. **AoE-2+**: any AoE ability hitting ≥2 hostiles at its optimal origin → prefer most-hits winner.
2. **Finishing-blow**: target lowest-HP reachable hostile; among abilities in range, pick highest expected damage.
3. **Best damage**: globally highest `_expected_damage(ability, enemy, hostile)` across all (hostile, ability) pairs.

#### `_pick_best_mend(enemy, allies, abilities)`
- Collect targets (self + allies) below 70% HP, sorted ascending by HP.
- For each target, pick the ability whose heal value (`sum of MEND base_values`) minimizes `abs(heal - hp_missing)`.
- Tiebreak: cheapest energy cost.

#### `_pick_best_buff(enemy, allies, abilities)`
- For each ability: if SELF shape, target is self (skip if already buffed by this ability's id).
- For ALLY/ANY-applicable: find highest-HP living ally not already in `target.active_buff_ability_ids`.
- First successful (ability, target) pair wins.

#### `_pick_best_debuff(enemy, hostiles, abilities)`
- For each ability: find highest-HP hostile where:
  - `not h.active_debuff_ability_ids.has(ab.ability_id)` (not redundant)
  - `h.debuff_stat_stacks.get(target_stat, 0) < 3` (stack cap not reached)

#### `_pick_best_force(enemy, hostiles, abilities, grid)`
- **Currently bypassed** — case 2 in `_try_effect_type()` returns null before calling this.
- When re-enabled: for each (hostile, ability) pair in range, compute `_compute_force_dest()`, score: hazard landing=3, edge push=2, isolation gain=1, 0=drop. Returns null if best_score = 0.
- Null-grid fallback (Slice 2 headless test compatibility): any reachable hostile, first qualifying ability.

### Geometry Helpers (extracted from CombatManager3D)

These statics are also callable directly and are used by CM3D via thin wrappers:

| Method | Purpose |
|--------|---------|
| `_get_shape_cells_static(caster_pos, origin_pos, ability, grid)` | Returns all cells in AoE footprint for the given shape/caster/origin. CM3D's `_get_shape_cells()` delegates here. |
| `_cardinal_direction_static(from, to)` | Cardinal direction (4-way) from one cell to another. CM3D's `_cardinal_direction()` delegates here. |
| `_aoe_hostile_count(caster_pos, origin, ability, grid)` | Counts living player units in the AoE at origin. Used by `pick_best_aoe_origin` and `_pick_best_harm`. |
| `_compute_force_dest(caster_pos, target_pos, effect, grid)` | Simulates where a FORCE push/pull lands (stops at invalid cell or occupied cell). |
| `_force_push_dir(caster_pos, target_pos, effect)` | Returns displacement direction for a FORCE effect by force_type (PUSH/PULL/LEFT/RIGHT/RADIAL). RADIAL treated as PUSH. |

### Damage Estimator

```gdscript
static func _expected_damage(ability, attacker, target) -> int:
    return maxi(0, base_dmg + effective_attr - armor)
```
Mirrors `CombatManager3D._run_harm_defenders()` formula but ignores QTE roll (unknown at decision time). Uses `target.data.physical_defense` or `magic_defense` based on `ability.damage_type`. Used by `_pick_best_harm()` tiers 2 and 3.

**If the live HARM formula changes in CM3D, update this method to match.**

### Range Check

`_is_in_range(ability, caster_pos, target_pos)` — Manhattan distance ≤ `tile_range`. SELF shape always passes. `tile_range == -1` always passes.

---

## Transient Fields on Unit3D

All fields below are transient (not serialized, not saved). Cleared at `_end_combat()`.

| Field | Type | Default | Purpose |
|-------|------|---------|---------|
| `ai_override` | `String` | `""` | `"force_random"` bypasses role walk (future Confused condition). Not cleared in `reset_turn()`. |
| `last_ability_id` | `String` | `""` | Last ability used; EnemyAI deprioritizes it within same-bucket in the **old** two-pass walk. Now less relevant since scorers don't use last-ability cycling, but still set by CM3D post-pick. Not cleared in `reset_turn()`. |
| `active_buff_ability_ids` | `Array[String]` | `[]` | Ability IDs of active BUFF effects. Appended by CM3D `_apply_non_harm_effects()` on BUFF resolution. Used by `_pick_best_buff()` redundancy check. |
| `active_debuff_ability_ids` | `Array[String]` | `[]` | Ability IDs of active DEBUFF effects. Appended on DEBUFF resolution. Used by `_pick_best_debuff()` redundancy check. |
| `debuff_stat_stacks` | `Dictionary` | `{}` | Maps `int(EffectData.Attribute)` → stack count. Incremented on each DEBUFF resolution. Used by `_pick_best_debuff()` to enforce 3-stack cap per stat. |

All five fields are cleared in `CombatManager3D._end_combat()` after snapshot restore, so they never bleed into the next combat.

---

## Move Priority

`EnemyAI.MOVE_PRIORITY` determines the order enemies act within a turn:

| Priority | Role |
|----------|------|
| 0 | HEALER |
| 1 | SUPPORTER |
| 2 | DEBUFFER |
| 3 | ATTACKER |
| 4 | CONTROLLER |

`CombatManager3D._process_enemy_actions()` sorts `_enemy_units` by this priority before iterating. Support roles stride and act before damage dealers, so they can reach allies and debuff targets before ATTACKER/CONTROLLER movement blocks paths.

---

## Dev Test Rooms

MapManager dev panel — "AI SLICE 3 — SCORING" section (two rows of 3):

| Button | `test_room_kind` | Behavior to watch |
|--------|-----------------|-------------------|
| 🤖 AoE Bomb | `"ai_aoe_bomb"` | Mage AoE scorer picks sweep/fireball hitting ≥2 clustered players instead of single-target |
| 🤖 Finish Blow | `"ai_finish_blow"` | Mages pick arcane_bolt targeting DYING (1 HP) player over healthy targets |
| 🤖 Smart Heal | `"ai_healer"` | Alchemist strides toward Wounded Grunt (low-HP ally, not player), heals it, switches to acid_splash |
| 🤖 Buff/Debuff | `"ai_buff_debuff"` | Buffer uses counter once then acid_splash; Webber webs players in sequence then venom_bite |
| 🤖 Edge Push | `"ai_force_edge"` | **FORCE DISABLED** — Shover strides but does not use shove/yank (FORCE gated off pending Slice 4) |
| 🤖 Slice 3 Mix | `"ai_slice3_mix"` | All Slice 3 behaviors simultaneously — AoE, MEND stride, DEBUFF rotation |

Earlier Slice 2 rooms also available (AI Roles, AI Crit-Heal) in the COMBAT section.

---

## Design Constraints

- **5 roles total** — no primary+secondary per archetype
- **No AI tier system** — one shared policy; context drives variance
- **All scoring helpers are pure static functions** — no side effects, no instance state in EnemyAI.gd
- **Damage estimator mirrors live formula** — `_expected_damage()` must stay in sync with `CombatManager3D._run_harm_defenders()`. If the HARM formula changes, update both.
- **FORCE disabled** — `_try_effect_type()` case 2 returns null. `pick_force_stride_cell()` exists but is not called by CM3D. Both must be re-enabled together in Slice 4.
- **Buff/debuff tracker fields are cleared at combat end** — `_end_combat()` clears them alongside snapshot restore. They do not persist across combats.

---

## Recent Changes

| Date | Change |
|------|--------|
| 2026-05-02 | **Slice 6 — AutobattlerEnemyAI added.** `AutobattlerEnemyAI.gd` created (`class_name AutobattlerEnemyAI extends RefCounted`). `ROLE_PREFS` dictionary maps `ArchetypeData.Role` enum values → ordered `Array[EffectData.EffectType]`. `pick(unit, _allies, _hostiles, board)` walks prefs → available slots → ability has effect type → `resolve_targets` non-empty → return `{ability, targets, slot}`. `_get_role_prefs()` looks up role via `ArchetypeLibrary.get_archetype(unit.archetype_id).role`; falls back to `DEFAULT_PREFS` for generic/empty IDs. `_has_effect_type()` checks all effects in the array (not just first). `CombatManagerAuto._fire_unit_turn()` stub deleted; replaced with `AutobattlerEnemyAI.pick()` call. 4 headless tests (`test_autobattler_ai.gd/.tscn`) — all pass. |
| 2026-05-01 | **Slice 3 complete (FORCE disabled).** `_try_effect_type()` rewritten: old two-pass situational-useful walk replaced by per-type scorer dispatch (`_pick_best_harm`, `_pick_best_mend`, `_pick_best_buff`, `_pick_best_debuff`). FORCE case returns null pending Slice 4. `_pick_best_harm()`: AoE-2+ → finishing-blow → best expected damage. `_pick_best_mend()`: lowest-HP target, closest-fit heal. `_pick_best_buff()`: highest-HP non-redundant ally. `_pick_best_debuff()`: highest-HP non-capped hostile with 3-stack cap. `_expected_damage()` helper mirrors CM3D HARM formula (no QTE). Geometry statics extracted from CM3D: `_get_shape_cells_static`, `_cardinal_direction_static`, `_aoe_hostile_count`, `_compute_force_dest`, `_force_push_dir`. `pick_force_stride_cell()` added (CONTROLLER stride planner) but disabled in CM3D. New public: `pick_stride_target()`, `pick_best_aoe_origin()`, `pick_force_stride_cell()`. `MOVE_PRIORITY` const added — support roles (HEALER/SUPPORTER/DEBUFFER) process before ATTACKER/CONTROLLER. CM3D buff/debuff tracking: `active_buff_ability_ids`, `active_debuff_ability_ids`, `debuff_stat_stacks` on Unit3D; populated by `_apply_non_harm_effects()`; cleared in `_end_combat()`. 6 new dev test rooms (AI SLICE 3 — SCORING section). 13 headless tests (`test_enemy_ai_scoring.gd/.tscn`). |
| 2026-05-01 | **Slice 2 complete.** `EnemyAI.gd` created — `choose_action()`, `ROLE_PREFERENCES` table, critical-heal override (15%), `_is_situationally_useful()` per type (now replaced in Slice 3), two-pass `_try_effect_type()` with last-ability cycling. `Unit3D` gains `ai_override` + `last_ability_id`. CM3D `_process_enemy_actions()` replaces randi() picks with EnemyAI; adds `_player_units_alive()` + `_enemy_units_alive_excluding()` helpers. AI Roles + AI Crit-Heal dev test rooms. 9 headless tests. |
| 2026-04-30 | **Slice 1 complete.** `ArchetypeData.Role` enum (5 values), `role` column in `archetypes.csv`, `ArchetypeLibrary._parse_role()`. 6 headless tests. |
