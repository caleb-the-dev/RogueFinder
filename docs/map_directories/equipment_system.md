# System: Equipment & Consumables

> Last updated: 2026-04-28 (Rarity Foundation Slice 1 — rarity enum, RARITY_COLORS, weighted drop, 9 placeholder COMMON items replace old 20)

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
| `data/equipment.csv` | Source of truth — 20 items; `stat_bonuses` as `stat:value\|stat:value` pipe pairs |
| `scripts/globals/ConsumableLibrary.gd` | Static catalog — CSV-sourced (`res://data/consumables.csv`), `get_consumable()` / `all_consumables()` / `reload()` |
| `data/consumables.csv` | Source of truth — 6 consumables; edit here |

---

## EquipmentData

### Fields

| Field | Type | Notes |
|-------|------|-------|
| `equipment_id` | `String` | Snake_case key (e.g. `"iron_sword"`) |
| `equipment_name` | `String` | Display name |
| `slot` | `int` | `Slot.WEAPON(0)`, `Slot.ARMOR(1)`, or `Slot.ACCESSORY(2)` |
| `rarity` | `int` | `Rarity.COMMON(0)`, `Rarity.RARE(1)`, `Rarity.EPIC(2)`, `Rarity.LEGENDARY(3)` |
| `stat_bonuses` | `Dictionary` | Attribute name → int delta (e.g. `{"strength": 1}`) |
| `granted_ability_ids` | `Array[String]` | Ability IDs this item grants on equip (empty for Slice 1 placeholders; used by future weapon/armor slices) |
| `feat_id` | `String` | Feat ID this item grants on equip (empty for Slice 1 placeholders; used by future accessory slice) |
| `description` | `String` | Flavor line |

### Enums & Constants

```gdscript
enum Slot    { WEAPON = 0, ARMOR = 1, ACCESSORY = 2 }
enum Rarity  { COMMON = 0, RARE = 1, EPIC = 2, LEGENDARY = 3 }

## Canonical rarity colors — apply to item name text + card borders.
## Keys are Rarity int values (0–3). Grey / Green / Blue / Orange.
const RARITY_COLORS: Dictionary = { 0: Color(...), 1: Color(...), 2: Color(...), 3: Color(...) }
```

### Helpers

```gdscript
## Returns the bonus for stat_name, or 0 if the key is absent. Never errors.
func get_bonus(stat_name: String) -> int

## Returns RARITY_COLORS[rarity]. Convenience wrapper for UI code.
func rarity_color() -> Color
```

---

## EquipmentLibrary

Static class. Internal storage: `static var _cache: Dictionary` (lazy CSV parse).

### CSV Columns

`id, name, slot, rarity, stat_bonuses, granted_ability_ids, feat_id, description, notes`

- `rarity`: `COMMON | RARE | EPIC | LEGENDARY` (defaults to COMMON on unknown/empty)
- `granted_ability_ids`: pipe-separated ability id strings, or empty
- `feat_id`: single feat id string, or empty

### Defined Items — Slice 1 Placeholders (9, all COMMON)

Previous 20 items wiped. Slices 3–5 will replace these with tiered item families.

**WEAPON (3):**

| ID | Name | Bonuses |
|----|------|---------|
| `iron_sword` | Iron Sword | strength +1 |
| `crude_bow` | Crude Bow | dexterity +1 |
| `gnarled_staff` | Gnarled Staff | willpower +1 |

**ARMOR (3):**

| ID | Name | Bonuses |
|----|------|---------|
| `padded_armor` | Padded Armor | physical_armor +1 |
| `cloth_robe` | Cloth Robe | magic_armor +1 |
| `rough_hide` | Rough Hide | physical_armor +1, vitality +1 |

**ACCESSORY (3):**

| ID | Name | Bonuses |
|----|------|---------|
| `copper_ring` | Copper Ring | vitality +1 |
| `worn_amulet` | Worn Amulet | willpower +1 |
| `leather_bracers` | Leather Bracers | strength +1 |

### Public API

```gdscript
## Returns a populated EquipmentData. Never returns null — falls back to a stub for unknown IDs.
static func get_equipment(id: String) -> EquipmentData
## Returns all 9 defined items. Use for reward pools.
static func all_equipment() -> Array[EquipmentData]
```

---

## Rarity Model

Four tiers: **COMMON / RARE / EPIC / LEGENDARY**

### Colors (item name text + card border)

| Tier | Color |
|------|-------|
| COMMON | Grey `Color(0.65, 0.65, 0.65)` |
| RARE | Green `Color(0.25, 0.80, 0.35)` |
| EPIC | Blue `Color(0.30, 0.55, 1.00)` |
| LEGENDARY | Orange `Color(1.00, 0.55, 0.10)` |

Sourced from `EquipmentData.RARITY_COLORS` — single definition, referenced by all UI surfaces.

### Drop Weights (RewardGenerator)

```gdscript
const RARITY_WEIGHTS: Dictionary = {
    Rarity.COMMON: 60, Rarity.RARE: 25, Rarity.EPIC: 12, Rarity.LEGENDARY: 3
}
```

`RewardGenerator.roll(n)` picks rarity first (weighted), then a random item from that tier. Falls back to COMMON if the rolled tier bucket is empty. Consumables slot into the COMMON bucket. The roll is fixed for now; boss-iteration + player-level scaling is deferred to Stage 2.

### Tiered Item Families (Slices 3–5)

Each conceptual item (e.g. "iron sword") will have 4 variants as separate CSV rows with distinct IDs (e.g. `iron_sword_common`, `iron_sword_rare`, `iron_sword_epic`, `iron_sword_legendary`). Single row per variant, hand-authored. The 9 Slice 1 placeholders will be replaced.

### UI Color Surfaces

Applied across:
- **Party Sheet** — bag item card border (rarity color when seen; gold when unseen) + item name text
- **Party Sheet equipment slots** — occupied slot button text colored by equipped item's rarity
- **Reward Screen** (EndCombatScreen) — PanelContainer card border + item name label
- **Dev Menu "Add Item" modal** (MapManager) — button font color for equipment items

Inventory dicts include `"rarity": int` from `RewardGenerator.roll()` and all `add_to_inventory()` call sites. Old saves without the key default to COMMON via `.get("rarity", 0)`.

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

### Defined Consumables (6)

| ID | Name | Effect | Value |
|----|------|--------|-------|
| `healing_potion` | Healing Potion | MEND HP | 15 |
| `power_tonic` | Power Tonic | BUFF STR | +2 |
| `rage_draught` | Rage Draught | BUFF STR | +3 |
| `focus_brew` | Focus Brew | BUFF COG | +2 |
| `swiftness_tonic` | Swiftness Tonic | BUFF DEX | +2 |
| `antidote` | Antidote | MEND HP | 8 |

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
