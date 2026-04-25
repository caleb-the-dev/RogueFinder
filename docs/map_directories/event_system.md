# Event System

> Non-combat EVENT node system. Data layer (Slice 1), EventSelector (Slice 3), and EventScene overlay + effect dispatch (Slice 4) are live.

---

## Status

| Layer | Status |
|---|---|
| Data library (EventLibrary + CSVs) | ✅ Active (3 smoke events, 12 tests) |
| EventSelector (ring filter + no-repeat) | ✅ Active — Slice 3 (5 tests) |
| EventScene overlay + EventManager | ✅ Active — Slice 4 (19 tests) |
| Effect dispatch + condition evaluator | ✅ Active — Slice 4 |
| player_pick picker + new-item glow | 🔲 Stub — Slice 5 |
| Authoring pass (13+ real events) | 🔲 Stub — Slice 6 |

---

## Files

| File | Purpose |
|---|---|
| `rogue-finder/scripts/globals/EventSelector.gd` | Static picker — draws from unseen ring pool; exhaustion fallback; appends to `GameState.used_event_ids` |
| `rogue-finder/scripts/globals/EventLibrary.gd` | Static loader — parses events.csv + event_choices.csv, joins by event_id, exposes public API |
| `rogue-finder/scripts/events/EventManager.gd` | CanvasLayer (layer 10) overlay — show/hide event UI, condition evaluator, effect dispatcher (all static) |
| `rogue-finder/scenes/events/EventScene.tscn` | Minimal scene (root CanvasLayer + EventManager script) |
| `rogue-finder/resources/EventData.gd` | One non-combat event (id, title, body, ring_eligibility, choices) |
| `rogue-finder/resources/EventChoiceData.gd` | One choice within an event (label, conditions, effects, result_text) |
| `rogue-finder/data/events.csv` | Event rows — id, title, body, ring_eligibility |
| `rogue-finder/data/event_choices.csv` | Choice rows — event_id, order, label, conditions, effects, result_text |
| `rogue-finder/tests/test_event_library.gd` | 12 headless tests |
| `rogue-finder/tests/test_event_library.tscn` | Test runner scene |
| `rogue-finder/tests/test_event_manager.gd` | 19 headless tests (condition evaluator, effect dispatch, persistence, target resolution) |
| `rogue-finder/tests/test_event_manager.tscn` | Test runner scene |

---

## Data Classes

### EventData (`rogue-finder/resources/EventData.gd`)

| Field | Type | Default | Description |
|---|---|---|---|
| `id` | `String` | `""` | Unique event id (matches events.csv `id` column) |
| `title` | `String` | `""` | Short display title |
| `body` | `String` | `""` | Narrative prompt shown to player |
| `ring_eligibility` | `Array[String]` | `[]` | Which map rings can draw this event (`"outer"`, `"middle"`, `"inner"`) |
| `choices` | `Array[EventChoiceData]` | `[]` | Populated by EventLibrary after join; sorted by authored order |

### EventChoiceData (`rogue-finder/resources/EventChoiceData.gd`)

| Field | Type | Default | Description |
|---|---|---|---|
| `label` | `String` | `""` | Button label shown to player |
| `conditions` | `Array[String]` | `[]` | Opaque gate strings (e.g. `"stat_ge:STR:4"`); evaluated in Slice 4 condition evaluator |
| `effects` | `Array[Dictionary]` | `[]` | Opaque effect dicts (e.g. `{"type":"item_gain","item_id":"rusted_dagger"}`); dispatched in Slice 4 |
| `result_text` | `String` | `""` | Text shown in result panel after choice is taken; may be empty for nav effects |

---

## Public API — EventLibrary

All methods are `static`. No instantiation required.

