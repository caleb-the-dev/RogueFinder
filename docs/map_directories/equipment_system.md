# System: Equipment & Consumables

> Last updated: 2026-04-29 (Slice 5 — 12 tiered accessory families; read-time feat aggregation via accessory.feat_id)

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
| `data/equipment.csv` | Source of truth — 36 items (12 tiered weapons + 12 tiered armor + 12 tiered accessory); columns: `id, name, slot, rarity, stat_bonuses, granted_ability_ids, feat_id, description, notes` |
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

**ARMOR (12) — Tiered Families (Slice 4):**

3 families × 4 rarities. **Distribution rule:** `physical_armor + magic_armor = 6` at Common (before the +2/+2 Epic bump). **Tier ladder:** Common = stats only · Rare = stats + base ability · Epic = stats+2/+2 + base ability · Legendary = stats+2/+2 + upgraded ability.

**Iron Plate family (phys-heavy 5/1, dexterity:-1 tradeoff):**

| ID | Name | Rarity | Bonuses | Granted Ability |
|----|------|--------|---------|-----------------|
| `iron_plate` | Iron Plate | COMMON | physical_armor+5, magic_armor+1, dexterity-1 | — |
| `iron_plate_rare` | Fitted Plate | RARE | same | `stone_guard` |
| `iron_plate_epic` | War Plate | EPIC | physical_armor+7, magic_armor+3, dexterity-1 | `stone_guard` |
| `iron_plate_legendary` | Bulwark Plate | LEGENDARY | same as Epic | `fortified_guard` |

**Scale Mail family (balanced 3/3):**

| ID | Name | Rarity | Bonuses | Granted Ability |
|----|------|--------|---------|-----------------|
| `scale_mail` | Scale Mail | COMMON | physical_armor+3, magic_armor+3 | — |
| `scale_mail_rare` | Reinforced Scales | RARE | same | `guard` |
| `scale_mail_epic` | Dragon Scale | EPIC | physical_armor+5, magic_armor+5 | `guard` |
| `scale_mail_legendary` | Elder Scale Coat | LEGENDARY | same as Epic | `enhanced_guard` |

**Mystic Robe family (magic-heavy 1/5):**

| ID | Name | Rarity | Bonuses | Granted Ability |
|----|------|--------|---------|-----------------|
| `mystic_robe` | Mystic Robe | COMMON | physical_armor+1, magic_armor+5 | — |
| `mystic_robe_rare` | Warded Mantle | RARE | same | `divine_ward` |
| `mystic_robe_epic` | Arcane Vestment | EPIC | physical_armor+3, magic_armor+7 | `divine_ward` |
| `mystic_robe_legendary` | Sorcerer's Mantle | LEGENDARY | same as Epic | `greater_ward` |

**ACCESSORY (12) — Tiered Families (Slice 5):**

3 families × 4 rarities. Tier ladder: Common = `X:1` stat only · Rare = `X:1` + background feat · Epic = `X:1`, `Y:1` + same feat · Legendary = `X:1`, `Y:1`, `Z:2` + same feat. Accessories never have `granted_ability_ids`. The equipped accessory's `feat_id` applies stat bonuses at **read-time** via `get_feat_stat_bonus()` — NOT written to `feat_ids` on equip.

**Ring of Valor family (STR → VIT → WIL), feat: `combat_training` str:1):**

| ID | Name | Rarity | Bonuses | Feat |
|----|------|--------|---------|------|
| `ring_of_valor` | Ring of Valor | COMMON | strength+1 | — |
| `ring_of_valor_rare` | Veteran's Ring | RARE | strength+1 | `combat_training` |
| `ring_of_valor_epic` | Champion's Ring | EPIC | strength+1, vitality+1 | `combat_training` |
| `ring_of_valor_legendary` | Warlord's Signet | LEGENDARY | strength+1, vitality+1, willpower+2 | `combat_training` |

**Scholar's Amulet family (COG → WIL → VIT), feat: `analytical_mind` cog:2):**

| ID | Name | Rarity | Bonuses | Feat |
|----|------|--------|---------|------|
| `scholars_amulet` | Scholar's Amulet | COMMON | cognition+1 | — |
| `scholars_amulet_rare` | Seeker's Amulet | RARE | cognition+1 | `analytical_mind` |
| `scholars_amulet_epic` | Sage's Amulet | EPIC | cognition+1, willpower+1 | `analytical_mind` |
| `scholars_amulet_legendary` | Arcanist's Totem | LEGENDARY | cognition+1, willpower+1, vitality+2 | `analytical_mind` |

**Iron Bracers family (VIT → STR → DEX), feat: `hearty_constitution` vit:1):**

| ID | Name | Rarity | Bonuses | Feat |
|----|------|--------|---------|------|
| `iron_bracers` | Iron Bracers | COMMON | vitality+1 | — |
| `iron_bracers_rare` | Hardened Bracers | RARE | vitality+1 | `hearty_constitution` |
| `iron_bracers_epic` | Warden's Bracers | EPIC | vitality+1, strength+1 | `hearty_constitution` |
| `iron_bracers_legendary` | Unbroken Vambraces | LEGENDARY | vitality+1, strength+1, dexterity+2 | `hearty_constitution` |

### Public API

