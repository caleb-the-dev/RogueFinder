# System: Game State

> Last updated: 2026-04-28 (Pause Menu — encountered_archetypes field + record_archetype() + SettingsStore autoload)

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
| `XP_THRESHOLDS` | `[20, 35, 55, 80]` | XP needed to advance from level N to N+1 for the first 4 levels. Beyond index 3, the formula `level × 20` is used. |
| `BENCH_CAP` | `9` | Maximum number of followers that can sit on the bench at once. |

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
| `used_event_ids` | `Array[String]` | `[]` | Event ids already drawn this run. Appended to by `EventSelector.pick_for_node()` whenever an EVENT node is entered. Used to filter the candidate pool so the same event doesn't repeat until all ring events are exhausted. **Saved to disk.** |
| `party` | `Array[CombatantData]` | `[]` | Active party roster. index 0 = PC. Empty = not yet initialized (freshness check for `init_party()`). **Saved to disk.** |
| `test_room_mode` | `bool` | `false` | Transient flag — set by MapManager dev panel test-room buttons before transitioning to CombatScene3D. `CombatManager3D._setup_units()` reads it to spawn hardcoded test combatants instead of `GameState.party`. Cleared by `_end_combat()` on combat exit. **NOT saved to disk — never serialized.** |
| `test_room_kind` | `String` | `"armor_showcase"` | Picks which scenario `CombatManager3D._setup_test_room_units()` spawns. Valid values: `"armor_showcase"` (original dual-armor demo), `"armor_mod"` (stone_guard + divine_ward demo), and `"recruit_test"` (RogueFinder + 2 allies vs 3 one-HP weaklings for recruit QTE testing). Set by the matching dev menu button alongside `test_room_mode`. Reset to `"armor_showcase"` by `_end_combat()`. **NOT saved to disk.** |
| `run_summary` | `Dictionary` | `{}` | Snapshot of run stats written by `CombatManager3D._capture_run_summary()` immediately before a run-end transition. Keys: `pc_name`, `nodes_visited`, `nodes_cleared`, `threat_level`, `fallen_allies`. Read by `RunSummaryManager`. Cleared by `reset()`. **NOT saved to disk** — survives the scene transition only because GameState is an autoload. |
| `inventory` | `Array` | `[]` | Shared party bag. Holds raw reward dicts `{id, name, description, item_type, seen}` for both equipment and consumables. `item_type` is used by the bag UI (Stage 2) to filter into tabs. `seen: bool` drives the new-item glow in PartySheet — `add_to_inventory()` always stamps `false`; PartySheet sets it `true` on hover. Old saves without the `seen` key default to `true` via `.get("seen", true)` (no spurious glow on upgrade). Nothing is auto-assigned on pickup. Cleared by `reset()`. **Saved to disk.** |
| `bench` | `Array[CombatantData]` | `[]` | Follower bench — `CombatantData` instances recruited via the combat Recruit action. Capped at `BENCH_CAP = 9`. **Saved to disk** (serialized alongside `party`). Cleared by `reset()`. |
| `gold` | `int` | `0` | Player's current gold. Spent in the Hire Roster overlay (`BadurgaManager`). **Saved to disk** under key `"gold"`. Read back with `int(parsed.get("gold", 0))` — old saves default to `0`. Reset to `0` by `reset()`. |
| `encountered_archetypes` | `Array[String]` | `[]` | Archetype ids seen in combat or recruited this run. Populated by `record_archetype()`. Drives the Archetypes Log in the pause menu. **Saved to disk** under key `"encountered_archetypes"`. Old saves default to `[]`. Reset by `reset()`. |

