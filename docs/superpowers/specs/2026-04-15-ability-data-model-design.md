# Ability Data Model — Design Spec
**Date:** 2026-04-15  
**Status:** Approved  
**Scope:** Replace `AbilityData.gd` and `AbilityLibrary.gd`; add new `EffectData.gd` resource.

---

## Problem

The current `AbilityData` model has no effect data at all — abilities proxy through QTE damage as a placeholder. `TargetType` mixes shape (AOE, CONE) with targeting filter (SINGLE_ENEMY, SINGLE_ALLY), making it impossible to express "cone that hits allies" or "single target that hits anyone". There is no way to represent abilities with multiple effects (e.g. harm + debuff).

---

## Goals

- Represent any combination of effect types on a single ability (harm, mend, force, travel, buff, debuff)
- Cleanly separate targeting shape from targeting filter
- Link each ability to a primary attribute that scales its power
- Keep the authoring format (AbilityLibrary dicts) readable and CSV-migration-ready
- Keep `get_ability()` signature unchanged — all callers stay the same

---

## New File: `resources/EffectData.gd`

A small typed Resource representing one effect. An ability can carry any number of these.

```gdscript
class_name EffectData
extends Resource

enum EffectType { HARM, MEND, FORCE, TRAVEL, BUFF, DEBUFF }
enum PoolType   { HP, ENERGY }     # used by HARM / MEND
enum MoveType   { FREE, LINE }     # used by TRAVEL

@export var effect_type:   EffectType = EffectType.HARM
@export var base_value:    int        = 0
@export var target_pool:   PoolType   = PoolType.HP      # HARM / MEND only
@export var target_stat:   AbilityData.Attribute = AbilityData.Attribute.NONE  # BUFF / DEBUFF only
@export var movement_type: MoveType   = MoveType.FREE    # TRAVEL only
```

Fields irrelevant to a given `EffectType` are ignored at resolution time.

---

## Revised: `resources/AbilityData.gd`

### New Enums

```gdscript
enum Attribute {
    STRENGTH, DEXTERITY, COGNITION, VITALITY, WILLPOWER, NONE
}

enum TargetShape {
    SELF,    # auto-targets the caster; no highlight step
    SINGLE,  # player picks one valid unit within range
    CONE,    # T-shape: 1 cell adjacent to caster + 3 cells forming the top of the T
    LINE,    # straight line of cells extending from the caster in a chosen direction
    RADIAL,  # diamond AoE — 5 wide × 5 tall
}

enum ApplicableTo {
    ALLY,    # can only affect allied units
    ENEMY,   # can only affect enemy units
    ANY,     # can affect any unit (including self for area types)
}
```

### Fields

| Field | Type | Notes |
|-------|------|-------|
| `ability_id` | String | unique key |
| `ability_name` | String | display name |
| `attribute` | Attribute | stat this ability scales with |
| `target_shape` | TargetShape | area/shape of targeting |
| `applicable_to` | ApplicableTo | which units can be targeted |
| `tile_range` | int | 0–10; `-1` = whole map |
| `passthrough` | bool | effect continues past first collision if true; only meaningful for LINE, CONE, RADIAL |
| `energy_cost` | int | subtracted from caster's energy pool |
| `effects` | Array[EffectData] | ordered list of effects; first effect drives QTE type |
| `description` | String | flavor + mechanical summary |
| `ability_icon` | Texture2D | defaults to Godot icon until real art arrives |

`tags` array is removed — superseded by `attribute` + `target_shape`.

---

## AbilityLibrary Authoring Format

Effects are nested dicts inside each ability entry. `get_ability()` builds `EffectData` instances from them.

```gdscript
"flaming_blade": {
    "name":          "Flaming Blade",
    "attribute":     AbilityData.Attribute.STRENGTH,
    "target":        AbilityData.TargetShape.CONE,
    "applicable_to": AbilityData.ApplicableTo.ENEMY,
    "range":         1,
    "passthrough":   true,
    "cost":          2,
    "description":   "Use your flaming weapons to slice through many enemies in front of you.",
    "effects": [
        { "type": EffectData.EffectType.HARM, "base_value": 3, "pool": EffectData.PoolType.HP },
    ],
},

"acid_splash": {
    "name":          "Acid Splash",
    "attribute":     AbilityData.Attribute.COGNITION,
    "target":        AbilityData.TargetShape.SINGLE,
    "applicable_to": AbilityData.ApplicableTo.ENEMY,
    "range":         3,
    "passthrough":   false,
    "cost":          3,
    "description":   "Hurl a flask of sizzling reagent — damages on contact and eats through the target's armor.",
    "effects": [
        { "type": EffectData.EffectType.HARM,   "base_value": 3, "pool": EffectData.PoolType.HP },
        { "type": EffectData.EffectType.DEBUFF, "base_value": 1, "stat": AbilityData.Attribute.DEXTERITY },
    ],
},

"empower": {
    "name":          "Empower",
    "attribute":     AbilityData.Attribute.COGNITION,
    "target":        AbilityData.TargetShape.SINGLE,
    "applicable_to": AbilityData.ApplicableTo.ALLY,
    "range":         3,
    "passthrough":   false,
    "cost":          3,
    "description":   "Channel arcane energy into an ally — bolster their physical strength for the fight ahead.",
    "effects": [
        { "type": EffectData.EffectType.BUFF, "base_value": 1, "stat": AbilityData.Attribute.STRENGTH },
    ],
},
```

---

## QTE Resolution Rules

One QTE fires per ability, typed to the **first effect** in the array. The resulting `accuracy: float` (0.0–1.0) is shared across all effects:

| Effect Type | Resolution Formula |
|-------------|-------------------|
| HARM / MEND | `result = qte_accuracy × (base_value + caster.attribute_value)` |
| BUFF / DEBUFF | `result = base_value` flat; accuracy acts as success threshold (< 0.3 = miss) |
| FORCE | `tiles_pushed = round(qte_accuracy × base_value)` |
| TRAVEL | `tiles_moved = base_value` always; accuracy = success threshold only |

These formulas are the starting point — each can be tuned independently during implementation.

---

## What Changes vs. Current Code

| Current | New |
|---------|-----|
| `TargetType` enum (mixed shape + filter) | `TargetShape` + `ApplicableTo` (separated) |
| `tags: Array[String]` | Removed |
| No effect data | `effects: Array[EffectData]` |
| No attribute link | `attribute: Attribute` |
| No passthrough | `passthrough: bool` |
| `tile_range: int` (1–N) | `tile_range: int` (-1 = whole map) |

## What Does Not Change

- `get_ability(id: String) -> AbilityData` — signature unchanged
- `ability_id`, `ability_name`, `energy_cost`, `description`, `ability_icon` — unchanged
- All 12 existing abilities are updated in-place (no new IDs added in this pass)
- `AbilityLibrary` stub fallback behavior unchanged

---

## Files Affected

| File | Action |
|------|--------|
| `resources/EffectData.gd` | **Create** |
| `resources/AbilityData.gd` | **Rewrite** |
| `scripts/globals/AbilityLibrary.gd` | **Rewrite** (all 12 abilities get full effect data) |
| `scripts/combat/CombatManager3D.gd` | **Update** — read `effects` array; update `_pending_ability` flow |
| `docs/map_directories/combatant_data.md` | **Update** — new field reference |
