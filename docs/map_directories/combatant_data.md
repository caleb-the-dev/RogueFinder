# System: Combatant Data Model

> Last updated: 2026-04-15 (Session 6-7 — EffectData added; AbilityData rewritten with TargetShape/ApplicableTo/Attribute enums; AbilityLibrary abilities fully defined with typed effects)

---

## Purpose

`CombatantData` is the authoritative data record for every combatant (player or NPC). It replaces the simpler `UnitData` resource with a full identity + archetype + attribute model.

`ArchetypeLibrary` is the factory that creates randomized `CombatantData` instances according to per-archetype range constraints.

---

## Core Files

| File | Role |
|------|------|
| `resources/CombatantData.gd` | Resource: identity, attributes, equipment, ability pool. All derived stats are computed properties. |
| `scripts/globals/ArchetypeLibrary.gd` | Static factory: archetype definitions + `create()` method. |

---

## Design Principles

**Identity vs. Blueprint:**
- `character_name` — the name this specific combatant goes by (e.g., "Claude")
- `archetype_id` — the species/template (e.g., "archer_bandit"). Fixes class, artwork, and the *pools* from which background and attributes are drawn.

Like a Pokémon: the archetype is Pikachu, the character_name is whatever the trainer called it.

**Fixed per archetype:** `unit_class`, `artwork_idle`, `artwork_attack`, `abilities`.

**Randomized per instance (within archetype ranges):** `background`, all five core attributes, `armor_defense`, `qte_resolution`.

---

## CombatantData Fields

### Identity
| Field | Type | Notes |
|-------|------|-------|
| `character_name` | `String` | Display name; player-editable. |
| `archetype_id` | `String` | Key into `ArchetypeLibrary.ARCHETYPES`. |
| `is_player_unit` | `bool` | Team assignment; drives AI vs. player control. |

### Background & Class (placeholder — values from future CSV)
| Field | Type | Notes |
|-------|------|-------|
| `background` | `String` | e.g. "Crook", "Baker". Pool is per-archetype. |
| `unit_class` | `String` | e.g. "Rogue", "Barbarian", "Wizard". Fixed per archetype. |

### Portrait
| Field | Type | Notes |
|-------|------|-------|
| `portrait` | `Texture2D` | Face portrait for StatPanel / UnitInfoBar. `null` → falls back to Godot icon. |

### Artwork
| Field | Type | Notes |
|-------|------|-------|
| `artwork_idle` | `String` | `res://` path placeholder. |
| `artwork_attack` | `String` | `res://` path placeholder. |

### Core Attributes (range 0–5)
| Field | Drives |
|-------|--------|
| `strength` | `attack` (5 + STR) |
| `dexterity` | `speed` (2 + DEX) |
| `cognition` | Reserved for ability cost scaling (TBD) |
| `willpower` | `energy_regen` (2 + WIL) |
| `vitality` | `hp_max` (10 × VIT) and `energy_max` (5 + VIT) |

### Equipment Slots (placeholder strings — item system TBD)
`weapon`, `armor`, `accessory` — currently empty strings.
`consumable` — display name of the equipped consumable item (e.g. `"Healing Potion"`). Set to `""` when used in combat. Empty string means no consumable available.

### Ability Pool
`abilities: Array[String]` — exactly 4 slots. Stores **ability IDs** (e.g. `"strike"`, `"heavy_strike"`). Fixed per archetype. Empty string = unfilled slot. Looked up via `AbilityLibrary.get_ability()` at runtime.

### Enemy-Only
`qte_resolution: float` — auto-resolve accuracy for enemy QTE simulation (0.0–1.0).

---

## Derived Stats (computed properties on CombatantData)

| Property | Formula |
|----------|---------|
| `hp_max` | `10 * vitality` |
| `energy_max` | `5 + vitality` |
| `energy_regen` | `2 + willpower` |
| `speed` | `2 + dexterity` |
| `attack` | `5 + strength` |
| `defense` | alias → `armor_defense` (set by factory; item system TBD) |
| `unit_name` | alias → `character_name` (duck-type compat with HUD/Unit3D) |

---

## ArchetypeLibrary

### Defined Archetypes

