# System: Combat Manager

> Last updated: 2026-04-23 (S28 — kindred field displayed in CombatActionPanel; map audit grooming)

---

## What This System Owns

Owns the entire combat encounter. Responsible for the turn state machine, all player input routing, the ability targeting flow (including AoE shapes and hover previews), effect application, enemy AI, and win/lose conditions. Builds every other system node at scene start — it is the scene root.

Does **NOT** own: grid math (see `grid_system.md`), unit visuals/HP state (see `unit_system.md`), QTE execution (see `qte_system.md`), UI display (see `hud_system.md`).

---

## Core Files

| File | Scene | Role |
|------|-------|------|
| `scripts/combat/CombatManager3D.gd` | `scenes/combat/CombatScene3D.tscn` | **Active** — 3D state machine |
| `scripts/combat/CombatManager.gd` | `scenes/combat/CombatScene.tscn` | Legacy 2D — reference only |

`CombatScene3D.tscn` is the active combat scene. Reached via `MainMenuScene` → `MapScene` → node click → `change_scene_to_file()`. `main.tscn` loads `MainMenuScene.tscn`.

---

## Where NOT to Look

- **Damage calculation is NOT in Unit3D** — `_apply_effects()` in CombatManager3D owns all effect math; Unit3D only exposes `take_damage()` and `heal()`.
- **Ability definitions are NOT here** — see `AbilityLibrary.gd` and `combatant_data.md`.
- **Grid highlighting is NOT here** — `Grid3D.set_highlight()` / `Grid3D.clear_highlights()` are called from here but the logic lives in `Grid3D`.
- **QTE timing/display is NOT here** — `QTEBar.gd` owns that; CM3D only calls `start_qte()` and listens for `qte_resolved`.

---

## Dependencies

| System | How it's used |
|--------|--------------|
| **Grid3D** | Cell queries (`is_valid`, `is_occupied`, `get_unit_at`), move range, highlights, world↔grid math |
| **Unit3D** | HP/energy reads, `take_damage()`, `heal()`, `move_to()`, `play_attack_anim()`, `reset_turn()`, `add_stat_effect()`, signal subscriptions |
| **QTEBar** | `start_qte()` call; listens for `qte_resolved(accuracy)` signal |
| **CameraController** | Built by CM3D; `trigger_shake()` called on successful hit |
| **UnitInfoBar** | `show_for(unit)` on single-click; `refresh(unit)` after damage; `hide_bar()` on deselect |
| **StatPanel** | `show_for(unit)` on double-click; `hide_panel()` on deselect / combat end |
| **CombatActionPanel** | `open_for(unit, camera)` on any unit click (player=interactive, enemy=read-only); listens for `ability_selected(id)` and `consumable_selected()`; internal var is `_action_menu` (legacy naming — not a separate class) |
| **ArchetypeLibrary** | `create(archetype_id, name, is_player)` for enemy units only (player units come from `GameState.party`) |
| **GameState** | `GameState.party` read in `_setup_units()`; `GameState.save()` called on permadeath and combat end |
| **AbilityLibrary** | `get_ability(id)` to resolve `_pending_ability` before targeting |
| **EndCombatScreen** | Built in `_setup_ui()`; `show_victory()` called on win. Defeat path bypasses it entirely — `_show_run_end_overlay()` handles defeat. |
| **RunSummaryScene** | Loaded via `change_scene_to_file()` after the run-end overlay timer expires |
| **RewardGenerator** | `roll(3)` called on victory to populate the reward panel |

---

## State Machine

### Top-level phase

```
PLAYER_TURN
  └─[all player units acted]─→ ENEMY_TURN
  └─[Space confirm]──────────→ ENEMY_TURN

ENEMY_TURN
  └─[all enemies processed]─→ PLAYER_TURN
                            └─→ WIN / LOSE

WIN / LOSE → status label update; no further input accepted
```

### PlayerMode sub-state (during PLAYER_TURN)

