# System: Game State

> Last updated: 2026-04-19 (S19 — inventory field added; add_to_inventory() / remove_from_inventory() live; save/load/reset extended)

---

## Purpose

`GameState` is the **autoload singleton** for run-wide persistent data. It is the single source of truth for anything that needs to survive across scenes — party roster, equipment, currency, map progress, faction reputation.

**Current status: Active.** Map traversal, save/load, party roster, and inventory are live. Reputation and other Stage 2+ data are deferred.

---

## Core File

| File | Autoload Name | Role |
|------|--------------|------|
| `scripts/globals/GameState.gd` | `GameState` | Run-wide persistent data |

Registered as an autoload in `project.godot` so it is accessible from any script as `GameState`.

---

## Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `SAVE_PATH` | `"user://save.json"` | Godot user data directory — platform-resolved at runtime |

---

## Live Fields & Methods

### Map Progress

| Member | Type | Default | Description |
|--------|------|---------|-------------|
| `player_node_id` | `String` | `"badurga"` | The node the player is currently on |
| `visited_nodes` | `Array[String]` | `["badurga"]` | All nodes the player has been to this run |
| `map_seed` | `int` | `0` | RNG seed for `_build_edge_data()`. `0` = not yet seeded (fresh run). Lives here so `load_save()` can restore it before MapManager seeds its RNG. |
| `node_types` | `Dictionary` | `{}` | Maps node id → type string (e.g. `"COMBAT"`, `"BOSS"`, `"CITY"`). Populated by `MapManager._assign_node_types()` on first run; restored from save on subsequent loads. **Saved to disk.** |
| `pending_node_type` | `String` | `""` | Consumed by `NodeStub._ready()` on scene entry to know which stub to display. Set by `MapManager._enter_current_node()` for non-combat/non-city nodes. **NOT saved to disk.** |
| `current_combat_node_id` | `String` | `""` | Set by `MapManager._enter_current_node()` immediately before transitioning to `CombatScene3D`. Read by `EndCombatScreen._on_reward_chosen()` to know which node to append to `cleared_nodes`. **NOT saved to disk** (transient handoff, like `pending_node_type`). |
| `cleared_nodes` | `Array[String]` | `[]` | Nodes where the player completed combat AND collected a reward. Show a `✗` stamp on the map; traversable as pass-through. **Saved to disk.** |
| `threat_level` | `float` | `0.0` | Run-wide danger gauge. Range 0.0–1.0 (0%–100%). Incremented by MapManager on both travel (+0.05) and node entry (+0.05); capped at 1.0 via `minf()`. Reset to `0.0` by EndCombatScreen when a BOSS node is defeated. Displayed as a vertical bar in the map HUD. **Saved to disk.** |
| `party` | `Array[CombatantData]` | `[]` | Active party roster. index 0 = PC. Empty = not yet initialized (freshness check for `init_party()`). **Saved to disk.** |
| `run_summary` | `Dictionary` | `{}` | Snapshot of run stats written by `CombatManager3D._capture_run_summary()` immediately before a run-end transition. Keys: `pc_name`, `nodes_visited`, `nodes_cleared`, `threat_level`, `fallen_allies`. Read by `RunSummaryManager`. Cleared by `reset()`. **NOT saved to disk** — survives the scene transition only because GameState is an autoload. |
| `inventory` | `Array` | `[]` | Shared party bag. Holds raw reward dicts `{id, name, description, item_type}` for both equipment and consumables. `item_type` is used by the bag UI (Stage 2) to filter into tabs (All / Weapons / Armor / Accessories / Consumables). Nothing is auto-assigned on pickup — the player assigns from the bag manually. Cleared by `reset()`. **Saved to disk.** |

