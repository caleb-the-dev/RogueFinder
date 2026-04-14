# System: Combat Manager

> Last updated: 2026-04-14 (Session 2 — Stage 1.5)

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
| **HUD** | `refresh(player_units, enemy_units)` called after every state change |
| **CameraController** | Built by CM3D; `trigger_shake()` called on successful hit |
| **UnitData** | Constructed by `_make_unit_data()` and passed into `Unit3D.setup()` |

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
| `_make_unit_data(...)` | Factory for UnitData resources |
| `_input(event)` | Entry point for all player clicks; dispatches by combat state |
| `_handle_left_click()` | Raycasts grid cell, routes to select/move/attack |
| `_initiate_attack(attacker, target)` | `await` chain: lunge anim → QTE → apply damage → shake |
| `_on_qte_resolved(accuracy)` | Receives QTE result, calls `_calculate_damage()`, applies it |
| `_run_enemy_turn()` | Iterates enemy units, simulates QTE via `qte_resolution` stat |
| `_calculate_damage(atk, def, accuracy)` | `max(1, (atk - def) * accuracy)` |
| `_check_win_lose()` | Checks for all-dead on either side, transitions to WIN/LOSE |
| `_refresh_hud()` | Calls `hud.refresh()` — called after every meaningful state change |

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

- CM3D builds 3 player units (columns 1–2) and 3 enemy units (columns 3–4) on a 6×4 grid.
- `_process_enemy_actions()` uses `await get_tree().create_timer(0.4)` between enemies for pacing.
- The `await` on `_initiate_attack()` blocks the coroutine until QTE resolves — this is why `QTE_RUNNING` state exists to block input.
