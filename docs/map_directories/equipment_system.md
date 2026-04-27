# System: Equipment & Consumables

> Last updated: 2026-04-27 (added plate_cuirass + warded_robe — first magic_armor equipment piece)

---

## Purpose

Loot the player picks up and attaches to party members:

- **Equipment** — persistent gear in one of three slots (weapon / armor / accessory). Provides stat bonuses via `CombatantData._equip_bonus()`.
- **Consumables** — single-use items (one slot per combatant). Apply MEND / BUFF / DEBUFF immediately, no QTE, no energy cost.

Gear comes from rewards — no archetype starts with equipment. Consumables are archetype-seeded (e.g. RogueFinder starts with `power_tonic`) and refilled via rewards.

---

## Core Files

| File | Role |
|------|------|
| `resources/EquipmentData.gd` | Resource — one equipment item |
| `resources/ConsumableData.gd` | Resource — one consumable item |
| `scripts/globals/EquipmentLibrary.gd` | Static catalog — CSV-sourced (`res://data/equipment.csv`), `get_equipment()` / `all_equipment()` / `reload()` |
| `data/equipment.csv` | Source of truth — 9 items; `stat_bonuses` as `stat:value\|stat:value` pipe pairs |
| `scripts/globals/ConsumableLibrary.gd` | Static catalog — CSV-sourced (`res://data/consumables.csv`), `get_consumable()` / `all_consumables()` / `reload()` |
| `data/consumables.csv` | Source of truth — 2 consumables; edit here |

---

## EquipmentData

### Fields

| Field | Type | Notes |
|-------|------|-------|
| `equipment_id` | `String` | Snake_case key (e.g. `"short_sword"`) |
| `equipment_name` | `String` | Display name |
| `slot` | `int` | `Slot.WEAPON(0)`, `Slot.ARMOR(1)`, or `Slot.ACCESSORY(2)` |
| `stat_bonuses` | `Dictionary` | Attribute name → int delta (e.g. `{"strength": 1}`) |
| `description` | `String` | Flavor line |

### Helpers

```gdscript
## Returns the bonus for stat_name, or 0 if the key is absent. Never errors.
func get_bonus(stat_name: String) -> int
```

---

## EquipmentLibrary

Static class. Internal storage: `const _ITEMS: Array[Dictionary]`.

### Defined Items (9)

| ID | Name | Slot | Bonuses | Description |
|----|------|------|---------|-------------|
| `leather_armor` | Leather Armor | ARMOR | physical_armor +1 | Light protection. |
| `chain_mail` | Chain Mail | ARMOR | physical_armor +2, dexterity -1 | Heavier. Slower. |
| `plate_cuirass` | Plate Cuirass | ARMOR | physical_armor +3, dexterity -2 | Heavy steel plate. Soaks blows but you'll feel every step. |
| `warded_robe` | Warded Robe | ARMOR | magic_armor +2 | First magic_armor equipment piece — exercises the `_equip_bonus("magic_armor")` codepath that previously had no live data. |
| `short_sword` | Short Sword | WEAPON | strength +1 | A simple blade. |
| `rusted_dagger` | Rusted Dagger | WEAPON | (none) | A dagger eaten by rust. Still sharp enough. |
| `hunters_bow` | Hunter's Bow | WEAPON | dexterity +1 | Better range. |
| `iron_ring` | Iron Ring | ACCESSORY | vitality +1 | Adds constitution. |
| `lucky_charm` | Lucky Charm | ACCESSORY | willpower +1 | Luck of the draw. |

### Public API

```gdscript
## Returns a populated EquipmentData. Never returns null — falls back to a stub for unknown IDs.
static func get_equipment(id: String) -> EquipmentData
## Returns all 9 defined items. Use for reward pools.
static func all_equipment() -> Array[EquipmentData]
```

---

## ConsumableData

### Fields

| Field | Type | Notes |
|-------|------|-------|
| `consumable_id` | `String` | Snake_case key |
| `consumable_name` | `String` | Display name |
| `effect_type` | `EffectData.EffectType` | MEND, BUFF, or DEBUFF only |
| `base_value` | `int` | Flat HP healed (MEND) or stat delta (BUFF/DEBUFF) |
| `target_stat` | `int` | `AbilityData.Attribute` int — BUFF/DEBUFF only |
| `description` | `String` | Tooltip text |

Only MEND, BUFF, and DEBUFF are valid — consumables never HARM, FORCE, or TRAVEL.

---

## ConsumableLibrary

Static class. Internal storage: `const CONSUMABLES: Dictionary`.

### Defined Consumables (2)

| ID | Name | Effect | Value |
|----|------|--------|-------|
| `healing_potion` | Healing Potion | MEND HP | 15 |
| `power_tonic` | Power Tonic | BUFF STR | +2 |

### Public API

```gdscript
## Returns a populated ConsumableData. Never returns null — falls back to a stub for unknown IDs.
static func get_consumable(consumable_id: String) -> ConsumableData
```

### Effect Resolution

Consumables apply immediately when used — no QTE, no energy cost. Handled in `CombatManager3D._on_consumable_selected()`.

| Effect Type | Resolution |
|-------------|------------|
| MEND | `unit.heal(base_value)` — flat heal, no stat scaling |
| BUFF | `_apply_stat_delta(unit, target_stat, +base_value)` |
| DEBUFF | `_apply_stat_delta(unit, target_stat, -base_value)` |

---

## Dependencies

| Dependent | On |
|-----------|----|
| `EquipmentData` | Nothing (leaf node) |
| `ConsumableData` | `EffectData` (for EffectType enum) |
| `EquipmentLibrary` | `EquipmentData` |
| `ConsumableLibrary` | `ConsumableData`, `EffectData` |
| `RewardGenerator` | `EquipmentLibrary.all_equipment()`, `ConsumableLibrary` (all consumables) |
| `CombatantData` | `EquipmentData` (weapon / armor / accessory slots) |
| `GameState` | `EquipmentLibrary.get_equipment()` (resolves slot IDs on save load) |
| `CombatActionPanel` | `ConsumableLibrary.get_consumable()` (button build + tooltip) |

---

## Where NOT to Look

- **Stat bonus application is NOT here** — `CombatantData._equip_bonus()` sums bonuses from all three slots; see `combatant_data.md`.
- **Consumable use is NOT here** — `CombatManager3D._on_consumable_selected()` dispatches MEND/BUFF/DEBUFF effects.
- **Reward pool shuffling is NOT here** — `RewardGenerator.roll(n)` builds the mixed equipment + consumable pool.

---

## Key Patterns & Gotchas

- **Slots serialize as id strings** — `CombatantData` slots are `EquipmentData` resources, but `GameState.save()` writes them as their `equipment_id` string. Empty string on load → `null` slot.
- **Unknown ids survive load** — `get_equipment()` / `get_consumable()` return stubs, not null. A corrupt save never silently drops a slot.
- **Consumable slot is a String, not a Resource** — `CombatantData.consumable: String`. Unlike the three equipment slots, consumables resolve through `ConsumableLibrary` at use-time. `""` means the slot is empty.