| Method | Signature | Description |
|--------|-----------|-------------|
| `move_player` | `(node_id: String) -> void` | Updates `player_node_id`; appends to `visited_nodes` if not already there |
| `is_visited` | `(node_id: String) -> bool` | Returns `true` if the node is in `visited_nodes` |
| `is_adjacent_to_player` | `(node_id: String, adjacency: Dictionary) -> bool` | Returns `true` if `node_id` is in the adjacency list for `player_node_id`. The `adjacency` dict is passed in from `MapManager` to keep `GameState` decoupled from map-building data. |
| `get_threat_level` | `() -> float` | Returns `threat_level`. Stub hookpoint for Feature 8 boss difficulty scaling — annotated with a comment pointing there. |
| `init_party` | `() -> void` | Seeds `party` with PC (RogueFinder/"Hero") + 2 allies (archer_bandit, grunt). Guard: no-ops if `party` is already populated — safe to call after `load_save()`. |
| `add_to_inventory` | `(item: Dictionary) -> void` | Appends the reward dict to the party bag. No routing — both equipment and consumables land here. |
| `remove_from_inventory` | `(item_id: String) -> bool` | Removes the first bag entry whose `id` matches `item_id`. Returns `true` if found and removed, `false` if not present. |

### Save / Load

| Method | Signature | Description |
|--------|-----------|-------------|
| `save` | `() -> void` | Serializes all persistent fields (including `party`) to `user://save.json` as indented JSON. Party members are written as plain dicts with equipment slots serialized as their `equipment_id` string. Called by: **MapManager** after travel increments, node entry, and `_assign_node_types()`; **EndCombatScreen** on reward selection; **CombatManager3D** on ally permadeath (`_on_unit_died()`), on victory write-back, and on run-end (defeat). |
| `load_save` | `() -> bool` | Reads and deserializes `user://save.json`. Returns `true` if a valid save was found and loaded, `false` on a fresh run or corrupt file. Called by **MapManager** at the start of `_ready()`, before any map data is built. Typed arrays are converted via `Array(raw, TYPE_STRING, "", null)`. Equipment slots resolve via `EquipmentLibrary.get_equipment(id)`; `""` id → `null` slot. |
| `delete_save` | `() -> void` | Removes `user://save.json` if it exists. Called by **MapManager**'s debug "Delete Save" button before resetting in-memory state. |
| `reset` | `() -> void` | Resets all in-memory fields to fresh-run defaults (`player_node_id = "badurga"`, `visited_nodes = ["badurga"]`, `map_seed = 0`, `node_types = {}`, `pending_node_type = ""`, `current_combat_node_id = ""`, `cleared_nodes = []`, `threat_level = 0.0`, `party = []`, `run_summary = {}`, `inventory = []`). Must be called alongside `delete_save()` when wiping a save mid-session. |

---

## Save File Contents

| Key | Corresponds to | Notes |
|-----|---------------|-------|
| `player_node_id` | `GameState.player_node_id` | String |
| `visited_nodes` | `GameState.visited_nodes` | JSON Array — typed back via `Array(..., TYPE_STRING, "", null)` on load |
| `map_seed` | `GameState.map_seed` | int — determines map topology for the run |
| `node_types` | `GameState.node_types` | JSON Object (id → type string) — values already strings from JSON, no conversion needed |
| `cleared_nodes` | `GameState.cleared_nodes` | JSON Array — typed back via `Array(raw, TYPE_STRING, "", null)` on load |
| `threat_level` | `GameState.threat_level` | float — read back via `float(parsed.get("threat_level", 0.0))` (no typed-array conversion needed) |
| `party` | `GameState.party` | JSON Array of dicts — each dict holds all scalar fields (including `kindred: String`) + `abilities`/`ability_pool` as string arrays + `weapon_id`/`armor_id`/`accessory_id` as strings. Deserialized back to `Array[CombatantData]` by `_deserialize_combatant()`. Missing `kindred` key (old saves) defaults to `"Unknown"`. |
| `inventory` | `GameState.inventory` | JSON Array of reward dicts `{id, name, description, item_type}`. Stored and loaded as-is — no resolution step needed. |

**What is saved now:** map position, visited nodes, map topology seed, node type assignments, cleared (completed) nodes, threat level, party roster (all CombatantData fields including persistent run state), inventory (equipment item ids).

Note: `pending_node_type` and `current_combat_node_id` are **not** saved — they are transient handoffs consumed within a single scene transition.

**Deferred (Stage 2+):** combat state, faction reputation.

---

## Dependencies

