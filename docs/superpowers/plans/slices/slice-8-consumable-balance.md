# RogueFinder — Combat Pivot · Slice 8: Consumable Balance Pass

> Paste this entire prompt into a fresh Claude Code session. It is the kickoff for the **final slice** of the 8-slice combat pivot. **After this slice, the vert slice is complete and play-testable end-to-end.**

## Project Snapshot

- **Game:** RogueFinder — tactical turn-based roguelite / creature collector. Godot 4 / GDScript. Solo dev.
- **Repo root:** `C:\Users\caleb\.local\bin\Projects\RogueFinder` (the Godot project lives in `rogue-finder/`).
- **Pivot in progress:** The autobattler is **live** — countdown ticking, role-driven AI, lane targeting, placement UI, floating countdowns, consumable interject button. This slice tunes consumables so they feel impactful as the only mid-fight player input.
- **Spec:** `docs/superpowers/specs/2026-05-02-combat-pivot-design.md`
- **Plan:** `docs/superpowers/plans/2026-05-02-combat-pivot.md` (8 slices, TDD bite-sized tasks).
- **Branch:** `claude/combat-pivot-20260502`. Already exists at remote with prior slice work committed.

## Required Reading Order

Before writing any code, read in this order:

1. `CLAUDE.md` (project root) — code conventions, scoping discipline.
2. `docs/superpowers/specs/2026-05-02-combat-pivot-design.md` — focus on Player Agency (consumables are the only knob the player turns mid-fight).
3. `docs/superpowers/plans/2026-05-02-combat-pivot.md` — read **Slice 8 only** (lines 2524–2575). Short slice — single task.

## Prior Slices Already Done

- **Slices 1–7:** SPD attribute, cooldown field, combat scaffold, countdown engine, lane targeting, AI module, cutover (flag flipped, old combat ripped, placement UI + countdown numbers + consumable button live).

## Your Slice

**Goal:** Buff existing consumables so they feel impactful as the only mid-fight player input. **No code changes — just CSV value edits.**

**Tasks (in order, follow the plan):**

- [ ] **8.1** Tune `consumables.csv` values

Proposed pattern from the plan (verify against current CSV before editing):
- `steel_tonic`, `clarity_brew`, `iron_word` and similar +1-stat sips → bump to +3
- Healing potion → +12 (clutch heal)
- Optionally add 2–3 "panic button" consumables (`phoenix_draught` MEND +20, etc.) **only if** the slate feels thin
- **Defer** any consumable that needs `COUNTDOWN_MOD` or duration-based effects — those features are post-slice per the spec.

## Workflow Rules (non-negotiable)

1. **Verify branch first.** `git status` — you should be on `claude/combat-pivot-20260502` with Slices 1–7 commits. New combat must be live (flag true).
2. **CSV-only edits.** No code changes. If you find yourself wanting to add a new effect type or modify the consumable pipeline, stop — that's Slice 9+ territory and likely a future-Caleb decision.
3. **Run consumable tests headless after editing:**
   ```powershell
   godot --headless --path rogue-finder tests/test_consumables.tscn
   ```
   Expected: PASS.
4. **Play-test in-engine.** Run the game. Enter combat. Use a consumable. Verify it feels like a meaningful "press now" moment.
5. **No scope creep.** **Especially here.** This slice is the slimmest in the plan for a reason — it's the last fence before play-test. Resist the urge to "while I'm here" anything. The next step after this slice is Caleb plays the build and decides what to deepen.
6. **End-of-slice deliverables:**
   - `test_consumables.tscn` green; all surviving tests still green.
   - Branch pushed.
   - Final report: numbered list of what was tuned + an explicit play-test prompt: **"Caleb — play through 3+ combats, use 2+ consumables per fight, and tell me whether the agency layer feels meaningful."**

## End-of-Slice Acceptance

After this slice:

- `consumables.csv` values are tuned per the proposed pattern (or your judgment-call variant).
- `test_consumables.tscn` passes.
- The autobattler vert slice is **complete**. End-of-pivot marker hit.
- All deferred features (status effects, countdown manipulation, front/back depth, hazards, stance, class-button override, defining class abilities, multi-attack penalty, boss scaling, WIL→CHA rename) **stay deferred** until Caleb's play-test confirms the core works.

## After This Slice — Hold the Line

The pivot's central lesson is: **slices are disposable, depth is added after the slice proves the core**. After Slice 8 ships, the next move is **play-test**, not "Slice 9." Don't propose new work until Caleb has actually played the build.

---

Begin by reading `CLAUDE.md`, then the spec, then the Slice 8 section of the plan. Then start Task 8.1.
