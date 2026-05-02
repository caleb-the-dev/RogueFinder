# RogueFinder — Combat Pivot · Slice 2: Cooldown Field on AbilityData (Additive)

> Paste this entire prompt into a fresh Claude Code session. It is the kickoff for one slice of an 8-slice combat pivot.

## Project Snapshot

- **Game:** RogueFinder — tactical turn-based roguelite / creature collector. Godot 4 / GDScript. Solo dev.
- **Repo root:** `C:\Users\caleb\.local\bin\Projects\RogueFinder` (the Godot project lives in `rogue-finder/`).
- **Pivot in progress:** Replacing the 10×10 tactical-grid combat with a turn-tick autobattler (Wildfrost-shape — 3 flat lanes per side, per-unit countdown, per-ability cooldown, simple priority-list AI, consumable-only player intervention). All non-combat systems are untouched.
- **Spec:** `docs/superpowers/specs/2026-05-02-combat-pivot-design.md`
- **Plan:** `docs/superpowers/plans/2026-05-02-combat-pivot.md` (8 slices, TDD bite-sized tasks).
- **Branch:** `claude/combat-pivot-20260502`. Already exists at remote with prior slice work committed. Do NOT rebase, do NOT merge to main, do NOT touch other slices.

## Required Reading Order

Before writing any code, read in this order:

1. `CLAUDE.md` (project root) — code conventions, save-system rules, **scoping discipline**.
2. `docs/superpowers/specs/2026-05-02-combat-pivot-design.md` — focus on the Ability System Updates section (the cooldown migration table).
3. `docs/superpowers/plans/2026-05-02-combat-pivot.md` — read **Slice 2 only** (lines 423–571).

## Prior Slices Already Done

- **Slice 1 — SPD Attribute Foundation:** `CombatantData.spd` exists; `kindreds.csv` has `spd_bonus`; SPD displays in PartySheet/StatPanel/Char Creation; persists to save. Old combat is unaffected.

## Your Slice

**Goal:** Add a `cooldown_max: int` field to `AbilityData`. Add a `cooldown` column to `abilities.csv`. Populate values per the migration table (1–2 → 2, 3–4 → 3, 5+ → 5). Old combat continues to use `energy_cost`. New combat (Slice 4+) will use `cooldown_max`. **Both fields coexist** until the Slice 7 cutover.

**Tasks (in order, follow the plan):**

- [ ] **2.1** Add `cooldown_max` field to `AbilityData`
- [ ] **2.2** Add `cooldown` column to `abilities.csv` + parse in `AbilityLibrary`

## Workflow Rules (non-negotiable)

1. **Verify branch first.** `git status` — you should be on `claude/combat-pivot-20260502` with Slice 1's commits in your log. If not, stop and ask.
2. **TDD per task.** Failing test → run → implement → run → commit. One commit per task.
3. **Run tests headless:**
   ```powershell
   godot --headless --path rogue-finder tests/<name>.tscn
   ```
4. **Typed GDScript only.** snake_case vars/funcs, PascalCase classes, ALL_CAPS constants. Comment the *why*, not the *what*.
5. **Additive only.** Do NOT delete `energy_cost` or change how the old combat uses it. The two fields **must** coexist until Slice 7.
6. **No scope creep.** Don't tune values, don't add new abilities, don't refactor `AbilityLibrary` beyond the new column. Defer.
7. **End-of-slice deliverables:**
   - All Slice 2 tests green; all pre-existing ability tests still green.
   - Branch pushed.
   - Final report: numbered list of what was built and what to manually verify in-engine.

## End-of-Slice Acceptance

After this slice:

- The game still launches. Old combat plays exactly as before — `energy_cost` is untouched.
- `AbilityData.cooldown_max` is a new `@export var`, defaults to 0.
- `abilities.csv` has a `cooldown` column populated per the migration table for every existing ability.
- `AbilityLibrary.get_ability(id).cooldown_max` returns the value from the CSV.
- All Slice 2 tests pass; pre-existing `test_ability_library` and any other ability-touching tests pass.

---

Begin by reading `CLAUDE.md`, then the spec, then the Slice 2 section of the plan. Then start Task 2.1.
