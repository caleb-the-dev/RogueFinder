# System: Enemy AI

> Last updated: 2026-05-01 (Slice 2 — EnemyAI.gd module: role-driven picker, critical-heal override, last-ability cycling; dev test rooms)

---

## Purpose

Role-driven AI system for enemy combatants. Replaces the old `randi()` target and ability picks with contextual decisions guided by each archetype's `Role`. Movement and AoE origin selection were already smart before this system; this layer adds role-aware target and ability picking.

---

## Build Status

| Slice | Description | Status |
|-------|-------------|--------|
| Slice 1 | Role data layer — `ArchetypeData.Role` enum + `archetypes.csv` column + `ArchetypeLibrary._parse_role()` | ✅ Done |
| Slice 2 | EnemyAI module — role preference walk, critical-heal override, two-pass last-ability cycling, `last_ability_id` tracker | ✅ Done |
| Slice 3 | Within-bucket scoring — HARM finishing-blow/AoE preference, MEND closest-fit, BUFF/DEBUFF redundancy, FORCE hazard/edge awareness, role-aware movement stride | ⏳ Planned |

---

## Role Enum

Defined on `ArchetypeData` (`resources/ArchetypeData.gd`). Stored in `archetypes.csv` under the `role` column.

| Role | Int | Design intent |
|------|-----|---------------|
| `ATTACKER` | 0 | Prefers HARM above all else; falls back to displacement then debuff |
| `HEALER` | 1 | Prefers MEND first; buffs second; attacks only as last resort |
| `SUPPORTER` | 2 | Buffs allies first; heals second; attacks only as last resort |
| `DEBUFFER` | 3 | Leads with DEBUFF; HARM second; displacement third |
| `CONTROLLER` | 4 | Leads with FORCE displacement; debuff second; HARM third |

**Stub fallback:** `ATTACKER`. Any unrecognized `role` string in the CSV falls back to `ATTACKER`.

---

## Key Files

| File | Purpose |
|------|---------|
| `resources/ArchetypeData.gd` | Defines `Role` enum + `role: Role` field |
| `data/archetypes.csv` | `role` column — one of: attacker / healer / supporter / debuffer / controller |
| `scripts/globals/ArchetypeLibrary.gd` | `_parse_role(val)` — case-insensitive string → enum |
| `scripts/combat/EnemyAI.gd` | **New in Slice 2.** Static module — `choose_action()` + all private helpers. No instance state. |
| `scripts/combat/CombatManager3D.gd` | Calls `EnemyAI.choose_action()` inside `_process_enemy_actions()`; sets `enemy.last_ability_id` after each pick |
| `scripts/combat/Unit3D.gd` | Holds transient AI fields: `ai_override`, `last_ability_id` |
| `tests/test_archetype_role.gd/.tscn` | 6 headless tests — role CSV parse, stub fallback, reload() |
| `tests/test_enemy_ai.gd` | 10 headless SceneTree tests — affordable filter, consumable trigger, QTE tiers (Slice 1 era) |
| `tests/test_enemy_ai_2.gd/.tscn` | 9 headless tests — Slice 2: all role preferences, critical-heal threshold, ai_override seam, null fallback |

---

## EnemyAI Module (`scripts/combat/EnemyAI.gd`)

Static `RefCounted` — mirrors `RewardGenerator` pattern. No instance state.

### Public API

```gdscript
static func choose_action(
    enemy: Unit3D,
    allies: Array[Unit3D],    # living enemy-side units excluding this enemy
    hostiles: Array[Unit3D],  # living player-side units
    _grid: Grid3D             # reserved for Slice 3 path-awareness; currently unused
) -> Dictionary               # {"target": Unit3D, "ability": AbilityData}
                              # {"target": null, "ability": null} → caller skips action
```

### Decision Flow (in order)

1. **`ai_override` seam** — if `enemy.ai_override == "force_random"`, bypasses role walk. Dormant until future Confused condition sets it.
2. **Critical-heal global override** — if any affordable MEND ability can reach any ally (including self) below **15% HP**, pick that MEND on the lowest-HP qualifying ally. Fires before the role walk regardless of role.
3. **Role preference walk** — look up `ROLE_PREFERENCES[role]`, an ordered list of effect types. For each effect type, try `_try_effect_type()`. Return the first valid result.
4. **Final fallback** — return `{null, null}`. Caller (`CombatManager3D._process_enemy_actions`) skips the action and advances the turn.

### Role Preference Table (`ROLE_PREFERENCES` const)

| Role | Effect-type priority order |
|------|---------------------------|
| ATTACKER (0) | HARM → FORCE → DEBUFF → BUFF → MEND → TRAVEL |
| HEALER (1) | MEND → BUFF → DEBUFF → HARM → FORCE → TRAVEL |
| SUPPORTER (2) | BUFF → MEND → DEBUFF → HARM → FORCE → TRAVEL |
| DEBUFFER (3) | DEBUFF → HARM → FORCE → BUFF → MEND → TRAVEL |
| CONTROLLER (4) | FORCE → DEBUFF → HARM → BUFF → MEND → TRAVEL |

### Bucketing Rule