```
IDLE
  └─[left-click player unit]──────→ STRIDE_MODE

STRIDE_MODE
  └─[click move tile]─────────────→ IDLE (unit moved; re-select to act)
  └─[CombatActionPanel: ability]──→ ABILITY_TARGET_MODE
  └─[CombatActionPanel: consumable]→ IDLE (consumable used; panel refreshes in-place)
  └─[click elsewhere]─────────────→ IDLE

ABILITY_TARGET_MODE  (purple highlights; _selected_unit + _pending_ability set)
  └─[SELF shape]──────────────────→ QTE_RUNNING (skips target pick)
  └─[click valid SINGLE target]───→ QTE_RUNNING
  └─[click valid AoE cell]────────→ QTE_RUNNING  (_aoe_origin stored)
  └─[ESC / invalid click]─────────→ STRIDE_MODE (cancel)
  └─[mouse motion, CONE/ARC/RADIAL]→ _handle_shape_hover() updates preview

QTE_RUNNING  (blocks all input until qte_resolved fires)
  └─[qte_resolved(multiplier)]────→ _on_qte_resolved:
        TRAVEL effect?  → TRAVEL_DESTINATION
        AoE?            → STRIDE_MODE / IDLE (after shape effects applied)
        Single?         → STRIDE_MODE / IDLE (after effects applied)

TRAVEL_DESTINATION  (blue tiles; player picks where to land)
  └─[click valid tile]────────────→ IDLE (unit repositioned)
  └─[ESC / invalid click]─────────→ IDLE (cancelled)
```

---

## Signals Listened To

| Signal | Source | Usage |
|--------|--------|-------|
| `qte_resolved(multiplier: float)` | QTEBar | Awaited inline via `await _qte_bar.qte_resolved` inside `_run_harm_defenders()` — no signal handler |
| `ability_selected(ability_id)` | CombatActionPanel | `_on_ability_selected(ability_id)` |
| `consumable_selected()` | CombatActionPanel | `_on_consumable_selected()` |

*(CM3D emits no external signals — it is the scene root.)*

---

## Public Methods

None — CombatManager3D is the scene root. All other systems signal up to it.

---

## Key Internal Methods

| Method | Purpose |
|--------|---------|
| `_ready()` | Builds entire scene: env → camera → grid → units → UI |
| `_unhandled_input(event)` | All player input. `_unhandled_input` so GUI nodes consume events first. StatPanel open: swallows all except ESC. Mouse motion in AoE target mode: calls `_handle_shape_hover()`. |
| `_handle_left_click()` | Raycast cell → delegates to `_try_select_unit`, `_try_move`, `_try_ability_target`, or `_try_travel_destination` based on mode |
| `_handle_double_click()` | Opens StatPanel for any clicked unit |
| `_on_ability_selected(id)` | Resolves ability via AbilityLibrary; enters ABILITY_TARGET_MODE; highlights based on TargetShape |
| `_try_ability_target(cell)` | SINGLE → `_initiate_action`; AoE shapes → store `_aoe_origin`, call `_initiate_aoe_action` |
| `_initiate_action(attacker, target)` | Spends energy + marks acted; detects TRAVEL → destination mode; applies non-HARM effects; awaits `_run_harm_defenders` |
| `_initiate_aoe_action(attacker, origin_world)` | AoE equivalent of `_initiate_action`; collects all hit units, applies non-HARM to all, then queues HARM through `_run_harm_defenders` |
| `_apply_non_harm_effects(ability, caster, target, blast_origin)` | Applies MEND/BUFF/DEBUFF/FORCE at full strength (multiplier 1.0). HARM and TRAVEL skipped. |
| `_get_harm_effect(ability)` | Returns the first HARM EffectData in an ability, or null. |
| `_run_harm_defenders(caster, defenders, effect, energy_cost)` | Sequential HARM loop: player-controlled defenders see QTE bar (await `start_qte(energy_cost, caster)`); AI-controlled defenders instant-sim via `qte_resolution`. Applies damage per-defender. |
| `_defender_roll_to_dmg_multiplier(roll)` | Maps defender QTE roll (1.25/1.0/0.75/0.25) to damage multiplier (0.5/0.75/1.0/1.25). |
| `_apply_stat_delta(unit, stat, delta)` | Modifies `unit.data.<stat>`, clamps [0,5], calls `unit.add_stat_effect()` to record named status |
| `_apply_force(caster, target, effect, blast_origin)` | Slides target along computed direction for `base_value` tiles; stops at wall/unit. Tracks full path; applies 2 HP hazard damage for **every** hazard cell traversed (including landing cell). Direction from `effect.force_type` (PUSH/PULL/LEFT/RIGHT/RADIAL). |
| `_get_shape_cells(caster_pos, origin_pos, ability)` | Returns all cells in the ability's AoE footprint, respecting `passthrough` for CONE and RADIAL |
| `_get_units_in_cells(cells, applicable_to)` | Filters cell list to living units matching ALLY/ENEMY/ANY |
| `_handle_shape_hover()` | On mouse motion in ABILITY_TARGET_MODE: updates highlights live for CONE, ARC, RADIAL. RADIAL shows blast footprint at hovered cell; CONE/ARC shows directional shape at direction root. |
| `_highlight_travel_destinations(unit, effect)` | FREE → Manhattan ≤ base_value unoccupied cells; LINE → straight cardinal unoccupied cells |
| `_try_travel_destination(cell)` | Moves unit to chosen cell, updates occupancy, tweens position |
| `_request_end_player_turn()` | Space key: confirm dialog if any unit can still act |
| `_check_auto_end_turn()` | After each action: auto-ends turn when no player can still act |
| `_run_enemy_turn()` | Iterates enemy units via `_process_enemy_actions()`; regens energy + resets turns + **hazard damage for player units**; returns to PLAYER_TURN |
| `_process_enemy_actions()` | Full enemy AI loop: **hazard damage check** → target selection → consumable use → stride → ability selection → execute. 0.65s delay between enemies. |
| `_check_hazard_damage(unit)` | If unit is on a HAZARD cell and alive: `unit.take_damage(2)` + camera shake + `_check_win_lose()`. Called at: start of player turn (all player units), start of each enemy's action, and on entry after any voluntary move (stride, TRAVEL). FORCE traversal damage is handled separately inside `_apply_force()` via path iteration. |
| `_setup_environment_tiles()` | Calls `_grid.build_walls()` and `_grid.set_cell_type()` for the hardcoded placeholder layout. Called from `_ready()` after `_setup_grid()`. |
| `_pick_best_aoe_origin(enemy, ability)` | For AoE abilities: finds the origin cell that maximizes living player units hit (random tiebreak). RADIAL scans all cells in range; CONE/ARC/LINE try 4 cardinal roots. |
| `_check_win_lose()` | All-dead check on either side; calls `_end_combat()` |
| `_end_combat(player_won)` | Sets WIN/LOSE state; hides UI; restores `_attr_snapshots` for all player units. **Victory:** writes `current_hp`/`current_energy` back; PC revives at 1 HP if downed; calls `GameState.save()` then `EndCombatScreen.show_victory()`. **Defeat:** marks PC `is_dead = true`; calls `_capture_run_summary()` + `GameState.save()` + `_show_run_end_overlay()`. |
| `_capture_run_summary()` | Snapshots run stats into `GameState.run_summary` (pc_name, nodes_visited, nodes_cleared, threat_level, fallen_allies list) immediately before defeat transition |
| `_show_run_end_overlay()` | Builds a full-screen "The RogueFinder has perished." CanvasLayer (layer 20); awaits 3 seconds then `change_scene_to_file("res://scenes/ui/RunSummaryScene.tscn")` |
| `_toggle_debug_menu()` | T key: creates `_debug_menu` on first call (returns immediately, so menu appears); toggles visible on subsequent presses |
| `_unit_can_still_act(unit)` | True if alive, has_acted=false, energy ≥ lowest affordable ability cost |

