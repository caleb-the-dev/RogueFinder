# Non-Combat Events — Session Prompts (Slices 1–6)

Each `## Slice N` section below is a **self-contained, paste-ready prompt** for a fresh Claude session. Copy the body of a single section (from "Kickoff" through "Done when") into a new session. Future sessions don't need any of the other slice sections.

All slices share a parent spec: **`docs/superpowers/specs/2026-04-24-events-design.md`**. Future-Claude reads that first, then works only within the slice's scope.

---

## Slice 1 — Event data library foundation

> **Kickoff**
> Create and push a branch `claude/events-slice1-data-library-<YYYYMMDD>` before any work. Never touch `main` until I approve.
>
> **Read first (in this order)**
> 1. `CLAUDE.md` — project conventions and build state
> 2. `docs/superpowers/specs/2026-04-24-events-design.md` — the full events design spec (authoritative)
> 3. `rogue-finder/scripts/globals/BackgroundLibrary.gd` — the template all new libraries mirror
> 4. `rogue-finder/resources/BackgroundData.gd` — data-class template
>
> **Scope (this slice only)**
> Build the event data library foundation: data classes, two CSVs with 3 smoke events, and the loader. No scene work, no gameplay wiring yet. Follows spec §3 exactly.
>
> **Files to create**
> - `rogue-finder/resources/EventData.gd` — `class_name EventData`; fields per spec §3.2
> - `rogue-finder/resources/EventChoiceData.gd` — `class_name EventChoiceData`; fields per spec §3.2
> - `rogue-finder/data/events.csv` — columns per spec §3.1; 3 smoke events covering the full effect vocabulary (include one choice with a condition, one with `player_pick` target, one nav effect, one no-op choice)
> - `rogue-finder/data/event_choices.csv` — columns per spec §3.1; choices for the 3 events
> - `rogue-finder/scripts/globals/EventLibrary.gd` — `class_name EventLibrary`; follows `BackgroundLibrary` template; loads both CSVs, joins by `event_id` + `order`, provides `get_event` / `all_events` / `all_events_for_ring` / `reload`
> - `rogue-finder/tests/test_event_library.gd` — headless tests per spec §6
>
> **Decisions already locked (do not re-derive)**
> - Two-CSV relational split (spec §3.1); do **not** collapse to single-CSV JSON
> - `get_<name>` returns a populated stub on unknown id — never null (matches every existing library)
> - Condition strings and effect JSON are stored as opaque Arrays on `EventChoiceData`; this slice does **not** evaluate them
>
> **Tests (headless, plain `assert`)**
> Must cover: CSV parse + join, `all_events_for_ring` ring filter (outer/middle/inner), unknown id returns stub not null, `reload()` re-populates, choices sort by `order`.
>
> **Out of scope**
> Selector module, GameState plumbing, scene overlay, effect dispatch, condition evaluator. Those are Slices 2–4.
>
> **Done when**
> All new tests + the existing 43 tests pass headlessly. Commit + push and tell me what was built and what to test. Don't merge to main yet.

---

## Slice 2 — Feat library

> **Kickoff**
> Create and push branch `claude/events-slice2-feat-library-<YYYYMMDD>`. Don't touch main until I approve.
>
> **Read first**
> 1. `CLAUDE.md`
> 2. `docs/superpowers/specs/2026-04-24-events-design.md` §7 Slice 2 and §9 (feat-related open items)
> 3. `rogue-finder/scripts/globals/KindredLibrary.gd` + `rogue-finder/data/kindreds.csv` — current feat references live in the `feat_pool` column
> 4. Every script that displays feats today: `StatPanel`, `CombatActionPanel`, `PartySheet` — grep for `feat` to find them
> 5. `rogue-finder/scripts/globals/BackgroundLibrary.gd` — library template
>
> **Scope**
> Central registry for feats so events can reference them by id in `feat_grant` effects, and display surfaces render canonical name + description instead of raw ids.
>
> **Files to create**
> - `rogue-finder/resources/FeatData.gd` — fields: `id: String`, `display_name: String`, `description: String`, `effect: Dictionary` (nullable placeholder for future mechanical effects)
> - `rogue-finder/data/feats.csv` — columns: `id, display_name, description, effect`. Populate with every feat currently referenced in `kindreds.csv` feat pools; `effect` cell empty for now (mechanical effects are placeholder per build state)
> - `rogue-finder/scripts/globals/FeatLibrary.gd` — `class_name FeatLibrary`; `BackgroundLibrary` pattern; `get_feat(id) -> FeatData` / `all_feats() / reload`
> - `rogue-finder/tests/test_feat_library.gd`
>
> **Files to modify**
> - Display call sites (StatPanel/CombatActionPanel/PartySheet) switch from raw feat id to `FeatLibrary.get_feat(id).display_name`; tooltip/description surfaces switch to `.description`
> - `KindredLibrary` / `kindreds.csv` — no schema change; feat pool stays a pipe-separated list of ids, but now those ids are guaranteed to resolve via `FeatLibrary`
>
> **Decisions already locked**
> - No mechanical feat effects in this slice; `effect` column is populated when a separate "feat effects" feature lands
> - Feat pool on `KindredData` stays as is; consumers opt in to `FeatLibrary` for lookup
>
> **Tests**
> Headless: every feat id from `kindreds.csv` resolves through `FeatLibrary` without hitting the unknown-id fallback; `reload()` re-populates; `get_feat("nonexistent")` returns a populated stub.
>
> **Out of scope**
> Mechanical effects of feats. Events' `feat_grant` dispatch (that's Slice 4).
>
> **Done when**
> All tests pass. Manual verification: launch game, open PartySheet, Kindred feat(s) still display with their name and now show a description.

