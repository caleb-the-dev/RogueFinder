# System: Combat Manager

> Last updated: 2026-04-15 (Session 6 — ActionMenu, ability targeting flow, _apply_effects, EffectData dispatch)

---

## What This System Owns

Owns the entire combat encounter. Responsible for the turn state machine, all player input routing, the ability targeting flow, effect application, enemy AI, and win/lose conditions. Builds every other system node at scene start — it is the scene root.

Does **NOT** own: grid math (see `grid_system.md`), unit visuals/HP state (see `unit_system.md`), QTE execution (see `qte_system.md`), UI display (see `hud_system.md`).

---

## Core Files

| File | Scene | Role |
|------|-------|------|
| `scripts/combat/CombatManager3D.gd` | `scenes/combat/CombatScene3D.tscn` | **Active** — 3D state machine |
| `scripts/combat/CombatManager.gd` | `scenes/combat/CombatScene.tscn` | Legacy 2D — reference only |

`CombatScene3D.tscn` is the active entry point. `main.tscn` loads it.

---

## Where NOT to Look

- **Damage calculation is NOT in Unit3D** — `_apply_effects()` in CombatManager3D owns all effect math; Unit3D only exposes `take_damage()` and `heal()`.
- **Ability definitions are NOT here** — see `AbilityLibrary.gd` and `combatant_data.md`.
- **Grid highlighting is NOT here** — `Grid3D.highlight_cells()` / `Grid3D.clear_highlights()` are called from here but the logic lives in `Grid3D`.
- **QTE timing/display is NOT here** — `QTEBar.gd` owns that; CM3D only calls `start_qte()` and listens for `qte_resolved`.

---

## Dependencies

| System | How it's used |
|--------|--------------|
| **Grid3D** | Cell queries (`is_valid`, `is_occupied`, `get_unit_at`), move range, highlights, world↔grid math |
| **Unit3D** | HP/energy reads, `take_damage()`, `heal()`, `move_to()`, `play_attack_anim()`, `reset_turn()`, signal subscriptions |
| **QTEBar** | `start_qte()` call; listens for `qte_resolved(accuracy)` signal |
| **CameraController** | Built by CM3D; `trigger_shake()` called on successful hit |
| **UnitInfoBar** | `show_for(unit)` on single-click; `refresh(unit)` after damage; `hide_bar()` on deselect |
| **StatPanel** | `show_for(unit)` on double-click; `hide_panel()` on deselect / combat end |
| **ActionMenu** | `show_for(unit)` on player unit selection; listens for `ability_selected(id)` and `consumable_selected()` |
| **ArchetypeLibrary** | `create(archetype_id, name, is_player)` to build all units at scene start |
| **AbilityLibrary** | `get_ability(id)` to resolve `_pending_ability` before targeting |

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

WIN  → prints "YOU WIN"
LOSE → prints "GAME OVER"
```

### PlayerMode sub-state (during PLAYER_TURN)

```
IDLE
  └─[left-click player unit]─→ STRIDE_MODE

STRIDE_MODE
  └─[click move tile]────────→ IDLE (unit moved, re-select to act)
  └─[ActionMenu: ability]────→ ABILITY_TARGET_MODE
  └─[ActionMenu: consumable]─→ IDLE (consumable used, no target needed)
  └─[click elsewhere]────────→ IDLE

ABILITY_TARGET_MODE  (purple highlights; unit is _selected_unit, ability is _pending_ability)
  └─[click valid target]─────→ QTE_RUNNING
  └─[ESC / click elsewhere]──→ STRIDE_MODE (cancel targeting)

QTE_RUNNING  (blocks all input until qte_resolved fires)
  └─[qte_resolved(accuracy)]─→ STRIDE_MODE or IDLE (after _apply_effects)
