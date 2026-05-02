# RogueFinder — Combat Pivot · Slice 1: SPD Attribute Foundation

> Paste this entire prompt into a fresh Claude Code session. It is the kickoff for one slice of an 8-slice combat pivot.

## Project Snapshot

- **Game:** RogueFinder — tactical turn-based roguelite / creature collector. Godot 4 / GDScript. Solo dev.
- **Repo root:** `C:\Users\caleb\.local\bin\Projects\RogueFinder` (the Godot project lives in `rogue-finder/`).
- **Pivot in progress:** Replacing the 10×10 tactical-grid combat with a turn-tick autobattler (Wildfrost-shape — 3 flat lanes per side, per-unit countdown, per-ability cooldown, simple priority-list AI, consumable-only player intervention). All non-combat systems (map, events, vendors, city, build, equipment, save) are untouched.
- **Spec:** `docs/superpowers/specs/2026-05-02-combat-pivot-design.md`
- **Plan:** `docs/superpowers/plans/2026-05-02-combat-pivot.md` (8 slices, TDD bite-sized tasks).
- **Branch:** `claude/combat-pivot-20260502`. Already exists at remote with the spec + plan committed. Do NOT rebase, do NOT merge to main, do NOT touch other slices.

## Required Reading Order

Before writing any code, read in this order:

1. `CLAUDE.md` (project root) — code conventions, save-system rules, **scoping discipline** (push back on scope creep).
2. `docs/superpowers/specs/2026-05-02-combat-pivot-design.md` — design intent. Skim; focus on the SPD/stat sections.
3. `docs/superpowers/plans/2026-05-02-combat-pivot.md` — open and read **Slice 1 only** (lines 74–421). Each task gives you exact code, exact paths, exact commands.

## Prior Slices Already Done

(none — you are the first slice.)

## Your Slice

**Goal:** Add SPD as a 6th core attribute. Migrate kindred `speed_bonus` into the new `spd_bonus` column. Persist `spd` to disk. Display SPD in PartySheet, StatPanel, and the Character Creation preview. The old `speed` getter retires (replaced by `spd`). Old combat is unaffected.

**Tasks (in order, follow the plan):**

- [ ] **1.1** Add `spd` field to `CombatantData`
- [ ] **1.2** Add `spd_bonus` column to `kindreds.csv` + `KindredLibrary`
- [ ] **1.3** Persist `spd` in save/load
- [ ] **1.4** Show SPD in `PartySheet` and `StatPanel`
- [ ] **1.5** Show SPD in `CharacterCreationManager` preview panel

## Workflow Rules (non-negotiable)

1. **Verify branch first.** Run `git status`. You should be on `claude/combat-pivot-20260502`. If not, stop and ask before switching.
2. **TDD per task.** For each task, follow the plan's exact steps: write failing test → run (expect fail) → implement → run (expect pass) → commit. **One commit per task** — do not batch.
3. **Run tests headless:**
   ```powershell
   godot --headless --path rogue-finder tests/<name>.tscn
   ```
   The plan calls out when an initial `godot --headless --path rogue-finder --import` is needed.
4. **Typed GDScript only.** snake_case vars/funcs, PascalCase class/node names, ALL_CAPS constants. Section headers `## --- Section ---`. Comment the *why*, not the *what*.
5. **No scope creep.** If you spot a "while I'm here, let me also..." temptation, defer it. The slice proves the core; depth comes after. Surface scope-trim opportunities — don't act on adjacent improvements.
6. **End-of-slice deliverables:**
   - All slice tests green (re-run them once at the end as a smoke check).
   - Branch pushed: `git push` (already tracking remote).
   - Final report: a numbered list of (a) what was built, (b) what Caleb should manually play-test in-engine before approving Slice 2.

## End-of-Slice Acceptance

After this slice:

- The game still launches and runs the **old** combat exactly as before (no behavior change in COMBAT/BOSS nodes).
- `CombatantData.spd` is a real `@export_range(1,10)` field, defaults to 4, round-trips through save/load.
- `kindreds.csv` has a `spd_bonus` column populated for all 8 kindreds. `KindredLibrary.get_spd_bonus(kindred)` returns the right value.
- PartySheet, StatPanel, and Character Creation preview all show an SPD line/column alongside STR/DEX/COG/WIL/VIT.
- All Slice 1 tests pass headlessly.

---

Begin by reading `CLAUDE.md`, then the spec, then the Slice 1 section of the plan. Then start Task 1.1.