- **MapManager** reads and writes GameState for traversal (`move_player`, `is_visited`, `is_adjacent_to_player`); calls `init_party()` on fresh runs (after `load_save()` if `party.is_empty()`); increments `threat_level` by 0.05 (capped at 1.0) on every `_move_player_to()` call (travel increment) and again in `_enter_current_node()` for non-cleared nodes (entry increment); calls `save()` after each increment and after `_assign_node_types()`; calls `load_save()` at startup; calls `delete_save()` + `reset()` from the debug button; sets `pending_node_type` before transitioning to NodeStub; sets `current_combat_node_id` before transitioning to CombatScene3D; reads `cleared_nodes` in `_refresh_all_node_visuals()` and `_on_node_clicked()`; reads `threat_level` in `_add_threat_meter()` to render the HUD bar.
- **NodeStub** reads and clears `GameState.pending_node_type` in `_ready()`
- **EndCombatScreen** reads `current_combat_node_id` and appends to `cleared_nodes` immediately on reward selection; resets `threat_level = 0.0` if the defeated node was a BOSS; calls `GameState.save()` then returns to map. Calls `GameState.add_to_inventory(item)` via `has_method()` guard — method is live, reward dict lands in the party bag on every pickup.

---

## Signals Emitted

None currently.

---

## Planned Responsibilities (Stage 2+)

| Data | Type | Notes |
|------|------|-------|
| Faction reputation | `Dictionary` | Per-faction standing |
| Currency / resources | `int` | TBD |
| Run flags | `Dictionary` | Misc boolean state |

---

## Notes

- The singleton pattern was chosen so that any scene in the game can access run state without manual node references or signal chains up the tree.
- Do not put **combat-local** state here (selected unit, current turn, etc.) — that belongs in CombatManager. GameState is for data that persists between combat encounters.
- The `adjacency` dict is intentionally passed into `is_adjacent_to_player()` from `MapManager` — GameState should not import or own map topology data.
- `map_seed` lives in GameState (not MapManager) so `load_save()` can restore it before MapManager calls `seed()` in `_build_edge_data()`. MapManager generates the seed on a fresh run (`randi()`) and writes it to `GameState.map_seed` — GameState never generates it.
- **Typed-array conversion:** `JSON.parse_string()` returns untyped `Array`. Any `Array[T]` field must be converted back with `Array(raw, TYPE_*, "", null)` when reading from the save. `inventory` is intentionally an untyped `Array` (holds mixed reward dicts) — no conversion needed; just guard each entry with `if entry is Dictionary` on load.
- **`save()` has no null guard on `FileAccess.open()`** — if `user://` is unwritable (rare on desktop, possible on some platforms), it will crash. Add a null check before `file.store_string()` if this becomes an issue in future platform targets.
- **Field defaults are fresh-run values only** — `player_node_id = "badurga"` and `visited_nodes = ["badurga"]` are the GDScript initializers. On any run with a valid save file, `load_save()` overwrites them before anything reads them. Do not rely on these defaults in code that runs after `MapManager._ready()`.
- **GameState persists across `change_scene_to_file()` calls** — as an autoload it is never freed. In-memory fields survive scene transitions without saving; `save()` is called explicitly to persist to disk.
- **`load_save()` does NOT reset fields on a missing file** — it returns `false` immediately if `user://save.json` doesn't exist, leaving all in-memory fields unchanged. This means calling `delete_save()` alone before a scene reload is NOT enough for a clean fresh-run state in a live session; you must also call `reset()` to clear the in-memory fields. If you only delete the file, the player marker and visited state persist in memory for the remainder of the session.
- **`_serialize_combatant()` / `_deserialize_combatant()`** — private helpers that convert a `CombatantData` to/from a plain Dictionary for JSON. Equipment slots (which are `EquipmentData` resources) serialize as their `equipment_id: String`; on deserialize, `EquipmentLibrary.get_equipment(id)` resolves back to the item. Empty string id → `null` slot (no equipment). If a save contains an unknown equipment id, the stub returned by `get_equipment()` is kept — slots are never silently dropped. These methods are the only place where `CombatantData` ↔ JSON translation lives; extend them (not `save()`/`load_save()`) when new fields are added to `CombatantData`. **`kindred`** is serialized as a plain string; old saves without the key deserialize to `"Unknown"` via `.get("kindred", "Unknown")`.
