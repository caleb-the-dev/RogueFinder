# System: Combat Manager

> Last updated: 2026-04-14 (Session 5 — input isolation for StatPanel; removed ATK/DEF/SPD from UnitInfoBar)

---

## Purpose

The Combat Manager is the **root authority** for a combat encounter. It owns the entire scene — building the environment, camera, grid, units, and UI entirely in `_ready()`. It runs the turn state machine, routes all player input, executes enemy AI, triggers the QTE flow, calculates damage, and decides win/lose conditions.

There are two versions: `CombatManager3D.gd` (active, 3D) and `CombatManager.gd` (legacy 2D, kept for reference).

---

## Core Nodes / Scripts

| File | Scene | Role |
|------|-------|------|
| `scripts/combat/CombatManager3D.gd` | `scenes/combat/CombatScene3D.tscn` | **Active** — 3D state machine |
| `scripts/combat/CombatManager.gd` | `scenes/combat/CombatScene.tscn` | Legacy 2D — reference only |

`CombatScene3D.tscn` is the active entry point. `main.tscn` loads it.

---

## Dependencies

| System | How it's used |
|--------|--------------|
| **Grid3D** | Cell queries (`is_valid`, `is_occupied`, `get_unit_at`), move range, highlights, world↔grid math |
| **Unit3D** | HP/energy reads, `take_damage()`, `move_to()`, `play_attack_anim()`, `reset_turn()`, signal subscriptions |
| **QTEBar** | `start_qte()` call; listens for `qte_resolved(accuracy)` signal |
| **CameraController** | Built by CM3D; `trigger_shake()` called on successful hit |
| **UnitInfoBar** | `show_for(unit)` on single-click; `refresh(unit)` after damage; `hide_bar()` on deselect |
| **StatPanel** | `show_for(unit)` on double-click; `hide_panel()` on deselect / combat end |
| **ArchetypeLibrary** | `create(archetype_id, name, is_player)` to build all units at scene start |

---

## State Machine

```
PLAYER_TURN
  └─[player selects unit + action]─→ QTE_RUNNING (on attack)
                                   └─→ PLAYER_TURN (after stride or if all acted)
QTE_RUNNING
  └─[qte_resolved signal]─→ ENEMY_TURN (if all player units acted)
                          └─→ PLAYER_TURN (if others remain)
ENEMY_TURN
  └─[all enemies processed]─→ PLAYER_TURN
                            └─→ WIN / LOSE

WIN  → prints "YOU WIN"
LOSE → prints "GAME OVER"
```

**Player Mode sub-state (during PLAYER_TURN):**
- `IDLE` — no unit selected
- `STRIDE_MODE` — unit selected, showing move highlights
- `ATTACK_MODE` — unit selected, showing attack target highlights

---

## Signals Emitted

| Signal | When |
|--------|------|
| *(none emitted externally in 3D version)* | CM3D is the root; no parent to signal |

> The 2D version emits `phase_changed(new_phase: String)` and `combat_ended(player_won: bool)`.

---

## Public Methods (called by other systems)

None — CombatManager3D is the root; other systems signal *up* to it, not the other way around.

---

## Key Internal Methods

| Method | Purpose |
|--------|---------|
| `_ready()` | Builds entire scene: env → camera → grid → units → UI |
| `_unhandled_input(event)` | Entry point for all player input. Uses `_unhandled_input` (not `_input`) so StatPanel GUI controls receive events first. When StatPanel is visible, swallows all events except ESC (which closes the panel). |
| `_handle_left_click()` | Single-click: raycasts cell → select/move/attack; shows UnitInfoBar |
| `_handle_double_click()` | Double-click: raycasts cell → opens StatPanel for that unit |
| `_request_end_player_turn()` | Space key handler: shows confirm dialog if any unit can still act |
| `_check_auto_end_turn()` | Called after each attack; auto-ends turn when no player can act |
| `_initiate_attack(attacker, target)` | `await` chain: lunge anim → QTE → apply damage → shake |
| `_on_qte_resolved(accuracy)` | Applies damage, checks auto-end, refreshes UnitInfoBar |
| `_run_enemy_turn()` | Iterates enemy units, simulates QTE via `qte_resolution` stat |
| `_calculate_damage(atk, def, accuracy)` | `max(1, round(atk * stat_mult * acc_mult))` |
| `_check_win_lose()` | Checks for all-dead on either side, transitions to WIN/LOSE |

---

## Damage Formula

```
damage = max(1, (attacker.attack - defender.defense) * accuracy)
```

- `accuracy` is 0.0–1.0 from QTE (or `qte_resolution` stat for enemies)
- Floor of 1 ensures attacks always deal at least 1 damage

---

## Hardcoded Stats (placeholder — to be balanced post-playtest)

| Unit | HP | Attack | Defense | Speed | QTE Res |
|------|-----|--------|---------|-------|---------|
| Player | 20 | 10 | 10 | 3 | — |
| Grunt enemy | 15 | 8 | 6 | 2 | 0.3 |

---

## Notes

- CM3D builds 3 player units (left side, col 0–1) and 3 enemy units (right side, col 8–9) on a 10×10 grid.
- Player slot 0 is always the RogueFinder PC (archetype "RogueFinder", named "Vael"). Slots 1-2 are random allied archetypes auto-named from flavor pools.
- Space key ends the player turn. If any unit can still act, a confirmation dialog appears first.
- Turn auto-ends after each attack resolves, if no alive player unit can still take an active action.
- `_process_enemy_actions()` uses `await get_tree().create_timer(0.65)` between enemies for pacing.
- The `await` on `_initiate_attack()` blocks the coroutine until QTE resolves — this is why `QTE_RUNNING` state exists to block input.
