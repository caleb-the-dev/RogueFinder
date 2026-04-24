# Character Creation — Design Spec

> Status: Approved  
> Date: 2026-04-23  
> Scope: B1 (init_party revision) + B2 (minimal creation flow). B3 (Dial UX) and B4 (preview panel) are separate future plans.

---

## Locked Decisions (from prior session — not re-litigated)

### Q1 — Scope: Solo start
- Player customizes the PC only.
- Starting party = PC alone. No auto-spawned allies. Allies are encountered/recruited on the map (separate future feature).
- `GameState.init_party()` currently spawns 3 characters; B1 revises it to spawn only the PC as a fallback. After character creation is live, `init_party()` is dead code on the new-run path.

### Q2 — Feel: Light, with modifications
- Single-screen UX. ~30 seconds for a veteran. No "host" / reincarnation framing in UI copy.
- **Archetype is always `"RogueFinder"`** for the PC — not a pick.
- Player picks: `name`, `kindred`, `class`, `background`, `portrait`. All independent axes (any combination legal).
- Stats: rolled flat 1–4 (placeholder). Real per-pick stat contributions are a later feature.
- Starting abilities + feats are derived, not picked:
  - 1 class ability (`classes.csv.starting_ability_id`)
  - 1 background ability (`backgrounds.csv.starting_ability_id`)
  - 1 kindred feat (auto via `KindredLibrary.get_feat_id()`)
  - No class/background feat at L1 — those come when the feat system lands.

### Q3 — Content posture: Ship against existing data
- No new data authoring needed. All libraries are ready: 4 kindreds, 4 classes, 4 backgrounds, 6 portraits, 22 abilities — all CSV-native.

### Q4 — Integration point
- `MainMenuManager._on_new_run()` → currently routes to MapScene. Creation inserts between `reset()` and MapScene.
- `RunSummaryScene`'s "Main Menu" button already routes back correctly — no change needed.

