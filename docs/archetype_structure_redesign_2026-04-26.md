# Archetype Structure Redesign — Brainstorm Notes

**Date:** 2026-04-26
**Status:** Architecture LOCKED. Specific content (per-pillar abilities/feats/numbers) deferred to follow-up sessions.
**Canonical reference:** `GAME_BIBLE_roguefinder.md` → Build System section.

> This is the brainstorm-history doc — captures the *why*, the *open questions*, and the *implementation punch list*. The game bible carries the locked structure as canon.

---

## 1. The shape (summary)

See game bible for the canonical version. Quick recap:

- **Class** is the spine. Owns ~85% of run-time ability + feat growth. Provides a unique-per-class defining ability, auto-granted at run start.
- **Kindred** owns the ability lane only — 1 natural-attack starter + 2 ancestry abilities in pool.
- **Background** owns the feat lane only — 1 defining feat starter + 2 bg feats in pool.
- **Stats** start at base 4; pillar bumps capped at +2 max / −1 min per stat per pillar.
- **End-of-run:** 6 abilities (1 kindred + 5 class) + 5 feats (1 bg + 4 class).

---

## 2. Class defining abilities (locked)

Auto-granted at run start as the first class pool pick. **Unique per class — never shared.**

| Class | Defining Ability | Attribute / Type | Target | Range | Effects | Cost |
|---|---|---|---|---|---|---|
| **Vanguard** | Tower Slam | STR / Phys | SINGLE enemy | 1 | HARM 4 + push 1 | 3 |
| **Arcanist** | Arcane Bolt | COG / Arc | SINGLE enemy | 4 | HARM 5 | 3 |
| **Prowler** | Slipshot | DEX / Phys | SINGLE enemy | 3 | HARM 4 + free 1-tile reposition (before or after) | 3 |
| **Warden** | Bless | WIL | SINGLE ally | 3 | BUFF +1 STR (1 turn) | 2 |

Numbers are first-pass — balance over polish, tunable later.

---

## 3. Overlap rules

- **Class definings** — unique per class. No two classes share their defining ability.
- **Class pool abilities & feats** — can overlap freely with other classes' pools.
- **Kindred natural-attack starters** — flavored per species, but mechanically can be shared (e.g., Human and Half-Orc could both start with "Strike").
- **Kindred ancestry pool abilities** — can overlap freely between kindreds.
- **Background defining feats** — should be unique per background (each has a clear identity feat). Pool overlap allowed.
- **Background pool feats** — can overlap freely.

Sharing is encouraged where it serves clarity (Magic Bolt feels right for both spellcasters); avoided where it would erase identity (Tower Slam is a Vanguard thing).

---

## 4. Vertical-slice scope (estimates)

| Item | Count after overlap | Notes |
|---|---|---|
| Class defining abilities | 4 (1 per class) | **Locked.** |
| Class pool abilities | ~26 unique (52 slots × ~50% overlap) | Need design pass |
| Kindred natural attacks | ~4-6 unique (4 starters + sharable) | Need design pass |
| Kindred ancestry abilities | ~4-6 unique (8 slots × ~50% overlap) | Need design pass |
| Background defining feats | 4 (1 per bg) | Pick from existing `feats.csv`? |
| Background pool feats | ~4-6 unique (8 slots × ~50% overlap) | Need design pass |
| Class pool feats | ~20 unique (40 slots × ~50% overlap) | 28 feats already in CSV; ~4 short |

**Targets for vertical slice:**
- ~32-38 unique abilities
- ~28-32 unique feats

---

## 5. Data migration notes (for the implementation session)

The locked architecture requires CSV/data changes:

### `classes.csv`
- `starting_ability_id` updates to the new defining abilities:
  - vanguard → `tower_slam` (replaces `shield_bash`)
  - arcanist → `arcane_bolt` (replaces `fireball`)
  - prowler → `slipshot` (replaces `quick_shot`)
  - warden → `bless` (replaces `inspire`)
- `ability_pool` expands to 13 ids (currently 5)
- `feat_pool` expands to 10 ids (currently 3)

