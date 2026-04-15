# Session Handoff: Functional AoE Shapes + TRAVEL/FORCE Effects

> Drop this at the start of the next session to skip context-building.
> Read `docs/map_directories/combatant_data.md` if you need deeper reference on enums/fields.
> Read `docs/map_directories/map.md` for the full system index.

---

## What Was Just Built (Session 6–7)

The ability infrastructure is fully wired. As of `main` (commit `9862996`):

- `EffectData` resource — typed sub-resource for one effect within an ability (HARM/MEND/BUFF/DEBUFF/FORCE/TRAVEL)
- `AbilityData` — rewritten with `TargetShape`, `ApplicableTo`, `Attribute` enums; `effects: Array[EffectData]`
- `AbilityLibrary` — 12 abilities, all fully defined with typed effects
- `CombatManager3D._apply_effects()` — loops `ability.effects`, dispatches per EffectType; HARM/MEND/BUFF/DEBUFF all work; FORCE/TRAVEL are `pass` stubs
- Energy is spent on use; stat deltas are applied and clamped to `[0,5]`

---

## What Is NOT Yet Working

### 1. AoE target shapes (CONE, LINE, RADIAL)

`CombatManager3D._on_ability_selected()` has this comment (line ~345):

```gdscript
# AoE shapes (CONE, LINE, RADIAL) still use single-target pick as a placeholder
# until per-shape resolution is implemented.
```

Currently CONE/LINE/RADIAL abilities behave exactly like SINGLE — the player picks one unit and only that unit is hit. The only current AoE ability is `smoke_bomb` (RADIAL).

### 2. TRAVEL effect (disengage ability)

`_apply_effects()` has `EffectData.EffectType.TRAVEL: pass` — the effect does nothing. `disengage` has shape=SELF so the QTE fires, but no movement happens afterward.

### 3. FORCE effect (no ability currently uses it)

`_apply_effects()` has `EffectData.EffectType.FORCE: pass`. No ability in `AbilityLibrary` currently produces FORCE, so this can be deferred until an ability needs it.

### 4. Stat buff/debuff has no visual feedback

`_apply_stat_delta()` modifies `unit.data.strength` etc. but nothing displays the change to the player. The stat panel (double-click) would reflect it if opened, but there is no in-world indicator.

### 5. Stat changes are permanent within a session

Comment in `_apply_stat_delta()`: "stat changes are not currently reset at combat end; that is a future task."

---

## Suggested Session Split

### Session A — AoE Target Shapes (RADIAL/CONE/LINE)

**Scope:** Make `smoke_bomb` (RADIAL) actually hit all units in the shape. Lay the groundwork for CONE and LINE.

**Key design decisions to confirm before building:**
- RADIAL center: player clicks any tile within ability range, all units within the diamond (Manhattan ≤ 2, per the docs) are affected
- CONE: player picks a direction (4-directional is simpler; 8-directional matches the sprite system). Shape is the T defined in `combatant_data.md`: 1 adjacent cell + 3 cells forming the top of the T
- LINE: player picks a direction; hits all units in a straight line up to `tile_range`
- `passthrough` field on `AbilityData` controls whether LINE/CONE continue past the first unit hit

**Files to modify:**
- `scripts/combat/CombatManager3D.gd` — `_on_ability_selected()` and `_try_ability_target()`
- `scripts/combat/Grid3D.gd` — may need helpers to compute shape cell sets; read this file first

**What to add to CombatManager3D:**
- A helper `_get_shape_cells(caster_pos, origin_pos, shape) -> Array[Vector2i]` that returns all cells covered by the shape
- `_on_ability_selected()`: for AoE shapes, highlight valid "origin" cells (where the player aims) rather than individual unit cells
- `_try_ability_target()`: for AoE shapes, when origin is clicked, collect all living units in the shape cells and call `_apply_effects()` once per unit

**No new tests needed** for grid math if it's simple; add tests in `tests/test_ability_library.gd` only if new logic is non-obvious.

---

### Session B — TRAVEL Effect (disengage)

**Scope:** After disengage QTE resolves, the caster repositions 1 tile freely.

**Key design decisions:**
- TRAVEL abilities have `target_shape = SELF`, so the QTE fires and accuracy is computed normally
- After QTE resolves, instead of a normal effect, the player gets a secondary "pick a destination tile" step
- `base_value` = number of tiles the unit can move (1 for disengage)
- `MoveType.FREE` = any adjacent empty tile; `MoveType.LINE` = must move in a straight line