```gdscript
## Returns a populated EquipmentData. Never returns null — falls back to a stub for unknown IDs.
static func get_equipment(id: String) -> EquipmentData
## Returns all 36 defined items (12 weapons + 12 armor + 12 accessory). Use for reward pools.
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

Each family has 4 variants as separate CSV rows (e.g. `iron_sword` COMMON → `long_sword` RARE → `war_blade` EPIC → `warlords_cleaver` LEGENDARY). Single row per variant. Weapon tier ladder: Common = ability only · Rare = ability + +1 primary stat · Epic = Rare's stat + upgraded ability · Legendary = Epic's stat + extra stat. Accessory tier ladder: Common = X:1 stat · Rare = X:1 + background feat · Epic = X:1,Y:1 + same feat · Legendary = X:1,Y:1,Z:2 + same feat.

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

## Accessory-Feat Aggregation (Slice 5)

Accessories carry a `feat_id` field (single background feat). When a Rare/Epic/Legendary accessory is equipped, its feat's stat bonuses apply **at read-time** inside `CombatantData.get_feat_stat_bonus()`.

**Rules:**
- Read-time only — do NOT push to `feat_ids` on equip; do NOT remove from `feat_ids` on unequip.
- Deduplication: if `accessory.feat_id` already appears in `feat_ids` (e.g. the character's background granted the same feat), the bonus counts **once** — a `Dictionary` seen-set prevents double-counting.
- COMMON accessories have empty `feat_id` — no feat contribution.

**`get_feat_stat_bonus()` (updated):**
```gdscript
func get_feat_stat_bonus(stat: String) -> int:
    var seen: Dictionary = {}
    var total: int = 0
    for id in feat_ids:
        if not seen.has(id):
            seen[id] = true
            total += FeatLibrary.get_feat(id).stat_bonuses.get(stat, 0)
    if accessory != null and accessory.feat_id != "":
        if not seen.has(accessory.feat_id):
            total += FeatLibrary.get_feat(accessory.feat_id).stat_bonuses.get(stat, 0)
    return total
```

This method is already called in all 7 derived stats (hp_max, energy_max, energy_regen, physical_defense, magic_defense, attack, and any speed-keyed future feats) — no call site changes needed.

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
| 2026-04-29 | **Accessory Tier Families — Slice 5.** 3 placeholder COMMON accessory rows replaced by 12 tiered entries across 3 families × 4 rarities. Tier ladder: Common = X:1 · Rare = X:1 + background feat · Epic = X:1,Y:1 + feat · Legendary = X:1,Y:1,Z:2 + feat. Families: Ring of Valor (STR/VIT/WIL, feat=combat_training), Scholar's Amulet (COG/WIL/VIT, feat=analytical_mind), Iron Bracers (VIT/STR/DEX, feat=hearty_constitution). `get_feat_stat_bonus()` updated to include accessory.feat_id at read-time with dedup. No on_equip/on_unequip changes — feat is never written to feat_ids. 5 new headless tests (test_accessory_feat.gd). Total: 36 equipment items. |
| 2026-04-29 | **Armor Tier Families — Slice 4.** 3 placeholder COMMON armor rows replaced by 12 tiered entries across 3 families × 4 rarities. Distribution rule: `physical_armor + magic_armor = 6` at Common. Tier ladder: Common = stats only · Rare = stats + base ability · Epic = stats +2/+2 + base ability · Legendary = Epic stats + upgraded ability. Families: Iron Plate (5/1, dexterity-1), Scale Mail (3/3), Mystic Robe (1/5). Armor abilities: `stone_guard`→`fortified_guard` (Iron Plate), `guard`→`enhanced_guard` (Scale Mail), `divine_ward`→`greater_ward` (Mystic Robe); `upgraded_id` wired on 3 existing base rows; 3 new upgraded abilities added to `abilities.csv`. No code changes — `on_equip`/`on_unequip` already handled armor. 7 new headless tests (`test_armor_equip.gd`). Totals: 66 abilities, 27 equipment items. |
| 2026-04-28 | **Weapon Tier Families — Slice 3.** 3 placeholder COMMON weapons replaced by 12 tiered entries across 3 families (STR/DEX/COG) × 4 rarities. `abilities.csv` gained 6 weapon abilities: `blade_strike`→`heavy_blade_strike` (STR), `quick_draw`→`aimed_draw` (DEX), `staff_bolt`→`empowered_bolt` (COG). `CombatantData.on_equip()` / `on_unequip()` added — manage `granted_ability_ids` in `ability_pool` without touching active slots. All equip/unequip call sites in `PartySheet`, `BadurgaManager`, `GameState.release_from_bench()` updated. `EquipmentLibrary.granted_ability_ids` parse fixed (`.assign()` not typed `Array()` ctor). 7 new headless tests (`test_weapon_equip.gd`). |
| 2026-04-28 | **Rarity Foundation — Slice 1.** `EquipmentData`: `Rarity` enum + `rarity: int` field + `granted_ability_ids: Array[String]` + `feat_id: String` + `RARITY_COLORS: Dictionary` (int keys 0–3 → grey/green/blue/orange) + `rarity_color() -> Color` helper. `EquipmentLibrary`: parses `rarity`, `granted_ability_ids` (pipe-split), `feat_id` from CSV; stub defaults COMMON / [] / "". Old 20-item CSV wiped; 9 COMMON placeholders added. UI color treatment across PartySheet, EndCombatScreen, MapManager Add Item modal. All `add_to_inventory` call sites updated with `"rarity"`. |
| 2026-04-27 | Kindred expansion (equipment 9→20; added war_hammer, twin_daggers, mages_staff, bone_club, hide_armor, silk_shroud, dragonscale_vest, swift_boots, scholars_ring, amulet_of_will, fang_necklace). First magic_armor equipment (`warded_robe`, `silk_shroud`, `dragonscale_vest`). `plate_cuirass` (heavy physical armor). |
| 2026-04-27 | **Dual armor.** `leather_armor` / `chain_mail` stat_bonuses column renamed `armor_defense` → `physical_armor`. All armor stat keys updated. `warded_robe` added (first `magic_armor` equipment). |
| 2026-04-24 | **Events Slice 4.** `rusted_dagger` added to equipment.csv (zero bonuses, WEAPON slot) for event reward use. |