| ID | Class | Backgrounds | STR | DEX | COG | WIL | VIT | Armor |
|----|-------|-------------|-----|-----|-----|-----|-----|-------|
| `RogueFinder` | Custom | Noble, Peasant, Scholar, Soldier, Merchant | 1–4 | 1–4 | 1–4 | 1–4 | 2–5 | 4–8 |
| `archer_bandit` | Rogue | Crook, Soldier | 1–2 | 3–4 | 1–2 | 0–2 | 1–3 | 3–5 |
| `grunt` | Barbarian | Crook, Soldier | 2–4 | 1–2 | 0–1 | 0–2 | 2–4 | 4–7 |
| `alchemist` | Wizard | Baker, Scholar, Merchant | 0–1 | 1–3 | 3–5 | 2–4 | 1–2 | 2–4 |
| `elite_guard` | Warrior | Soldier, Noble | 3–5 | 1–3 | 1–2 | 2–4 | 3–5 | 7–10 |

### Public API

```gdscript
## Creates a randomized CombatantData for the given archetype.
## character_name: optional override; falls back to flavor name pool if "".
## is_player: sets is_player_unit on result.
static func create(archetype_id: String, character_name: String = "",
    is_player: bool = false) -> CombatantData
```

---

## Dependencies

| Dependent | On |
|-----------|----|
| `CombatantData` | Nothing (leaf node) |
| `ArchetypeLibrary` | `CombatantData` |
| `Unit3D` | `CombatantData` (via `@export var data`) |
| `StatPanel` | `CombatantData`, `Unit3D` |
| `CombatManager3D` | `ArchetypeLibrary`, `CombatantData` |

---

## Notes

- `UnitData.gd` still exists for the legacy 2D system (`Unit.gd`, `test_unit.gd`). Do not delete it until the 2D prototype is retired.
- A future CSV import will replace the hardcoded `ARCHETYPES` dictionary in `ArchetypeLibrary`.
- `cognition` has no derived stat yet — it is reserved for the ability system (energy cost scaling, etc.).
- `armor_defense` is set by `ArchetypeLibrary.create()` until the item system drives it from the equipped armor.

---

## AbilityData

`resources/AbilityData.gd` — Resource subclass. One instance per ability. Created by `AbilityLibrary.get_ability()`.

### Enums

**Attribute** — which stat an ability scales with; also used by EffectData as `target_stat` for BUFF/DEBUFF:
`STRENGTH(0)`, `DEXTERITY(1)`, `COGNITION(2)`, `VITALITY(3)`, `WILLPOWER(4)`, `NONE(5)`

**TargetShape** — the geometry of the targeting area:

| Value | Behavior |
|-------|---------|
| `SELF` | Auto-targets the caster; no highlight step |
| `SINGLE` | Player picks one valid unit within range |
| `CONE` | T-shape: 1 cell adjacent to caster + 3 cells forming the top of the T |
| `LINE` | Straight line extending from the caster in a chosen direction |
| `RADIAL` | Diamond AoE — 5 wide × 5 tall |

**ApplicableTo** — which units can be targeted (irrelevant when `target_shape` is `SELF`):
`ALLY(0)`, `ENEMY(1)`, `ANY(2)`

### Fields

| Field | Type | Notes |
|-------|------|-------|
| `ability_id` | `String` | Snake_case key, e.g. `"heavy_strike"` |
| `ability_name` | `String` | Display name |
| `attribute` | `Attribute` | Stat this ability scales with |
| `target_shape` | `TargetShape` | Area/geometry of targeting |
| `applicable_to` | `ApplicableTo` | Which units can be targeted |
| `tile_range` | `int` | 0–10; `-1` = whole map |
| `passthrough` | `bool` | Effect continues past first collision (LINE/CONE/RADIAL only) |
| `energy_cost` | `int` | Subtracted from unit energy on use |
| `effects` | `Array[EffectData]` | Ordered list of effects; first effect determines QTE type |
| `description` | `String` | Flavor + mechanical tooltip text |
| `ability_icon` | `Texture2D` | Defaults to Godot icon (placeholder) |

---

## EffectData

`resources/EffectData.gd` — Resource subclass. One instance per effect within an ability. Created by `AbilityLibrary.get_ability()` from nested dicts — never instantiated directly.

### Enums

**EffectType:** `HARM(0)`, `MEND(1)`, `FORCE(2)`, `TRAVEL(3)`, `BUFF(4)`, `DEBUFF(5)`

**PoolType** (HARM / MEND only): `HP(0)`, `ENERGY(1)`

**MoveType** (TRAVEL only): `FREE(0)`, `LINE(1)`

### Fields

| Field | Type | Used by |
|-------|------|---------|
| `effect_type` | `EffectType` | All |
| `base_value` | `int` | All |
| `target_pool` | `PoolType` | HARM, MEND |
| `target_stat` | `int` | BUFF, DEBUFF (stores `AbilityData.Attribute` int) |
| `movement_type` | `MoveType` | TRAVEL |