---

## Slice 3 — EventSelector + run-state plumbing + autosave-on-node-travel

> **Kickoff**
> Create and push branch `claude/events-slice3-selector-<YYYYMMDD>`.
>
> **Read first**
> 1. `CLAUDE.md`
> 2. `docs/superpowers/specs/2026-04-24-events-design.md` §5 (full) and §4.6 (autosave)
> 3. `rogue-finder/scripts/globals/GameState.gd` — save/load pattern, `cleared_nodes` field is the reference
> 4. `rogue-finder/scripts/map/MapManager.gd` — `_on_node_reached` is where autosave + selector call land
> 5. `docs/map_directories/map_scene.md` — current node-entry flow
>
> **Scope**
> The selection layer plus its persistence. No overlay, no dispatch yet. After this slice, EVENT nodes still route to `NodeStub` — but the selector is callable and tested.
>
> **Files to create**
> - `rogue-finder/scripts/misc/EventSelector.gd` — plain static class; `pick_for_node(node_id: String) -> String` per spec §5.1
> - `rogue-finder/tests/test_event_selector.gd`
>
> **Files to modify**
> - `rogue-finder/scripts/globals/GameState.gd` — add `var used_event_ids: Array[String] = []`; include in `save()`, `load_save()` (typed-array round-trip matching `cleared_nodes`), and `reset_for_new_run()` (or whatever the current run-reset function is named)
> - `rogue-finder/scripts/map/MapManager.gd` — at the end of `_on_node_reached`, call `GameState.save()` unconditionally (autosave-on-node-travel). **Verify first** whether this is already wired — if so, leave it; if not, add it. Check save load docs if unclear.
> - Update `docs/map_directories/game_state.md` and `map_scene.md` to reflect the new field and autosave beat
>
> **Decisions already locked**
> - Non-seeded selection (`pick_random()`); matches reward system and combat
> - Dry-pool returns `""`, which downstream (Slice 4) routes to `NodeStub` as safety net
> - `used_event_ids` is run-scoped; resets on new run
>
> **Tests (headless)**
> - Selector filters by ring correctly (inner events hidden from middle-ring query, etc.)
> - No-repeat: calling `pick_for_node` twice on the same node type doesn't return the same id twice
> - Dry pool returns `""` and logs a warning
> - Save round-trip: `used_event_ids` persists and restores
> - `reset_for_new_run` clears `used_event_ids`
>
> **Out of scope**
> Overlay, dispatch, `MapManager` routing EVENT to the new scene (stays pointed at NodeStub this slice).
>
> **Done when**
> All tests pass. Manual smoke: autosave on node arrival is observable (timestamp on `user://save.json` updates on each node step).

---

## Slice 4 — Scene overlay + effect dispatch