---

## Effect Formulas

**HARM** (defender-driven):
```
defender_roll  = player QTE result OR _qte_resolution_to_multiplier(defender.data.qte_resolution)
dmg_multiplier = _defender_roll_to_dmg_multiplier(defender_roll)
               : 1.25→0.5, 1.0→0.75, 0.75→1.0, 0.25→1.25

dmg = max(1, round(dmg_multiplier * (effect.base_value + caster.data.attack)))
```

**MEND** (auto-resolve, full strength, no QTE):
```
heal = max(1, round(effect.base_value))
```

**BUFF / DEBUFF** (auto-resolve, full strength, no QTE):
```
delta = max(1, effect.base_value)  applied to target_stat, clamped [0,5]
```

**FORCE** (auto-resolve, always displaces, no QTE):
```
slides target along ForceType direction for base_value tiles (or until wall/unit)
```

**TRAVEL** (auto-resolve, always succeeds, no QTE):
```
enters TRAVEL_DESTINATION mode immediately; player picks destination tile
```

`caster.data.attack` = `5 + strength + equip_bonus`

---

## AoE Shape Details

| Shape | Highlight step | Footprint |
|-------|---------------|-----------|
| SELF | None (auto) | Caster only |
| SINGLE | Highlights valid units within range | 1 cell |
| ARC | 4 cardinal roots; hover shows 3-cell arc preview | 3 cells at distance 1: left, center, right |
| CONE | 4 cardinal roots; hover shows full shape preview | 9 cells: stem(1) + crossbar(3) + back row(5). Unit at stem blocks crossbar+back if passthrough=false |
| LINE | All cells along 4 cardinal axes up to tile_range | Ray until wall/unit (stops unless passthrough=true) |
| RADIAL | All cells within tile_range of caster | Diamond ≤ 2 Manhattan. Without passthrough, pure cardinal cells at distance 2 blocked by occupied distance-1 neighbors |