**Complexity note:** TRAVEL needs a second input phase after the QTE, which breaks the current single-pass `_apply_effects()` flow. Options:
1. Detect TRAVEL effects before `_apply_effects()` and enter a new `PlayerMode.TRAVEL_DESTINATION` state
2. Add an `await` inside `_apply_effects()` that suspends until a tile is clicked (messier)
Option 1 is cleaner.

**Files to modify:**
- `scripts/combat/CombatManager3D.gd` — new `PlayerMode.TRAVEL_DESTINATION`, new `_try_travel_destination()` handler
- `scripts/combat/Unit3D.gd` — `move_to()` already exists and updates `grid_pos` + emits `unit_moved`

---

### Session C — Buff/Debuff Visual Feedback + Stat Reset

**Scope:** Show the player when a stat changes, and reset temporary buffs at turn end.

**Buff/debuff display:**
- Simplest option: a brief floating text label above the unit (e.g., "+2 STR" or "−1 DEX") that fades after ~1.5 s
- This is a visual-only change; no data model changes needed

**Stat reset:**
- Need a duration model: does a buff last 1 turn? Until combat ends? Permanent within a run?
- Confirm design intent before building. The simplest rule: stat changes persist until combat ends (resetting to archetype-baseline values)
- `CombatantData` doesn't store the original values; `ArchetypeLibrary.create()` would need to be called again, or a `base_stats` snapshot stored at `Unit3D.setup()` time

**Files to modify:**
- `scripts/combat/Unit3D.gd` — `play_stat_change_label(stat_name, delta)` visual method
- `scripts/combat/CombatManager3D.gd` — call the label from `_apply_effects()` after each BUFF/DEBUFF

---

## Key File Locations

| File | Purpose |
|------|---------|
| `scripts/combat/CombatManager3D.gd` | Main file for all 3 sessions |
| `scripts/combat/Grid3D.gd` | Cell highlighting, movement helpers — read before Session A |
| `scripts/combat/Unit3D.gd` | Unit visuals and move_to() — modify for Session B and C |
| `resources/AbilityData.gd` | TargetShape / ApplicableTo / Attribute enums |
| `resources/EffectData.gd` | EffectType / PoolType / MoveType enums |
| `scripts/globals/AbilityLibrary.gd` | The 12 abilities and their shapes/effects |
| `docs/map_directories/combatant_data.md` | Shape definitions, effect formulas, full field reference |

---

## Enum Quick Reference

```gdscript
# AbilityData.TargetShape
SELF=0, SINGLE=1, CONE=2, LINE=3, RADIAL=4

# AbilityData.ApplicableTo
ALLY=0, ENEMY=1, ANY=2

# EffectData.EffectType
HARM=0, MEND=1, FORCE=2, TRAVEL=3, BUFF=4, DEBUFF=5

# EffectData.MoveType
FREE=0, LINE=1
```

## Current Ability Shapes (for reference)

| Ability | Shape | Notes |
|---------|-------|-------|
| strike, heavy_strike, quick_shot | SINGLE/ENEMY | ✅ working |
| acid_splash, shield_bash, taunt, inspire | SINGLE | ✅ working |
| healing_draught, counter, guard | SELF | ✅ working |
| disengage | SELF + TRAVEL effect | QTE fires, movement is stub |
| smoke_bomb | RADIAL/ANY | Hits 1 target (placeholder) |

---

## Dead Code Note

`CombatManager3D._calculate_damage()` (line ~600) is no longer called anywhere. It can be deleted or left alone — GDScript does not error on unused methods.

---

## Code Conventions

- Typed GDScript: always declare types (`var x: int = 0`)
- `snake_case` vars/funcs, `PascalCase` class/node names, `ALL_CAPS` constants
- Section headers: `## --- Section Name ---`
- `.tscn` files stay minimal — build children in `_ready()`
- Signals named as past-tense events: `unit_moved`, `qte_resolved`
- Tests: `extends SceneTree`, `_initialize()`, plain `assert()`, `quit()`
- Run tests headless: `godot --headless --path rogue-finder --import` first (to generate class cache), then `godot --headless --path rogue-finder --script tests/<file>.gd`
