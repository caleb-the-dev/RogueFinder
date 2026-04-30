# Event System

> Non-combat EVENT node system. Data layer (Slice 1), EventSelector (Slice 3), EventScene overlay + effect dispatch (Slice 4), and player_pick picker (Slice 5) are live.

---

## Status

| Layer | Status |
|---|---|
| Data library (EventLibrary + CSVs) | ✅ Active (18 events, 55 choice rows, 12 tests) |
| BenchSwapPanel (compare UI for bench-full recruit) | ✅ Active — Slice 7 |
| EventSelector (ring filter + no-repeat) | ✅ Active — Slice 3 (5 tests) |
| EventScene overlay + EventManager | ✅ Active — Slice 4 (19 tests) |
| Effect dispatch + condition evaluator | ✅ Active — Slice 4 |
| player_pick picker + new-item glow | ✅ Active — Slice 5 (7 tests) |
| Authoring pass (13+ real events) | ✅ Active — Slice 6 |

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
| `rogue-finder/tests/test_event_manager_slice5.gd` | 7 headless tests (player_pick picker flow, forced_target dispatch, new-item glow stamps) |
| `rogue-finder/tests/test_event_manager_slice5.tscn` | Test runner scene |
| `rogue-finder/tests/test_event_follower.gd` | 6 headless tests (recruit_follower effect, bench_not_full condition, bench release path) |
| `rogue-finder/tests/test_event_follower.tscn` | Test runner scene |
| `rogue-finder/scripts/ui/BenchSwapPanel.gd` | Static builder — bench-swap comparison panel (portrait, archetype, 10-stat grid with Δ, Swap + cancel buttons). Used by EventManager and CombatManager3D. |

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

### Static: `evaluate_condition(condition, party) -> bool`

Returns `true` if ANY party member satisfies the condition. Supported forms:

| Form | Logic |
|---|---|
| `stat_ge:STAT:N` | Any member's stat ≥ N. Stat map: STR→strength, DEX→dexterity, COG→cognition, WIL→willpower, VIT→vitality |
| `kindred:ID` | Any member's `kindred == ID` |
| `class:ID` | Any member's `unit_class == ID` |
| `background:ID` | Any member's `background == ID` |
| `feat:ID` | Any member's `feat_ids` array contains ID |
| `item:ID` | Any entry in `GameState.inventory` has `id == ID` |
| `bench_not_full` | Bench has fewer than `BENCH_CAP` (9) followers; zero-argument form (no `:`) |
| `has_gold:N` | `GameState.gold >= N`. True at exact threshold and above. |

Unknown form → `push_warning` + return `true` (fail open — never silently gate a choice).

A choice whose `conditions` array is empty is always enabled (loop never runs).

### Static: `resolve_target(target, party) -> CombatantData`

| target | Resolution |
|---|---|
| `"PC"` | `party[0]` |
| `"random_ally"` | Random alive non-PC member. Degrades to `party[0]` + `push_warning` if no alive allies. |
| `"random_party"` | Random alive member from full party. |
| `"player_pick"` | Degrades to `party[0]` + `push_warning` when called directly (e.g., from tests). In the normal flow, `_on_choice_pressed` intercepts `player_pick` before calling `dispatch_effect`, so `resolve_target` is bypassed via `forced_target` (see below). |

"Alive" = `not is_dead`. Always falls back to `party[0]` if resolved pool is empty.

### Static: `dispatch_effect(effect, party, forced_target, bench_release_idx, prebuilt_follower) -> void`

`forced_target: CombatantData = null` — optional override for `player_pick` effects.
`bench_release_idx: int = -1` — bench slot to release before adding a `recruit_follower`. -1 = bench not full or player cancelled.
`prebuilt_follower: CombatantData = null` — if provided for a `recruit_follower` effect, this instance is used directly (skips `ArchetypeLibrary.create()`). Set by `_on_choice_pressed` when the comparison panel was shown, so the displayed stats are identical to what lands on the bench.

