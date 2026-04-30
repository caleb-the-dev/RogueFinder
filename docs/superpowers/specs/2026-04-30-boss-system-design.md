# Boss System Design

**Date:** 2026-04-30
**Status:** Approved

---

## Overview

BOSS nodes already exist on the map (outer ring, 1 per run, pulsing glow). Currently they route to the same `CombatScene3D` as regular COMBAT nodes with no special behavior. This feature makes boss encounters meaningfully distinct through: exclusive boss abilities, threat-scaled stat tiers, a visually distinct QTE bar, and a map-level escalation warning.

---

## Scope

- Boss archetype is **randomized each run** (any of the 9 archetypes can be the boss). Fixed story boss deferred to a later milestone.
- Vertical slice: some archetypes may have placeholder/empty boss ability IDs — the spawning code falls back gracefully.
- Archetype roles are referenced conceptually (boss_role_id is tied to the archetype's role) but the role system implementation is deferred to a separate feature. This spec treats `boss_role_id` as a named ability ID that will be authored when roles land.

---

## Data Model

### archetypes.csv — two new columns

| Column | Type | Notes |
|---|---|---|
| `boss_harm_id` | String | ID of the boss-exclusive HARM ability for this archetype. Empty string = use regular slot. |
| `boss_role_id` | String | ID of the boss-exclusive role-flavored ability. Tied to archetype role (deferred system). Empty string = use regular slot. |

### abilities.csv — one new column

| Column | Type | Notes |
|---|---|---|
| `boss_only` | int (0/1) | When true: ability never appears in regular pools (level-up picks, hire cards, equipment grants). Only enters play via boss spawning injection. |

### CombatantData.gd — one new field

```
speed_bonus: int = 0
```

Flat additive to the `speed` computed property: `speed = 1 + kindred_speed_bonus + speed_bonus`. Plain `var`, not `@export`, never serialized. Set by `BossScaler` before boss unit spawn. Always `0` on player units and regular enemies.

---

## Boss Spawning

`CombatManager3D._setup_units()` gets a new branch: when the current node type is `"BOSS"`:

1. Create the boss `CombatantData` via `ArchetypeLibrary.create()` as normal.
2. Look up the archetype's `boss_harm_id` and `boss_role_id`.
3. If `boss_harm_id` is non-empty: replace active slot 2 with it; add to `ability_pool` (deduped).
4. If `boss_role_id` is non-empty: replace active slot 3 with it; add to `ability_pool` (deduped).
5. Call `BossScaler.apply(boss_data, GameState.threat_level)` before `unit.setup()`.

The encounter is still 3v3 — the boss unit occupies enemy slot 0; the two flankers are regular `ArchetypeLibrary.create()` instances of the **same archetype_id** (no boss ability injection, no BossScaler — just normal stat-range instances).

---

## Threat Scaling — BossScaler

New static helper: `scripts/globals/BossScaler.gd`.

**Public API:**
```
static func apply(data: CombatantData, threat: float) -> void
```

Applies cumulative tier bonuses by directly mutating the freshly-created boss `CombatantData` before spawn. Safe to mutate directly — boss data is created fresh each combat and is not a `GameState.party` member, so no snapshot/restore is needed.

**Tier table (cumulative — all tiers at or below current threshold stack):**

| Threshold | Stat Changes |
|---|---|
| threat ≥ 0.25 | +1 speed_bonus, +1 willpower |
| threat ≥ 0.50 | +1 vitality |
| threat ≥ 0.75 | +1 physical_armor, +1 magic_armor |
| threat ≥ 1.00 | +1 strength, +1 dexterity, +1 cognition |

---

## Boss QTE

Boss-exclusive HARM abilities trigger a visually and mechanically distinct QTE for the defending player unit.

**Signal path:** `CombatManager3D._run_harm_defenders()` checks whether the caster is an enemy and `ability.boss_only == true`. If so, it passes `is_boss_move: bool = true` to `QTEBar.start_qte()`.

**QTEBar changes when `is_boss_move` is true:**
- Bar tints **red/dark orange** (vs. default color).
- Safe window (perfect/good zone) is **narrower** — exact thresholds TBD during tuning.
- Same slide mechanic, same result multipliers. No new QTE type.

**`AbilityData`** gains a `boss_only: bool` field parsed from the CSV column. `AbilityLibrary` parses it the same way it parses other bool columns.

---

## "Boss Grows Stronger" Notification

### GameState

One new persisted field:
```
boss_tier_notified: int = 0
```
Tracks the highest tier already announced this run (0–4). Serialized in `save()` / `load_save()`. Old saves default to `0`.

### MapManager

New method `_check_boss_tier_escalation()`, called after any node is completed and `threat_level` has updated.

Logic:
1. Compute `current_tier` from `threat_level` using the same thresholds as `BossScaler`.
2. If `current_tier <= GameState.boss_tier_notified`: do nothing.
3. If the BOSS node is already in `GameState.cleared_nodes`: do nothing (boss is dead, warning is moot).
4. Otherwise: show the overlay, set `GameState.boss_tier_notified = current_tier`, call `GameState.save()`.

**Overlay:** Full-screen `CanvasLayer` (layer above map HUD). Displays **"The Boss Grows Stronger."** Fades in, holds ~1.5 s, fades out. Fire-and-forget — no player input required.

---

## Slices

| Slice | Title | Scope |
|---|---|---|
| 1 | Boss Data Layer | `boss_harm_id`/`boss_role_id` columns in archetypes.csv; `boss_only` column in abilities.csv; `speed_bonus` field on CombatantData wired into speed; author boss abilities for all 9 archetypes (stub empties allowed); `AbilityData.boss_only` field + library parse; headless tests |
| 2 | Boss Spawning | CombatManager3D BOSS branch: inject boss ability slots 2+3; fallback on empty IDs; headless tests |
| 3 | Threat Scaling | `BossScaler.gd` static helper; called from CombatManager3D at boss spawn; headless tests for all 4 tiers + cumulative stacking |
| 4 | Boss QTE | QTEBar `is_boss_move` param; tinted bar + narrower window; CombatManager3D passes flag for boss_only HARM abilities |
| 5 | Escalation Notification | `GameState.boss_tier_notified` (persisted); `MapManager._check_boss_tier_escalation()`; full-screen overlay; cleared-boss guard |

---

## Open Questions / Deferred

- Boss ability content for role-based slot (`boss_role_id`) will be authored once the archetype roles system lands — that feature will update the CSV rows.
- Exact QTE window narrowing values (Slice 4) are tuning decisions, not design decisions.
- Multiple bosses per run (future milestone) — this design assumes exactly 1 BOSS per run, consistent with current map layout.