| Method | Signature | Description |
|--------|-----------|-------------|
| `move_player` | `(node_id: String) -> void` | Updates `player_node_id`; appends to `visited_nodes` if not already there |
| `is_visited` | `(node_id: String) -> bool` | Returns `true` if the node is in `visited_nodes` |
| `is_adjacent_to_player` | `(node_id: String, adjacency: Dictionary) -> bool` | Returns `true` if `node_id` is in the adjacency list for `player_node_id`. The `adjacency` dict is passed in from `MapManager` to keep `GameState` decoupled from map-building data. |
| `get_threat_level` | `() -> float` | Returns `threat_level`. Stub hookpoint for Feature 8 boss difficulty scaling — annotated with a comment pointing there. |
| `init_party` | `() -> void` | **Safety fallback only** — seeds `party` with a single default PC (RogueFinder/"Hero"). Guard: no-ops if `party` is already populated. On the new-run path, `CharacterCreationManager._on_confirm()` appends the real PC before `MapManager._ready()` fires, so the guard triggers immediately and `init_party()` is a no-op. Only executes substantively if the game somehow reaches `MapScene` with an empty party (e.g., skipping the creation scene in dev). |
| `add_to_inventory` | `(item: Dictionary) -> void` | Stamps `item["seen"] = false` on the dict, then appends to the party bag. Always marks new — even unequipped items returning to the bag will glow until hovered. No routing — both equipment and consumables land here. |
| `remove_from_inventory` | `(item_id: String) -> bool` | Removes the first bag entry whose `id` matches `item_id`. Returns `true` if found and removed, `false` if not present. |
| `add_to_bench` | `(follower: CombatantData) -> bool` | Appends `follower` to `bench` if `bench.size() < BENCH_CAP`. Returns `true` on success, `false` if bench is full. Does **not** call `save()` — caller must save explicitly after successful insert. |
| `release_from_bench` | `(index: int) -> void` | Removes `bench[index]`. Auto-deequips all three gear slots (weapon/armor/accessory) back to `GameState.inventory` before removing. Calls `save()`. No-op on out-of-bounds index. |
| `swap_active_bench` | `(party_idx: int, bench_idx: int) -> void` | Swaps `party[party_idx]` with `bench[bench_idx]` in-place. Gear deequip is the **caller's responsibility** — `BadurgaManager` calls `_deequip_to_bag()` before this. No-op on out-of-bounds indices. Does **not** call `save()` — caller must save. |
| `record_archetype` | `(id: String) -> void` | Appends `id` to `encountered_archetypes` if non-empty and not already present. Calls `save()`. Called by `CombatManager3D._setup_units()` for each enemy at combat start (encounter recorded even if the player flees). TODO comment marks the recruit site for future wiring. |
| `grant_feat` | `(pc_index: int, feat_id: String) -> void` | Appends `feat_id` to `party[pc_index].feat_ids` if not already present (deduplicates). Calls `save()` immediately. `push_error` + no-op on invalid index. The canonical way to add feats during a run — `EventManager.dispatch_effect` routes `feat_grant` effects here. |
| `xp_needed_for_next_level` | `(current_level: int) -> int` | Returns the XP threshold to advance from `current_level` to `current_level + 1`. Uses `XP_THRESHOLDS` for levels 1–4; `current_level × 20` for level 5+. |
| `grant_xp` | `(amount: int) -> void` | Awards `amount` XP to every non-dead party member. For each member, while XP ≥ threshold and level < 20: subtracts threshold XP, increments `level`, increments `pending_level_ups`. Calls `save()` once after all members are processed. Called by `CombatManager3D._end_combat(true)` with `amount = 15` on every combat victory. |
| `sample_ability_candidates` | `static (pc: CombatantData, count: int) -> Array[String]` | Returns up to `count` ability IDs the character can learn. Draws from `class.ability_pool + kindred.ability_pool`, deduplicates, excludes IDs already in `pc.ability_pool` (owned), shuffles, then slices to `count`. Returns fewer than `count` if the combined pool is exhausted. |
| `sample_feat_candidates` | `static (pc: CombatantData, count: int) -> Array[String]` | Returns up to `count` feat IDs the character can learn. Draws from `class.feat_pool + background.feat_pool`, deduplicates, excludes IDs already in `pc.feat_ids`, shuffles, slices to `count`. |

### Save / Load