| `type` | Behavior |
|---|---|
| `item_gain` | Looks up `item_id` in EquipmentLibrary then ConsumableLibrary; calls `GameState.add_to_inventory(dict)`. push_warning + no-op if not found in either. |
| `item_remove` | `GameState.remove_from_inventory(item_id)` |
| `harm` | `_resolve_with_override` → `target.current_hp = maxi(0, current_hp - value)` |
| `heal` | `_resolve_with_override` → `target.current_hp = mini(hp_max, current_hp + value)` |
| `xp_grant` | `print("[EventEffect] xp_grant %d — stub")` — no-op until XP system exists |
| `threat_delta` | `GameState.threat_level = clampf(threat_level + float(value) / 100.0, 0.0, 1.0)` — value is signed int treated as percentage points |
| `feat_grant` | `_resolve_with_override` → calls `GameState.grant_feat(party.find(target), feat_id)`. Deduplication and save are handled inside `grant_feat()`. |
| `recruit_follower` | Builds a CombatantData (or uses `prebuilt_follower`), level-matches to `party[0]`, resets xp/pending. If bench full and `bench_release_idx >= 0`: calls `GameState.release_from_bench(idx)` first. Then calls `GameState.add_to_bench(follower)`. push_warning + no-op if bench still full. |
| `gold_change` | `GameState.gold = maxi(0, gold + value)`. Negative `value` debits gold; clamped to 0 — gold cannot go negative. |
| `open_vendor` / `open_bench` | **Not dispatched here** — handled in `_on_choice_pressed` as nav effects before dispatch loop runs |

Unknown type → `push_warning` + skip.

### Static: `_resolve_with_override(target, party, forced_target) -> CombatantData`

Private helper called by `dispatch_effect` for harm/heal/feat_grant. Routes to `forced_target` when `target == "player_pick"` and `forced_target != null`; otherwise delegates to `resolve_target`. Keeps the override logic in one place.

### Instance: `_show_picker() / _hide_picker()`

`_show_picker()` — builds a `CenterContainer` + `PanelContainer` overlay (~500×200 px, blue border, layer 10) dynamically as a child of the CanvasLayer. Shows a "Choose a target:" prompt and one `Button` per alive party member (displays `character_name`, HP, and class). Clicking a button emits `target_picked(member)`. The choice buttons are hidden before the picker appears to block concurrent input.

`_hide_picker()` — frees the `CenterContainer` and nulls `_picker_centering`.

### Instance: `_show_bench_picker(new_recruit) / _hide_bench_picker()`

`_show_bench_picker(new_recruit: CombatantData)` — builds and adds a `BenchSwapPanel` Control to the CanvasLayer. Shows a full comparison panel: left = new recruit card (portrait, archetype, level, 10 stats), right = scrollable list of all 9 bench members (small portrait, archetype, level, stat grid with Δ = new recruit − bench member, Swap button), bottom = "Never Mind" cancel. `Swap →` button emits `bench_target_picked(idx)`; "Never Mind" emits `bench_target_picked(-1)` (cancel sentinel). Stores the panel root in `_bench_picker_centering: Control`.

`_hide_bench_picker()` — frees `_bench_picker_centering` and nulls it.

### Signals

| Signal | Args | When emitted |
|---|---|---|
| `event_finished` | — | Player clicked "Continue" on the result panel. `GameState.save()` called before emit. |
| `event_nav` | `dest: String` | Nav effect taken. No result panel; `hide_event()` called first. |
| `target_picked` | `target: CombatantData` | Picker overlay: player selected a party member. |
| `bench_target_picked` | `index: int` | Bench picker overlay: player chose bench slot `index` to release (≥ 0), or -1 to cancel. |

### UI Flow (Slice 7 — current)

1. `show_event(event_data)` — populate title/body, build choice buttons (disabled+dimmed for failed conditions), show overlay.
2. Player clicks a choice → `_on_choice_pressed(choice)` (coroutine — uses `await`).
3. Nav effect check first: if any effect is `open_vendor` or `open_bench` → `hide_event()` → `event_nav.emit(dest)`. MapManager handles routing. No result panel. Returns immediately.
4. **player_pick scan**: pre-scan `choice.effects` for any effect whose `target == "player_pick"`. If found: hide choice buttons → `_show_picker()` → `await target_picked` → `_hide_picker()`. The resolved `CombatantData` is stored as `picked_target`.
5. **bench-full scan**: pre-scan `choice.effects` for `recruit_follower` when `bench.size() >= BENCH_CAP`. If found: build the follower now (same stats as what will be added), store as `pending_recruit`; hide choice buttons → `_show_bench_picker(pending_recruit)` → `await bench_target_picked` → `_hide_bench_picker()`. If result is -1 (cancel): restore choice buttons, return — choice is undone, player can pick again. If result ≥ 0: store as `bench_release_idx`.
6. Dispatch all effects via `dispatch_effect(effect, party, picked_target, bench_release_idx, pending_recruit)`.
7. Show result panel with `choice.result_text`, hide choice buttons.
8. Player clicks "Continue" → `GameState.save()` → `event_finished.emit()` → `hide_event()`.

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
| `recruit_follower` | `archetype_id`, `name` (optional) | Builds a follower from archetype, level-matches to party[0], inserts into bench. `name` field used as-is; if absent, picks from kindred pool. No-op + push_warning when bench is full. |
| `open_bench` | — | Nav effect; terminates event, routes to bench |
| `open_vendor` | — | Nav effect; terminates event, routes to vendor |

