# System: Combat Manager

> Last updated: 2026-05-02 (Combat Pivot Slice 3 — CombatManagerAuto + LaneBoard + PlacementOverlay skeletons; USE_AUTOBATTLER_COMBAT flag in MapManager)

---

## Coexistence Strategy (Combat Pivot)

The old combat (CombatManager3D) and new autobattler (CombatManagerAuto) **coexist until Slice 7**. `MapManager.USE_AUTOBATTLER_COMBAT: bool = false` is the feature flag — flip it to `true` to load `CombatSceneAuto.tscn` instead of `CombatScene3D.tscn`. Default is `false`; old combat runs by default. Slice 7 will flip it permanently, rip out 3D combat, and remove the constant.

---

## What This System Owns

Owns the entire combat encounter. Responsible for the turn state machine, all player input routing, the ability targeting flow (including AoE shapes and hover previews), effect application, enemy AI, and win/lose conditions. Builds every other system node at scene start — it is the scene root.

Does **NOT** own: grid math (see `grid_system.md`), unit visuals/HP state (see `unit_system.md`), QTE execution (see `qte_system.md`), UI display (see `hud_system.md`).

---

## Core Files

| File | Scene | Role |
|------|-------|------|
| `scripts/combat/CombatManager3D.gd` | `scenes/combat/CombatScene3D.tscn` | **Active** — 3D tactical grid state machine |
| `scripts/combat/CombatManagerAuto.gd` | `scenes/combat/CombatSceneAuto.tscn` | **Skeleton** — autobattler (Slice 3); no tick loop yet; `class_name CombatManagerAuto` |
| `scripts/combat/LaneBoard.gd` | — | **Active data layer** — 3-lane × 2-side board; `class_name LaneBoard extends RefCounted`; used by CombatManagerAuto |
| `scripts/ui/PlacementOverlay.gd` | `scenes/ui/PlacementOverlay.tscn` | **Skeleton** — pre-fight lane assignment; `class_name PlacementOverlay extends CanvasLayer`; layer 22 |
| `scripts/combat/CombatManager.gd` | `scenes/combat/CombatScene.tscn` | Legacy 2D — reference only |

`CombatScene3D.tscn` is the active combat scene (flag false). `CombatSceneAuto.tscn` loads when flag true — currently just prints ready message, exits cleanly via PauseMenu ESC. Reached via `MainMenuScene` → `MapScene` → node click → `change_scene_to_file()`. `main.tscn` loads `MainMenuScene.tscn`.

---

## LaneBoard API

`LaneBoard` is a pure-data `RefCounted` — no Node, no scene. Holds `CombatantData` references by (lane_index, side).

| Method | Signature | Description |
|--------|-----------|-------------|
| `place` | `(unit: CombatantData, lane: int, side: String)` | Stores unit in slot; last-write-wins (no occupancy check) |
| `remove` | `(lane: int, side: String)` | Clears slot to null |
| `get_unit` | `(lane: int, side: String) -> CombatantData` | Returns unit or null; returns null for out-of-range lane |
| `get_opposite` | `(unit: CombatantData) -> CombatantData` | Finds unit's lane, returns the unit directly across; null if not on board |
| `get_lane_of` | `(unit: CombatantData) -> int` | Returns lane index 0–2, or -1 if not on board |
| `get_side_of` | `(unit: CombatantData) -> String` | Returns "ally" / "enemy" / "" |
| `get_adjacent_lane_units` | `(lane: int, side: String) -> Array[CombatantData]` | Up to 2 non-null units in lanes ±1 |
| `get_all_on_side` | `(side: String) -> Array[CombatantData]` | All non-null units on one side |
| `is_side_wiped` | `(side: String) -> bool` | True if all units on that side have `current_hp ≤ 0` or are null |

Constants: `LANE_COUNT = 3`, `SIDES = ["ally", "enemy"]`. Sides: `"ally"` = player side, `"enemy"` = enemy side.

**Gotcha:** `place()` is destructive — no occupancy check. Caller is responsible for not double-placing. Slot 0–2 are valid indices; anything else returns null from `get_unit()`.

---

## PlacementOverlay API (Skeleton)

Layer 22 (above PartySheet 20, below PauseMenu 26). Invisible by default (`visible = false`).

| Method/Signal | Description |
|---|---|
| `show_placement(party: Array[CombatantData])` | Defaults each unit to lane = its index; sets visible; Slice 4 builds real drag UI |
| `placement_locked(party_by_lane: Array)` | Emitted when Begin pressed; carries 3-element Array (CombatantData per lane) |