---

## Stat Effect Tracking (`STAT_STATUS_NAMES`)

Named status effects are recorded on each unit when `_apply_stat_delta()` fires:

| Attribute | Buff name | Debuff name |
|-----------|-----------|-------------|
| STRENGTH | Empowered | Weakened |
| DEXTERITY | Hasted | Slowed |
| COGNITION | Focused | Muddled |
| VITALITY | Fortified | Vulnerable |
| WILLPOWER | Resolute | Demoralized |

Stored in `unit.stat_effects: Array[Dictionary]` as `{display_name, stat, delta}`. Displayed in UnitInfoBar (colored chips) and StatPanel (full list). Buff/debuff billboard indicators appear above world units.

---

## Key Patterns & Gotchas

- **`_unhandled_input` not `_input`** — must stay `_unhandled_input` or GUI nodes stop capturing clicks. See memory `feedback_godot_input.md`.
- **`_pending_ability` and `_aoe_origin`** — stored between `_on_ability_selected()` and action resolution. Both cleared after resolution.
- **Energy deducted before effects resolve** — spent at the top of `_initiate_action()` / `_initiate_aoe_action()`. An ability still costs energy even if no HARM effect is present.
- **TRAVEL is immediate** — detected in `_initiate_action()` before any effect loop; enters `TRAVEL_DESTINATION` PlayerMode directly (no QTE, always succeeds).
- **Defender-driven QTE**: `_run_harm_defenders()` is `await`-ed inline. Player-controlled defenders see the bar and input; AI defenders instant-sim silently. State = QTE_RUNNING during any player-defender QTE.
- **`_apply_force` uses `target.move_to()`** — forced displacement moves the unit but does NOT consume `remaining_move`. Forced movement is involuntary and does not affect the stride budget.
- **Hazard damage has two triggers** — `_check_hazard_damage()` fires on voluntary movement entry (stride, TRAVEL) and at start-of-turn. FORCE traversal damage is different: `_apply_force()` iterates the full path and calls `unit.take_damage(2)` + `_check_win_lose()` directly for each hazard cell crossed — it does NOT call `_check_hazard_damage()`.
- **`_calculate_damage()` is dead code** — safe to delete when convenient.
- **`_attr_snapshots: Dictionary`** — per-unit attribute baseline recorded in `_setup_units()`. `_end_combat()` restores these on both win and defeat so stat-delta mutations never bleed into the next combat.
- **`_setup_units()` reads `GameState.party`** — passes the same `CombatantData` resource instance, not a copy. Mutations via `_apply_stat_delta()` hit the live party member, which is why snapshot/restore is mandatory.
- **Dead members are skipped on spawn** — if `cd.is_dead == true`, no unit is created for that party slot. Fewer than 3 player units may enter combat.
- **"Redo" reloads CombatScene3D with current party state** — after Slice 3 it re-uses the (possibly damaged) party, not a fresh one. This is intentional.
- **Ally permadeath vs PC permadeath are separate paths** — `_on_unit_died()` only sets `is_dead = true` and saves for non-RogueFinder player units (allies). The PC's death is deferred to `_end_combat()`: on victory the PC revives at 1 HP; on defeat `_end_combat()` marks the PC dead and triggers the run-end flow. Check `unit.data.archetype_id != "RogueFinder"` before touching `is_dead` in `_on_unit_died()`.
- **Defeat path does NOT use EndCombatScreen** — it calls `_show_run_end_overlay()` directly. `EndCombatScreen.show_defeat()` is now dead code (no callers).

---

## Recent Changes

