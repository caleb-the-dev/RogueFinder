# System: QTE System

> Last updated: 2026-04-28 (Slice 3 — RecruitBar added as a second QTE type)

---

## Purpose

The QTE system covers two distinct skill checks used in combat:

1. **QTEBar** — the original horizontal Slide dodge check, played by the DEFENDER when a HARM effect targets them.
2. **RecruitBar** — a new vertical hold-and-release capture check, played by the PATHFINDER when attempting to recruit an enemy.

Both bars live at CanvasLayer 10–11, float above their target in world space, and emit a `float` result (0.25 / 0.75 / 1.0 / 1.25).

---

## QTEBar — Dodge Check

The QTEBar renders a **horizontal Slide** check overlay and emits a `multiplier` float
(0.25 / 0.75 / 1.0 / 1.25) that represents the **defender's dodge quality**.

This multiplier is mapped to a **damage multiplier** in CombatManager3D:

| Defender roll | Damage multiplier |
|---|---|
| 1.25 (perfect dodge) | 0.5 |
| 1.0 (good dodge) | 0.75 |
| 0.75 (weak dodge) | 1.0 |
| 0.25 (miss) | 1.25 |

**HARM-only.** The QTE fires only for HARM effects. All other effect types (MEND, BUFF,
DEBUFF, FORCE, TRAVEL) auto-resolve at effective multiplier 1.0 — never miss, no QTE.

**Defender-driven.** The QTE is played by the unit being attacked, not the caster:
- Player-controlled defender: `QTEBar.start_qte()` runs; player plays Slide.
- AI-controlled defender: invisible roll via `qte_resolution` stat (no bar shown).

Enemy simulation is handled entirely in CombatManager3D; the QTEBar is never shown.

---

## QTEBar — Core Nodes / Scripts

| File | Scene | Role |
|------|-------|------|
| `scripts/combat/QTEBar.gd` | `scenes/combat/QTEBar.tscn` | Single-beat Slide QTE, CanvasLayer layer 10 |

`.tscn` is minimal. All UI nodes are built in `_build_ui()`.

---

## QTE Style: Slide (only)

The **Slide** style is the only QTE style. Stop a sliding cursor in the coloured zone to
dodge. Higher zone = better dodge = less incoming damage.

All other styles (Hold, Target, Directional) have been deleted.

---

## Dependencies

None. QTEBar has **no runtime dependencies** on other game systems. It is purely
input-in → multiplier-out.

CombatManager3D calls `start_qte()` and **awaits** `qte_resolved` inline (no signal
connection — `await _qte_bar.qte_resolved`).

---

## Signals Emitted

| Signal | Arguments | When |
|--------|-----------|------|
| `qte_resolved` | `multiplier: float` | Single beat completes and feedback is shown |

`multiplier` is the **defender's dodge roll**: one of `1.25` (perfect), `1.0` (good),
`0.75` (weak), `0.25` (miss). CombatManager maps this via `_defender_roll_to_dmg_multiplier()`.

---

## Public Methods

| Method | Signature | Purpose |
|--------|-----------|---------|
| `start_qte` | `(energy_cost: int, attacker: Node3D) -> void` | Sets difficulty, stores attacker ref for world-space tracking, resets state, starts cursor animation |

`attacker` is the enemy Unit3D whose world position the bar tracks each frame.
Difficulty is set from the attacking ability's `energy_cost` (harder abilities = faster
cursor = harder to dodge).

---

## Dynamic Difficulty

`energy_cost` sets the difficulty tier once per `start_qte()` call:

| Tier | Energy cost | Slide ss_half | Cursor duration |
|------|-------------|---------------|-----------------|
| Low | 1–2 | 0.20 (40 %) | 2.2 s |
| Medium | 3–4 | 0.12 (24 %) | 1.6 s |
| High | 5+ | 0.07 (14 %) | 1.1 s |

---

## 4-Zone Bar Layout

```
[=red===|===orange=|==green=|=GOLD=|=green==|===orange=|===red===]
         ←── sweet spot (ss_half × 2 wide) ──→
```

All zones are symmetric around bar center (0.5). `dist = |cursor_pos − 0.5|`.

| Zone | Condition | Defender roll | Colour |
|------|-----------|--------------|--------|
| Gold (perfect dodge) | `dist < ss_half × 0.30` | **1.25** | Gold `#FFD900` |
| Green (good dodge) | `ss_half×0.30 ≤ dist < ss_half×0.70` | **1.0** | Green `#2EC038` |
| Orange (weak dodge) | `ss_half×0.70 ≤ dist ≤ ss_half` | **0.75** | Orange `#E68019` |
| Red (miss) | `dist > ss_half` | **0.25** | Dark red background |