| Method | Returns | Description |
|---|---|---|
| `get_event(id: String)` | `EventData` | Returns populated EventData for the given id. **Never returns null** — unknown ids get a stub (title="Unknown"). |
| `all_events()` | `Array[EventData]` | Returns every loaded event. |
| `all_events_for_ring(ring: String)` | `Array[EventData]` | Returns events whose `ring_eligibility` contains `ring`. Used by EventSelector (Slice 3). |
| `reload()` | `void` | Clears cache and re-parses both CSVs. Dev/test helper. |

---

---

## Public API — EventManager

`EventManager` extends `CanvasLayer` (layer 10). Instantiated as a child of `MapManager` in `_ready()`. All condition / target / effect logic is `static` — headless-testable without a scene.

### Instance Methods

| Method | Description |
|---|---|
| `show_event(event_data: EventData) -> void` | Populates title/body, builds choice buttons (disabled+dimmed if conditions fail), shows overlay. |
| `hide_event() -> void` | Hides overlay, frees choice button children, resets result panel visibility. |

### Signals

| Signal | Args | When emitted |
|---|---|---|
| `event_finished` | — | Player clicked "Continue" on the result panel (non-nav choice). `GameState.save()` is called before emit. |
| `event_nav` | `dest: String` | A nav effect (`open_vendor` → `"VENDOR"`, `open_bench` → `"BENCH"`) was chosen. No result panel; `hide_event()` called first. |

### Static: `evaluate_condition(condition, party) -> bool`

Returns `true` if ANY party member satisfies the condition. Supported forms:

| Form | Logic |
|---|---|
| `stat_ge:STAT:N` | Any member's stat ≥ N. Stat map: STR→strength, DEX→dexterity, COG→cognition, WIL→willpower, VIT→vitality |
| `kindred:ID` | Any member's `kindred == ID` |
| `class:ID` | Any member's `unit_class == ID` |
| `background:ID` | Any member's `background == ID` |
| `feat:ID` | Any member's `feats` array contains ID |
| `item:ID` | Any entry in `GameState.inventory` has `id == ID` |

Unknown form → `push_warning` + return `true` (fail open — never silently gate a choice).

A choice whose `conditions` array is empty is always enabled (loop never runs).

### Static: `resolve_target(target, party) -> CombatantData`

| target | Resolution |
|---|---|
| `"PC"` | `party[0]` |
| `"random_ally"` | Random alive non-PC member. Degrades to `party[0]` + `push_warning` if no alive allies. |
| `"random_party"` | Random alive member from full party. |
| `"player_pick"` | `party[0]` + `push_warning("player_pick not yet implemented")` (Slice 5). |

"Alive" = `not is_dead`. Always falls back to `party[0]` if resolved pool is empty.

### Static: `dispatch_effect(effect, party) -> void`

| `type` | Behavior |
|---|---|
| `item_gain` | Looks up `item_id` in EquipmentLibrary then ConsumableLibrary; calls `GameState.add_to_inventory(dict)`. push_warning + no-op if not found in either. |
| `item_remove` | `GameState.remove_from_inventory(item_id)` |
| `harm` | `resolve_target` → `target.current_hp = maxi(0, current_hp - value)` |
| `heal` | `resolve_target` → `target.current_hp = mini(hp_max, current_hp + value)` |
| `xp_grant` | `print("[EventEffect] xp_grant %d — stub")` — no-op until XP system exists |
| `threat_delta` | `GameState.threat_level = clampf(threat_level + float(value) / 100.0, 0.0, 1.0)` — value is signed int treated as percentage points |
| `feat_grant` | `resolve_target` → appends `feat_id` to `target.feats` if not already present |
| `open_vendor` / `open_bench` | **Not dispatched here** — handled in `_on_choice_pressed` as nav effects before dispatch loop runs |

Unknown type → `push_warning` + skip.

### UI Flow

