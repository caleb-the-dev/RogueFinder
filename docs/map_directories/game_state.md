# System: Game State

> Last updated: 2026-04-14 (Session 2 — Stage 1.5)

---

## Purpose

`GameState` is the **autoload singleton** for run-wide persistent data. It is intended to be the single source of truth for anything that needs to survive across scenes — party roster, equipment, currency, map progress, faction reputation.

**Current status: Stub.** The file exists as a scaffold but contains no live data or logic. No other system reads from or writes to it yet.

---

## Core File

| File | Autoload Name | Role |
|------|--------------|------|
| `scripts/globals/GameState.gd` | `GameState` | Run-wide persistent data — stub |

Registered as an autoload in `project.godot` so it is accessible from any script as `GameState`.

---

## Dependencies

None currently. When fleshed out, it will be depended on by:
- CombatManager (read party stats, write combat outcome)
- Map system (read/write traversal progress)
- Recruitment system (write new party members)

---

## Signals Emitted

None currently.

---

## Planned Responsibilities (Stage 2+)

| Data | Type | Notes |
|------|------|-------|
| Party roster | `Array[UnitData]` | Active + bench units for the run |
| Run seed | `int` | For reproducibility |
| Map progress | `Dictionary` | Node visited state |
| Faction reputation | `Dictionary` | Per-faction standing |
| Currency / resources | `int` | TBD |
| Run flags | `Dictionary` | Misc boolean state |

---

## Notes

- The singleton pattern was chosen so that any scene in the game can access run state without manual node references or signal chains up the tree.
- Do not put **combat-local** state here (selected unit, current turn, etc.) — that belongs in CombatManager. GameState is for data that persists between combat encounters.
- When Stage 2 begins (node map + recruitment), this file will need a full design pass.