### Q5 — Layout: Single screen, combination-lock dials
1. **Name** — text input + 🎲 (pulls from active kindred's `name_pool`)
2. **Kindred** — spin-dial + search + 🎲 (4 options)
3. **Class** — spin-dial + search + 🎲 (4 options)
4. **Background** — spin-dial + search + 🎲 (4 options)
5. **Portrait** — spin-dial + 🎲, no search (visual; 6 options)

Plus **"Randomize All"** at top and a **live preview panel** below the dials (stat ranges, class ability, background ability, kindred feat name).

On Confirm: build `CombatantData` → `GameState.party = [pc]` → MapScene.

### Approach: 4-slice plan (B1–B4)
- **B1** — revise `init_party()` to spawn only the PC. Folds into B2.
- **B2** — minimal creation flow: placeholder controls (OptionButton dropdowns + LineEdit name field + Confirm button). Hooks into `MainMenuManager`. End-to-end working feature, ugly but functional.
- **B3** — replace dropdowns with reusable `Dial` spin-control. Per-dial search + 🎲. Randomize All.
- **B4** — live preview panel: stat ranges + derived abilities + kindred feat.
- B3 and B4 are parallel-safe (both subscribe to the same selection-changed signals).

---

## Scene + Script Architecture

### Files created for B2

| File | Root node | Notes |
|------|-----------|-------|
| `scenes/ui/CharacterCreationScene.tscn` | `CanvasLayer` | Root + script only (minimal .tscn convention). No children in file. |
| `scripts/ui/CharacterCreationManager.gd` | attached to above | Owns `_build_ui()`, `_build_pc()`, `_on_confirm()`. |

### Files created for B3 (future, not B2 scope)

| File | Root node | Notes |
|------|-----------|-------|
| `scenes/ui/components/Dial.tscn` | `Control` | Root + script only. Reusable widget. |
| `scripts/ui/components/Dial.gd` | attached to above | Spin-dial logic, search field, 🎲 button. |

`components/` is a new subfolder under `scripts/ui/` and `scenes/ui/`. B3 introduces it.

### Existing files modified (B1 + B2)

- `scripts/ui/MainMenuManager.gd` — `_on_new_run()` routes to `CharacterCreationScene` instead of `MapScene`.
- `scripts/globals/GameState.gd` — `init_party()` revised to spawn only the PC (no allies).

### Conventions honored
- Both `.tscn` files: root node + script only; children built in `_ready()`.
- `CharacterCreationManager` extends `CanvasLayer` (matches `MainMenuManager`).
- `Dial.gd` extends `Control` (widget, not a manager).
- Signals named past-tense: `pick_changed`, `creation_confirmed`.

---

## Data Flow

### End-to-end (B2)

1. **`MainMenuManager._on_new_run()`**
   `delete_save()` → `reset()` → `change_scene_to_file(CREATION_SCENE_PATH)`
   `GameState.party` is now `[]`.

2. **`CharacterCreationManager._ready()`**
   Builds UI. Loads option lists:
   - `KindredLibrary.all_kindreds()`
   - `ClassLibrary.all_classes()`
   - `BackgroundLibrary.all_backgrounds()`
   - `PortraitLibrary.all_portraits()`
   Defaults: first item of each list. Name field starts empty.

3. **Player interacts** — changes picks, types or 🎲-generates a name.

4. **Player hits Confirm** — `_on_confirm()` calls `_build_pc(...)`, appends result to `GameState.party`, then `change_scene_to_file(MAP_SCENE_PATH)`.

5. **`MapManager._ready()`** — calls `GameState.init_party()`. Guard fires: party is non-empty. No-op.

### Build from scratch (not `ArchetypeLibrary.create()`)

`create("RogueFinder")` would fix kindred=Human, unit_class=Custom, and derive abilities from the RogueFinder archetype list — all wrong for free-pick creation. `_build_pc()` constructs `CombatantData` field by field:

```
archetype_id   = "RogueFinder"
is_player_unit = true
character_name = name input
kindred        = kindred pick (e.g. "Dwarf")
kindred_feat_id = KindredLibrary.get_feat_id(kindred_id)
unit_class     = ClassLibrary.get_class_data(class_id).display_name
background     = bg_id  (snake_case ID)
abilities      = [class.starting_ability_id, bg.starting_ability_id, "", ""]
ability_pool   = [class.starting_ability_id, bg.starting_ability_id]  (deduped)
strength / dex / cog / wil / vit = randi_range(1, 4)  (v1 placeholder)
armor_defense  = randi_range(4, 8)
qte_resolution = 0.5
current_hp     = hp_max   (computed property; includes kindred bonus)
current_energy = energy_max
```

### Known inconsistency: background field format

Existing ally `CombatantData.background` stores PascalCase display strings ("Crook", "Soldier") because `ArchetypeLibrary.create()` reads from the archetype's background pool. The PC created here stores the snake_case `background_id` from `BackgroundLibrary` — the canonical form. `BackgroundLibrary.get_background_by_name()` already bridges old code. No migration needed now.

---

## Dial Widget Contract

This is the load-bearing interface for B3/B4 parallelism. Both slices subscribe to the same signals; neither depends on the other's internals.

### Signals

```gdscript
signal pick_changed(item_id: String)  # fires on any selection change (arrow, search, 🎲)
signal randomized(item_id: String)    # fires only when 🎲 is pressed (subset of pick_changed)
```

Everything listens to `pick_changed`. `randomized` is available for consumers that specifically need to know it was a dice roll (e.g., triggering a spin animation).

### Public API

```gdscript
func setup(items: Array[Dictionary], label_text: String) -> void
    # items = [{id: String, display: String}, ...]
    # call once from parent's _ready()

func set_index(i: int) -> void
    # programmatic selection (used by Randomize All on the parent scene)

func get_selected_id() -> String
func get_selected_index() -> int
```

### Internal behavior (B3's job)
- Prev/Next arrows wrap around (index 0 − 1 → last; last + 1 → 0).
- Search field filters the visible list; selecting from filtered results updates dial position.
- 🎲 picks a random index from the full unfiltered list; emits `randomized` then `pick_changed`.

### How `CharacterCreationManager` uses it
- Connects `pick_changed` on all four dials to a single `_on_pick_changed()` handler.
- "Randomize All" calls `set_index(randi() % items.size())` on each dial.

### B2 compatibility
In B2, `OptionButton` replaces the Dial. `_on_pick_changed()` and `_build_pc()` are identical in both slices — only the control type changes in B3.

---

## Preview Calculation

### What's shown (B4)
- HP range (min / max) based on kindred pick
- Speed based on kindred pick
- Class ability: name + description
- Background ability: name + description
- Kindred feat: name only

### Where the math lives

A private `_calc_preview() -> Dictionary` on `CharacterCreationManager`. Inline at v1 — not a separate helper class. Migrates to `CharacterCreationPreview` only if the formula grows complex (real per-pick stat contributions). Not now.

### v1 formula (placeholder)

```
hp_min = 10 + KindredLibrary.get_hp_bonus(kindred_id) + 1 * 6   # VIT floor = 1
hp_max = 10 + KindredLibrary.get_hp_bonus(kindred_id) + 4 * 6   # VIT ceiling = 4
speed  = 1 + KindredLibrary.get_speed_bonus(kindred_id)
STR / DEX / COG / WIL displayed as flat label "1–4"
```

### Wiring

`_on_pick_changed()` calls `_calc_preview()` and pushes results to preview labels. In B2, `_calc_preview()` exists as a stub (returns the dictionary but nothing renders it). B4 slots in the rendering without touching the manager.

---

## Save / Load Implications

**No new save fields needed for B2.**

The PC's identity picks (kindred, unit_class, background, kindred_feat_id, abilities, ability_pool) all serialize today via existing fields in `GameState._serialize_combatant()`.

**Portrait exception — deferred:** `CombatantData.portrait` is a `Texture2D` (not serializable). At v1 all portrait options render as `res://icon.svg` (placeholder), so losing the portrait pick on save/load is invisible to the player. When real portrait art ships, add `portrait_id: String` to `CombatantData`, serialize it in `_serialize_combatant()` / `_deserialize_combatant()`, and restore the texture on load. That work belongs in the art integration pass.

`GameState.reset()` already clears `party = []`, so a new run always starts clean. No additional wiring needed.

---

## Testing

### Unit-testable (no scene, plain `assert()` in `/tests/`)

File: `tests/test_character_creation.gd`

- **`_build_pc()` correctness** — given a fixed set of picks, assert:
  - `kindred_feat_id` matches `KindredLibrary.get_feat_id(kindred_id)`
  - `abilities[0]` matches the class's `starting_ability_id`
  - `abilities[1]` matches the background's `starting_ability_id`
  - `ability_pool` contains both, deduped (if class + bg share an ability, pool has it once)
  - `abilities` is exactly 4 slots; slots 2–3 are `""`
  - `current_hp == hp_max` and `current_energy == energy_max` at creation
  - `is_player_unit == true`, `archetype_id == "RogueFinder"`
- **Dial index wrap-around** — index 0 prev → last; last next → 0. Pure math.
- **Name randomization** — result is always a member of the kindred's pool; "Unit" fallback fires on empty pool.

### Manual (in-game click-through)

- Full new-run flow: Main Menu → Character Creation → Confirm → MapScene. PC appears alone in party (no allies).
- All four dials/dropdowns cycle through all options without error.
- 🎲 name button produces a name from the active kindred's pool; changing kindred and re-rolling gives pool-appropriate names.
- "Randomize All" populates all fields without crashing.
- Confirm with default values (no changes made) produces a valid, playable PC.
- Preview panel (B4) updates in real time as picks change.
- Continue from a saved run correctly restores the PC (kindred, class, background, abilities intact).

---

## Out of Scope

- Writing implementation code (scenes, scripts, tests) — execution is a separate session.
- Authoring new game content.
- Meta-progression gating (locked options, unlock screen) — Stage 2+.
- Portrait serialization — deferred to art integration pass.
- B3 (Dial UX) and B4 (preview panel) — separate future implementation plans.
