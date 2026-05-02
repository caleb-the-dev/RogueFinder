# Combat Pivot — Autobattler Turn-Tick

**Date:** 2026-05-02
**Status:** Pending review

---

## Overview

Stage 1.5 play-testing on 2026-05-02 revealed that the current 3v3 tactical-grid combat is slow, complicated, and over-scoped for a 6-month solo timeline. Significant unstarted work remained: enemy AI Slice 4 (FORCE multi-step planner), per-room map authoring, AoE-shape balance, and the QTE-tuning surface.

Caleb's earlier GMS2 RogueFinder prototype validated a faster turn-tick autobattler shape. This pivot replaces the **combat resolution layer only** with a turn-tick autobattler. Everything outside combat — map traversal, events, vendors, city, build pillars, equipment, save system, character creation, follower recruitment — survives untouched.

**This spec is for a vertical slice, not a final design.** The goal is to put a playable autobattler in the player's hands fast and learn whether the genre lands. Polish, depth, and additional agency knobs are deferred until the slice plays.

---

## The Pivot at a Glance

| Pillar | Was | Becomes |
|---|---|---|
| Genre | Tactical grid (Into the Breach-shape) | Autobattler turn-tick (Wildfrost-shape) |
| Grid | 10×10 cells with movement, knockback, AoE shapes | 3 lanes × 2 deep per side (12 cells total), positions locked at fight start |
| Resolution | Team-based initiative; player drives all 3 units | Per-unit countdown; AI picks ability per unit; player intervenes via consumable only |
| Cost economy | Energy (per-character pool, regen per turn) | Per-ability cooldown; energy stat retires |
| Ability slots | 4 per character | 3 per character; slot 0 = weapon-locked HARM |
| Defining class ability | Auto-granted to slot 0 | **Dropped for vert slice** — abilities come from class+kindred pool selection |
| Player agency in combat | Full control of all 3 units + defender QTE | Consumable interject only |
| AI complexity | Role-driven walk + within-bucket scoring (HARM/MEND/BUFF/DEBUFF) | Simple "best off-cooldown" priority-list pick |
| QTE | Defender-driven Slide bar on every HARM | Removed entirely |
| New attribute | — | SPD (drives countdown_max) |

---

## Combat Resolution Model

### Hybrid Countdown System

Two timers per unit:

1. **Unit countdown** — floats above the unit's head. Decrements each "tick" of combat. When it hits 0, the unit takes its turn (one ability fires). After firing, countdown resets to `countdown_max`.
2. **Per-ability cooldown** — each of the 3 slotted abilities tracks its own cooldown counter. When a unit takes its turn, AI picks from abilities currently off-cooldown.

```
On unit's turn (countdown reaches 0):
  available = [ab for ab in slots if ab.cooldown_remaining == 0]
  if available is empty: skip turn (or fire weapon ability if always-on-cd-0)
  picked = ai_pick(available, role, hostiles, allies)
  fire(picked)
  picked.cooldown_remaining = picked.cooldown_max
  unit.countdown_current = unit.countdown_max
  process_unit_turn_status_ticks(unit)  # DoT/HoT/duration decrements
```

Each tick of combat:
- All `countdown_current` values decrement by 1
- All `cooldown_remaining` values decrement by 1
- DoT/HoT effects are NOT processed here — they tick on each affected unit's *own* turn

**Tiebreak when multiple units hit 0 same tick:** higher SPD acts first; if still tied, deterministic by unit ID order.

### countdown_max Derivation

`countdown_max` is derived from the new SPD attribute at combat start:

```
countdown_max = clamp(8 - SPD, 2, 12)
```

| SPD | countdown_max |
|---|---|
| 1 (heavily slowed) | 7 |
| 4 (default base) | 4 |
| 6 | 2 |
| 8+ (clamp) | 2 |

Locked once derived at combat start. Status effects (`HASTE`, `SLOW`) modify `countdown_current` directly, not `countdown_max`.

### Energy System Retirement

The `energy`, `energy_max`, and `energy_regen` fields all retire. Cooldown alone gates ability availability. WIL no longer drives energy.