```

---

## Signals Listened To

| Signal | Source | Handler |
|--------|--------|---------|
| `qte_resolved(accuracy)` | QTEBar | `_on_qte_resolved(accuracy)` |
| `ability_selected(ability_id)` | ActionMenu | `_on_ability_selected(ability_id)` |
| `consumable_selected()` | ActionMenu | `_on_consumable_selected()` |

*(CM3D emits no external signals in the 3D version — it is the root.)*

---

## Public Methods

None — CombatManager3D is the scene root. All other systems signal up to it.

---

## Key Internal Methods

| Method | Purpose |
|--------|---------|
| `_ready()` | Builds entire scene: env → camera → grid → units → UI |
| `_unhandled_input(event)` | All player input. Uses `_unhandled_input` so GUI (StatPanel, ActionMenu) consumes events first. Swallows all events when StatPanel is open except ESC. |
| `_handle_left_click()` | Single-click: raycast cell → select/move/attack; shows ActionMenu for player units, UnitInfoBar for all |
| `_handle_double_click()` | Double-click: raycast cell → opens StatPanel |
| `_on_ability_selected(id)` | Resolves ability via AbilityLibrary, stores in `_pending_ability`, enters ABILITY_TARGET_MODE, highlights valid targets |
| `_try_ability_target(cell)` | Called when player clicks a cell in ABILITY_TARGET_MODE; validates target, deducts energy, triggers QTE |
| `_on_qte_resolved(accuracy)` | Calls `_apply_effects(_pending_unit, _pending_ability, accuracy)`; checks auto-end; refreshes UnitInfoBar |
| `_apply_effects(caster, target, ability, accuracy)` | Loops `ability.effects`; dispatches per EffectType; HARM/MEND/BUFF/DEBUFF implemented; FORCE/TRAVEL are `pass` stubs |
| `_apply_stat_delta(unit, stat_name, delta)` | Modifies `unit.data.<stat>` and clamps to `[0, 5]`. Stat changes are NOT reset at combat end (future task). |
| `_on_consumable_selected()` | Marks consumable used; restores HP (placeholder effect); hides ActionMenu |
| `_request_end_player_turn()` | Space key handler: confirm dialog if any unit can still act |
| `_check_auto_end_turn()` | After each action: auto-ends turn when no player can still take an active action |
| `_run_enemy_turn()` | Iterates enemy units; simulates QTE via `qte_resolution` stat; 0.65 s delay between enemies |
| `_check_win_lose()` | Checks for all-dead on either side; transitions to WIN/LOSE |
| `_unit_can_still_act(unit)` | Returns true if unit is alive, has energy ≥ lowest ability cost, and `has_acted` is false |

---

## Damage / Effect Formulas

```
# HARM / MEND
value = max(1, round(accuracy × (base_value + caster.attribute_value)))

# BUFF / DEBUFF
flat base_value applied; accuracy < 0.3 = miss

# FORCE
tiles_pushed = round(accuracy × base_value)   [stub — not yet implemented]

# TRAVEL
base_value tiles always; accuracy = success threshold only   [stub]
```

`attribute_value` is determined by `ability.attribute` enum → `caster.data.strength / dexterity / etc.`

---

## Key Patterns & Gotchas

- **`_pending_ability` and `_pending_target`** — stored on CM3D between `_on_ability_selected()` and `_on_qte_resolved()`. Both are cleared after `_apply_effects()` completes.
- **`_unhandled_input` not `_input`** — must stay `_unhandled_input` or GUI nodes stop capturing clicks correctly. See `feedback_godot_input.md` in memory.
- **Energy deducted before QTE fires** — the energy cost is spent in `_try_ability_target()`, not after the QTE. If QTE fails (low accuracy), energy is still spent.
- **`_apply_effects()` is single-pass** — TRAVEL abilities need a second input phase (player picks destination) that breaks this flow. The plan is a new `PlayerMode.TRAVEL_DESTINATION` state. Do not add `await` inside `_apply_effects()`.
- **`_calculate_damage()` is dead code** — no longer called anywhere as of Session 6. Safe to delete when convenient.
- **AoE shapes (CONE/LINE/RADIAL) behave like SINGLE** — placeholder until per-shape resolution is implemented. See `docs/session_handoff_ability_shapes.md` for the implementation plan.

---

## Recent Changes

| Date | Change |
|---|---|
| 2026-04-15 | Added `_apply_effects()` dispatching all EffectTypes; HARM/MEND/BUFF/DEBUFF functional; FORCE/TRAVEL stubs |
| 2026-04-15 | Added `ABILITY_TARGET_MODE` PlayerMode sub-state; `_pending_ability` flow; `_try_ability_target()` |
| 2026-04-15 | Wired ActionMenu signals (`ability_selected`, `consumable_selected`); consumable use flow |
| 2026-04-14 | Added `_unit_can_still_act()` for auto-end-turn; removed [A] key shortcut |
| 2026-04-14 | Added `_request_end_player_turn()` with Space key + confirm dialog |