### `kindreds.csv`
- **Remove** `feat_id` column (kindreds no longer grant feats)
- **Add** `starting_ability_id` column (the natural-attack basic per kindred)
- **Add** `ability_pool` column (2 ancestry abilities per kindred, pipe-separated)
- **Add** `stat_bonuses` column for parity (currently has only speed/hp)

### `backgrounds.csv`
- **Remove** `starting_ability_id` (backgrounds no longer grant abilities)
- **Add** `starting_feat_id` (the defining feat per background)
- **Add** `feat_pool` column (2 bg feats per background)
- **Add** `stat_bonuses` column

### `feats.csv`
- 4 `source_type=kindred` rows become orphaned. **Decision:** migrate their stat bumps directly into `kindreds.stat_bonuses` and delete the kindred-source feats.
- 12 background-source feats already exist; 4 become defining starters; remaining 8 distribute across bg pools (2 per bg).
- 12 class-source feats need expansion to ~10 per class with overlap (~20 unique total).

### `abilities.csv`
- Add 4 class definings (Tower Slam, Arcane Bolt, Slipshot, Bless)
- Add ~4 kindred natural attacks
- Add ~4-6 kindred ancestry abilities
- Re-flavor / replace some of the existing 22 placeholder abilities to fit the new class pools

### `CombatantData` / `GameState`
- `kindred_feat_id` field unused — remove or repurpose
- Existing `feat_ids` array stays as-is (now sourced from bg + class only)
- Migration code needed for old saves with kindred feat ids

### `CharacterCreationManager`
- Class def ability auto-granted (first pick from class pool, not a select-3)
- Kindred ability granted from `KindredData.starting_ability_id`
- Background feat granted from `BackgroundData.starting_feat_id`
- Stat bumps applied from all 3 pillars
- Preview panel updates: show class def + kindred ability + bg feat (instead of class ability + bg ability + kindred feat)

---

## 6. Open questions / deferred decisions

1. **Specific kindred natural attacks** — 4 needed for current vertical slice (Human, Half-Orc, Gnome, Dwarf).
2. **Specific kindred ancestry abilities** — 8 slots × overlap → ~4-6 unique to design.
3. **Specific class pool abilities** — 52 slots × overlap → ~26 unique across HARM/MEND/BUFF/DEBUFF/FORCE/TRAVEL with ~15-25% off-type variety per the bible.
4. **Specific class pool feats** — 40 slots × overlap → ~20 unique.
5. **Specific background defining feats** — 4 to lock in (existing `feats.csv` has good candidates).
6. **Specific background pool feats** — 8 slots × overlap → ~4-6 unique.
7. **Stat bump distribution per pillar** — final tuning per pillar.
8. **Class def ability auto-grant UX** — should CharacterCreation surface "Vanguard always starts with Tower Slam" clearly to the player at class-pick time?

---

## 7. Suggested order for follow-up sessions

**Session 1 — Lock kindred & background content:**
- Design 4 kindred natural attacks
- Design 4-6 kindred ancestry abilities (with overlap noted)
- Pick 4 background defining feats
- Design 4-6 background pool feats
- Tune stat bumps across all 3 pillars

**Session 2 — Lock class content:**
- Design class pool abilities (~26 unique across 4 classes)
- Design class pool feats (~20 unique)
- Document overlaps explicitly

**Session 3 — Implementation pass:**
- All CSV updates per §5
- Code migrations (CombatantData, CharacterCreationManager, save migration)
- Tests
- `/wrapup`

---

## 8. Design philosophy reminders from this session

- **No new combat mechanics.** Stick to the 6 existing effect types: HARM / MEND / BUFF / DEBUFF / FORCE / TRAVEL. No Marks, no aggro, no target_marking.
- **Balance is OK-ish, not perfect.** Numbers are first-pass and tunable in playtest.
- **Class is the spine.** Kindred and Background are flavor anchors.
- **Stay-in-lane.** Kindred = ability lane only. Background = feat lane only. Class = both.
- **Statistics-driven variety.** Pool size differences (87/13, 83/17) deliver flavor without needing complex acquisition rules.
- **Kindred natural attack = the floor.** Ensures every character always has a damage option.