`AbilityData.energy_cost` field renames to `cooldown_max` and changes meaning. Existing values become a starting point:

| Old energy_cost | New cooldown_max |
|---|---|
| 1–2 (chip) | 2 |
| 3–4 (standard) | 3 |
| 5+ (signature) | 5 |

All 63 abilities migrate. Weapon-granted slot-0 abilities sit at cooldown 2.

---

## Layout

3 lanes × 2 deep per side. 12 cells total (6 ally + 6 enemy).

```
       LANE 1   LANE 2   LANE 3
      ┌───────┬───────┬───────┐
 B    │       │       │       │   ← back  (your side)
 F    │       │       │       │   ← front (your side)
══════╪═══════╪═══════╪═══════╪══   neutral line
 F    │       │       │       │   ← front (enemy)
 B    │       │       │       │   ← back  (enemy)
      └───────┴───────┴───────┘
```

### Pre-fight Placement

Before combat begins: drag your 3 active units onto your 6 cells. Each unit lands in a single (lane, row) position. Stacking forbidden — each cell holds at most 1 unit. Placement is meaningful build expression — front-row tanks soak; back-row casters are protected unless flanked; lane assignment determines which abilities can reach.

Default placement on first combat: lane 1 / lane 2 / lane 3, all back row. Player drags to adjust. Subsequent combats default to last-used positions for the same units.

### Targeting Shapes

Abilities target by lane + row rules. The 10×10 shapes (cone, line of N, plus) retire in favor of:

| Shape | Description |
|---|---|
| `single` | one target by rule (front-of-lane / lowest-HP / highest-threat) |
| `same_lane` | all targets in caster's lane |
| `adjacent_lane` | lanes ± 1 |
| `all_lanes` | every lane |
| `front_row` | enemy front cells only |
| `back_row` | enemy back cells only (requires reach or empty front) |
| `self` / `ally` / `all_allies` | non-hostile targeting |
| `same_row_allies` | ally row (front or back) |

`AbilityData.target_shape` already exists. The shape enum updates to the new vocabulary; old shapes retire.

### Hazards — Deferred

Cell-level hazards (lava, caltrops, regen tiles) are designed but **deferred for the vert slice.** The MVP grid is empty. Add hazards later if combat needs more variety.

---

## Ability System Updates

### Slot Structure

Each unit has **3 ability slots:**

| Slot | Source | Notes |
|---|---|---|
| 0 | **Equipped weapon's `granted_ability_ids[0]`** | Auto-populated from current weapon; cannot be unslotted while weapon equipped; replaced when weapon changes. Falls back to a generic `basic_strike` ability (low-damage HARM, cooldown 2) if no weapon is equipped — every unit always has *something* in slot 0. |
| 1 | Player choice from class + kindred ability pool | Build expression slot. |
| 2 | Player choice from class + kindred ability pool | Build expression slot. |

### Run-Start Ability Counts

| Phase | Pool size |
|---|---|
| Character creation | Player picks 1 starter ability from the class pool. Result: 1 kindred natural + 1 class pick = **2 abilities in pool** at run start. |
| Per level-up | Player picks 1 ability from a 3-card draw (existing system). 4 picks across the run. |
| End of run | 1 kindred + 5 class = **6 abilities in pool** (unchanged from current design). |

Slot 0 is weapon-derived and **does not count toward the pool count.** The pool exists independently — slots 1+2 are drawn from it. So a unit at run start has 1 weapon-granted slot 0 + 2 pool abilities to fill slots 1 and 2 = 3 active slots covered.

### Class Defining Ability — Dropped for Vert Slice

The auto-granted "defining ability" concept (Tower Slam = Bastion, Arcane Bolt = Mystic, etc.) **retires** for the vert slice. Class identity comes from:

- The class's ability pool (13 abilities to draw from)
- Class stat distribution (4 points)
- Class feat pool (10 feats to draw from)
- Class role bias for AI ability selection

Defining abilities can return as a feature later if classes feel under-differentiated after the slice plays. Don't pre-build for it now.

