# Non-Combat Events — Design

**Date:** 2026-04-24
**Status:** Approved — ready for implementation planning
**Scope:** Full design for the EVENT node system, from data layer through runtime overlay, with slice plan for phased implementation.

---

## 1. Context

RogueFinder maps currently contain 8 `EVENT` nodes per run (3 outer + 3 middle + 2 inner). On arrival they route to `NodeStub` (`rogue-finder/scripts/misc/NodeStub.gd`), a placeholder screen. This spec replaces that placeholder with a real non-combat event system.

Per the game bible (§ Non-Combat Events):
- Streamlined presentation — combat is the core; events provide context, trajectory, and resources.
- Party composition can open or close choices.
- Background does not gate or branch event outcomes.
- Bible names three event categories: Shopping/Vendors, Story Beats, Environmental/Mechanical. Shopping is redundant with the existing `VENDOR` node type, so EVENT nodes cover Story Beats + Environmental/Mechanical. These are **authoring tags, not mechanical sub-systems** — both share the same engine.

---

## 2. Architectural shape

**Event overlay on MapScene, owned by its own scene + script.** Instanced as a child `CanvasLayer` of `MapScene` (layer 20, matching the PartySheet precedent), not via `change_scene_to_file`. This:

- Keeps the map visible behind the modal (bible's streamlined brief).
- Preserves file-layout consistency with other systems (`EventScene.tscn` + `EventManager.gd`).
- Lets the design upgrade later to full-screen illustrated vignettes by swapping the overlay's root control, with no change to how the map invokes it.

`MapManager._on_node_reached` changes its EVENT branch from `change_scene_to_file(NodeStub.tscn)` to a local `_spawn_event_overlay(event_id)` call.

**Presentation tier.** Vertical slice is "Tier C": text-only modal (title + body + choice buttons + result panel + Continue). A full-screen illustrated "Tier A" vignette for story-beat events is the end goal but explicitly out of scope here; the overlay architecture accommodates it without rework.

---

## 3. Data model

### 3.1 CSV layout

Events use a **two-CSV relational split** because each event has 2–4 structured choices and deeply nested JSON in a single cell is miserable to edit in a spreadsheet. This breaks the single-CSV convention of existing libraries (`BackgroundLibrary` et al.) intentionally — events are the first data type with repeating child rows.

**`rogue-finder/data/events.csv`** — one row per event:

| column | type | example |
|---|---|---|
| `id` | string | `chest_rusty` |
| `title` | string | `Rusted Chest` |
| `body` | string | `A chest sits in the corner, lid half-rusted shut.` |
| `ring_eligibility` | pipe list | `outer\|middle` |

**`rogue-finder/data/event_choices.csv`** — one row per choice, joined on `event_id` + `order`:

| column | type | example |
|---|---|---|
| `event_id` | string | `chest_rusty` |
| `order` | int | `0` |
| `label` | string | `Kick it open (STR 4)` |
| `conditions` | pipe list | `stat_ge:STR:4` |
| `effects` | JSON array | `[{"type":"item_gain","item_id":"rusted_dagger","target":"bag"}]` |
| `result_text` | string | `The lid gives. Inside: a dagger.` |

### 3.2 Data classes

Data class files live under `rogue-finder/resources/` (matching `BackgroundData.gd`, `CombatantData.gd`, etc. — not under `scripts/`).

- `rogue-finder/resources/EventData.gd` — `{id, title, body, ring_eligibility: Array[String], choices: Array[EventChoiceData]}`
- `rogue-finder/resources/EventChoiceData.gd` — `{label, conditions: Array[String], effects: Array[Dictionary], result_text}`

### 3.3 Loader

`rogue-finder/scripts/globals/EventLibrary.gd`, following the `BackgroundLibrary.gd` template:

```gdscript
const EVENTS_CSV := "res://data/events.csv"
const CHOICES_CSV := "res://data/event_choices.csv"
static var _cache: Dictionary = {}

static func _ensure_loaded() -> void
static func get_event(id: String) -> EventData
static func all_events() -> Array[EventData]
static func all_events_for_ring(ring: String) -> Array[EventData]
static func reload() -> void
```

`_ensure_loaded` parses both CSVs; choices are grouped by `event_id`, sorted by `order`, and attached to their parent event. `get_event` returns a stub-populated fallback on unknown id (never null, per existing library convention).

### 3.4 Condition string vocabulary

All conditions evaluated as "any party member satisfies." Multiple conditions on a choice AND together. Meeting a condition is **deterministic** — no RNG on gates.

| form | meaning |
|---|---|
| `stat_ge:<STAT>:<N>` | any party member's stat ≥ N |
| `kindred:<ID>` | any party member matches kindred |
| `class:<ID>` | any party member matches class |
| `background:<ID>` | any party member matches background |
| `feat:<ID>` | any party member has the feat |
| `item:<ID>` | specific item sits in the party bag |

### 3.5 Effect JSON vocabulary

| `type` | required fields | behavior |
|---|---|---|
| `item_gain` | `item_id` | effect handler builds an inventory dict (same shape as reward drops) and calls `GameState.add_to_inventory(dict)`; new-item glow (Slice 5) signals to player |
| `item_remove` | `item_id` | calls `GameState.remove_from_inventory(item_id)`; no-op if absent |
| `harm` | `target`, `value` | HP reduction; respects existing permadeath path |
| `heal` | `target`, `value` | clamped to max HP |
| `xp_grant` | `value` | party-shared XP. **Party XP/level system does not exist in GameState yet** — see §9 open items; effect handler stubs to a log line until the XP system lands, then activates without re-authoring content |
| `threat_delta` | `value` | signed int; HUD bar updates via existing signal |
| `feat_grant` | `target`, `feat_id` | appended to combatant's feat list (mechanical effect still placeholder per build state) |
| `open_bench` | — | navigates to bench flow; terminates event resolution |
| `open_vendor` | — | navigates to vendor flow; terminates event resolution |

### 3.6 Target vocabulary

`target` is required only for `harm` / `heal` / `feat_grant`. Other effects have implicit targets (bag, threat meter, party level).

| value | resolution |
|---|---|
| `PC` | `GameState.party[0]` |
| `random_ally` | random non-PC alive member |
| `random_party` | random alive member including PC |
| `player_pick` | opens a secondary picker panel; only target that async-extends resolution |

---

## 4. Runtime flow

### 4.1 Entry

`MapManager._on_node_reached()` EVENT branch:

1. `event_id = EventSelector.pick_for_node(node_id)`
2. If `event_id == ""` (pool dry) → log warning, fall back to `NodeStub` as safety net.
3. Otherwise → instance `EventScene.tscn` as child `CanvasLayer` of MapScene, pass `event_id`, disable map input.

### 4.2 Overlay structure

`rogue-finder/scenes/events/EventScene.tscn` — minimal (root `CanvasLayer` + script), per convention. `rogue-finder/scripts/ui/EventManager.gd` builds in `_ready()`:

- Semi-transparent `ColorRect` at `MOUSE_FILTER_STOP` covering the screen (map visible behind but unclickable).
- Centered `PanelContainer` with title `Label`, body `Label`, and VBox of choice `Button`s.
- Unmet-condition choices render disabled with greyed label showing the requirement (e.g. `[STR 4] Kick it open`).

### 4.3 Resolution loop

```
open_event(event_id)
  └─ build modal from EventData
  └─ for each choice:
       ├─ conditions unmet → disabled button, show requirement inline
       └─ pressed → _resolve_choice(choice)

_resolve_choice(choice)
  ├─ for each effect in choice.effects:
  │    ├─ nav effect (open_bench / open_vendor)?
  │    │    ├─ free overlay
  │    │    ├─ mark node cleared
  │    │    ├─ GameState.save()
  │    │    └─ route to bench/vendor scene — DONE, no result panel
  │    └─ mutating effect → _apply_effect(effect)
  ├─ swap modal body to choice.result_text with single "Continue" button
  └─ Continue pressed → free overlay, mark node cleared, GameState.save(), re-enable map input
```

### 4.4 Effect dispatch

`_apply_effect(effect)` switches on `effect.type`:

- `item_gain` → build inventory dict (id, item_type, payload — matching reward-drop shape) → `GameState.add_to_inventory(dict)` (silently; new-item glow flags the pickup — Slice 5)
- `item_remove` → `GameState.remove_from_inventory(item_id)` (no-op if absent)
- `harm` / `heal` → resolve target → mutate `combatant.hp`
- `xp_grant` → log-only stub until party XP system exists; wire to `GameState.grant_party_xp(value)` (or equivalent) once that lands
- `threat_delta` → `GameState.threat_level += value`; emit HUD-update signal
- `feat_grant` → resolve target → append to `combatant.feats`
- `open_bench` / `open_vendor` → handled in resolve loop, not here

### 4.5 Target resolution

`_resolve_target(target_key) -> CombatantData` — sync for `PC` / `random_ally` / `random_party`; async for `player_pick` (spawns secondary picker panel, awaits click, returns pick).

### 4.6 Autosave beats

- `GameState.save()` fires once at the end of event resolution (after result dismiss, or immediately for nav effects).
- `GameState.save()` also fires at the end of `MapManager._on_node_reached` when the player lands on any node — this creates the "autosave on node travel" beat called out during brainstorming. Verify against current code during Slice 3; add if not wired.

### 4.7 Node clearing

Resolving an event appends `node_id` to `cleared_nodes` (same as COMBAT). Combined with no-repeat-within-run (§5), a cleared EVENT node greys visually and cannot fire again.

### 4.8 No-op choices

A choice with empty `effects` is valid — the result panel still shows `result_text` and a Continue button. Clean way to author "walk away" flavor options.

---

## 5. Selection and no-repeat

### 5.1 Selector module

`rogue-finder/scripts/misc/EventSelector.gd` — plain static helper (not an autoload; libraries stay pure data, this sits between `MapManager` and `EventLibrary` because it reads `GameState`).

```gdscript
static func pick_for_node(node_id: String) -> String:
    # 1. Resolve ring from MapManager._node_data[node_id].ring
    # 2. candidates = EventLibrary.all_events_for_ring(ring)
    # 3. Filter out GameState.used_event_ids
    # 4. If empty → log warning, return "" (MapManager routes to NodeStub)
    # 5. Else → pick = candidates.pick_random(); append pick.id to used_event_ids; return pick.id
```

### 5.2 Pool sizing

Per-run EVENT node count: 3 outer + 3 middle + 2 inner = 8. Author baseline for a shippable slice: **≥ 5 outer + ≥ 5 middle + ≥ 3 inner** (13+ total), which guarantees no repeats in a single run and gives 2–3× variety.

### 5.3 Run-scoped state

New field on `GameState`:

```gdscript
var used_event_ids: Array[String] = []
```

Save/load: typed-array round-trip matching `cleared_nodes` (`Array(..., TYPE_STRING, "", null)` on load). Reset alongside other run-scoped fields in `reset_for_new_run()`.

### 5.4 Pool-dry fallback

MVP: warn to console, return `""`, `MapManager` falls through to `NodeStub`. Long-term upgrade (trivial): if filtered pool is empty, retry without the used-ids filter, allowing cosmetic repeats. Deferred.

### 5.5 Determinism

Selection is non-seeded (`pick_random()`). Reward system and combat are also non-seeded today; events match. Map generation is seeded but happens at run start, not during play.

---

## 6. Testing approach

Per `CLAUDE.md`: headless `assert`-based tests for pure logic; UI/rendering not tested.

**Headless tests planned:**
- CSV parse + join (`EventLibrary`)
- Ring filter (`all_events_for_ring`)
- Condition evaluator — one test per vocabulary entry (pass + fail cases)
- Effect dispatch — one test per effect type (state mutation verified)
- Target resolution — `PC`, `random_ally`, `random_party` return expected combatants
- Selector — pool filter by ring, no-repeat enforcement, dry-pool null return
- Save round-trip — `used_event_ids` persists and restores correctly

**Not tested (per convention):** modal rendering, button layout, scene overlay spawn, nav routing to bench/vendor scenes.

**Target:** ~15 new passing tests by end of Slice 4, bringing suite from 43 → ~58.

---

## 7. Slice plan

Each slice is roughly one session. Ordering matters — each builds on the last.

| # | Slice | Scope |
|---|---|---|
| 1 | **Event data library foundation** | `EventData` + `EventChoiceData` · `events.csv` + `event_choices.csv` with 3 smoke events covering all effect types · `EventLibrary.gd` (two-CSV load + join + ring filter). Headless tests. |
| 2 | **Feat library** | `FeatLibrary.gd` + `feats.csv` (id, name, description, effect JSON nullable) · migrate existing kindred feat references to resolve through `FeatLibrary.get_feat(id)` · update display paths in StatPanel / CombatActionPanel / PartySheet. Headless tests. |
| 3 | **Selector + run-state + autosave-on-node-travel** | `EventSelector.pick_for_node()` · `GameState.used_event_ids` with save/load/reset · verify (or wire) `GameState.save()` at end of `MapManager._on_node_reached`. Headless tests. |
| 4 | **Scene overlay + effect dispatch** | `EventScene.tscn` + `EventManager.gd` overlay · condition evaluator · effect dispatch for all 9 types · target resolution for `PC` / `random_ally` / `random_party` (`player_pick` degrades to `PC` + console warning until Slice 5) · `MapManager` EVENT branch routes to overlay. Headless tests + manual in-game smoke. |
| 5 | **`player_pick` picker + new-item glow** | Secondary picker panel for `target: "player_pick"` · inventory item `seen: bool` flag persisted in save · party-bag UI glow on unseen items, flag flips on first hover/peek. |
| 6 | **Authoring pass** | Write 13+ real events (≥ 5 outer, ≥ 5 middle, ≥ 3 inner), mixing Story Beat and Environmental/Mechanical flavors. Pure content. |

**Notes:**

- Slice 2 (Feat library) is a "should-first" — events technically work without it, but `feat_grant` authoring gets much cleaner once feats have a central registry with descriptions.
- Slice 5 bundles two features that share session timing but are otherwise orthogonal. Split into 5a (picker) and 5b (glow) if session slots are tight.
- Slice 6 is content-only and pairs well with a short polish session.

---

## 8. Decisions log (why these picks)

- **Overlay over scene swap:** bible brief of streamlined presentation + "map visible behind" requirement + PartySheet precedent.
- **Two-CSV relational split:** spreadsheet ergonomics (Caleb edits data in sheets), broken only because events uniquely have repeating child rows.
- **Deterministic gates (no RNG on stat checks):** matches streamlined-presentation brief; RNG on resolution is a separate system that can layer in later.
- **Per-effect target vocabulary:** flexibility at authoring time without forcing every event through a picker modal.
- **No event type-tagging column:** YAGNI — tone/intent distinction is author's job; engine doesn't care.
- **Silent item gain + new-item glow:** faster than routing through `RewardScreen` while still signaling "something new is here."
- **`feat_grant` data applies even though feat mechanical effects are still placeholder:** the data layer is forward-compatible; when feat effects ship, events gain them for free.

---

## 9. Open / deferred items (explicitly out of scope)

- **Party XP/level system.** Bible calls for shared party level from XP, but no tracker exists in `GameState` today. `xp_grant` effect ships as a log-only stub in Slice 4; activates when the XP system is built (separate feature, unscoped here). Content authored with `xp_grant` in Slice 6 is forward-compatible.
- Rarity weights on event pool (only ring tiering in MVP).
- Across-run persistence of event firings (bulletin-board milestones — separate meta layer).
- Tier-A illustrated vignette presentation for story beats (art-pass dependent).
- Faction reputation effects (faction rep not yet saved).
- Cosmetic-repeat fallback when pool dries (trivial add, deferred).
- Event category tagging column (YAGNI'd — add if selection logic ever needs it).
- Routing `item_gain` through `RewardScreen` for parity with combat drops (deferred; silent drop + new-item glow covers the ergonomic hole).

---
