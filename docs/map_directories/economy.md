# Economy System

> Covers gold generation, pricing, vendor data layer, and stock manifest generation. Vendor UI (VendorScene) is Slice 5 and not yet built.

---

## Systems in This Bucket

| System | Status |
|--------|--------|
| RewardGenerator — `gold_drop()` | ✅ Active (Vendor Slice 1) |
| PricingFormula — `price_for()` | ✅ Active (Vendor Slice 2) |
| VendorLibrary / VendorData | ✅ Active (Vendor Slice 3 — data layer only; no UI yet) |
| StockGenerator — `roll_stock()` | ✅ Active (Vendor Slice 4) |
| GameState.vendor_stocks + regen | ✅ Active (Vendor Slice 4) |
| VendorScene (map VENDOR node UI) | ⏳ Deferred (Vendor Slice 5) |

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

Rarity → base price map (COMMON 10, RARE 40, EPIC 120, LEGENDARY 400). Applies ±10% jitter via caller-supplied `rng`. Returns clamped int ≥ 1. Caller supplies the RNG so vendor stock generation can be deterministic from a seed.

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
| `tests/test_vendor_stock.gd/.tscn` | 7 | determinism; seed variance; category filter; mixed pool coverage; stock count; sold-flag JSON round-trip; regen WORLD-only |

---

## Recent Changes

| Date | Change |
|------|--------|
| 2026-04-30 | **Vendor Slice 4 — Stock Manifest + Persistence.** `StockGenerator.gd` (new — `roll_stock(vendor, seed_int)`; seeded Fisher-Yates; category filter; PricingFormula per entry). `RewardGenerator._eq_to_dict/_con_to_dict` renamed to public `eq_to_dict/con_to_dict`. `GameState.vendor_stocks: Dictionary` added (CITY keyed by vendor_id, WORLD keyed by node_id; save/load/reset wired; `regen_world_vendor_stocks()` method added). `MapManager._generate_vendor_stocks()` populates all stocks on map-gen (no-op if already present — handles old-save migration). 7 headless tests. |
| 2026-04-30 | **Vendor Slice 3 — VendorLibrary.** `VendorData.gd`, `vendors.csv` (7 seed rows), `VendorLibrary.gd` (BackgroundLibrary shape; `vendors_by_scope()` added). 17 headless tests. |
| 2026-04-29 | **Vendor Slice 2 — PricingFormula.** `PricingFormula.price_for(item, rng)` — rarity base × jitter, caller-supplied RNG. |
| 2026-04-29 | **Vendor Slice 1 — Currency Reward Channel.** `RewardGenerator.gold_drop()`, `GameState.current_combat_ring`, `EndCombatScreen` gold line. |

---

## StockGenerator

**File:** `rogue-finder/scripts/globals/StockGenerator.gd`

```gdscript
static func roll_stock(vendor: VendorData, seed_int: int) -> Array
```

Pre-rolls a vendor's stock manifest from a deterministic seeded RNG. Returns an Array of `{ vendor_id: String, item: Dictionary, price: int, sold: bool }` entries. The `item` dict has the same `{ id, name, description, item_type, rarity }` shape as `RewardGenerator` reward items. Filters `EquipmentLibrary.all_equipment()` + `ConsumableLibrary.all_consumables()` to entries whose slot/type is in `vendor.category_pool`. Shuffles with seeded Fisher-Yates, then calls `PricingFormula.price_for()` with the same RNG for deterministic pricing.

Category mapping: `"weapon"`, `"armor"`, `"accessory"` match equipment slot lowercased; `"consumable"` matches all consumables.

Called by `MapManager._generate_vendor_stocks()` (map-gen time) and `GameState.regen_world_vendor_stocks()` (future map-reset).

---

## GameState.vendor_stocks

**Field:** `GameState.vendor_stocks: Dictionary`  
**Saved to disk:** yes (key `"vendor_stocks"`).

Keyed by instance_key:
- **CITY vendors:** `vendor_id` (e.g. `"vendor_weapon"`) — seeded with `hash(str(map_seed) + "::" + vendor_id)`
- **WORLD vendors:** `node_id` (e.g. `"node_o3"`) — vendor picked via `hash(str(map_seed) + node_id) % world_vendors.size()`; seeded with `hash(str(map_seed) + "::" + node_id)`

Each value is an Array of stock entries (same shape as `roll_stock` output). Populated once by `MapManager._generate_vendor_stocks()` on the first map load of a run. Never re-rolled mid-run unless `regen_world_vendor_stocks()` is called.

**`GameState.regen_world_vendor_stocks() -> void`:** Regenerates ONLY the WORLD-vendor entries (nodes in `node_types == "VENDOR"`). CITY entries are untouched. Future trigger: every 3 boss wins. Not yet wired.

---

## Dependencies

```
StockGenerator (static)
  ├── EquipmentLibrary  (all_equipment() — filtered by category)
  ├── ConsumableLibrary (all_consumables() — if "consumable" in pool)
  ├── PricingFormula    (price_for(item, rng))
  └── RewardGenerator   (eq_to_dict / con_to_dict — shared item dict shape)

MapManager._generate_vendor_stocks()
  ├── VendorLibrary     (vendors_by_scope("CITY") + vendors_by_scope("WORLD"))
  ├── StockGenerator    (roll_stock)
  └── GameState.vendor_stocks  ← writes; calls save()

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