### Status Effects (in scope, from backlog)

New EffectType values:

| Type | Behavior |
|---|---|
| `BURN` (DoT) | N damage at start of unit's turn for K turns |
| `POISON` (DoT) | N damage at end of unit's turn for K turns |
| `BLEED` (DoT) | N damage when unit fires its next ability for K turns |
| `REGEN` (HoT) | N heal at start of unit's turn for K turns |
| `STUN` | countdown reset to `countdown_max + N` on next reset (skip turn-or-two) |
| `SILENCE` | unit acts but only fires slot 0 (no choice from cooldown set) for K turns |
| `HASTE` | `countdown_current` reduced by N once per turn for K turns |
| `SLOW` | `countdown_current` increased by N once per turn for K turns |

Status effects stored on `Unit3D.active_status_effects: Array[Dictionary]`. Each entry: `{type, duration_remaining, value, source_ability_id}`. Cleared at `_end_combat()` (no carry-over between fights).

### Countdown Manipulation (in scope)

New EffectType: `COUNTDOWN_MOD`. Modifies the target's `countdown_current` directly, bounded to `[0, countdown_max + 5]`.

- Negative value = haste (subtract from countdown, target acts sooner)
- Positive value = slow (add to countdown, target acts later)

Specific ability patterns to author:

| Ability | Effect |
|---|---|
| **Frostbind** (Mystic) | enemy COUNTDOWN_MOD +3 |
| **Haste** (Warden) | ally COUNTDOWN_MOD −2 |
| **Snap Strike** (Outlaw) | self COUNTDOWN_MOD −5 (act again immediately) |
| **Stun Hammer** (Bastion) | enemy COUNTDOWN_MOD +countdown_max (skip next turn) |

---

## Stat Changes

### New Attribute: SPD

A 6th attribute joins STR/DEX/COG/WIL/VIT. Drives `countdown_max` (faster = more turns).

| Pillar | SPD contribution |
|---|---|
| Class | None initially — class doesn't invest SPD points (existing 4-point budget across other 5 stats stays). Revisit if classes feel speed-flat. |
| Kindred | Existing kindred speed values migrate from `speed_bonus` to a SPD entry in `stat_bonuses`. Spider gets SPD +3, Skeleton SPD −1, Dwarf SPD 0, etc. |
| Background | SPD becomes one of the 6 options for the +1-stat bonus. |
| Temperament | Add one new pair to temperaments.csv: SPD-boosted / SPD-hindered (e.g., "Hasty" boosts SPD, "Lethargic" hinders). Total goes from 21 → 22 (10 paired + Even + 1 new pair). Or replace one existing pair. Decide during implementation. |
| Equipment | Some accessories may grant +SPD (e.g., a future Boots of Speed). Not blocking. |

The current `CombatantData.speed` computed property (`1 + kindred_speed_bonus`) retires. Replaced by `spd: int` as a normal attribute (defaults to 4 like the others).

### WIL Repurposed

WIL no longer drives `energy_max` / `energy_regen` (those retire). New role:

