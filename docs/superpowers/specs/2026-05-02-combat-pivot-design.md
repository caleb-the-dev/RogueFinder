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
| Grid | 10×10 cells with movement, knockback, AoE shapes | 3 lanes flat per side (6 cells total), positions locked at fight start. Add front/back depth post-slice if play-test calls for it. |
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
  if available is empty: skip turn (rare — slot 0 weapon ability has cooldown 2 max)
  picked = ai_pick(available, role, hostiles, allies)
  fire(picked)
  picked.cooldown_remaining = picked.cooldown_max
  unit.countdown_current = unit.countdown_max
```

Each tick of combat:
- All `countdown_current` values decrement by 1
- All `cooldown_remaining` values decrement by 1

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

Locked once derived at combat start. Post-slice status effects (HASTE/SLOW), if added, will modify `countdown_current` directly, not `countdown_max`.

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

3 lanes flat per side. 6 cells total (3 ally + 3 enemy).

```
       LANE 1   LANE 2   LANE 3
      ┌───────┬───────┬───────┐
      │       │       │       │   ← your side
══════╪═══════╪═══════╪═══════╪══   neutral line
      │       │       │       │   ← enemy side
      └───────┴───────┴───────┘
```

### Pre-fight Placement

Before combat begins: drag your 3 active units onto your 3 lanes. Each unit lands in one lane. Stacking forbidden — each lane holds exactly 1 unit per side. Placement expression: lane assignment determines which abilities can reach (e.g., a `same_lane` HARM ability hits whoever's directly across). Same-lane match-ups are the core positioning consideration.

Default placement on first combat: party-order to lane 1/2/3. Player drags to adjust. Subsequent combats default to last-used lane assignments for the same units.

### Targeting Shapes

Abilities target by lane rules. The 10×10 shapes (cone, line of N, plus) retire in favor of:

| Shape | Description |
|---|---|
| `single` | one target by rule (same-lane opposite / lowest-HP / highest-threat) |
| `same_lane` | the target directly across in the same lane |
| `adjacent_lane` | the targets in lanes ± 1 from caster |
| `all_lanes` | every enemy |
| `self` / `ally` / `all_allies` | non-hostile targeting |

`AbilityData.target_shape` already exists. The shape enum updates to the new vocabulary; old shapes retire.

### Hazards — Deferred

Lane-wide hazards (e.g. "lane 2 burns for 1 damage per tick") are designed but **deferred for the vert slice.** The MVP grid is empty. Add hazards later if combat needs more variety. If front/back depth lands post-slice, hazards can move to per-cell.

### Front/Back Depth — Deferred

The front/back row dimension (3 lanes × 2 deep) is **deferred for the vert slice.** Test the flat 3×1 layout first; add depth back as a post-slice feature if the slice plays well but feels too positionally thin. This decision was made to get a playable slice as fast as possible.

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

### Status Effects + Countdown Manipulation — Deferred

DoTs (BURN, POISON, BLEED), HoTs (REGEN), control effects (STUN, SILENCE), countdown buffs/debuffs (HASTE, SLOW), and the `COUNTDOWN_MOD` EffectType are all **deferred for the vert slice.** They were designed in this brainstorm session but pulled from the slice scope to test whether the core autobattler shape (countdown ticking + per-ability cooldown rotation + lane targeting + consumable interject) feels right *before* layering depth on top.

Vert slice abilities use only the existing EffectTypes: HARM / MEND / BUFF / DEBUFF (with stat targets that are already in the schema). FORCE and TRAVEL retire as planned. No new EffectTypes added.

If the slice play-tests well, status effects + countdown manipulation are the first post-slice additions. The mechanical shape they would take is captured in the original brainstorm transcript and can be re-spec'd cleanly when needed.

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
| CONTROLLER | DEBUFF > HARM |

Per-ability targeting rule (simple — no scoring):

- HARM single → opposite-lane target; fall back to nearest non-empty lane if opposite is empty
- HARM same_lane / adjacent / all_lanes → first valid target by rule, no scoring
- MEND → lowest-HP ally in valid range
- BUFF → first non-redundant ally
- DEBUFF → first non-already-debuffed enemy

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
- `Grid3D` — 10×10 cell math retires (replaced by simple 3-lane data structure: lane 1 / lane 2 / lane 3 per side)
- `QTEBar.gd` — retires entirely
- `EnemyAI.gd` (Slice 2 + 3 work) — most of it retires; small priority-list module replaces
- Energy fields and logic across `CombatantData`, ability dispatch, save/load
- TRAVEL effect type — retires (no movement)
- FORCE effect type — retires for now (could return later as a lane-swap effect or via the deferred COUNTDOWN_MOD)
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
- New `EnemyAI.gd` priority-list selector (likely <100 lines)
- New SPD attribute across `CombatantData`, character creation slot wheels, temperaments CSV, kindreds CSV
- New combat scene layout (3 lanes flat 3D presentation, 6 cells total)
- New pre-fight placement UI (drag your 3 active units onto your 3 lanes)
- Migration logic for old saves (drop energy fields, derive SPD)
- Headless tests for: countdown decrement, cooldown decrement, AI pick from off-cooldown set, lane targeting, placement validation

---

## Open Questions / TBD

- **Pre-fight placement UI** — quick wireframe needed before implementation. Mocked: 3 active party portraits sit above an empty 3-slot lane row; drag-and-drop. Auto-restore last placement on subsequent combats.
- **Cooldown tuning** — initial values are a starting point. Likely need iteration after first playable build.
- **Consumable punch-up** — current consumables may feel weak as sole agency. Defer until first play-test, then re-tune.
- **Enemy ability count** — current archetypes have multi-ability kits. May simplify to "1 HARM + 1 utility" max for vert slice instead of full pool. Decide during implementation.

---

## Suggested Implementation Order (sketch)

This is high-level. The full implementation plan is the next document.

1. **SPD attribute foundation** — add field, migrate kindred speed bonuses, character creation UI, save migration
2. **Cooldown migration** — rename `energy_cost` to `cooldown_max`, retire energy fields, update CSV reads + AbilityLibrary
3. **Combat scaffold rewrite** — new `CombatManager`, lane-based scene, pre-fight placement UI (3 lanes flat)
4. **Countdown engine** — `countdown_current` ticking, ability cooldown decrement, AI picker scaffolding
5. **Lane targeting** — replace AoE shapes with lane rules, update existing ability data
6. **AI simplification** — new lean priority-list module, retire role/scoring complexity
7. **Polish + test rooms** — dev panel rebuilds, headless tests, end-to-end play-test
8. **Consumable balance pass** — buff existing consumables to feel impactful as sole agency

🎯 **End of slice.** After step 8 the autobattler core is testable end-to-end with no status effects, no countdown manipulation, no front/back depth, no hazards. **Play-test moment:** does turn-tick autobattler with consumable agency feel right? Hold *all* deferred features until the play-test confirms the core works.

### Deferred Until Slice Validates

Captured here so they're not lost — but not in scope for this implementation:

- **Status effects** — BURN, POISON, BLEED, REGEN, STUN, SILENCE, HASTE, SLOW (DoT/HoT/control framework + new EffectTypes + `StatusEffectProcessor`)
- **Countdown manipulation** — `COUNTDOWN_MOD` EffectType for haste/slow/skip/ready abilities (Frostbind, Haste, Snap Strike, Stun Hammer)
- **Front/back depth** — adding the row dimension (3×2 per side, hazards per cell, row-targeting shapes)
- **Hazards** — lane-wide tile effects (lava, regen, caltrops)
- **Stance toggle** — Aggressive/Balanced/Careful biasing AI ability picks
- **Class-button override** — manual fire of a specific ability, skipping cooldown
- **Defining class abilities** — auto-granted slot identity per class (Tower Slam etc.)
- **Multi-attack penalty** — PF2e-style escalating cost on repeated same-attack use
- **Boss-difficulty scaling** — boss-specific ability injection + threat-based stat tiers (existing backlog)
- **WIL → CHA rename** — vocabulary drift away from Paizo identity

Per the vert-slice discipline note in `CLAUDE.md`, do not pre-build any of these.

---

## Notes on Standalone Identity

User flagged a goal of drifting away from PF2e-derivative identity (no Paizo partnership planned). Vocabulary changes are *not* in scope for this spec but worth tracking for future passes:

- "Stride" → can retire entirely (no movement in autobattler anyway)
- "Strike" → could become "Attack" or "Swing"
- "Ancestry" → already replaced by "Kindred"
- Specific spell-name overlaps with PF2e — audit later

The mechanical identity (autobattler + lane combat + creature collector) is already differentiated. Naming polish can come post-slice.