## Target Vocabulary (`target` field on harm/heal/feat_grant)

| Value | Resolution |
|---|---|
| `PC` | `GameState.party[0]` |
| `random_ally` | Random non-PC alive member |
| `random_party` | Random alive member including PC |
| `player_pick` | Opens secondary picker panel; player selects an alive party member. Resolved via `forced_target` param in `dispatch_effect`. Degrades to `PC` + warning when called through `resolve_target` directly (e.g., headless tests). |

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

## Implementation Gotchas

- **Event nodes become cleared after completion** — `MapManager._on_event_finished()` and `_on_event_nav()` both append `player_node_id` to `GameState.cleared_nodes`. The guard at the top of `_enter_current_node()` then prevents re-entry. Event nodes show the ✗ stamp immediately on completion.
- **Nav effects short-circuit the result panel** — `open_vendor` / `open_bench` are detected before the dispatch loop in `_on_choice_pressed`. They call `hide_event()` then `event_nav.emit()` and return. No `result_text` is shown and `GameState.save()` is NOT called here — `_on_event_nav()` in MapManager owns the save.
- **`dispatch_effect` is static** — call it from tests without a scene instance.
- **`item_gain` lookup order** — EquipmentLibrary first (check `equipment_name != "Unknown"`), then ConsumableLibrary (check `consumable_id == item_id`). ConsumableLibrary stub sets `consumable_id = "unknown"` (not the queried id) — this distinguishes stub from real entry.
- **`player_pick` two-path resolution** — In the normal game flow, `_on_choice_pressed` pre-scans effects and shows the picker before dispatch, passing the chosen member as `forced_target` to `dispatch_effect`. The static `resolve_target("player_pick", party)` is therefore never called during live gameplay. It still degrades gracefully (returns `party[0]` + warning) for headless tests that call `dispatch_effect` without a `forced_target`.
- **Threat meter redraws live** — `_refresh_threat_meter()` updates `_threat_fill.size`/`.position`/`.color` and `_threat_pct_lbl.text` from `GameState.threat_level`. Called by `MapManager` on traversal, node entry, and after `event_finished`. `threat_delta` effects are reflected in the map HUD immediately on event completion.
- **`GameState.save()` timing** — EventManager's Continue button calls `save()` before emitting `event_finished`. Nav effects do NOT call save here — `MapManager._on_event_nav()` calls `save()` before scene change.

---

## Recent Changes