- Scales MEND `base_value` (heal numbers grow with healer's WIL)
- Resists DEBUFF effects (high WIL = duration reduction or chance to ignore)

The future WIL → CHA rename is out of scope for this spec.

### CombatantData Field Changes

| Action | Field |
|---|---|
| Add | `spd: int` (defaults to 4 like other attrs; serialized) |
| Add | `countdown_current: int` (transient, not serialized) |
| Add | `countdown_max: int` (transient, computed at combat start) |
| Add | `active_status_effects: Array[Dictionary]` (transient) |
| Remove | `energy: int`, `energy_max: int`, `energy_regen: int` |
| Remove | `speed: int` computed property (replaced by `spd` attribute) |

**Save migration:** old saves missing `spd` derive a default of `4 + old_kindred_speed_bonus`. Old `energy*` fields are dropped on load.

---

## AI Redesign

The role-driven walk + within-bucket scoring (Slice 2 + Slice 3 work) collapses to a small priority-list selector.

```
ai_pick(available_abilities, role, hostiles, allies):
  by_pref = sort_by_role_preference(available_abilities, role)
  for ability in by_pref:
    target = pick_target(ability, hostiles, allies)
    if target is not null: return (ability, target)
  return (null, null)  # turn skipped (rare; weapon ability is always cooldown-low)
```

Role preference table:

| Role | Preference order |
|---|---|
| ATTACKER | HARM > DEBUFF > BUFF > MEND |
| TANK | HARM > BUFF (self) > DEBUFF |
| HEALER | MEND (low-HP ally) > BUFF (ally) > HARM |
| SUPPORTER | BUFF (ally) > DEBUFF > MEND > HARM |
| CONTROLLER | DEBUFF > COUNTDOWN_MOD slow > HARM |

Per-ability targeting rule (simple — no scoring):

- HARM single → front-of-lane in caster's reach; fall back to back-row if front empty
- HARM lane / adjacent / all_lanes → first valid target by rule, no scoring
- MEND → lowest-HP ally in valid range
- BUFF → first non-redundant ally
- DEBUFF → first non-already-debuffed enemy
- COUNTDOWN_MOD slow → enemy with lowest `countdown_current`
- COUNTDOWN_MOD haste → ally about to act (lowest `countdown_current` ally)

Critical-heal override (today's HEALER 15%-HP override) **retires** for vert slice. HEALER role just runs its preference list; lowest-HP ally is the natural pick.

---

## Player Agency

In-combat: **consumable interject only.**

- Each unit has a consumable slot (existing system stays as-is).
- During combat, between any two unit actions, the player can press a consumable button on any of their 3 units.
- Consumable consumes the item, applies its effect, does not advance the tick or interrupt the resolution flow.
- Once-per-combat per consumable slot.

Stance toggle and class-button override are **deferred for vert slice.** Re-evaluate after first play-test.

**Implication:** consumables become the entire mid-fight decision layer. Today's consumables are mostly +1-stat sips (mild). They will likely need a balance pass to feel meaningful as the only player input. Tuning task — flagged, not blocking.

---

## What Survives Untouched

These systems require **zero changes** for the pivot:

- Map traversal, all 5 node types (COMBAT/VENDOR/EVENT/BOSS/CITY), threat escalation, save/load
- Character creation, all 4 build pillars (Class, Kindred, Background, Temperament) — only the SPD addition touches
- Equipment system (36 items, 4 slots, on_equip/on_unequip lifecycle)
- Vendor system (CITY + WORLD vendors, stocks, gold economy)
- Event system (18 events, condition + effect dispatch)
- Follower / recruit system (Pathfinder QTE, bench, hire roster)
- City scene (Badurga shell — Party Management + Hire Roster live)
- XP / level-up overlay
- Pause menu, archetypes log, settings store
- Run summary scene
- Inventory, gold, party persistence
- All data libraries (kindreds, classes, backgrounds, temperaments, portraits, archetypes, feats, vendors, events)

---

## What Gets Ripped Out

- `CombatManager3D` — combat loop replaced; movement, QTE pipeline, initiative all gone
- `Grid3D` — 10×10 cell math retires (replaced by 3×2 lane data structure)
- `QTEBar.gd` — retires entirely
- `EnemyAI.gd` (Slice 2 + 3 work) — most of it retires; small priority-list module replaces
- Energy fields and logic across `CombatantData`, ability dispatch, save/load
- TRAVEL effect type — retires (no movement)
- FORCE effect type — retires for now (could return later as row-swap or COUNTDOWN_MOD wrapper)
- AoE shape rendering on grid — retires
- All CombatManager3D-tied test rooms — retire (test scaffolding pattern stays; rewrite rooms for new model)
- Existing enemy AI scoring tests — retire (replaced by new simpler tests)
- Critical-heal override (15% HP HEALER threshold) — retires
- `Unit3D` movement code, AoE shape rendering, FORCE response, QTE binding — strip while keeping the unit shell

`RecruitBar.gd` is **kept** — used outside combat for follower recruitment, no change needed.

---

## What Gets Added

- New `CombatManager` autoload (or scene script) for turn-tick autobattler — lean, likely <500 lines
- New `CountdownTracker` module (per-unit countdown, per-ability cooldown management)
- New `StatusEffectProcessor` (DoT/HoT/stun/silence/haste/slow ticking + duration decrement)
- New `EnemyAI.gd` priority-list selector (likely <100 lines)
- New SPD attribute across `CombatantData`, character creation slot wheels, temperaments CSV, kindreds CSV
- New EffectTypes: `BURN`, `POISON`, `BLEED`, `REGEN`, `STUN`, `SILENCE`, `HASTE`, `SLOW`, `COUNTDOWN_MOD`
- New combat scene layout (3 lanes × 4-cell-deep 3D presentation)
- New pre-fight placement UI (drag your 3 onto your 6 cells)
- Migration logic for old saves (drop energy fields, derive SPD)
- Headless tests for: countdown decrement, cooldown decrement, AI pick from off-cooldown set, status effect application/expiration, countdown manipulation, lane targeting, placement validation

---

## Open Questions / TBD

- **Pre-fight placement UI** — quick wireframe needed before implementation. Mocked: 3 active party portraits sit above an empty 3×2 grid; drag-and-drop. Auto-restore last placement on subsequent combats.
- **Cooldown tuning** — initial values are a starting point. Likely need iteration after first playable build.
- **Consumable punch-up** — current consumables may feel weak as sole agency. Defer until first play-test, then re-tune.
- **Hazards** — deferred for vert slice. Add when combat feels too samey.
- **Enemy ability count** — current archetypes have multi-ability kits. May simplify to "1 HARM + 1 utility" max for vert slice instead of full pool. Decide during implementation.
- **Defining class ability** — dropped for vert slice. Re-evaluate after play-test if classes feel under-differentiated.
- **Stance + class-button** — deferred. Re-evaluate after play-test if combat feels too passive.
- **WIL → CHA rename** — out of scope for this spec.

---

## Suggested Implementation Order (sketch)

This is high-level. The full implementation plan is the next document.

1. **SPD attribute foundation** — add field, migrate kindred speed bonuses, character creation UI, save migration
2. **Cooldown migration** — rename `energy_cost` to `cooldown_max`, retire energy fields, update CSV reads + AbilityLibrary
3. **Combat scaffold rewrite** — new `CombatManager`, lane-based scene, pre-fight placement UI
4. **Countdown engine** — `countdown_current` ticking, ability cooldown decrement, AI picker scaffolding
5. **Lane targeting** — replace AoE shapes with lane/row rules, update existing ability data
6. **AI simplification** — new lean priority-list module, retire role/scoring complexity

🎯 **First-playable milestone:** after step 6, combat is functional end-to-end. Caleb can play-test the *core* autobattler shape with no status effects, no countdown manipulation, no DoTs. **This is the slice's actual test moment** — does turn-tick autobattler with consumable agency feel right? Hold further work pending a "yes."

7. **Status effect framework** — new EffectTypes, `StatusEffectProcessor`, DoT/HoT ticking on unit turn
8. **Countdown manipulation** — `COUNTDOWN_MOD` effect, ability authoring, status interactions
9. **Polish + test rooms** — dev panel rebuilds, headless tests
10. **Consumable balance pass** — buff existing consumables to feel impactful as sole agency

Steps 7–10 only land if the play-test at step 6 confirms the core works. Per the vert-slice discipline note in `CLAUDE.md`, do not pre-build them.

---

## Notes on Standalone Identity

User flagged a goal of drifting away from PF2e-derivative identity (no Paizo partnership planned). Vocabulary changes are *not* in scope for this spec but worth tracking for future passes:

- "Stride" → can retire entirely (no movement in autobattler anyway)
- "Strike" → could become "Attack" or "Swing"
- "Ancestry" → already replaced by "Kindred"
- Specific spell-name overlaps with PF2e — audit later

The mechanical identity (autobattler + lane combat + creature collector) is already differentiated. Naming polish can come post-slice.