> **Kickoff**
> Create and push branch `claude/events-slice4-overlay-<YYYYMMDD>`.
>
> **Read first**
> 1. `CLAUDE.md`
> 2. `docs/superpowers/specs/2026-04-24-events-design.md` §§2, 4 (runtime flow — full)
> 3. `rogue-finder/scripts/party/PartySheet.gd` — overlay precedent at layer 20; follow this pattern
> 4. `rogue-finder/scripts/map/MapManager.gd` — `_on_node_reached` EVENT branch
> 5. `docs/map_directories/party_sheet.md` — overlay conventions
>
> **Scope**
> The visible, playable slice. An EVENT node spawns a text modal with choices, resolves, mutates state, autosaves, clears the node. No player-pick target yet (degrades to `PC` with a console warning).
>
> **Files to create**
> - `rogue-finder/scenes/events/EventScene.tscn` — minimal, root `CanvasLayer` + script only
> - `rogue-finder/scripts/ui/EventManager.gd` — the overlay script; builds UI in `_ready()` (per `.tscn` minimalism rule); implements the resolution loop in spec §4.3
> - `rogue-finder/scripts/events/EventConditions.gd` — pure static helper; `is_satisfied(condition: String) -> bool` covering every vocabulary entry in spec §3.4
> - `rogue-finder/scripts/events/EventEffects.gd` — pure static helper; `apply(effect: Dictionary) -> void` covering every type in spec §3.5, **except**: `xp_grant` is a log-only stub (party XP system doesn't exist; see spec §9), `open_bench`/`open_vendor` return a sentinel so `EventManager` can handle scene routing
> - `rogue-finder/scripts/events/EventTargeting.gd` — `resolve(target_key: String) -> CombatantData` for `PC` / `random_ally` / `random_party`; `player_pick` falls back to `PC` with a warning (Slice 5 adds the picker)
> - Tests: `test_event_conditions.gd`, `test_event_effects.gd`, `test_event_targeting.gd`
>
> **Files to modify**
> - `rogue-finder/scripts/map/MapManager.gd` — EVENT branch changes from `pending_node_type = "EVENT"; change_scene_to_file(NodeStub)` to: call `EventSelector.pick_for_node`; if empty, keep the NodeStub fallback; otherwise instance `EventScene.tscn` as child `CanvasLayer`, pass `event_id`, disable map input; on overlay free, re-enable input and mark node cleared
> - `docs/map_directories/map_scene.md` — document the new EVENT flow; add a new bucket file `docs/map_directories/events_system.md` covering EventScene + manager + condition/effect/targeting helpers
>
> **Decisions already locked**
> - Overlay (`CanvasLayer` at layer 20), not scene change; PartySheet is the precedent
> - Disabled choice buttons for unmet conditions, showing the requirement inline (e.g. `[STR 4] Kick it open`)
> - Nav effects (`open_bench`, `open_vendor`) terminate resolution — no result panel, straight to target scene
> - `GameState.save()` fires once per event, at end of resolution (or immediately for nav effects)
> - `item_gain` builds a dict and calls `GameState.add_to_inventory(dict)`; do **not** invent a new API
>
> **Tests (headless)**
> - One test per condition vocabulary entry (pass + fail cases)
> - One test per effect type (state mutation verified; `xp_grant` stub logs + no-ops)
> - Target resolution: `PC`, `random_ally`, `random_party` return the expected combatant; `player_pick` falls back to `PC`
>
> **Manual in-game smoke**
> - Walk onto an EVENT node; modal appears with map visible behind; buttons work; unmet-condition choice is disabled; resolution applies, closes, autosave fires, node marks cleared
> - Nav effect `open_bench` routes to Badurga bench stub; `open_vendor` routes to vendor stub; both flows are smoke-testable
>
> **Out of scope**
> `player_pick` picker UI (Slice 5). New-item glow (Slice 5). Authoring more than the 3 smoke events (Slice 6).
>
> **Done when**
> All tests green, in-game smoke passes, all 3 smoke events fire correctly. Commit + push, summarize what to test.

---

## Slice 5 — `player_pick` picker + new-item glow

> **Kickoff**
> Create and push branch `claude/events-slice5-picker-and-glow-<YYYYMMDD>`.
>
> **Read first**
> 1. `CLAUDE.md`
> 2. `docs/superpowers/specs/2026-04-24-events-design.md` §§3.6, 4.5 (picker), §9 (silent drops + glow motivation)
> 3. `rogue-finder/scripts/ui/EventManager.gd` — extend the resolve loop
> 4. Party-bag UI renderer (grep for inventory rendering inside PartySheet)
>
> **Scope**
> Two orthogonal features bundled because they share session timing:
> 1. **Picker panel** for `target: "player_pick"` — a secondary overlay that lists alive party members, awaits a click, returns the pick.
> 2. **New-item glow** — inventory items gain a `seen: bool` flag, persisted in save; party-bag UI renders unseen items with a glow (e.g., pulsing border or color tint); first hover/peek flips the flag.
>
> **Files to create / modify**
>
> *Picker:*
> - `rogue-finder/scripts/ui/EventPickerPanel.gd` — the secondary overlay; async pattern returning a `CombatantData` reference
> - `rogue-finder/scripts/events/EventTargeting.gd` — replace `player_pick → fallback to PC` with a real picker call
> - `rogue-finder/scripts/ui/EventManager.gd` — resolve loop now awaits picker when encountered
>
> *New-item glow:*
> - `rogue-finder/scripts/globals/GameState.gd` — inventory dicts gain `seen: bool` (default false); save/load round-trips the flag; fresh drops from events (and combat rewards, to stay consistent) land with `seen: false`
> - Party-bag rendering — unseen items receive glow treatment; hover (or open PartySheet first time the item is visible) flips to `seen: true` and persists
>
> *Tests:*
> - Picker routing: `player_pick` effect on `harm`/`heal`/`feat_grant` routes through the picker and hits only the picked combatant (simulate the click programmatically)
> - Glow state: new drops have `seen: false`; hover flips to `true`; save round-trip preserves both states
>
> **Decisions already locked**
> - Picker is a second `CanvasLayer` overlay on top of the event modal, not a modal-swap on the same panel — keeps event result separate from pick
> - Glow behavior: pulse or tint, exact treatment author's choice (state the decision in the commit message)
> - Glow applies to **all** new inventory items, not just event-granted ones — the UX rule is "anything you haven't looked at is glowing"
>
> **Out of scope**
> Content authoring (Slice 6). Any other inventory UX polish (tooltips, sort, filter).
>
> **Done when**
> Both features testable end-to-end. Manual smoke: an event with `target: "player_pick"` prompts for pick, applies to chosen ally only; new items in the bag glow until hovered.

---

## Slice 6 — Authoring pass

> **Kickoff**
> Create and push branch `claude/events-slice6-authoring-<YYYYMMDD>`.
>
> **Read first**
> 1. `CLAUDE.md`
> 2. `docs/superpowers/specs/2026-04-24-events-design.md` — especially §3.4, §3.5, §3.6 (vocabularies), §5.2 (pool sizing)
> 3. Existing `rogue-finder/data/events.csv` + `event_choices.csv` — the 3 smoke events as starting tone reference
> 4. `GAME_BIBLE_roguefinder.md` § Non-Combat Events — tone & intent for Story Beats vs Environmental/Mechanical
>
> **Scope**
> Pure content work — no code changes beyond CSV. Write enough events that a single run never repeats and players see variety across runs.
>
> **Authoring targets**
> - ≥ 5 outer-ring-eligible events (early-run, gentler stakes)
> - ≥ 5 middle-ring-eligible events (mid stakes)
> - ≥ 3 inner-ring-eligible events (late, harsher — can use `harm` with larger values, can risk ally targets)
> - 13+ total; mix both authoring flavors:
>   - **Story Beats** — narrative moments; lean on `xp_grant`, `feat_grant`, `open_bench`, threat tweaks, item rewards that feel like found-treasure
>   - **Environmental/Mechanical** — "you find a chest" style; lean on condition gates (stat checks, item checks), harm/heal, item gain/remove
> - Sprinkle condition gates across ~40% of choices so the party-comp-matters promise lands
> - Every event has at least one "leave it" / no-op choice (empty `effects`) so players can always walk away
>
> **Files to modify**
> - `rogue-finder/data/events.csv` — add new rows
> - `rogue-finder/data/event_choices.csv` — add choice rows for each new event
>
> **Decisions already locked**
> - No new columns (YAGNI; type tagging explicitly deferred)
> - `xp_grant` still works in authoring even though it's a log-only stub today — forward-compatible when the party XP system lands
>
> **Tests**
> Existing `test_event_library.gd` continues to pass. No new code tests — this is content. If CSV parse fails, the existing loader tests catch it.
>
> **Manual playtest**
> - Launch a run; walk through all 8 EVENT nodes; no repeats; every condition-gated choice correctly gates/ungates based on your party; every `player_pick` prompts the picker
>
> **Out of scope**
> Code. Any system-level changes. If you discover a gap in the vocabulary during authoring, stop and surface it — don't patch it ad hoc.
>
> **Done when**
> 13+ events authored, all parse, full run playtest clean, committed + pushed.
