# System: Equipment & Consumables

> Last updated: 2026-04-28 (Slice 3 — 12 tiered weapon families; equip/unequip pool lifecycle)

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
| `data/equipment.csv` | Source of truth — 18 items (12 tiered weapons + 3 COMMON armor + 3 COMMON accessory); columns: `id, name, slot, rarity, stat_bonuses, granted_ability_ids, feat_id, description, notes` |
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

### Defined Weapon Items — Tiered Families (12, Slice 3)

3 placeholder COMMON weapons replaced by 3 full families × 4 rarities.
Each weapon grants exactly 1 ability via `granted_ability_ids`.

**STR family (melee):**

| ID | Name | Rarity | Bonuses | Granted Ability |
|----|------|--------|---------|-----------------|
| `iron_sword` | Iron Sword | COMMON | — | `blade_strike` |
| `long_sword` | Long Sword | RARE | strength +1 | `blade_strike` |
| `war_blade` | War Blade | EPIC | strength +1 | `heavy_blade_strike` |
| `warlords_cleaver` | Warlord's Cleaver | LEGENDARY | strength +2 | `heavy_blade_strike` |

**DEX family (ranged):**

| ID | Name | Rarity | Bonuses | Granted Ability |
|----|------|--------|---------|-----------------|
| `crude_bow` | Crude Bow | COMMON | — | `quick_draw` |
| `hunters_bow` | Hunter's Bow | RARE | dexterity +1 | `quick_draw` |
| `shadow_bow` | Shadow Bow | EPIC | dexterity +1 | `aimed_draw` |
| `longbow` | Longbow | LEGENDARY | dexterity +2 | `aimed_draw` |

**COG family (magic):**

| ID | Name | Rarity | Bonuses | Granted Ability |
|----|------|--------|---------|-----------------|
| `gnarled_staff` | Gnarled Staff | COMMON | — | `staff_bolt` |
| `focusing_wand` | Focusing Wand | RARE | cognition +1 | `staff_bolt` |
| `ley_staff` | Ley Staff | EPIC | cognition +1 | `empowered_bolt` |
| `archmages_focus` | Archmage's Focus | LEGENDARY | cognition +1, willpower +1 | `empowered_bolt` |

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

### Tiered Item Families

Each family has 4 variants as separate CSV rows (e.g. `iron_sword` COMMON → `long_sword` RARE → `war_blade` EPIC → `warlords_cleaver` LEGENDARY). Single row per variant. Weapon tier ladder: Common = ability only · Rare = ability + +1 primary stat · Epic = Rare's stat + upgraded ability · Legendary = Epic's stat + extra stat (either +1 more primary OR +1 secondary). Armor and accessory families (Slices 4–5) still placeholder.

### UI Color Surfaces

Applied across:
- **Party Sheet** — bag item card border (rarity color when seen; gold when unseen) + item name text
- **Party Sheet equipment slots** — occupied slot button text colored by equipped item's rarity
- **Reward Screen** (EndCombatScreen) — PanelContainer card border + item name label
- **Dev Menu "Add Item" modal** (MapManager) — button font color for equipment items

Inventory dicts include `"rarity": int` from `RewardGenerator.roll()` and all `add_to_inventory()` call sites. Old saves without the key default to COMMON via `.get("rarity", 0)`.

---

## Weapon-Grants-Ability Lifecycle

When a weapon with `granted_ability_ids` is equipped, its ability IDs are added to the combatant's `ability_pool` (deduped). When unequipped, they are removed — unless the ability is currently occupying one of the 4 active slots, in which case it stays in the pool until the player manually replaces it.

**Two methods on `CombatantData`** (call at all equip/unequip sites):

```gdscript
## Adds granted ids to ability_pool (deduped). Safe on armor/accessories — no-op.
func on_equip(eq: EquipmentData) -> void

## Removes granted ids from ability_pool AND clears any active slot holding the ability.
## Unequipping always strips the granted ability — slots are NOT preserved.
func on_unequip(eq: EquipmentData) -> void
```

**Call sites that invoke these:**
- `PartySheet._drop_to_slot()` / `_unequip_item()`
- `BadurgaManager._pm_drop_to_slot()` / `_pm_unequip_item()` / `_deequip_to_bag()`
- `GameState.release_from_bench()`

Armor and accessories have empty `granted_ability_ids` so `on_equip`/`on_unequip` are no-ops for them — safe to call unconditionally.

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
- **Rarity in inventory dicts** — all `add_to_inventory()` call sites are responsible for including `"rarity": eq.rarity` in the dict. The field defaults to 0 (COMMON) via `.get("rarity", 0)` in UI code, so missing it causes no crash — but items will display as grey regardless of tier.
- **EquipmentData stub rarity** — `get_equipment(unknown_id)` returns a stub with `rarity = COMMON`. Old saves equipping now-deleted item IDs silently slot a COMMON-colored "Unknown" item.

---

## Recent Changes

| Date | Change |
|---|---|
| 2026-04-28 | **Weapon Tier Families — Slice 3.** 3 placeholder COMMON weapons replaced by 12 tiered entries across 3 families (STR/DEX/COG) × 4 rarities. `abilities.csv` gained 6 weapon abilities: `blade_strike`→`heavy_blade_strike` (STR), `quick_draw`→`aimed_draw` (DEX), `staff_bolt`→`empowered_bolt` (COG). `CombatantData.on_equip()` / `on_unequip()` added — manage `granted_ability_ids` in `ability_pool` without touching active slots. All equip/unequip call sites in `PartySheet`, `BadurgaManager`, `GameState.release_from_bench()` updated. `EquipmentLibrary.granted_ability_ids` parse fixed (`.assign()` not typed `Array()` ctor). 7 new headless tests (`test_weapon_equip.gd`). |
| 2026-04-28 | **Rarity Foundation — Slice 1.** `EquipmentData`: `Rarity` enum + `rarity: int` field + `granted_ability_ids: Array[String]` + `feat_id: String` + `RARITY_COLORS: Dictionary` (int keys 0–3 → grey/green/blue/orange) + `rarity_color() -> Color` helper. `EquipmentLibrary`: parses `rarity`, `granted_ability_ids` (pipe-split), `feat_id` from CSV; stub defaults COMMON / [] / "". Old 20-item CSV wiped; 9 COMMON placeholders added. UI color treatment across PartySheet, EndCombatScreen, MapManager Add Item modal. All `add_to_inventory` call sites updated with `"rarity"`. |
| 2026-04-27 | Kindred expansion (equipment 9→20; added war_hammer, twin_daggers, mages_staff, bone_club, hide_armor, silk_shroud, dragonscale_vest, swift_boots, scholars_ring, amulet_of_will, fang_necklace). First magic_armor equipment (`warded_robe`, `silk_shroud`, `dragonscale_vest`). `plate_cuirass` (heavy physical armor). |
| 2026-04-27 | **Dual armor.** `leather_armor` / `chain_mail` stat_bonuses column renamed `armor_defense` → `physical_armor`. All armor stat keys updated. `warded_robe` added (first `magic_armor` equipment). |
| 2026-04-24 | **Events Slice 4.** `rusted_dagger` added to equipment.csv (zero bonuses, WEAPON slot) for event reward use. |
