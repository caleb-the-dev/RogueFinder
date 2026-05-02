# RogueFinder — Combat Pivot · Slice 6: AI Module (Priority-List Pick)

> Paste this entire prompt into a fresh Claude Code session. It is the kickoff for one slice of an 8-slice combat pivot.

## Project Snapshot

- **Game:** RogueFinder — tactical turn-based roguelite / creature collector. Godot 4 / GDScript. Solo dev.
- **Repo root:** `C:\Users\caleb\.local\bin\Projects\RogueFinder` (the Godot project lives in `rogue-finder/`).
- **Pivot in progress:** Replacing the 10×10 tactical-grid combat with a turn-tick autobattler. The new combat already ticks units, resolves lane targeting, and fires `abilities[0]` as a stub. This slice replaces the stub with a real role-driven priority-list AI.
- **Spec:** `docs/superpowers/specs/2026-05-02-combat-pivot-design.md`
- **Plan:** `docs/superpowers/plans/2026-05-02-combat-pivot.md` (8 slices, TDD bite-sized tasks).
- **Branch:** `claude/combat-pivot-20260502`. Already exists at remote with prior slice work committed.

## Required Reading Order

Before writing any code, read in this order:

1. `CLAUDE.md` (project root) — code conventions, scoping discipline.
2. `docs/superpowers/specs/2026-05-02-combat-pivot-design.md` — focus on the AI Redesign section (priority list per role).
3. `docs/superpowers/plans/2026-05-02-combat-pivot.md` — read **Slice 6 only** (lines 1802–2093).

## Prior Slices Already Done

- **Slice 1 — SPD Attribute:** done.
- **Slice 2 — Cooldown Field:** done.
- **Slice 3 — Combat Scaffold:** done.
- **Slice 4 — Countdown Engine:** new combat runs end-to-end (stub AI fires `abilities[0]`).
- **Slice 5 — Lane Targeting:** ability shapes resolve correctly to lane targets.

## Your Slice

**Goal:** Replace the "always slot 0" stub with a **small priority-list AI**. Each role (ATTACKER, TANK, HEALER, SUPPORTER, CONTROLLER) has a preferred ordering of effect types (e.g. ATTACKER prefers HARM > BUFF; HEALER prefers MEND > BUFF > HARM). The AI picks the **highest-preference available off-cooldown ability with a valid target**. Wire into `_fire_unit_turn`. Apply MEND / BUFF / DEBUFF effects in `_apply_ability` so the AI's varied picks actually do something.

**Tasks (in order, follow the plan):**

- [ ] **6.1** Implement `AutobattlerEnemyAI` static module — `pick(unit, allies, hostiles, board) → {ability, target}`
- [ ] **6.2** Wire `AutobattlerEnemyAI` into `CombatManager`
- [ ] **6.3** Apply MEND / BUFF / DEBUFF effects in `_apply_ability` (HARM already worked from Slice 4)

## Workflow Rules (non-negotiable)

1. **Verify branch first.** `git status` — you should be on `claude/combat-pivot-20260502` with Slices 1–5 commits.
2. **TDD per task.** Failing test → run → implement → run → commit. One commit per task.
3. **Run tests headless:**
   ```powershell
   godot --headless --path rogue-finder tests/<name>.tscn
   ```
4. **Typed GDScript only.** Static module: `class_name AutobattlerEnemyAI extends RefCounted`, all `static func`.
5. **Player units use the same picker.** No separate "player AI" branch — player units run the same AI in autobattler. Player agency is the consumable interject (lands in Slice 7), not per-turn ability picking.
6. **No scope creep.** No FORCE/multi-step planning, no critical-heal override, no buff-redundancy scoring, no aggression-stance manipulation. Just role priority list + cooldown filter + valid-target filter. Depth comes after the slice proves the core.
7. **End-of-slice deliverables:**
   - All Slice 6 tests green; pre-existing tests still green.
   - Branch pushed.
   - Final report: numbered list of what was built + (a) verify old combat still works with flag false, (b) flip flag locally and verify role-biased ability variety — healers heal, attackers strike, buffers buff. Combat should look richer than just everyone strike-spamming.

## End-of-Slice Acceptance

After this slice:

- `AutobattlerEnemyAI.pick(unit, allies, hostiles, board)` returns `{ability, target}` (or null/empty if nothing fires) using role-based effect-type preference order.
- Off-cooldown filter works: an ability with `cooldowns[slot] > 0` is skipped.
- Valid-target filter works: an ability with no resolvable target (e.g. MEND when all allies full HP, or a SAME_LANE strike with no opposite enemy) is skipped.
- `_apply_ability` correctly applies HARM, MEND, BUFF, and DEBUFF effects to the resolved targets.
- With flag locally true, the autobattler shows ability variety — not every unit just strikes.
- All Slice 6 tests pass.

---

Begin by reading `CLAUDE.md`, then the spec, then the Slice 6 section of the plan. Then start Task 6.1.
