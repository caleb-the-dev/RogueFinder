# System: UI Overlays

> Last updated: 2026-04-30 (Vendor Slice 6 — VendorOverlay wired to map nodes + Badurga; blocks_pause group)

Covers standalone modal overlays that don't belong to a single game system bucket. Combat HUD (UnitInfoBar, StatPanel, CombatActionPanel, EndCombatScreen) is documented in `hud_system.md`. PartySheet is in `party_sheet.md`. Hire Roster is in `map_scene.md`.

---

## VendorOverlay

**Files:**
- `rogue-finder/scripts/ui/VendorOverlay.gd` (`class_name VendorOverlay`)
- `rogue-finder/scenes/ui/VendorOverlay.tscn`

**Layer:** 20 (matches Hire Roster, above map/combat, below Pause Menu layer 26).

Modal shop overlay. Caller instantiates from the scene, adds as a child, then calls `show_vendor()`. Closes on the ✕ button, ESC, or emits `closed` and frees itself either way.

### Public API

| Method / Signal | Signature | Notes |
|---|---|---|
| `show_vendor` | `(instance_key: String) -> void` | Pulls `GameState.vendor_stocks[instance_key]`; derives `VendorData` from the first entry's `vendor_id` |
| `closed` | signal | Emitted on close before `queue_free()` |
| `try_buy` | `static (entry: Dictionary) -> bool` | Validates gold ≥ price and not already sold; debits gold, flips `sold`, calls `add_to_inventory`, saves; returns false on rejection — pure data logic, no UI side effects |

### try_buy Details

```gdscript
static func try_buy(entry: Dictionary) -> bool
```

- **Rejects** if `entry["sold"] == true` or `GameState.gold < entry["price"]` — returns `false`, state untouched.
- **On success:** `GameState.gold -= price`, `entry["sold"] = true`, `GameState.add_to_inventory(entry["item"].duplicate())`, `GameState.save()` — returns `true`.
- The `.duplicate()` on `item` prevents `add_to_inventory`'s `item["seen"] = false` from leaking back into the vendor_stocks manifest.
- Static so headless tests can call `VendorOverlay.try_buy(entry)` without instantiating the scene.

### Stock Row Layout

Each row: `[item name (rarity-colored)] [stat summary] [price in gold] [Buy button / SOLD label]`

- **Item name:** colored by `EquipmentData.RARITY_COLORS[entry.item.rarity]`; grey `Color(0.40, 0.38, 0.35)` when sold.
- **Stat summary:** for equipment, `stat_bonuses` formatted as `"STR +1  VIT +2"`; for consumables, item description.
- **Price:** `Color(0.90, 0.80, 0.30)` gold color; grey when sold.
- **Buy button:** disabled when `GameState.gold < price`; replaced by "SOLD" label after purchase.

After a buy: `_refresh_gold()` updates the header readout; `_rebuild_stock_rows()` rebuilds all rows (reflects disable states for remaining items the player can no longer afford).

### Usage Pattern

```gdscript
var overlay: VendorOverlay = preload("res://scenes/ui/VendorOverlay.tscn").instantiate()
add_child(overlay)
overlay.show_vendor(instance_key)   # "vendor_weapon" for CITY; node_id for WORLD
overlay.closed.connect(_on_vendor_closed)
```

**MapManager** instantiates fresh per VENDOR node visit, tracks it as `_vendor_overlay`, and connects `closed` to mark the node cleared + save. **BadurgaManager** calls `_open_vendor_stall(vendor_id)` for each of the 4 vendor stall buttons (no-op needed on close — Badurga scene stays live underneath).

### Gotchas

- **Overlay frees itself on close** — `_on_close()` calls `queue_free()`. The caller must re-instantiate for a second open; it cannot call `show_vendor()` again on the same instance after closing. Slice 6 should create a fresh instance each time the vendor node is entered.
- **`try_buy` modifies the entry dict in-place** — `entry["sold"] = true` mutates the Dictionary stored in `GameState.vendor_stocks`. This is intentional — the sold state persists across reopens without additional save plumbing. Do not pass a copy to `try_buy`.
- **Closed emitted before `queue_free()`** — the `closed` signal fires while the overlay is still alive. Signal handlers can safely read overlay state; they must not `queue_free()` it again.
- **Empty stock key** — if `instance_key` is not in `GameState.vendor_stocks`, `_stock` will be `[]` and the overlay shows "No stock available." with the VendorLibrary stub name. `MapManager._generate_vendor_stocks()` is additive and runs on every map load, so this should not occur in normal play.
- **blocks_pause group** — `VendorOverlay` joins the `"blocks_pause"` group on `_ready()`. While any member of this group is visible, `PauseMenuManager` hides the ☰ button and ignores ESC, preventing the pause menu from bleeding over the shop overlay.

### Dependencies

```
VendorOverlay
  ├── GameState           (vendor_stocks, gold, add_to_inventory, save)
  ├── VendorLibrary       (get_vendor — display_name + flavor for header)
  ├── EquipmentLibrary    (get_equipment — stat_bonuses + description for row summary)
  └── EquipmentData       (RARITY_COLORS, Rarity enum)
```

---

## Tests

| File | Count | Notes |
|------|-------|-------|
| `tests/test_vendor_buy.gd/.tscn` | 6 | gold debit; rarity preserved in inventory; sold-flag flip; insufficient-gold rejection; already-sold rejection; save round-trip |

---

## Recent Changes

| Date | Change |
|------|--------|
| 2026-04-30 | **Vendor Slice 6 — Wire-up.** VendorOverlay wired to map VENDOR nodes (MapManager `_enter_current_node` VENDOR branch; `_vendor_overlay` ref; clears node on close) and all 4 Badurga stalls (`_open_vendor_stall`). Dev test button removed. `add_to_group("blocks_pause")` added — PauseMenuManager hides ☰ and skips ESC while overlay is visible. |
| 2026-04-30 | **Vendor Slice 5 — VendorOverlay.** `VendorOverlay.gd` + `VendorOverlay.tscn` (layer 20 modal). `show_vendor(instance_key)` API. `try_buy(entry)` static transaction method. Scrollable stock rows with rarity colors, stat summary, gold price, Buy/SOLD states. Dev test button in MapManager. 6 headless tests. |