1. `show_event(event_data)` — populate title/body, build choice buttons (disabled+dimmed for failed conditions), show overlay.
2. Player clicks a choice → `_on_choice_pressed(choice)`.
3. Nav effect check first: if any effect is `open_vendor` or `open_bench` → `hide_event()` → `event_nav.emit(dest)`. MapManager handles routing. No result panel.
4. Otherwise: dispatch all effects, show result panel with `choice.result_text`, hide choice buttons.
5. Player clicks "Continue" → `GameState.save()` → `event_finished.emit()` → `hide_event()`.

---

## Public API — EventSelector

All methods are `static`. No instantiation required.

| Method | Returns | Description |
|---|---|---|
| `pick_for_node(ring: String)` | `EventData` | Picks one event for the given ring. Filters out ids already in `GameState.used_event_ids`; if all ring events are exhausted, silently falls back to the full ring pool. Appends the chosen id to `GameState.used_event_ids`. **Never returns null.** Pushes a warning + returns the stub if no events are authored for the ring. |

**Important:** `pick_for_node` does NOT call `GameState.save()`. The caller (EventManager, Slice 4) owns persistence. Only appends to the in-memory `GameState.used_event_ids` array.

---

## CSV Layout

### events.csv

| Column | Type | Notes |
|---|---|---|
| `id` | string | Primary key; matched by event_choices.csv |
| `title` | string | Short display name |
| `body` | string | Narrative prompt |
| `ring_eligibility` | pipe list | e.g. `outer\|middle` — which map rings can draw this event |

### event_choices.csv

| Column | Type | Notes |
|---|---|---|
| `event_id` | string | Foreign key → events.csv `id` |
| `order` | int | Sort order within the event; library sorts ascending before attaching |
| `label` | string | Button text |
| `conditions` | pipe list | e.g. `stat_ge:STR:4` — empty = no gate |
| `effects` | JSON array | e.g. `[{"type":"item_gain","item_id":"rusted_dagger"}]` — empty array `[]` = no-op choice |
| `result_text` | string | Result panel text; empty for nav effects (`open_vendor`, `open_bench`) |

---

## Effect Vocabulary (authored in effects JSON, dispatched in Slice 4)

| `type` | Required fields | Behavior |
|---|---|---|
| `item_gain` | `item_id` | Adds item to party bag |
| `item_remove` | `item_id` | Removes item from party bag; no-op if absent |
| `harm` | `target`, `value` | HP reduction |
| `heal` | `target`, `value` | HP restoration, clamped to max |
| `xp_grant` | `value` | Log-only stub until party XP system lands |
| `threat_delta` | `value` | Signed int; updates threat meter |
| `feat_grant` | `target`, `feat_id` | Appends feat to combatant's feat list |
| `open_bench` | — | Nav effect; terminates event, routes to bench |
| `open_vendor` | — | Nav effect; terminates event, routes to vendor |

## Target Vocabulary (`target` field on harm/heal/feat_grant)

| Value | Resolution |
|---|---|
| `PC` | `GameState.party[0]` |
| `random_ally` | Random non-PC alive member |
| `random_party` | Random alive member including PC |
| `player_pick` | Opens secondary picker panel (Slice 5); degrades to `PC` + warning in Slice 4 |

## Condition Vocabulary (authored in conditions pipe list, evaluated in Slice 4)

| Form | Gate |
|---|---|
| `stat_ge:<STAT>:<N>` | Any party member's stat ≥ N |
| `kindred:<ID>` | Any party member matches kindred |
| `class:<ID>` | Any party member matches class |
| `background:<ID>` | Any party member matches background |
| `feat:<ID>` | Any party member has the feat |
| `item:<ID>` | Specific item in party bag |

---

## Key Patterns / Gotchas