| Date | Change |
|---|---|
| 2026-04-30 | **Vendor Slice 6 — gold_change + has_gold.** `dispatch_effect` gains `gold_change` type (`GameState.gold = maxi(0, gold + value)`; negative value debits, clamped at 0). `evaluate_condition` gains `has_gold:N` form (`GameState.gold >= N`; true at exact threshold). `road_deal` smoke event added (events.csv row 18, 2 choice rows): demonstrates both new paths — pay-25-gold choice gated by `has_gold:25`, gains a `healing_potion`. EventManager joins `"blocks_pause"` group so the ☰ pause button hides and ESC doesn't open the pause menu while an event overlay is live. |
| 2026-04-28 | **Follower Slice 7 — Bench-swap comparison panel.** `BenchSwapPanel.gd` added (`scripts/ui/`): static builder returning a `Control` tree with left recruit card (64px portrait, archetype, 10-stat grid) and right scrollable bench list (36px portraits, archetype, stat grid with Δ = new recruit − bench member, green/red coloring, Swap → button). Cancel label configurable ("Never Mind" for events, "Lose Recruit" for combat). `dispatch_effect` gains `bench_release_idx: int = -1` and `prebuilt_follower: CombatantData = null` params. `_on_choice_pressed` builds the follower before showing the panel so displayed stats = added stats; cancel restores choice buttons. `CombatManager3D._show_bench_full_modal` replaced with `BenchSwapPanel`. `bench_target_picked(index: int)` signal added. Recruit choices no longer carry `bench_not_full` condition — always available; bench-full triggers the comparison panel instead. 6th headless test added for release+recruit path. |
| 2026-04-28 | **Follower Slice 5 — Event follower channel.** `recruit_follower` effect added to `dispatch_effect()`: builds a CombatantData from archetype, level-matches to party[0], inserts into bench (no-op + warning when full). `bench_not_full` zero-argument condition added to `evaluate_condition()` (checked before the `:` split). 3 follower-offer events authored: `wandering_sellsword` (outer/middle), `skeletal_wanderer` (middle/inner), `stray_dog` choice 0 upgraded from no-op to live recruit. `ArchetypeLibrary.create()` defensively guards empty `backgrounds` array (empty string instead of crash). events.csv: 17 rows. event_choices.csv: 53 rows. 5 new headless tests (`test_event_follower.gd`). |
| 2026-04-25 | **Slice 6b — Event revisions.** Post-testing pass: 13 changes to authored events. `wounded_traveler` rewritten as Wandering Medic (healer NPC, not victim). `fallen_signpost` body reworded. `stray_dog` choice 0 changed to recruit placeholder (no-op). `abandoned_campfire` choice 1 label/result clarified. `road_patrol`: "Cite your service" → no-op (was −5% threat); "Take the long way" → +10% threat (was no-op). `mercenary_camp`: dropped COG-gated "Trade information"; "Hire escort" → recruit placeholder no-op. `burned_farmhouse`: tend-to-child → `item_gain lucky_charm` (was heal PC). `river_crossing`: "Turn back" → +10% threat (was no-op). `survivor_in_the_dark` removed entirely. `mass_grave`: dropped COG-gated "Examine carefully"; "Disturb soil" → harm 5 + `item_gain rusted_dagger` (was harm-only). `ember_idol`: dropped `item:lucky_charm`-gated "Leave the charm" choice. Final counts: events.csv 15 rows, event_choices.csv 46 rows. |
| 2026-04-25 | **Slice 6** — Authoring pass. 12 new events authored across all three rings. events.csv: 15 rows. event_choices.csv: 46 rows. No GDScript changes. Ring coverage: outer (fallen_signpost, roadside_shrine, dry_well, abandoned_campfire, stray_dog, road_patrol), middle (road_patrol, mercenary_camp, burned_farmhouse, standing_stone, river_crossing), inner (standing_stone, mass_grave, ember_idol). Effects used: item_gain, item_remove, harm, heal, threat_delta, feat_grant. `wounded_traveler` preserved as canonical player_pick test event. |
| 2026-04-25 | **Slice 5** — `player_pick` picker overlay + `target_picked` signal. `_on_choice_pressed` is now a coroutine (`await`): pre-scans effects for `player_pick`, shows picker if needed, awaits `target_picked`, then dispatches with `forced_target`. `dispatch_effect` signature extended with optional `forced_target: CombatantData = null`; new `_resolve_with_override` helper routes it. Picker: `CenterContainer` + `PanelContainer` (~500×200 px), one button per alive party member, freed after pick. 7 new headless tests (96 total). |
| 2026-04-25 | **Slice 4** — `EventManager.gd` + `EventScene.tscn` created. CanvasLayer (layer 10) overlay with `show_event`/`hide_event` API, condition-gated choice buttons (disabled+dimmed), result panel, Continue → save → `event_finished`. Static `evaluate_condition` (6 forms), `resolve_target` (4 values), `dispatch_effect` (7 types). MapManager wired: EVENT branch calls `EventSelector.pick_for_node()` + `show_event()` instead of NodeStub; `_on_event_finished` marks node cleared + refreshes visuals; `_on_event_nav` marks cleared + saves + routes to NodeStub. 19 headless tests (89 total). `rusted_dagger` added to equipment.csv. |
| 2026-04-24 | **Slice 3** — `EventSelector.gd` created. `pick_for_node(ring)`: filters `GameState.used_event_ids`, exhaustion fallback to full pool, never-null, warning on missing ring data. Does not call `GameState.save()` — caller owns persistence. 5 headless tests. |
| 2026-04-24 | **Slice 1** — EventData, EventChoiceData, EventLibrary created. events.csv (3 smoke events) + event_choices.csv (7 choices covering full effect vocabulary). 12 headless tests. |