| Method | Signature | Description |
|--------|-----------|-------------|
| `save` | `() -> void` | Serializes all persistent fields (including `party`) to `user://save.json` as indented JSON. Party members are written as plain dicts with equipment slots serialized as their `equipment_id` string. Called by: **MapManager** after travel increments, node entry, and `_assign_node_types()`; **EndCombatScreen** on reward selection; **CombatManager3D** on ally permadeath (`_on_unit_died()`), on victory write-back, and on run-end (defeat). |
| `load_save` | `() -> bool` | Reads and deserializes `user://save.json`. Returns `true` if a valid save was found and loaded, `false` on a fresh run or corrupt file. Called by **MapManager** at the start of `_ready()`, before any map data is built. Typed arrays are converted via `Array(raw, TYPE_STRING, "", null)`. Equipment slots resolve via `EquipmentLibrary.get_equipment(id)`; `""` id → `null` slot. |
| `delete_save` | `() -> void` | Removes `user://save.json` if it exists. Called by **MapManager**'s debug "Delete Save" button before resetting in-memory state. |
| `reset` | `() -> void` | Resets all in-memory fields to fresh-run defaults (`player_node_id = "badurga"`, `visited_nodes = ["badurga"]`, `map_seed = 0`, `node_types = {}`, `pending_node_type = ""`, `current_combat_node_id = ""`, `cleared_nodes = []`, `threat_level = 0.0`, `used_event_ids = []`, `party = []`, `bench = []`, `run_summary = {}`, `inventory = []`, `gold = 0`). Must be called alongside `delete_save()` when wiping a save mid-session. |

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
| `used_event_ids` | `GameState.used_event_ids` | JSON Array — typed back via `Array(raw, TYPE_STRING, "", null)` on load; defaults to `[]` if key absent (old saves) |
| `encountered_archetypes` | `GameState.encountered_archetypes` | JSON Array — typed back via `Array(raw, TYPE_STRING, "", null)`; defaults to `[]` on old saves |
| `party` | `GameState.party` | JSON Array of dicts — each dict holds all scalar fields + `abilities`/`ability_pool` as string arrays + `feat_ids` as string array + `level`/`xp`/`pending_level_ups` as ints + `physical_armor`/`magic_armor` as ints + `weapon_id`/`armor_id`/`accessory_id` as strings + `temperament_id` as string. Deserialized back to `Array[CombatantData]` by `_deserialize_combatant()`. **Migrations:** old saves with `armor_defense` key → both armor lanes. Missing `level`/`xp`/`pending_level_ups` default to `1`/`0`/`0`. Missing `temperament_id` defaults to `"even"` (neutral). |
| `bench` | `GameState.bench` | JSON Array using the same `_serialize_combatant()` / `_deserialize_combatant()` format as `party`. Loaded back via the same deserialization path with `bench.clear()` + append loop. Old saves without the `bench` key default to an empty bench (no crash). |
| `inventory` | `GameState.inventory` | JSON Array of reward dicts `{id, name, description, item_type, seen}`. Stored and loaded as-is — no resolution step needed. `seen` persists naturally in JSON; old saves without the key read as `true` via `.get("seen", true)`. |
| `gold` | `GameState.gold` | `int`. Read back as `int(parsed.get("gold", 0))` — old saves without the key default to `0`. |

**What is saved now:** map position, visited nodes, map topology seed, node type assignments, cleared (completed) nodes, threat level, used event ids, **encountered archetypes**, party roster, **bench roster** (all CombatantData fields, same format as party), inventory, **gold**.

Note: `pending_node_type` and `current_combat_node_id` are **not** saved — they are transient handoffs consumed within a single scene transition.

**Deferred (Stage 2+):** combat state, faction reputation.

---

## Dependencies

