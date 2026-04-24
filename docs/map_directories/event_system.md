# Event System

> Non-combat EVENT node system. This doc covers the **data layer only** (Slice 1). Scene overlay, selector, effect dispatch, and condition evaluator are documented here as they land in later slices.

---

## Status

| Layer | Status |
|---|---|
| Data library (EventLibrary + CSVs) | ✅ Active (3 smoke events, 12 tests) |
| EventSelector (ring filter + no-repeat) | 🔲 Stub — Slice 3 |
| EventScene overlay + EventManager | 🔲 Stub — Slice 4 |
| Effect dispatch + condition evaluator | 🔲 Stub — Slice 4 |
| player_pick picker + new-item glow | 🔲 Stub — Slice 5 |
| Authoring pass (13+ real events) | 🔲 Stub — Slice 6 |

---

## Files

| File | Purpose |
|---|---|
| `rogue-finder/scripts/globals/EventLibrary.gd` | Static loader — parses events.csv + event_choices.csv, joins by event_id, exposes public API |
| `rogue-finder/resources/EventData.gd` | One non-combat event (id, title, body, ring_eligibility, choices) |
| `rogue-finder/resources/EventChoiceData.gd` | One choice within an event (label, conditions, effects, result_text) |
| `rogue-finder/data/events.csv` | Event rows — id, title, body, ring_eligibility |
| `rogue-finder/data/event_choices.csv` | Choice rows — event_id, order, label, conditions, effects, result_text |
| `rogue-finder/tests/test_event_library.gd` | 12 headless tests |
| `rogue-finder/tests/test_event_library.tscn` | Test runner scene |

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
| Will depend on (Slice 3+) | GameState (`used_event_ids`), MapManager (ring resolution) |
| Depended on by (Slice 3+) | EventSelector, EventManager |

---

## Recent Changes

| Date | Change |
|---|---|
| 2026-04-24 | **Slice 1** — EventData, EventChoiceData, EventLibrary created. events.csv (3 smoke events) + event_choices.csv (7 choices covering full effect vocabulary). 12 headless tests. |