Not wired into CombatManagerAuto yet — Slice 4 connects it.

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
| **CombatActionPanel** | `open_for(unit, camera)` on any unit click (player=interactive, enemy=read-only); listens for `ability_selected(id)`, `consumable_selected()`, and `recruit_selected()`; internal var is `_action_menu` (legacy naming — not a separate class) |
| **RecruitBar** | `start_recruit_qte(base_chance, target)` called from `_initiate_recruit()`; awaits `recruit_resolved(result)` inline |
| **EnemyAI** | `choose_action(enemy, allies, hostiles, grid)` called per enemy in `_process_enemy_actions()`; returns `{target, ability}` or `{null, null}` |
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
  └─[CombatActionPanel: recruit]──→ RECRUIT_TARGET_MODE (Pathfinder only)
  └─[click elsewhere]─────────────→ IDLE

ABILITY_TARGET_MODE  (purple highlights; _selected_unit + _pending_ability set)
  └─[SELF shape]──────────────────→ QTE_RUNNING (skips target pick)
  └─[click valid SINGLE target]───→ QTE_RUNNING
  └─[click valid AoE cell]────────→ QTE_RUNNING  (_aoe_origin stored)
  └─[ESC / invalid click]─────────→ STRIDE_MODE (cancel)
  └─[mouse motion, CONE/ARC/RADIAL]→ _handle_shape_hover() updates preview

RECRUIT_TARGET_MODE  (teal highlights on enemies ≤3 tiles; _recruit_caster set)
  └─[click teal enemy]────────────→ QTE_RUNNING → _initiate_recruit()
  └─[ESC / click non-teal]────────→ STRIDE_MODE (cancel; no energy spent)
  └─[mouse motion over teal enemy]→ odds label shown above target ("Very Low"–"Very High")

QTE_RUNNING  (blocks all input until qte_resolved or recruit_resolved fires)
  └─[qte_resolved(multiplier)]────→ _on_qte_resolved:
        TRAVEL effect?  → TRAVEL_DESTINATION
        AoE?            → STRIDE_MODE / IDLE (after shape effects applied)
        Single?         → STRIDE_MODE / IDLE (after effects applied)
  └─[recruit_resolved(result)]────→ _initiate_recruit (resumed):
        success?        → recruit_attempt_succeeded.emit(target); STRIDE_MODE / IDLE
        failure?        → "Failed!" floating text; STRIDE_MODE / IDLE

TRAVEL_DESTINATION  (blue tiles; player picks where to land)
  └─[click valid tile]────────────→ IDLE (unit repositioned)
  └─[ESC / invalid click]─────────→ IDLE (cancelled)
