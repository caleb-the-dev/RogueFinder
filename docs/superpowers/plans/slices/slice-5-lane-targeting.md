# RogueFinder — Combat Pivot · Slice 5: Lane Targeting

> Paste this entire prompt into a fresh Claude Code session. It is the kickoff for one slice of an 8-slice combat pivot.

## Project Snapshot

- **Game:** RogueFinder — tactical turn-based roguelite / creature collector. Godot 4 / GDScript. Solo dev.
- **Repo root:** `C:\Users\caleb\.local\bin\Projects\RogueFinder` (the Godot project lives in `rogue-finder/`).
- **Pivot in progress:** Replacing the 10×10 tactical-grid combat with a turn-tick autobattler. 3 flat lanes per side; abilities target by lane shape (same lane, adjacent, all).
- **Spec:** `docs/superpowers/specs/2026-05-02-combat-pivot-design.md`
- **Plan:** `docs/superpowers/plans/2026-05-02-combat-pivot.md` (8 slices, TDD bite-sized tasks).
- **Branch:** `claude/combat-pivot-20260502`. Already exists at remote with prior slice work committed.

## Required Reading Order

Before writing any code, read in this order:

1. `CLAUDE.md` (project root) — code conventions, scoping discipline.
2. `docs/superpowers/specs/2026-05-02-combat-pivot-design.md` — focus on the Layout and Ability System Updates sections (target shapes).
3. `docs/superpowers/plans/2026-05-02-combat-pivot.md` — read **Slice 5 only** (lines 1491–1801).

## Prior Slices Already Done

- **Slice 1 — SPD Attribute:** done.
- **Slice 2 — Cooldown Field:** done.
- **Slice 3 — Combat Scaffold:** done.
- **Slice 4 — Countdown Engine:** new combat runs end-to-end with stub AI (`abilities[0]` only). Flag still defaults to false.

## Your Slice

**Goal:** Replace the stub target picker with **shape-aware lane targeting**. Add new `TargetShape` enum values (`SAME_LANE`, `ADJACENT_LANE`, `ALL_LANES`, `ALL_ALLIES`), update `abilities.csv` to use them, and write the resolver in `CombatManager`. **Old TargetShape values (CONE/LINE/RADIAL/ARC) stay** until Slice 7 to keep old combat compiling.

**Tasks (in order, follow the plan):**

- [ ] **5.1** Add lane `TargetShape` enum values (additive — old values stay)
- [ ] **5.2** Migrate `abilities.csv` to lane shapes (per the migration table in the plan)
- [ ] **5.3** Lane-aware target resolver in `CombatManager` (`resolve_targets` static helper)

## Workflow Rules (non-negotiable)

1. **Verify branch first.** `git status` — you should be on `claude/combat-pivot-20260502` with Slices 1–4 commits.
2. **TDD per task.** Failing test → run → implement → run → commit. One commit per task.
3. **Run tests headless:**
   ```powershell
   godot --headless --path rogue-finder tests/<name>.tscn
   ```
4. **Typed GDScript only.** snake_case vars/funcs, PascalCase classes.
5. **Additive enum values.** Do NOT remove `CONE`, `LINE`, `RADIAL`, or `ARC` — old combat still references them. They die in Slice 7.
6. **Migration mapping** is in the plan (SINGLE→SAME_LANE, CONE→ADJACENT_LANE, etc.). Tune individual abilities away from defaults only if design intent calls for it (e.g. `cleave` may fit `ALL_LANES` better than `ADJACENT_LANE`).
7. **No scope creep.** No real placement UI, no countdown labels, no consumable button. Targeting only.
8. **End-of-slice deliverables:**
   - All Slice 5 tests green; pre-existing tests still green (especially `test_ability_library`).
   - Branch pushed.
   - Final report: numbered list of what was built + (a) verify old combat still works with flag false, (b) flip flag locally and verify autobattler now picks correct lane targets (e.g. SINGLE strike hits the same-lane opponent, not just any enemy).

## End-of-Slice Acceptance

After this slice:

- `AbilityData.TargetShape` has new enum values: `SAME_LANE`, `ADJACENT_LANE`, `ALL_LANES`, `ALL_ALLIES`.
- `abilities.csv` has been migrated — every row uses a new shape value (no remaining `CONE`/`LINE`/`RADIAL`/`ARC` for live abilities).
- Old enum values still exist in code and parse correctly (legacy until Slice 7).
- `CombatManagerAuto.resolve_targets(ability, caster, board)` returns a typed `Array[CombatantData]` of valid targets per shape.
- With flag locally true, the autobattler resolves shape correctly: a `SAME_LANE` strike hits only the opposite-lane enemy; an `ALL_LANES` ability hits every enemy; an `ALL_ALLIES` heal touches every ally.
- All Slice 5 tests pass.

---

Begin by reading `CLAUDE.md`, then the spec, then the Slice 5 section of the plan. Then start Task 5.1.