- **Two-CSV relational split** — intentional deviation from single-CSV convention. Events are the first data type with repeating child rows; JSON arrays per row would be miserable to edit in a spreadsheet.
- **Never null** — `get_event` always returns at least a stub. Callers need no null guards.
- **Opaque conditions and effects** — this layer stores strings/dicts verbatim. No evaluation or dispatch here. That belongs in the Slice 4 overlay/evaluator.
- **Cache not committed** — `.godot/global_script_class_cache.cfg` is gitignored. Godot rebuilds it on first project open. The three new `class_name` declarations (`EventData`, `EventChoiceData`, `EventLibrary`) will be picked up automatically.
- **No-op choices** — `effects: []` is valid. result_text still shows and Continue still fires. Good for "walk away" flavor branches.
- **Nav effect result_text** — `open_vendor` / `open_bench` terminate event resolution immediately; their `result_text` column is intentionally empty in the CSV.

---

## Dependencies

| Direction | System |
|---|---|
| EventLibrary depends on | nothing (pure data, no autoloads) |
| EventSelector depends on | EventLibrary (ring pool), GameState (`used_event_ids`) |
| EventManager depends on | GameState (party, inventory, save, threat_level), EquipmentLibrary + ConsumableLibrary (item_gain lookup), EventChoiceData / EventData (data types) |
| MapManager depends on | EventManager (instantiated in `_ready()`), EventSelector (called in EVENT branch of `_enter_current_node()`) |

---

## Key Patterns / Gotchas

- **Event nodes become cleared after completion** — `MapManager._on_event_finished()` and `_on_event_nav()` both append `player_node_id` to `GameState.cleared_nodes`. The guard at the top of `_enter_current_node()` then prevents re-entry. Event nodes show the ✗ stamp immediately on completion.
- **Nav effects short-circuit the result panel** — `open_vendor` / `open_bench` are detected before the dispatch loop in `_on_choice_pressed`. They call `hide_event()` then `event_nav.emit()` and return. No `result_text` is shown and `GameState.save()` is NOT called here — `_on_event_nav()` in MapManager owns the save.
- **`dispatch_effect` is static** — call it from tests without a scene instance.
- **`item_gain` lookup order** — EquipmentLibrary first (check `equipment_name != "Unknown"`), then ConsumableLibrary (check `consumable_id == item_id`). ConsumableLibrary stub sets `consumable_id = "unknown"` (not the queried id) — this distinguishes stub from real entry.
- **`player_pick` degrades to PC** — `resolve_target("player_pick", party)` pushes a warning and returns `party[0]`. Full picker UI is Slice 5.
- **Threat meter does not redraw dynamically** — `_add_threat_meter()` builds a static bar from `GameState.threat_level` at scene load. `threat_delta` effects correctly mutate `GameState.threat_level` in memory; the visual updates on next MapScene load.
- **`GameState.save()` timing** — EventManager's Continue button calls `save()` before emitting `event_finished`. Nav effects do NOT call save here — `MapManager._on_event_nav()` calls `save()` before scene change.

---

## Recent Changes

| Date | Change |
|---|---|
| 2026-04-25 | **Slice 4** — `EventManager.gd` + `EventScene.tscn` created. CanvasLayer (layer 10) overlay with `show_event`/`hide_event` API, condition-gated choice buttons (disabled+dimmed), result panel, Continue → save → `event_finished`. Static `evaluate_condition` (6 forms), `resolve_target` (4 values), `dispatch_effect` (7 types). MapManager wired: EVENT branch calls `EventSelector.pick_for_node()` + `show_event()` instead of NodeStub; `_on_event_finished` marks node cleared + refreshes visuals; `_on_event_nav` marks cleared + saves + routes to NodeStub. 19 headless tests (89 total). `rusted_dagger` added to equipment.csv. |
| 2026-04-24 | **Slice 3** — `EventSelector.gd` created. `pick_for_node(ring)`: filters `GameState.used_event_ids`, exhaustion fallback to full pool, never-null, warning on missing ring data. Does not call `GameState.save()` — caller owns persistence. 5 headless tests. |
| 2026-04-24 | **Slice 1** — EventData, EventChoiceData, EventLibrary created. events.csv (3 smoke events) + event_choices.csv (7 choices covering full effect vocabulary). 12 headless tests. |