```

---

## Signals Listened To

| Signal | Source | Usage |
|--------|--------|-------|
| `qte_resolved(multiplier: float)` | QTEBar | Awaited inline via `await _qte_bar.qte_resolved` inside `_run_harm_defenders()` — no signal handler |
| `recruit_resolved(result: float)` | RecruitBar | Awaited inline via `await _recruit_bar.recruit_resolved` inside `_initiate_recruit()` — no signal handler |
| `ability_selected(ability_id)` | CombatActionPanel | `_on_ability_selected(ability_id)` |
| `consumable_selected()` | CombatActionPanel | `_on_consumable_selected()` |
| `recruit_selected()` | CombatActionPanel | `_on_recruit_selected()` |

## Signals Emitted

| Signal | Args | When |
|--------|------|------|
| `recruit_attempt_succeeded` | `target: Unit3D` | Recruit QTE succeeds and randf() < final_chance. Emitted at the start of `_on_recruit_succeeded()` for external listeners. The full success path is handled internally via `await _on_recruit_succeeded(target)`. |

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
| `_apply_non_harm_effects(ability, caster, target, blast_origin)` | Applies MEND/BUFF/DEBUFF/FORCE at full strength (multiplier 1.0). HARM and TRAVEL skipped. BUFF resolution appends `ability.ability_id` to `target.active_buff_ability_ids`. DEBUFF resolution appends to `target.active_debuff_ability_ids` and increments `target.debuff_stat_stacks[target_stat]`. |
| `_get_harm_effect(ability)` | Returns the first HARM EffectData in an ability, or null. |
| `_run_harm_defenders(caster, defenders, effect, energy_cost, ability)` | Sequential HARM loop: player-controlled defenders see QTE bar; AI defenders instant-sim. Damage formula: `max(1, round(dmg_mult × (effect.base_value + _get_attribute_value(caster, ability.attribute))) - armor)`. `ability.attribute` determines which stat (STR/DEX/COG/etc.) scales the hit; `ability.damage_type` selects `physical_defense` or `magic_defense` on the defender. No separate attack stat. |
| `_defender_roll_to_dmg_multiplier(roll)` | Maps defender QTE roll (1.25/1.0/0.75/0.25) to damage multiplier (0.5/0.75/1.0/1.25). |
| `_apply_stat_delta(unit, stat, delta)` | Modifies `unit.data.<stat>` and calls `unit.add_stat_effect()` to record named status. Core attributes (STR/DEX/COG/VIT/WIL) clamp to `[0, 5]`; armor mods (`PHYSICAL_ARMOR_MOD` / `MAGIC_ARMOR_MOD`) write to `unit.data.physical_armor_mod` / `magic_armor_mod` and clamp to `[-10, 10]`. |
| `_setup_units()` | Checks `GameState.test_room_mode` first — if true, delegates entirely to `_setup_test_room_units()`. Otherwise spawns party + random enemies as normal. |
| `_setup_test_room_units()` | Dispatcher — picks a scenario from `GameState.test_room_kind` and forwards to `_spawn_test_room()`. Slice 3 rooms: `"ai_aoe_bomb"`, `"ai_finish_blow"`, `"ai_healer"`, `"ai_buff_debuff"`, `"ai_force_edge"`, `"ai_slice3_mix"`. Earlier rooms: `"ai_roles"`, `"ai_crit_heal"`, `"armor_mod"`, `"recruit_test"`. Default → armor showcase. |
| `_spawn_test_room(player_defs, enemy_defs, p_pos, e_pos)` | Generic spawner. `p_pos`/`e_pos` are typed `Array = []` (not `Array[Vector2i]`) due to a Godot 4.5 bug where omitted typed-array default params are passed as untyped at call sites. Internally uses `.assign()` to coerce to `Array[Vector2i]`. Calls `unit.setup()`, registers `_attr_snapshots`, connects `unit_died`. |
| `_armor_showcase_player_defs()` / `_armor_showcase_enemy_defs()` | Original dual-armor demo — Kara (magic) / Brak (physical) / Wren (mixed) vs Iron Wall (phys_armor 12) / Arcane Shell (magic_armor 12) / Balanced Guard (6/6). |
| `_armor_mod_player_defs()` / `_armor_mod_enemy_defs()` | Armor mod demo — Boran (Dwarf vanguard, owns `stone_guard`) / Velis (Human warden, owns `divine_ward`) / Rune (Gnome arcanist, magic damage caster) vs Stone Bruiser (heavy physical) / Pyromancer (heavy magic) / Twin Threat (mixed). All enemies sit at 4/4 armor so the player's defensive buffs visibly matter. |
| `_make_test_combatant(def: Dictionary) -> CombatantData` | Constructs a `CombatantData` from a flat Dictionary. Supports optional `"hp"` key to override `current_hp` (e.g., `"hp": 1` for recruit_test weaklings); defaults to `hp_max` if absent. |
| `_apply_force(caster, target, effect, blast_origin)` | Slides target along computed direction for `base_value` tiles; stops at wall/unit. Tracks full path; applies 2 HP hazard damage for **every** hazard cell traversed (including landing cell). Direction from `effect.force_type` (PUSH/PULL/LEFT/RIGHT/RADIAL). |
| `_get_shape_cells(caster_pos, origin_pos, ability)` | Returns all cells in the ability's AoE footprint, respecting `passthrough` for CONE and RADIAL |
| `_get_units_in_cells(cells, applicable_to)` | Filters cell list to living units matching ALLY/ENEMY/ANY |
| `_handle_shape_hover()` | On mouse motion in ABILITY_TARGET_MODE: updates highlights live for CONE, ARC, RADIAL. RADIAL shows blast footprint at hovered cell; CONE/ARC shows directional shape at direction root. |
| `_highlight_travel_destinations(unit, effect)` | FREE → Manhattan ≤ base_value unoccupied cells; LINE → straight cardinal unoccupied cells |
| `_try_travel_destination(cell)` | Moves unit to chosen cell, updates occupancy, tweens position |
| `_request_end_player_turn()` | Space key: confirm dialog if any unit can still act |
| `_check_auto_end_turn()` | After each action: auto-ends turn when no player can still act |
| `_run_enemy_turn()` | Iterates enemy units via `_process_enemy_actions()`; regens energy + resets turns + **hazard damage for player units**; returns to PLAYER_TURN |
| `_process_enemy_actions()` | Full enemy AI loop. Sorts `_enemy_units` by `EnemyAI.MOVE_PRIORITY` (HEALER first, CONTROLLER last) so support roles position before damage dealers. Per enemy: **hazard damage check** → `EnemyAI.pick_stride_target()` for move heuristic → consumable use → greedy Manhattan stride toward move target (FORCE-aware stride disabled pending Slice 4) → `EnemyAI.choose_action()` → if null skip; else set `enemy.last_ability_id`, spend energy, execute. 0.65s delay between enemies. |
| `_player_units_alive()` | Returns all living player-side Unit3D. Used by EnemyAI and the movement heuristic. |
| `_enemy_units_alive_excluding(self_enemy)` | Returns all living enemy-side Unit3D excluding the given unit. Used by EnemyAI for the allies array. |
| `_on_recruit_selected()` | Connected to `CombatActionPanel.recruit_selected`. Stores `_selected_unit` as `_recruit_caster`, enters `RECRUIT_TARGET_MODE`, clears highlights, teal-highlights living enemies ≤3 Manhattan tiles. |
| `_try_recruit_target(cell)` | Click handler in `RECRUIT_TARGET_MODE`. Teal cell → `_initiate_recruit(caster, target)`. Non-teal → `_cancel_recruit_targeting()`. |
| `_cancel_recruit_targeting()` | Clears `_recruit_caster`, hides odds label, calls `_select_unit(_selected_unit)` to re-open panel and restore STRIDE/IDLE. Free cancel — no energy spent. |
| `_initiate_recruit(caster, target)` | Commits the recruit: `spend_energy(RECRUIT_ENERGY_COST)`, `has_acted = true`, `open_for()` refresh; camera focus on target; awaits `_recruit_bar.recruit_resolved`; computes `final_chance = clamp(base × qte_mult, 0, 1)`; rolls `randf()`; on failure shows "Failed!" text + continues turn; on success emits `recruit_attempt_succeeded(target)` (Slice 4 handles the rest). |
| `_compute_recruit_base_chance(caster, target)` | Returns `clamp(hp_component × 0.80 + wil_delta × 0.20, 0.05, 0.95)`. `hp_component = 1 − target.current_hp/hp_max`; `wil_delta = (party_wil_sum − enemy_wil_sum) / 20.0`. |
| `_recruit_odds_label(base_chance)` | Maps float → qualitative string: <0.20 "Very Low", <0.40 "Low", <0.60 "Moderate", <0.80 "High", else "Very High". |
| `_qte_mult_to_recruit_mult(qte_mult)` | Passthrough mapping: 1.25→1.25, 1.0→1.0, 0.75→0.75, else→0.25. Makes intent explicit at call site. |
| `_show_recruit_fail_feedback(target)` | Shows "Failed!" floating text in red over the target unit via `target.show_floating_text()`. |
| `_show_recruit_odds(target)` | Creates or updates `_recruit_odds_label_node` (Label on `_recruit_odds_layer`); positions it via `Camera3D.unproject_position(target.global_position + Vector3(0, 2.5, 0))`; shows qualitative odds. Called from `_handle_unit_hover()` when hovering a teal enemy. |
| `_clear_recruit_odds_label()` | Hides `_recruit_odds_label_node`. Called on mode exit, cancel, deselect. |
| `_on_recruit_succeeded(target)` | **Async** — the full recruit success coroutine. Called via `await` in `_initiate_recruit()`. Sequence: (1) emit `recruit_attempt_succeeded`; (2) erase target from `_enemy_units`, clear grid cell; (3) show "Recruited!" floating text, wait 0.4 s, hide target; (4) `_build_follower(target.data)`; (5) `await _show_recruit_rename_prompt(follower)`; (6) `GameState.add_to_bench()` — if full, `await _show_bench_full_modal(follower)`; (7) `target.queue_free()`, camera shake, `_check_win_lose()`, turn cleanup. State remains `QTE_RUNNING` throughout steps 1–6 so no combat input is accepted during the modal flow. |
| `_build_follower(source)` | Copies all relevant fields from a captured enemy `CombatantData` into a new player-side `CombatantData`. Sets `is_player_unit = true`, `qte_resolution = 0.0`, `feat_ids = []`, HP/energy seeded to max. Level is `GameState.party[0].level` (falls back to 1 if party is empty — recruit_test room guard). `character_name` is left blank until the rename prompt fills it. |
| `_show_recruit_rename_prompt(follower)` | **Async** — builds a blocking CanvasLayer (layer 16) rename overlay. Pre-fills the name field from `KindredLibrary.get_name_pool(follower.kindred)`. Confirms on button click or Enter key. Validates: empty input re-fills from pool. Sets `follower.character_name` and emits `_recruit_rename_confirmed`. Cannot be cancelled. |
| `_show_bench_full_modal(follower)` | **Async** — builds a blocking CanvasLayer (layer 16) listing all 9 bench slots as buttons plus a "Lose Recruit" button. Releasing a slot calls `GameState.release_from_bench(idx)` + `add_to_bench(follower)` + `save()` then closes. "Lose Recruit" discards the follower (enemy already removed from combat). Emits `_bench_full_resolved`. |
| `_show_bench_add_label(world_pos)` | Fire-and-forget Label3D "Added to bench!" at the given world position, parented to CM3D so it's independent of the (now hidden) target Unit3D. Rises and fades over 2 s. |
| `_recruit_test_player_defs()` | Returns player def list for the `"recruit_test"` scenario: The RogueFinder (vit 10, high HP/energy), Ally A (vanguard), Ally B (warden). |
| `_recruit_test_enemy_defs()` | Returns enemy def list for `"recruit_test"`: 3 Whelps with `vit 1`, `qte 0.05`, `"hp": 1` override — trivially recruitable. |
| `_check_hazard_damage(unit)` | If unit is on a HAZARD cell and alive: `unit.take_damage(2)` + camera shake + `_check_win_lose()`. Called at: start of player turn (all player units), start of each enemy's action, and on entry after any voluntary move (stride, TRAVEL). FORCE traversal damage is handled separately inside `_apply_force()` via path iteration. |
| `_setup_environment_tiles()` | Calls `_grid.build_walls()` and `_grid.set_cell_type()` for the hardcoded placeholder layout. Called from `_ready()` after `_setup_grid()`. |
| `_pick_best_aoe_origin(enemy, ability)` | For AoE abilities: finds the origin cell that maximizes living player units hit (random tiebreak). RADIAL scans all cells in range; CONE/ARC/LINE try 4 cardinal roots. |
| `_check_win_lose()` | All-dead check on either side; calls `_end_combat()` |
| `_calc_gold_reward()` | Computes gold drop for a player victory. Averages level of non-dead party members (matching `grant_xp()` skip logic). Converts `GameState.threat_level` (0.0–1.0) to 0–100 int. Calls `RewardGenerator.gold_drop(ring, threat_int, avg_level)`. |
| `_end_combat(player_won)` | Sets WIN/LOSE state; hides UI; restores `_attr_snapshots` for all player units. Also clears all transient AI tracker fields on every unit (`active_buff_ability_ids`, `active_debuff_ability_ids`, `debuff_stat_stacks`, `last_ability_id`, `ai_override`). **Victory:** writes `current_hp`/`current_energy` back; PC revives at 1 HP if downed; calls `GameState.grant_xp(15)`; calls `_calc_gold_reward()` and adds result to `GameState.gold`; calls `GameState.save()` then `EndCombatScreen.show_victory(items, gold)`. **Defeat:** marks PC `is_dead = true`; calls `_capture_run_summary()` + `GameState.save()` + `_show_run_end_overlay()`. |
| `_capture_run_summary()` | Snapshots run stats into `GameState.run_summary` (pc_name, nodes_visited, nodes_cleared, threat_level, fallen_allies list) immediately before defeat transition |
| `_show_run_end_overlay()` | Builds a full-screen "The RogueFinder has perished." CanvasLayer (layer 20); awaits 3 seconds then `change_scene_to_file("res://scenes/ui/RunSummaryScene.tscn")` |
| `_toggle_debug_menu()` | T key: creates `_debug_menu` on first call (returns immediately, so menu appears); toggles visible on subsequent presses |
| `_unit_can_still_act(unit)` | True if alive, has_acted=false, and (energy ≥ lowest affordable ability cost OR unit is Pathfinder with energy ≥ 3 and bench not full). Pathfinder check: `unit.data == GameState.party[0]` in normal combat; falls back to `archetype_id == "RogueFinder"` when `test_room_kind == "recruit_test"` (party is empty in that scenario). |

---

## Effect Formulas

**HARM** (defender-driven):
```
defender_roll  = player QTE result OR _qte_resolution_to_multiplier(defender.data.qte_resolution)
dmg_multiplier = _defender_roll_to_dmg_multiplier(defender_roll)
               : 1.25→0.5, 1.0→0.75, 0.75→1.0, 0.25→1.25

