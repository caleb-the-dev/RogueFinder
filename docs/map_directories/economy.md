# Economy System

> Covers gold generation, pricing, and the vendor data layer. Vendor UI (VendorScene) is Slice 4 and not yet built.

---

## Systems in This Bucket

| System | Status |
|--------|--------|
| RewardGenerator — `gold_drop()` | ✅ Active (Vendor Slice 1) |
| PricingFormula — `price_for()` | ✅ Active (Vendor Slice 2) |
| VendorLibrary / VendorData | ✅ Active (Vendor Slice 3 — data layer only; no UI yet) |
| VendorScene (map VENDOR node UI) | ⏳ Deferred (Vendor Slice 4) |

---

## Gold Drop Formula

**File:** `rogue-finder/scripts/globals/RewardGenerator.gd`

```
gold = (RING_BASE[ring] + 0.15 * threat + 3.0 * avg_level) * randf_range(0.9, 1.1)
```
Clamped to ≥ 1. RING_BASE: `outer=30`, `middle=20`, `inner=12`.

Called by `CombatManager3D._calc_gold_reward()` after combat victory. Result added to `GameState.gold` before save; amount forwarded to `EndCombatScreen.show_victory(items, gold)`.

`GameState.current_combat_ring: String = ""` is set by `MapManager._enter_current_node()` via `_get_ring()` on COMBAT/BOSS entry. Transient — NOT serialized.

---

## Pricing Formula

**File:** `rogue-finder/scripts/globals/PricingFormula.gd`

```
static func price_for(item: Dictionary, rng: RandomNumberGenerator) -> int
```

Rarity → base price map (COMMON 10, RARE 25, EPIC 60, LEGENDARY 150). Applies ±20% jitter via caller-supplied `rng`. Returns clamped int ≥ 1. Caller supplies the RNG so vendor stock generation can be deterministic from a seed.

---

## VendorData Resource

**File:** `rogue-finder/resources/VendorData.gd`

```gdscript
@export var vendor_id:       String        = ""
@export var display_name:    String        = ""
@export var flavor:          String        = ""
@export var category_pool:   Array[String] = []  # "weapon" | "armor" | "accessory" | "consumable"
@export var stock_count:     int           = 4
@export var scope:           String        = "WORLD"  # "CITY" or "WORLD"
```

`category_pool` drives which EquipmentLibrary/ConsumableLibrary buckets VendorScene samples from. `scope` controls where a vendor appears — `"CITY"` vendors are inside Badurga shop sections; `"WORLD"` vendors appear on map VENDOR nodes.

---

## VendorLibrary

**File:** `rogue-finder/scripts/globals/VendorLibrary.gd`  
**Data:** `rogue-finder/data/vendors.csv`

Mirrors BackgroundLibrary shape exactly: lazy cache, never-null get, reload().

### Public API

| Method | Returns | Notes |
|--------|---------|-------|
| `get_vendor(id)` | `VendorData` | Stub (id="unknown", scope="WORLD", empty pool) on unknown id — never null |
| `all_vendors()` | `Array[VendorData]` | All 7 seed vendors |
| `vendors_by_scope(scope)` | `Array[VendorData]` | Primary entry for Slice 4 — pass `"CITY"` or `"WORLD"` |
| `reload()` | `void` | Clears cache and re-parses; dev/test helper |

### Seed Data (vendors.csv — 7 rows)

| vendor_id | display_name | scope | categories | stock |
|-----------|--------------|-------|------------|-------|
| vendor_weapon | Ironmonger's Stall | CITY | weapon | 5 |
| vendor_armor | Seamstress & Leatherworks | CITY | armor | 5 |
| vendor_accessory | The Curio Dealer | CITY | accessory | 5 |
| vendor_consumable | Herbalist's Cart | CITY | consumable | 6 |
| road_peddler | Road Peddler | WORLD | weapon\|armor\|accessory\|consumable | 4 |
| wandering_quartermaster | Wandering Quartermaster | WORLD | weapon\|armor | 4 |
| apothecary_caravan | Apothecary Caravan | WORLD | consumable\|accessory | 5 |

---

## Tests

| File | Count | Notes |
|------|-------|-------|
| `tests/test_gold_reward.gd/.tscn` | 7 | gold_drop formula, ring scaling, jitter bounds |
| `tests/test_vendor_library.gd/.tscn` | 17 | all 7 vendors load; single + pipe category_pool; stub not null; scope filters; reload |

---

## Recent Changes

| Date | Change |
|------|--------|
| 2026-04-30 | **Vendor Slice 3 — VendorLibrary.** `VendorData.gd`, `vendors.csv` (7 seed rows), `VendorLibrary.gd` (BackgroundLibrary shape; `vendors_by_scope()` added). 17 headless tests. |
| 2026-04-29 | **Vendor Slice 2 — PricingFormula.** `PricingFormula.price_for(item, rng)` — rarity base × jitter, caller-supplied RNG. |
| 2026-04-29 | **Vendor Slice 1 — Currency Reward Channel.** `RewardGenerator.gold_drop()`, `GameState.current_combat_ring`, `EndCombatScreen` gold line. |

---

## Dependencies

```
VendorLibrary (static)
  └── vendors.csv   ← data source

PricingFormula (static)
  └── (no deps — caller supplies item dict + RNG)

RewardGenerator
  └── GameState.current_combat_ring  (transient, set by MapManager)

CombatManager3D
  └── RewardGenerator.gold_drop()
  └── EndCombatScreen.show_victory(items, gold)

MapManager
  └── GameState.current_combat_ring  ← sets on COMBAT/BOSS entry
```
