# System: Combatant Data Model

> Last updated: 2026-04-14 (Session 3 — AbilityData, AbilityLibrary added; ability IDs replace name strings)

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

### Fields

| Field | Type | Notes |
|-------|------|-------|
| `ability_id` | `String` | Snake_case key, e.g. `"heavy_strike"` |
| `ability_name` | `String` | Display name |
| `tags` | `Array[String]` | e.g. `["Melee"]`, `["Magic", "Ranged"]` |
| `energy_cost` | `int` | Subtracted from unit energy on use |
| `range` | `int` | Max tile distance to a valid target |
| `target_type` | `TargetType` | `AbilityData.TargetType` enum (see below) |
| `description` | `String` | Flavor + mechanical tooltip text |
| `ability_icon` | `Texture2D` | Defaults to Godot icon (placeholder) |

### TargetType Enum

| Value | Int | Behavior |
|-------|-----|---------|
| `SELF` | 0 | Auto-targets the caster; no target pick step |
| `SINGLE_ENEMY` | 1 | Player picks one living enemy within range |
| `SINGLE_ALLY` | 2 | Player picks one living ally within range |
| `AOE` | 3 | Placeholder — uses enemy cells for now |
| `CONE` | 4 | Placeholder — uses enemy cells for now |

---

## AbilityLibrary

`scripts/globals/AbilityLibrary.gd` — static class, mirrors `ArchetypeLibrary`.

### Defined Abilities (12 placeholders)

| ID | Name | Tags | Cost | Range | Target |
|----|------|------|------|-------|--------|
| `strike` | Strike | Melee | 2 | 1 | SingleEnemy |
| `heavy_strike` | Heavy Strike | Melee | 4 | 1 | SingleEnemy |
| `quick_shot` | Quick Shot | Ranged | 2 | 4 | SingleEnemy |
| `disengage` | Disengage | Utility | 2 | 1 | Self |
| `acid_splash` | Acid Splash | Magic, Ranged | 3 | 3 | SingleEnemy |
| `smoke_bomb` | Smoke Bomb | Utility | 2 | 2 | AOE |
| `healing_draught` | Healing Draught | Utility | 3 | 1 | Self |
| `shield_bash` | Shield Bash | Melee | 3 | 1 | SingleEnemy |
| `counter` | Counter | Melee | 2 | 1 | Self |
| `taunt` | Taunt | Utility | 1 | 3 | SingleEnemy |
| `inspire` | Inspire | Utility | 3 | 3 | SingleAlly |
| `guard` | Guard | Utility | 2 | 1 | Self |

### Public API

```gdscript
## Returns a populated AbilityData. Never returns null — falls back to a stub for unknown IDs.
static func get_ability(ability_id: String) -> AbilityData
```

### Notes
- A future CSV import will replace the `ABILITIES` dictionary without changing the `get_ability()` signature.
- Every non-empty string in `CombatantData.abilities` must be a valid key in `AbilityLibrary.ABILITIES`.
