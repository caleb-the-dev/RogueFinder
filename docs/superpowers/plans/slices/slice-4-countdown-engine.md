# RogueFinder — Combat Pivot · Slice 4: Countdown Engine + Tick Loop

> Paste this entire prompt into a fresh Claude Code session. It is the kickoff for one slice of an 8-slice combat pivot.

## Project Snapshot

- **Game:** RogueFinder — tactical turn-based roguelite / creature collector. Godot 4 / GDScript. Solo dev.
- **Repo root:** `C:\Users\caleb\.local\bin\Projects\RogueFinder` (the Godot project lives in `rogue-finder/`).
- **Pivot in progress:** Replacing the 10×10 tactical-grid combat with a turn-tick autobattler (Wildfrost-shape — 3 flat lanes per side, per-unit countdown, per-ability cooldown, simple priority-list AI, consumable-only player intervention).
- **Spec:** `docs/superpowers/specs/2026-05-02-combat-pivot-design.md`
- **Plan:** `docs/superpowers/plans/2026-05-02-combat-pivot.md` (8 slices, TDD bite-sized tasks).
- **Branch:** `claude/combat-pivot-20260502`. Already exists at remote with prior slice work committed.

## Required Reading Order

Before writing any code, read in this order:

1. `CLAUDE.md` (project root) — code conventions, save-system rules, scoping discipline.
2. `docs/superpowers/specs/2026-05-02-combat-pivot-design.md` — focus on Combat Resolution Model and Stat Changes (especially the `countdown_max = clamp(8 - SPD, 2, 12)` formula).
3. `docs/superpowers/plans/2026-05-02-combat-pivot.md` — read **Slice 4 only** (lines 974–1490).

## Prior Slices Already Done

- **Slice 1 — SPD Attribute:** `CombatantData.spd` field, kindred `spd_bonus`, UI display.
- **Slice 2 — Cooldown Field (Additive):** `AbilityData.cooldown_max` + CSV column.
- **Slice 3 — Combat Scaffold:** `LaneBoard`, `CombatManager` skeleton, `PlacementOverlay` skeleton, `USE_AUTOBATTLER_COMBAT` flag (default false). Empty `CombatSceneAuto` loads cleanly when flag flipped.

## Your Slice

**Goal:** Implement the **heart of the autobattler** — countdown ticking, per-ability cooldown decrement, and the basic tick loop that fires units when their countdown hits 0. AI is a **stub picker** (always picks slot 0 = basic strike) until Slice 6. After this slice, flipping the feature flag yields a watchable autobattler that runs to completion using only basic strikes.

**Tasks (in order, follow the plan):**

- [ ] **4.1** `CountdownTracker` static module
- [ ] **4.2** Add countdown fields to `CombatantData` (`countdown_current`, `countdown_max`, `cooldowns: Array[int]`)
- [ ] **4.3** `CombatManager` tick loop with stub AI (always slot 0)
- [ ] **4.4** Real-time tick driver via `_process`
- [ ] **4.5** Wire `MapManager` → `CombatManager.start_combat()`

## Workflow Rules (non-negotiable)

1. **Verify branch first.** `git status` — you should be on `claude/combat-pivot-20260502` with Slices 1–3 commits.
2. **TDD per task.** Failing test → run → implement → run → commit. One commit per task.
3. **Run tests headless:**
   ```powershell
   godot --headless --path rogue-finder tests/<name>.tscn
   ```
4. **Typed GDScript only.** Static module pattern for `CountdownTracker` (`class_name CountdownTracker extends RefCounted`, all `static func`).
5. **Coexistence-first.** Old combat code is **untouched**. The flag still defaults to `false`; flipping to `true` locally is how you test.
6. **Stub AI only this slice.** Do NOT write real ability picking, lane-shape resolving, or role logic. Always pick `unit.abilities[0]`. Real targeting lands in Slice 5; real AI lands in Slice 6.
7. **No scope creep.** No floating UI numbers, no consumable button, no placement UI, no animations. Behavior over polish.
8. **End-of-slice deliverables:**
   - All Slice 4 tests green; pre-existing tests still green.
   - Branch pushed.
   - Final report: numbered list of what was built + (a) verify old combat still works with flag false, (b) flip flag locally and verify the autobattler runs to completion (one side wipes the other) using basic strikes — no errors, no infinite loops.

## End-of-Slice Acceptance

After this slice:

- With `USE_AUTOBATTLER_COMBAT = true` locally, the new combat runs end-to-end: units tick, countdowns decrement, units fire `abilities[0]` when ready, HP drops, a side eventually wipes, combat ends, you return to the map.
- With the flag back to `false`, old combat is unaffected.
- `CountdownTracker.compute_countdown_max(spd)` matches `clamp(8 - spd, 2, 12)`.
- `CombatantData` has `countdown_current`, `countdown_max`, and `cooldowns: Array[int]` (typed). All Slice 4 tests pass.
- Tiebreak ordering (higher SPD acts first when multiple countdowns hit 0) works.

---

Begin by reading `CLAUDE.md`, then the spec, then the Slice 4 section of the plan. Then start Task 4.1.
