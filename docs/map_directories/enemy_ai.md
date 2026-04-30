# System: Enemy AI

> Last updated: 2026-04-30 (Slice 1 — Role data layer)

---

## Purpose

Role-driven AI system for enemy combatants. Replaces random target and ability selection with contextual decisions guided by each archetype's `Role`. Movement and AoE origin selection were already smart before this system; this layer adds role-aware target and ability picking.

---

## Build Status

| Slice | Description | Status |
|-------|-------------|--------|
| Slice 1 | Role data layer — `ArchetypeData.Role` enum + `archetypes.csv` column + `ArchetypeLibrary._parse_role()` | ✅ Done |
| Slice 2 | Target selection — role-aware picker replaces random target at `CombatManager3D.gd:1402` | ⏳ Planned |
| Slice 3 | Ability selection — role-aware picker replaces random ability at `CombatManager3D.gd:1475` | ⏳ Planned |

---

## Role Enum

Defined on `ArchetypeData` (`resources/ArchetypeData.gd`). Stored in `archetypes.csv` under the `role` column.

| Role | Int | Design intent |
|------|-----|---------------|
| `ATTACKER` | 0 | Targets lowest-HP or most-threatening enemy; prefers damage abilities |
| `HEALER` | 1 | Targets most-injured ally; prefers restore/buff abilities; attacks as fallback |
| `SUPPORTER` | 2 | Targets ally with lowest energy or combat disadvantage; buff-first |
| `DEBUFFER` | 3 | Targets highest-threat enemy; prefers status/penalty abilities |
| `CONTROLLER` | 4 | Targets clustered enemies or highest-mobility threat; prefers displacement/lockdown |

**Stub fallback:** `ATTACKER`. Any unrecognized `role` string in the CSV also falls back to `ATTACKER`.

---

## Key Files

| File | Purpose |
|------|---------|
| `resources/ArchetypeData.gd` | Defines `Role` enum + `role: Role` field |
| `data/archetypes.csv` | `role` column (after `kindred`) — one of: attacker / healer / supporter / debuffer / controller |
| `scripts/globals/ArchetypeLibrary.gd` | `_parse_role(val)` helper — case-insensitive string → enum |
| `scripts/combat/CombatManager3D.gd` | Target selection `:1402` and ability selection `:1475` — to be replaced in Slices 2–3 |
| `tests/test_archetype_role.gd` | 6 headless tests: all 9 archetype roles, stub fallback, case-insensitivity, unknown string, reload() |

---

## Design Constraints

- **5 roles total** — SKIRMISHER collapsed into ATTACKER for vertical slice
- **Single role per archetype** — no primary+secondary
- **No AI tier system** — one shared policy; context (role + situation) drives variance
- Movement is already smart (greedy Manhattan, `CombatManager3D.gd:1419–1449`)
- AoE origin selection is already smart (`_pick_best_aoe_origin`, `:1497`)