| Date | Change |
|---|---|
| 2026-04-26 | QTE Session B — world-space bar + camera focus. `_run_harm_defenders` now awaits `_camera_rig.focus_on(caster.global_position).finished` (0.5 s) + 0.25 s settle before calling `start_qte(energy_cost, caster)`. After `qte_resolved` fires, calls `_camera_rig.restore()` (fire-and-forget). `start_qte` signature changed to `(energy_cost: int, attacker: Node3D)`. |
| 2026-04-26 | QTE reactive overhaul (Session A) — defender-driven HARM-only QTE. Deleted `_on_qte_resolved`, `_apply_effects`. Added `_apply_non_harm_effects`, `_get_harm_effect`, `_run_harm_defenders`, `_defender_roll_to_dmg_multiplier`. Energy spent upfront in `_initiate_action`. TRAVEL always succeeds (no QTE miss). Enemy actions use `_run_harm_defenders` so player units see QTE when defending. |
| 2026-04-23 | S28 Kindred display — CombatActionPanel renders a small muted kindred label below unit name for both player and enemy views (`_kindred_label`). No CombatManager3D behavior change. |
| 2026-04-20 | S26+S27 UI overhaul — radial ActionMenu deleted; replaced by right slide-in `CombatActionPanel` (layer 12). CM3D's internal var is still named `_action_menu` (legacy) but the type is `CombatActionPanel`. `_handle_unit_hover()` added for `InputEventMouseMotion` → UnitInfoBar hover (replaced click-persistent info bar). `_hover_cell` field added. Consumable use no longer closes the panel — CM3D calls `_action_menu.open_for()` again to refresh in place. |
| 2026-04-19 | Permadeath rules, PC revival, run-end flow, debug menu — allies die permanently in `_on_unit_died()`; PC death deferred to `_end_combat()`. Victory: PC downed → revives at 1 HP. Defeat: PC `is_dead = true` → `_capture_run_summary()` → 3-second overlay → `RunSummaryScene`. `_attr_snapshots` restored on both outcomes. T key toggles in-combat debug menu (Kill PC / Kill Allies / Kill Enemies / Kill Party / Damage PC -20). |
| 2026-04-19 | Slice 3 — `_setup_units()` rewritten to spawn player units from `GameState.party` (shared resource references, not fresh instances); dead members skipped. `_attr_snapshots` dict records per-unit attribute baseline at setup. Victory path writes `current_hp`/`current_energy` back to party members. `Unit3D.setup()` now seeds from `data.current_hp`/`data.current_energy` instead of max. |
| 2026-04-17 | Pathfinding + movement reservation: `_try_move()` now uses `Grid3D.find_path()` for cell-by-cell tween traversal (~0.12s per cell); hazard damage fires on each cell entered. Unit3D `has_moved` replaced by `remaining_move: int` (initialized to `data.speed` on `setup()`/`reset_turn()`); stride can be used multiple times per turn until budget reaches 0. `_select_unit()` and enemy stride both pass `unit.remaining_move` to `get_move_range()`. Enemy stride updated to use same cell-by-cell traversal. |
| 2026-04-17 | Win/lose screen: `_end_combat()` triggers `EndCombatScreen` for victory (3 rewards from `RewardGenerator.roll(3)`); K key debug hotkey instant-kills all enemies |
| 2026-04-17 | Hazard polish: on-entry damage fires for player stride, TRAVEL, and enemy stride; `_apply_force()` now tracks full path and applies 2 HP per hazard cell traversed (not just landing cell); enemy killed by stride hazard damage skips ability execution; win/lose guard added after player hazard loop in `_run_enemy_turn()` |
| 2026-04-17 | Added wall/hazard environment tiles: `_setup_environment_tiles()`, `_check_hazard_damage()`, player hazard damage at start of player turn, enemy hazard damage before each enemy acts |
| 2026-04-17 | Rewrote `_process_enemy_actions()`: target selection, consumable use (50% at <50% HP), greedy Manhattan stride, per-enemy ability filtering (energy + range + applicable_to), AoE origin selection via `_pick_best_aoe_origin()` |
| 2026-04-17 | Added `_pick_best_aoe_origin()`: scans RADIAL range or 4 cardinal roots; counts living player units per candidate; random tiebreak. AoE targeting uses caster-perspective applicable_to (ENEMY=players, ALLY=enemies, ANY=all) |
| 2026-04-15 | Implemented all AoE TargetShapes (CONE/ARC/LINE/RADIAL) with per-shape `_get_shape_cells()` |
| 2026-04-15 | Added TRAVEL_DESTINATION PlayerMode; `_highlight_travel_destinations` (FREE + LINE); `_try_travel_destination` |
| 2026-04-15 | Implemented FORCE: `_apply_force()` with ForceType (PUSH/PULL/LEFT/RIGHT/RADIAL) |
| 2026-04-15 | Added passthrough for CONE (stem blocks crossbar) and RADIAL (cardinal-only blocking) |
| 2026-04-15 | Added `_handle_shape_hover()` — live blast preview for CONE, ARC, RADIAL on mouse motion |
| 2026-04-15 | Named stat effects: `_apply_stat_delta()` calls `unit.add_stat_effect()` with display name |
| 2026-04-15 | Removed testing_mode (T key + GameState flag) — double-click StatPanel supersedes it |