- **CharacterCreationManager** appends the newly built PC to `GameState.party` in `_on_confirm()` before transitioning to MapScene. This is the primary populator of `party` on a new run; `init_party()` acts as a fallback guard only.
- **EventSelector** appends to `used_event_ids` in `pick_for_node()`. Does not call `save()` — MapManager owns persistence.
- **EventManager** (static methods) reads `GameState.party`, `GameState.inventory`, and `GameState.threat_level` during effect dispatch. Calls `GameState.add_to_inventory()` / `remove_from_inventory()`. The instance's `_on_continue_pressed()` calls `GameState.save()` before emitting `event_finished`.
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
- **`_serialize_combatant()` / `_deserialize_combatant()`** — private helpers that convert a `CombatantData` to/from a plain Dictionary for JSON. Equipment slots serialize as their `equipment_id: String`; on deserialize, `EquipmentLibrary.get_equipment(id)` resolves back to the item. These methods are the only place where `CombatantData` ↔ JSON translation lives; extend them (not `save()`/`load_save()`) when new fields are added to `CombatantData`. **`feat_ids`** is written as `Array(d.feat_ids)` (untyped for JSON); on load it is converted back with `Array(raw, TYPE_STRING, "", null)`. **Save migration:** if the save dict has `feat_ids`, it is used directly; otherwise, `kindred_feat_id` (string) and `feats` (array) are merged into `feat_ids` deduplicated. This preserves all feats from saves that predate the unified format.
- **`sample_ability_candidates()` / `sample_feat_candidates()` are static** — they take a `CombatantData` and count, returning a shuffled, deduplicated slice of the draw pool minus already-owned. Can be called headlessly (no autoload context needed). They do NOT call `save()`.
- **`grant_xp()` increments level and pending simultaneously** — all level crossings in a single XP batch are resolved in one `while` loop before `save()` is called. If a PC jumps multiple levels, `pending_level_ups` accumulates accordingly. The `PartySheet` presents the pending picks back-to-back in a single overlay session.

---

## Recent Changes

| Date | Change |
|---|---|
| 2026-04-28 | **Follower Slice 6 — City Hire Channel: gold field.** `gold: int = 0` added to `GameState`. Wired into `save()` (key `"gold"`), `load_save()` (`int(parsed.get("gold", 0))` — old saves default 0), and `reset()` (`gold = 0`). `BadurgaManager._on_hire_pressed()` deducts `gold` on hire and restores it on Cancel. MapManager dev menu "Give Gold +100" button calls `GameState.gold += 100; GameState.save()`. |
| 2026-04-28 | **Follower Slice 4 — bench persistence + release + swap.** `bench` now saved to disk (serialized via `_serialize_combatant()` under key `"bench"`; deserialized on load with `bench.clear()` + append loop; `reset()` clears bench). `release_from_bench(index)` added: auto-deequips weapon/armor/accessory back to inventory, then removes the entry and calls `save()`. `swap_active_bench(party_idx, bench_idx)` added: in-place swap of `party[party_idx]` and `bench[bench_idx]`; gear deequip is caller's responsibility. `add_to_bench()` stub comment updated — no longer deferred. `test_room_kind` valid values extended to include `"recruit_test"`. |
| 2026-04-28 | **Follower bench stub (Slice 3).** `BENCH_CAP: int = 9` constant added. `bench: Array[CombatantData]` field added (not yet saved). `add_to_bench(follower) -> bool` method added. |
| 2026-04-27 | **Temperament serialization.** `_serialize_combatant()` now writes `temperament_id: String`. `_deserialize_combatant()` reads it with `dict.get("temperament_id", "even")` — old saves default to neutral `"even"`. |
| 2026-04-27 | **Dual armor serialization + test_room_mode.** `_serialize_combatant()` now writes `physical_armor` + `magic_armor` instead of `armor_defense`. `_deserialize_combatant()` reads new keys; if absent (old save), migrates: both lanes = old `armor_defense` value. `test_room_mode: bool = false` transient field added — NOT serialized; set by dev menu, cleared by `CombatManager3D._end_combat()`. |
| 2026-04-27 | **XP + Level-Up system.** `XP_THRESHOLDS: Array[int] = [20, 35, 55, 80]` constant added. New methods: `xp_needed_for_next_level(level)`, `grant_xp(amount)`, `sample_ability_candidates(pc, count)` (static), `sample_feat_candidates(pc, count)` (static). `_serialize_combatant()` + `_deserialize_combatant()` extended with `level`, `xp`, `pending_level_ups` fields. Old saves default: `level=1, xp=0, pending_level_ups=0`. `grant_xp()` also called by `CombatManager3D._end_combat(true)` with `amount=15` on every win. `GameState` now depends on `ClassLibrary`, `KindredLibrary`, and `BackgroundLibrary` for the static candidate samplers. |
| 2026-04-26 | **Feat system — `grant_feat()`.** `grant_feat(pc_index, feat_id)` added (dedup + save). `_serialize_combatant` writes `feat_ids`; `_deserialize_combatant` migrates old saves. |
