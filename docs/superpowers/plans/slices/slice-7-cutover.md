# RogueFinder — Combat Pivot · Slice 7: Cutover (Switch the Flag, Rip the Old Combat)

> Paste this entire prompt into a fresh Claude Code session. It is the kickoff for one slice of an 8-slice combat pivot. **This slice is destructive — read the workflow rules carefully.**

## Project Snapshot

- **Game:** RogueFinder — tactical turn-based roguelite / creature collector. Godot 4 / GDScript. Solo dev.
- **Repo root:** `C:\Users\caleb\.local\bin\Projects\RogueFinder` (the Godot project lives in `rogue-finder/`).
- **Pivot in progress:** Replacing the 10×10 tactical-grid combat with a turn-tick autobattler. By end of Slice 6 the new combat is feature-complete behind a feature flag. **This slice flips the flag, rips the old combat, and adds the polish UI** (placement, countdown numbers, consumable button).
- **Spec:** `docs/superpowers/specs/2026-05-02-combat-pivot-design.md`
- **Plan:** `docs/superpowers/plans/2026-05-02-combat-pivot.md` (8 slices, TDD bite-sized tasks).
- **Branch:** `claude/combat-pivot-20260502`. Already exists at remote with prior slice work committed.

## Required Reading Order

Before writing any code, read in this order:

1. `CLAUDE.md` (project root) — code conventions, scoping discipline, save-system rules (a save migration may be needed if energy fields persist).
2. `docs/superpowers/specs/2026-05-02-combat-pivot-design.md` — focus on Player Agency (consumable interject) and "What Gets Ripped Out / What Gets Added."
3. `docs/superpowers/plans/2026-05-02-combat-pivot.md` — read **Slice 7 only** (lines 2094–2522).

## Prior Slices Already Done

- **Slice 1 — SPD Attribute:** done.
- **Slice 2 — Cooldown Field:** done.
- **Slice 3 — Combat Scaffold:** done.
- **Slice 4 — Countdown Engine:** done.
- **Slice 5 — Lane Targeting:** done.
- **Slice 6 — AI Module:** new combat runs end-to-end with role-driven AI. Flag still defaults to false.

## Your Slice

**Goal:** Cutover. Flip `USE_AUTOBATTLER_COMBAT` to `true`. Build the **placement UI** so Caleb assigns his 3 active units to the 3 lanes pre-fight. Add **floating countdown numbers** above units. Add a **consumable interject button** (the only mid-fight player input). Then **rip out the legacy 3D combat** code and **retire the deprecated fields** (energy_cost, current_energy, energy_max, energy_regen, legacy TargetShape values).

**Tasks (in order, follow the plan):**

- [ ] **7.1** Flip the feature flag (`USE_AUTOBATTLER_COMBAT = true`)
- [ ] **7.2** Build `PlacementOverlay` UI (real, draggable lane assignment)
- [ ] **7.3** Floating countdown numbers above units
- [ ] **7.4** Consumable interject button
- [ ] **7.5** Rip out the legacy combat code
- [ ] **7.6** Retire energy fields and legacy TargetShape values

## Workflow Rules (non-negotiable)

1. **Verify branch first.** `git status` — you should be on `claude/combat-pivot-20260502` with Slices 1–6 commits. Also confirm Slices 1–6 tests are green before starting.
2. **TDD per task** where tests apply. Failing test → run → implement → run → commit. One commit per task. Some tasks are deletions/refactors; for those, commit per coherent unit (e.g. delete-old-combat-files in one commit, retire-fields in another).
3. **Run tests headless:**
   ```powershell
   godot --headless --path rogue-finder tests/<name>.tscn
   ```
4. **Destructive task safety (Task 7.5):**
   - Files deleted: `CombatManager3D.gd`, `Grid3D.gd`, `QTEBar.gd`, `EnemyAI.gd` (the old one), `CombatScene3D.tscn`, `Grid3D.tscn`, `QTEBar.tscn`. Confirm each file's last-known references are dead before `git rm`.
   - **Do NOT delete `Unit3D.gd`** — it survives but loses movement, AoE, FORCE response, QTE binding.
   - After deletes, run a project-wide `grep` for `CombatManager3D`, `Grid3D`, `QTEBar`, `class_name EnemyAI`, `CombatScene3D` — no live references should remain.
5. **Save migration (Task 7.6):** if `current_energy` was persisted in the save file, `GameState.load_save()` must tolerate older save files that contain the field. Discard cleanly; don't crash on legacy keys.
6. **Typed GDScript only.** snake_case vars/funcs, PascalCase classes.
7. **No scope creep.** No new abilities, no balance tuning (that's Slice 8), no new effect types, no new UI flourishes beyond the three things on the task list.
8. **End-of-slice deliverables:**
   - All slice tests green; pre-existing tests that survive the cutover still green.
   - Old-combat tests (e.g. `test_qte`, `test_grid3d` if any) deleted alongside the code they test.
   - Branch pushed.
   - Final report: numbered list of what was built/ripped + manual play-test checklist (a) placement UI works, (b) countdown numbers visible during combat, (c) consumable button fires mid-fight, (d) loading an old save (with energy fields) doesn't crash, (e) every COMBAT/BOSS node uses the new combat with no fallback to old.

## End-of-Slice Acceptance

After this slice:

- `MapManager.USE_AUTOBATTLER_COMBAT = true`. Old combat no longer reachable.
- Legacy combat files **deleted from disk and git** — no `CombatManager3D.gd`, `Grid3D.gd`, `QTEBar.gd`, `EnemyAI.gd` (old), `CombatScene3D.tscn`, `Grid3D.tscn`, `QTEBar.tscn`.
- `AbilityData.energy_cost` field removed; `CombatantData.current_energy` / `energy_max` / `energy_regen` removed; legacy `TargetShape.CONE/LINE/RADIAL/ARC` removed.
- `GameState.load_save()` tolerates older saves that still have energy keys (drops them silently).
- Pre-fight placement UI lets Caleb drag/assign 3 active units to 3 lanes.
- Floating countdown numbers tick down above each unit during combat.
- A consumable button is reachable mid-combat and applies its effect when pressed.
- All surviving tests pass.

---

Begin by reading `CLAUDE.md`, then the spec, then the Slice 7 section of the plan. Then start Task 7.1.