armor = defender.data.physical_defense  (if ability.damage_type == PHYSICAL)
      | defender.data.magic_defense     (if ability.damage_type == MAGIC)
      | 0                               (if ability.damage_type == NONE)

dmg = max(1, round(dmg_multiplier * (effect.base_value + _get_attribute_value(caster, ability.attribute))) - armor)
```
`_get_attribute_value(caster, ability.attribute)` calls `caster.data.effective_stat(stat)` — raw attribute + all 6 bonus sources (equip/feat/class/kindred/bg/temp). A STR ability scales with effective STR; COG with effective COG; etc. No separate attack stat.

Armor is subtracted **after** the QTE roll multiplier, so armor is a flat post-roll mitigation.

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

| Attribute | Buff name | Debuff name | Floating text |
|-----------|-----------|-------------|---------------|
| STRENGTH | Empowered | Weakened | STR |
| DEXTERITY | Hasted | Slowed | DEX |
| COGNITION | Focused | Muddled | COG |
| VITALITY | Fortified | Vulnerable | VIT |
| WILLPOWER | Resolute | Demoralized | WIL |
| PHYSICAL_ARMOR_MOD | P.Hardened | P.Cracked | P.ARM |
| MAGIC_ARMOR_MOD | M.Warded | M.Exposed | M.ARM |

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
- **`_attr_snapshots: Dictionary`** — per-unit baseline recorded in `_setup_units()` (or `_setup_test_room_units()`). Keys: `strength`, `dexterity`, `cognition`, `vitality`, `willpower`, `physical_armor_mod`, `magic_armor_mod`. `_end_combat()` restores these on both win and defeat so stat-delta mutations (including transient armor mods) never bleed into the next combat. The armor mod keys are restored via `snap.get(..., 0)` so legacy in-flight snapshots stay safe.
- **`_setup_units()` reads `GameState.party`** — passes the same `CombatantData` resource instance, not a copy. Mutations via `_apply_stat_delta()` hit the live party member, which is why snapshot/restore is mandatory. Not true for test room units — they are created fresh and not stored in `GameState`.
- **Dead members are skipped on spawn** — if `cd.is_dead == true`, no unit is created for that party slot. Fewer than 3 player units may enter combat.
- **"Redo" reloads CombatScene3D with current party state** — after Slice 3 it re-uses the (possibly damaged) party, not a fresh one. This is intentional.
- **Ally permadeath vs PC permadeath are separate paths** — `_on_unit_died()` only sets `is_dead = true` and saves for non-RogueFinder player units (allies), and only when `GameState.test_room_mode` is false. PC death is deferred to `_end_combat()`.
- **Defeat path does NOT use EndCombatScreen** — it calls `_show_run_end_overlay()` directly. `EndCombatScreen.show_defeat()` is now dead code (no callers).
- **Test room mode bypasses all GameState mutations** — `_end_combat()` checks `GameState.test_room_mode`: if true, clears the flag, also resets `test_room_kind` to `"armor_showcase"`, shows a brief "TEST ROOM: Victory! / Defeated." status, waits 2.5 s, then returns to MapScene. No XP, no save, no EndCombatScreen, no run-end flow. Test room units are not in `GameState.party` so no HP/energy writeback occurs.
- **`_run_harm_defenders` now requires the parent `ability: AbilityData`** — added as 5th parameter so armor type can be looked up. All call sites (2 player-path, 3 enemy-path) pass `_pending_ability` or `chosen` respectively.

---

## Recent Changes

| Date | Change |
|---|---|
| 2026-05-02 | **Combat Pivot Slice 3 — autobattler scaffold.** `CombatManagerAuto.gd` added (`class_name CombatManagerAuto extends Node3D`): skeleton with `board: LaneBoard`, `start_combat(party, enemies)` (default lane placement), `end_combat(victory)`. `CombatSceneAuto.tscn` added (minimal). `LaneBoard.gd` added (`class_name LaneBoard extends RefCounted`): 3-lane × 2-side pure-data board; full API live (see table above). `PlacementOverlay.gd` added (`class_name PlacementOverlay extends CanvasLayer`, layer 22): `show_placement(party)`, `placement_locked` signal — stub, Slice 4 wires it. `MapManager.USE_AUTOBATTLER_COMBAT: bool = false` constant added to top of constants section — gates COMBAT/BOSS scene dispatch. 6 headless tests (`test_lane_board.gd/.tscn`) — all 6 pass. Note: `CombatManagerAuto.gd` is named `Auto` to avoid collision with legacy `CombatManager.gd` (2D, class_name `CombatManager`). |
| 2026-05-01 | **Enemy AI Slice 3 — within-bucket scoring + move priority + buff/debuff tracker.** `_process_enemy_actions()` now sorts `_enemy_units` by `EnemyAI.MOVE_PRIORITY` before iterating (HEALER=0 → CONTROLLER=4). `EnemyAI.pick_stride_target()` replaces random-hostile heuristic for the movement target. FORCE-aware CONTROLLER stride (`pick_force_stride_cell`) is disabled pending Slice 4 — all roles use greedy Manhattan. `_apply_non_harm_effects()` BUFF case: appends `ability.ability_id` to `target.active_buff_ability_ids`. DEBUFF case: appends to `target.active_debuff_ability_ids`, increments `target.debuff_stat_stacks[stat]`. `_end_combat()` clears all 5 transient AI fields on every unit after snapshot restore. `_cardinal_direction()`, `_get_shape_cells()`, and `_pick_best_aoe_origin()` now delegate to EnemyAI statics. `_spawn_test_room()` `p_pos`/`e_pos` params changed from `Array[Vector2i] = []` to `Array = []` + internal `.assign()` (Godot 4.5 typed-array default param bug). `_setup_test_room_units()` dispatcher extended with 6 new Slice 3 AI rooms. `MapManager` dev panel gains "AI SLICE 3 — SCORING" row of 6 buttons. |
| 2026-05-01 | **Enemy AI Slice 2 — EnemyAI module wired in.** `_process_enemy_actions()` refactored: old randi() target + ability picks replaced with `EnemyAI.choose_action(enemy, allies, hostiles, grid)`. Movement stride still uses a random hostile as a positioning heuristic (suboptimal for HEALER; fix is Slice 3). `enemy.last_ability_id = chosen.ability_id` set after each confirmed pick so EnemyAI can deprioritize repeats next turn. Two new private helpers: `_player_units_alive() -> Array[Unit3D]` and `_enemy_units_alive_excluding(self_enemy) -> Array[Unit3D]`. `_setup_test_room_units()` dispatcher extended: `"ai_roles"` → AI Roles scenario (Grunt/Alchemist/Cave Spider); `"ai_crit_heal"` → AI Crit-Heal scenario (Alchemist with `heal_burst` + Near-Dead Grunt at 1 HP + Healthy Grunt). `_ai_roles_*_defs()` and `_ai_crit_heal_*_defs()` factory methods added. EnemyAI added to Dependencies table. |
| 2026-04-29 | **Vendor Slice 1 — gold reward on combat victory.** `_calc_gold_reward() -> int` added: averages non-dead party level, converts `threat_level` to 0–100 int, calls `RewardGenerator.gold_drop(ring, threat, avg_level)`. `_end_combat(true)` now calls it and adds result to `GameState.gold` before saving. `show_victory()` now takes `gold_amount: int` as second argument. Gold line displayed in `EndCombatScreen` above item cards using Hire Roster gold color. |
| 2026-04-29 | **ATK stat removed.** `_run_harm_defenders` HARM formula changed from `base_value + caster.data.attack` to `base_value + _get_attribute_value(caster, ability.attribute)`. `_get_attribute_value` updated: now calls `unit.data.effective_stat(stat_key)` for each attribute instead of returning raw field value. `effective_stat()` is a new method on `CombatantData` (raw attribute + all 6 bonus sources — equip/feat/class/kindred/bg/temp). No separate "attack" stat exists. A STR ability scales with effective STR; a COG ability with effective COG; etc. `CombatantData.attack` property removed. |
| 2026-04-28 | **Follower Slice 4 — recruit success path + recruit_test room.** `_initiate_recruit()` success branch replaced: instead of emitting + doing turn cleanup inline, it now does `await _on_recruit_succeeded(target)` so the entire async flow (rename + bench-full modal) runs before the turn resumes. Two internal signals added: `_recruit_rename_confirmed` (one-shot, emitted by confirm button/Enter key) + `_bench_full_resolved` (emitted by slot-release or Lose Recruit). New methods: `_on_recruit_succeeded(target)`, `_build_follower(source)`, `_show_recruit_rename_prompt(follower)`, `_show_bench_full_modal(follower)`, `_show_bench_add_label(world_pos)`. `_make_test_combatant()` gained optional `"hp"` dict key to override `current_hp`. New `"recruit_test"` scenario: `_recruit_test_player_defs()` + `_recruit_test_enemy_defs()` (3 Whelps at 1 HP, qte 0.05). `_unit_can_still_act()` Pathfinder check extended: also matches `archetype_id == "RogueFinder"` when `test_room_kind == "recruit_test"`. MapManager dev menu gained "⊕ Test Room — Recruit" button. 11 new headless tests (`test_recruit_success.gd/.tscn`). Bug fix: `GameState.swap_active_bench()` added (was called by BadurgaManager but missing from GameState). |
| 2026-04-28 | **Follower Slice 3 — Recruit action.** `RECRUIT_ENERGY_COST: int = 3` constant added. `recruit_attempt_succeeded(target: Unit3D)` signal added (stub — Slice 4 connects it). `RECRUIT_TARGET_MODE` added to `PlayerMode` enum. New vars: `_recruit_caster: Unit3D`, `_recruit_bar: RecruitBar`, `_recruit_odds_layer: CanvasLayer`, `_recruit_odds_label_node: Label`. `_setup_ui()` instantiates `RecruitBar.tscn` + odds CanvasLayer (layer 6) + connects `_action_menu.recruit_selected`. `_handle_left_click()` dispatches to `_try_recruit_target()` in new mode. `_handle_unit_hover()` shows qualitative odds label over teal enemies. ESC in `RECRUIT_TARGET_MODE` calls `_cancel_recruit_targeting()` instead of full deselect. `_deselect()` clears `_recruit_caster` + hides odds label. `_unit_can_still_act()` returns true for Pathfinder when energy ≥ 3 and bench not full (prevents premature auto-end-turn). `_update_status()` extended for new mode. 8 new methods: `_on_recruit_selected`, `_try_recruit_target`, `_cancel_recruit_targeting`, `_initiate_recruit`, `_compute_recruit_base_chance`, `_recruit_odds_label`, `_qte_mult_to_recruit_mult`, `_show_recruit_fail_feedback`, `_show_recruit_odds`, `_clear_recruit_odds_label`. |
| 2026-04-27 | **Test room dispatcher — second scenario.** `_setup_test_room_units()` is now a dispatcher that reads `GameState.test_room_kind`. Original 3v3 dual-armor demo lives behind `"armor_showcase"` (default). New `"armor_mod"` scenario spawns Boran (Dwarf vanguard, `stone_guard`) / Velis (Human warden, `divine_ward`) / Rune (Gnome arcanist) vs Stone Bruiser / Pyromancer / Twin Threat — all enemies sit at 4/4 armor so the player's defensive buffs are consequential. Common spawning logic factored into `_spawn_test_room(player_defs, enemy_defs)`; per-scenario defs in `_armor_showcase_*` and `_armor_mod_*` getters. `_end_combat()` now resets `test_room_kind` to default alongside clearing `test_room_mode`. |
| 2026-04-27 | **Armor mod — runtime BUFF/DEBUFF lane.** `_apply_stat_delta` gained two cases: `PHYSICAL_ARMOR_MOD` and `MAGIC_ARMOR_MOD` write to `unit.data.physical_armor_mod` / `magic_armor_mod` (transient on `CombatantData`) and clamp to `[-10, 10]`. `STAT_STATUS_NAMES` + `STAT_ABBREV` extended with the new attributes (`P.Hardened`/`P.Cracked`/`P.ARM` and `M.Warded`/`M.Exposed`/`M.ARM`). `_attr_snapshots` build sites in both `_setup_units()` and `_setup_test_room_units()` now record `physical_armor_mod` + `magic_armor_mod`; `_end_combat()` restores them via `snap.get(..., 0)`. Powers `stone_guard` (Dwarf kindred ancestry) and `divine_ward` (Warden pool) — both previously no-ops because the JSON `"ARMOR_DEFENSE"` key didn't resolve to a real `Attribute` enum value. |
| 2026-04-27 | **Dual armor + test room.** `_run_harm_defenders` signature extended with `ability: AbilityData` (5th param); HARM formula now subtracts `physical_defense` or `magic_defense` based on `ability.damage_type` (NONE = 0 armor). All 5 call sites updated. `_setup_units()` now branches on `GameState.test_room_mode`: if true, calls `_setup_test_room_units()` (hardcoded 3v3 armor showcase). `_make_test_combatant(def)` helper builds `CombatantData` from flat dict. `_end_combat()` test room branch: clears flag, shows result text, waits 2.5 s, returns to map — no XP/save/rewards. `_on_unit_died()` ally permadeath save guarded by `not GameState.test_room_mode`. |
| 2026-04-27 | **XP on victory.** `_end_combat(true)` now calls `GameState.grant_xp(15)` immediately after writing HP/energy back, before `GameState.save()`. Debug menu (T key) gained two new buttons: "Grant XP +20" (calls `GameState.grant_xp(20)`) and "Force Level-Up" (directly increments `pc.level` by 1 and `pc.pending_level_ups` by 1 for all living party members; does not cross XP thresholds). Force Level-Up also increments `level` so the party sheet displays the correct level after picks. |
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