An ability's **primary effect type = `ability.effects[0].effect_type`** (first effect wins). An ability with HARM primary and DEBUFF secondary is bucketed as HARM. Slice 3 must not change this without updating the comment in `_try_effect_type()`.

### `_try_effect_type()` — Two-Pass Walk

Within each bucket, candidates are split into two lists:
- **fresh** — abilities whose `ability_id != enemy.last_ability_id`
- **last-used** — abilities matching `last_ability_id`

Fresh options are tried first (in slot order). Last-used is the fallback. This prevents turn-to-turn spam when alternatives exist (e.g., a DEBUFFER with `web_shot` + `smoke_bomb` alternates between them rather than looping `web_shot`).

An ability is included only when:
- `enemy.current_energy >= ab.energy_cost`
- `_is_situationally_useful()` returns true
- `_pick_target()` returns a non-null target

### `_is_situationally_useful()` — Minimum-Viable Filters (Slice 2)

| Effect type | Filter (Slice 2) | Notes for Slice 3 |
|-------------|------------------|-------------------|
| HARM | ≥1 reachable hostile | Slice 3: prefer AoE hitting ≥2, then finishing blow |
| MEND | self or any ally below **70% HP** and in range | Slice 3: pick closest-fit heal |
| BUFF | self (SELF shape always useful); ≥1 ally in range otherwise | Slice 3: skip if redundant |
| DEBUFF | ≥1 reachable hostile | Slice 3: skip if redundant; cap at 3 stacks |
| FORCE | ≥1 reachable hostile | Slice 3: prefer hazard push, edge push, isolation |
| TRAVEL | always true (last resort) | Slice 3: skip if already in attack range |

### `_is_in_range()` — Range Check

Uses **Manhattan distance** for all non-SELF, finite-range abilities — mirrors the pre-existing distance gate in `_process_enemy_actions()`. SELF shape always passes. `tile_range == -1` (whole map) always passes.

### Critical-Heal Known Limitation (Slice 2)

The movement step fires **before** `EnemyAI.choose_action()`. A HEALER enemy strides toward a random player unit, which can walk it out of MEND range of a critically-injured ally before the heal check runs. The range check then fails and the role walk takes over. Fix: Slice 3 role-aware movement (healers stride toward low-HP allies, not toward enemies).

---

## Transient Fields on Unit3D

| Field | Type | Default | Purpose |
|-------|------|---------|---------|
| `ai_override` | `String` | `""` | Set to `"force_random"` by future Confused condition; bypasses role walk |
| `last_ability_id` | `String` | `""` | Ability used last turn; deprioritized within same-bucket candidates; **NOT reset in `reset_turn()`** — intentionally persists across turns |

Both fields are transient (not serialized, not saved).

---

## Dev Test Rooms

Two scenarios added to the dev panel (MapManager — COMBAT section, second row):

| Button | `test_room_kind` | Setup |
|--------|-----------------|-------|
| 🤖 Test Room — AI Roles | `"ai_roles"` | Grunt (ATTACKER) + Alchemist (HEALER) + Cave Spider (DEBUFFER) vs standard 3-player team. Demonstrates distinct role behaviors in one fight. |
| 🤖 Test Room — AI Crit-Heal | `"ai_crit_heal"` | Alchemist (has `heal_burst`) + Near-Dead Grunt (1 HP) + Healthy Grunt vs slow/tanky players. Alchemist should fire critical-heal on Near-Dead Grunt turn 1 **if it hasn't moved out of range**. |

**Known issue with AI Crit-Heal:** Alchemist strides toward a player before EnemyAI runs, potentially exiting `heal_burst` range (2 tiles). Fix is Slice 3 role-aware movement.

---

## Design Constraints

- **5 roles total** — no primary+secondary per archetype
- **No AI tier system** — one shared policy; context drives variance
- **All scoring helpers are pure static functions** — no side effects, no instance state in EnemyAI.gd
- **Damage estimation reads live formula** — Slice 3 `_expected_damage()` must mirror `CombatManager3D._run_harm_defenders()` exactly. If the formula changes, update both.
- Movement is smart (greedy Manhattan, `CombatManager3D._process_enemy_actions` stride section) but role-blind until Slice 3
- AoE origin selection (`_pick_best_aoe_origin`) is already smart and **not** part of EnemyAI — CM3D calls it in the execute path for AoE shapes

---

## Recent Changes

| Date | Change |
|------|--------|
| 2026-05-01 | **Slice 2 complete.** `EnemyAI.gd` created — `choose_action()`, `ROLE_PREFERENCES` table, critical-heal override (15%), `_is_situationally_useful()` per type, two-pass `_try_effect_type()` with last-ability cycling. `Unit3D` gains `ai_override` + `last_ability_id`. CM3D `_process_enemy_actions()` replaces randi() picks with EnemyAI; adds `_player_units_alive()` + `_enemy_units_alive_excluding()` helpers; sets `last_ability_id` post-pick. MapManager dev panel gains AI Roles + AI Crit-Heal test rooms. 9 new headless tests. |
| 2026-04-30 | **Slice 1 complete.** `ArchetypeData.Role` enum (5 values), `role` column in `archetypes.csv`, `ArchetypeLibrary._parse_role()`. 6 headless tests. |