Zone ColorRects are children of `_bar_bg`. `_rebuild_zones()` repositions them whenever
difficulty changes.

---

## Single Beat per QTE

One beat per QTE invocation. No multi-beat sequencing, no shape-scaled beat counts.

Feedback labels:
- **PERFECT DODGE!** (gold)
- **GOOD DODGE!** (green)
- **WEAK DODGE...** (orange)
- **HIT!** (red)

Feedback is shown for **0.85 s** before the bar hides and `qte_resolved` fires.

---

## Flow

```
CombatManager3D calls _run_harm_defenders(caster, [defender], effect, energy_cost)
  → defender.data.is_player_unit == true:
      state = QTE_RUNNING
      await _camera_rig.focus_on(caster.global_position).finished   # 0.5 s smooth pivot
      await get_tree().create_timer(0.25).timeout                    # brief settle
      _qte_bar.start_qte(energy_cost, caster)   ← caster is the attacker ref
          → _attacker = caster stored
          → _set_difficulty()              sets _ss_half, _cursor_duration
          → _reposition_to_attacker()     immediate world→screen placement
          → _animate_cursor()             slides cursor 0→1 over _cursor_duration
          → _process() each frame:        repositions bar over attacker; attacker-death guard
              → player input  → _register_hit() → _get_beat_result()
              → cursor expires → _on_cursor_expired() → result = 0.25
          → _process_result(result)
              → _show_feedback(result)    PERFECT DODGE / GOOD DODGE / WEAK DODGE / HIT
              → await 0.85 s → hide bar → _attacker = null → qte_resolved.emit(result)
      roll = await _qte_bar.qte_resolved
      _camera_rig.restore()                                          # fire-and-forget tween back
      dmg_mult = _defender_roll_to_dmg_multiplier(roll)
      dmg = max(1, round(dmg_mult * (effect.base_value + caster.data.attack)))
      defender.take_damage(dmg)

  → defender.data.is_player_unit == false:
      qte_result = _qte_resolution_to_multiplier(defender.data.qte_resolution)
      dmg_mult = _defender_roll_to_dmg_multiplier(qte_result)
      dmg applied silently — no bar shown
```

---

## AI Defender Simulation

CombatManager3D maps `defender.data.qte_resolution` to a defender roll without showing QTEBar:

| qte_resolution range | Defender roll |
|---------------------|--------------|
| 0.85–1.0 | 1.25 |
| 0.60–0.85 | 1.0 |
| 0.30–0.60 | 0.75 |
| 0.0–0.30 | 0.25 |

---

## AoE Sequencing

For AoE HARM abilities hitting multiple defenders:
- All defenders are collected first
- QTEs run **sequentially** in target order
- Player-controlled defenders each see the QTE bar in turn
- AI-controlled defenders resolve instantly (no bar shown)
- Damage applies per-defender with each's own multiplier

---

## QTEBar Notes

- The bar is always present in the scene tree (built by CombatManager3D in `_setup_ui()`), hidden until `start_qte()` is called.
- CombatManager uses `await _qte_bar.qte_resolved` (inline await) — no signal handler connection.
- `qte_resolved` fires **after** all feedback animations — intentional so the player sees their result before effects resolve.
- **Friendly fire** (caster hits own-team unit in AoE): no QTE, dmg_mult fixed at 1.0. Detection: `caster.is_player_unit == defender.is_player_unit`. The 1.0 constant is a hookpoint for feats/items.
- **World-space anchor (Session B):** The bar is a CanvasLayer but floats above the attacker via `Camera3D.unproject_position(attacker.global_position + Vector3(0, 2.0, 0))` each frame. The screen-space dark overlay has been removed — the world remains visible during QTE. `_attacker` is set to `null` after `qte_resolved` fires so `_process` stops repositioning.
- **Attacker-death guard:** If `_attacker` becomes invalid or `is_alive == false` mid-QTE, the tween is killed, the bar hides immediately, and `qte_resolved.emit(0.25)` fires (miss tier — the hit lands).

---

## RecruitBar — Capture Check

**Layer 11** (between QTEBar at 10 and CombatActionPanel at 12).

A **hold-and-release** vertical bar used when the Pathfinder attempts to recruit an enemy via the Recruit combat action. The player holds SPACE to push the fill faster and releases inside the gold window for a higher-tier result. The result multiplies the base recruit chance computed from target HP% and WIL delta.