### QTE Resolution

One QTE fires per ability (typed to the first effect). The resulting `accuracy: float` (0.0–1.0) is shared across all effects:

| Effect Type | Formula |
|-------------|---------|
| HARM / MEND | `max(1, round(accuracy × (base_value + caster.attribute_value)))` |
| BUFF / DEBUFF | flat `base_value`; accuracy < 0.3 = miss |
| FORCE | `round(accuracy × base_value)` tiles pushed |
| TRAVEL | `base_value` tiles always; accuracy = success threshold only |

---

## AbilityLibrary

`scripts/globals/AbilityLibrary.gd` — static class, mirrors `ArchetypeLibrary`.

### Defined Abilities (12)

| ID | Name | Attribute | Cost | Range | Shape | Applicable To | Effects |
|----|------|-----------|------|-------|-------|--------------|---------|
| `strike` | Strike | STR | 2 | 1 | Single | Enemy | HARM 5 HP |
| `heavy_strike` | Heavy Strike | STR | 4 | 1 | Single | Enemy | HARM 9 HP |
| `quick_shot` | Quick Shot | DEX | 2 | 4 | Single | Enemy | HARM 4 HP |
| `disengage` | Disengage | DEX | 2 | 1 | Self | Any | TRAVEL 1 FREE |
| `acid_splash` | Acid Splash | COG | 3 | 3 | Single | Enemy | HARM 3 HP + DEBUFF 1 DEX |
| `smoke_bomb` | Smoke Bomb | COG | 2 | 2 | Radial | Any | DEBUFF 1 DEX |
| `healing_draught` | Healing Draught | VIT | 3 | 0 | Self | Any | MEND 5 HP |
| `shield_bash` | Shield Bash | STR | 3 | 1 | Single | Enemy | HARM 3 HP + DEBUFF 1 STR |
| `counter` | Counter | WIL | 2 | 0 | Self | Any | BUFF 2 STR |
| `taunt` | Taunt | WIL | 1 | 3 | Single | Enemy | DEBUFF 1 WIL |
| `inspire` | Inspire | WIL | 3 | 3 | Single | Ally | BUFF 1 STR |
| `guard` | Guard | VIT | 2 | 0 | Self | Any | BUFF 2 VIT |

### Public API

```gdscript
## Returns a populated AbilityData. Never returns null — falls back to a stub for unknown IDs.
static func get_ability(ability_id: String) -> AbilityData
```

### Notes
- A future CSV import will replace the `ABILITIES` dictionary without changing the `get_ability()` signature.
- Every non-empty string in `CombatantData.abilities` must be a valid key in `AbilityLibrary.ABILITIES`.

---

## Where NOT to Look

- **Effect math is NOT here** — `EffectData` defines the shape of an effect (type, base_value, etc.) but all resolution math lives in `CombatManager3D._apply_effects()`.
- **Stat mutation at runtime is NOT here** — `CombatantData` stores base values; `_apply_stat_delta()` in CM3D modifies them mid-combat.
- **Unit visuals are NOT here** — HP bar rendering, lunge animations, hit flash are in `Unit3D.gd`.

---

## Key Patterns & Gotchas

- **Stats clamp to [0, 5] mid-combat** — `_apply_stat_delta()` in CM3D enforces this. `CombatantData` itself has no clamping logic.
- **Stat changes are permanent within a session** — there is no reset at combat end yet. A future task will snapshot base stats at `Unit3D.setup()` time and restore them after combat.
- **`cognition` has no derived stat yet** — reserved for ability cost scaling (TBD). Do not build anything that depends on it.
- **`abilities` array is exactly 4 slots** — empty string = unfilled slot. The ActionMenu button is greyed (not hidden) for empty slots.
- **`get_ability()` never returns null** — returns a safe stub for unknown IDs. Safe to call without nil checks.

---

## Recent Changes

| Date | Change |
|---|---|
| 2026-04-15 | Added `EffectData` resource (EffectType, PoolType, MoveType enums + fields) |
| 2026-04-15 | Rewrote `AbilityData` with `TargetShape`, `ApplicableTo`, `Attribute` enums; added `effects: Array[EffectData]`, `passthrough` |
| 2026-04-15 | `AbilityLibrary`: all 12 abilities fully defined with typed `EffectData` entries |
| 2026-04-14 | `AbilityData` initial version with `TargetType` enum and `tile_range`; ability IDs replace name strings in `CombatantData.abilities` |
| 2026-04-14 | `ArchetypeLibrary`: 5 archetypes defined; randomized factory |
