# RogueFinder — Combat Pivot · Slice 3: Combat Scaffold (Scene + LaneBoard + Skeleton)

> Paste this entire prompt into a fresh Claude Code session. It is the kickoff for one slice of an 8-slice combat pivot.

## Project Snapshot

- **Game:** RogueFinder — tactical turn-based roguelite / creature collector. Godot 4 / GDScript. Solo dev.
- **Repo root:** `C:\Users\caleb\.local\bin\Projects\RogueFinder` (the Godot project lives in `rogue-finder/`).
- **Pivot in progress:** Replacing the 10×10 tactical-grid combat with a turn-tick autobattler (Wildfrost-shape — 3 flat lanes per side, per-unit countdown, per-ability cooldown, simple priority-list AI, consumable-only player intervention).
- **Spec:** `docs/superpowers/specs/2026-05-02-combat-pivot-design.md`
- **Plan:** `docs/superpowers/plans/2026-05-02-combat-pivot.md` (8 slices, TDD bite-sized tasks).
- **Branch:** `claude/combat-pivot-20260502`. Already exists at remote with prior slice work committed. Do NOT rebase, do NOT merge to main, do NOT touch other slices.

## Required Reading Order

Before writing any code, read in this order:

1. `CLAUDE.md` (project root) — code conventions, save-system rules, **scoping discipline**.
2. `docs/superpowers/specs/2026-05-02-combat-pivot-design.md` — focus on the Layout, Combat Resolution Model, and "What Survives Untouched / Gets Ripped Out / Gets Added" sections.
3. `docs/superpowers/plans/2026-05-02-combat-pivot.md` — read the **Coexistence Strategy** at the top (around lines 65–72) and **Slice 3 only** (lines 573–972).

## Prior Slices Already Done

- **Slice 1 — SPD Attribute Foundation:** `CombatantData.spd` exists; kindred `spd_bonus` wired; SPD displays in UI; persists to save.
- **Slice 2 — Cooldown Field (Additive):** `AbilityData.cooldown_max` exists; `abilities.csv` has a `cooldown` column populated per the migration table. Old combat still uses `energy_cost`.

## Your Slice

**Goal:** Build the new combat scene shell that **coexists with the old**. Create:
- `LaneBoard` data structure (3 lanes × 2 sides — pure data, no movement).
- `CombatManager.gd` (`class_name CombatManagerAuto`) — stub that can be entered + exited, no tick loop yet.
- `PlacementOverlay.gd` skeleton — stubbed, no real UI yet.
- `MapManager.USE_AUTOBATTLER_COMBAT: bool = false` — feature flag that picks which scene COMBAT/BOSS nodes load. **Default false** so old combat still runs by default.

After this slice, flipping the flag to `true` locally yields a still-empty `CombatSceneAuto` that loads cleanly. Real combat logic lands in Slice 4.

**Tasks (in order, follow the plan):**

- [ ] **3.1** Create `LaneBoard` data structure
- [ ] **3.2** Create `CombatManager` skeleton (`class_name CombatManagerAuto`)
- [ ] **3.3** Add `USE_AUTOBATTLER_COMBAT` flag to `MapManager`
- [ ] **3.4** `PlacementOverlay` skeleton

## Workflow Rules (non-negotiable)

1. **Verify branch first.** `git status` — you should be on `claude/combat-pivot-20260502` with Slices 1+2 commits in your log.
2. **TDD per task.** Failing test → run → implement → run → commit. One commit per task.
3. **Run tests headless:**
   ```powershell
   godot --headless --path rogue-finder tests/<name>.tscn
   ```
4. **Typed GDScript only.** snake_case vars/funcs, PascalCase classes. `.tscn` files stay minimal (root + script only); build children in `_ready()`.
5. **Coexistence-first.** Do NOT delete or modify `CombatManager3D.gd`, `Grid3D.gd`, `QTEBar.gd`, `EnemyAI.gd`, or `CombatScene3D.tscn`. They survive until Slice 7.
6. **`USE_AUTOBATTLER_COMBAT` defaults to `false`.** Verifying old combat still runs is part of acceptance.
7. **No scope creep.** No tick loop, no targeting, no AI, no real placement UI in this slice. Skeletons only.
8. **End-of-slice deliverables:**
   - All Slice 3 tests green; all pre-existing combat-adjacent tests still green.
   - Branch pushed.
   - Final report: numbered list of what was built + (a) verify old combat still works with flag false, (b) verify empty CombatSceneAuto loads with flag flipped to true locally.

## End-of-Slice Acceptance

After this slice:

- With `USE_AUTOBATTLER_COMBAT = false`, the game runs the **old** combat at every COMBAT/BOSS node, exactly as before.
- With the flag flipped locally to `true`, COMBAT/BOSS nodes load `CombatSceneAuto.tscn` — it appears, runs `_ready()`, and can be exited cleanly back to the map (no error spam, no missing nodes).
- `LaneBoard` correctly stores 3 lanes × 2 sides, supports `place(unit, lane, side)`, lookup, and basic occupancy queries.
- `class_name CombatManagerAuto` resolves; `class_name LaneBoard` resolves.
- All Slice 3 tests pass (`test_lane_board.tscn` at minimum).

---

Begin by reading `CLAUDE.md`, then the spec, then the Slice 3 section of the plan. Then start Task 3.1.