### Files

| File | Scene | Role |
|------|-------|------|
| `scripts/combat/RecruitBar.gd` | `scenes/combat/RecruitBar.tscn` | Hold-and-release capture QTE, CanvasLayer layer 11 |

### Signals

| Signal | Args | When |
|--------|------|------|
| `recruit_resolved` | `result: float` | Release or timeout completes; 0.85 s feedback shown first |

### Public API

| Method | Signature | Purpose |
|--------|-----------|---------|
| `start_recruit_qte` | `(base_chance: float, target: Node3D) -> void` | Sizes the gold window from `base_chance`, stores target for world-space tracking, resets fill, shows bar |

### Mechanic

- Bar is 40 × 220 px, floats above `target` via `Camera3D.unproject_position(pos + Vector3(0, 2.5, 0))` each frame.
- Fill rises from bottom at `BASE_FILL_SPEED = 0.15/s`; holding SPACE raises it at `HOLD_FILL_SPEED = 0.45/s`.
- **Gold window** (success zone): centered at 0.65 of bar height from bottom (top-biased — releasing too late is punished). Window height = `lerp(0.08, 0.32, base_chance) × BAR_HEIGHT` — wider targets are easier to hit on high-chance recruits.
- Input: release SPACE (or LMB) to evaluate. Reaching the top without releasing = timeout miss (0.25).

### Result Buckets

| Condition | Result | Feedback |
|-----------|--------|---------|
| `dist ≤ window_half × 0.30` (centre 30% of window) | **1.25** | "PERFECT!" (gold) |
| `dist ≤ window_half` (inside window) | **1.0** | "GREAT!" (green) |
| `dist ≤ window_half × 1.10` (within 10% of edge) | **0.75** | "CLOSE..." (orange) |
| `dist > window_half × 1.10` or timeout | **0.25** | "MISSED." (red) |

where `dist = abs(fill_pos − 0.65)`.

### Flow

```
CombatManager3D._initiate_recruit(caster, target):
    await _camera_rig.focus_on(target.global_position).finished   # 0.5 s
    await create_timer(0.25).timeout                               # settle
    _recruit_bar.start_recruit_qte(base_chance, target)
        → window sized, bar visible, fill starts rising
        → player holds/releases SPACE
        → _get_release_result(fill_pos) → result tier
        → _process_result(result) → feedback 0.85 s → recruit_resolved.emit(result)
    qte_mult = await _recruit_bar.recruit_resolved
    _camera_rig.restore()
    final_chance = clamp(base_chance × _qte_mult_to_recruit_mult(qte_mult), 0, 1)
    success = randf() < final_chance
    → if not success: "Failed!" floating text, STRIDE_MODE, check auto-end
    → if success: recruit_attempt_succeeded.emit(target)  [Slice 4 handles bench insertion]
```

### RecruitBar Notes

- `target` ref stored in `_target`; `_process` repositions bar each frame. Target-death guard: if `_target` is invalid or `is_alive == false`, emits `recruit_resolved(0.25)` and hides.
- `_input` uses `_input()` (not `_unhandled_input`) — same pattern as QTEBar.
- Fill colour changes on release: green (≥1.0), orange (0.75), red (0.25).
- **Not saved.** Pure in-combat presentation; no state survives scene transitions.

---

## Recent Changes

| Date | Change |
|------|--------|
| 2026-04-28 | **RecruitBar added (Follower Slice 3).** New `RecruitBar.gd` + `RecruitBar.tscn` — vertical hold-and-release capture QTE (layer 11). `start_recruit_qte(base_chance, target)` + `recruit_resolved(result)` signal. Window height scales with `base_chance` so easier recruits have a wider target. 4-tier result same as QTEBar. World-space anchor above target. Death guard. Instantiated by `CombatManager3D._setup_ui()`; awaited inline via `_recruit_bar.recruit_resolved`. |
| 2026-04-26 | **Session B — world-space bar + camera focus.** `start_qte(energy_cost, attacker: Node3D)` — bar now floats above the attacker each frame via `Camera3D.unproject_position`. Camera focuses on attacker before each player-facing QTE. `_attacker` cleared on `qte_resolved`. |
| 2026-04-26 | **Reactive overhaul (Session A).** QTE is now defender-driven and HARM-only. Non-HARM auto-resolves at 1.0. `start_qte()` simplified. Friendly fire fixed at 1.0. |
