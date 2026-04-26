# System: QTE System

> Last updated: 2026-04-26 (Session A — defender-driven reactive overhaul)

---

## Purpose

The QTE (Quick Time Event) system is a **standalone dodge check overlay**. It renders a
sliding-bar skill check over the game as a CanvasLayer and emits a `multiplier` float
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

## Core Nodes / Scripts

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
| `start_qte` | `(energy_cost: int) -> void` | Sets difficulty, resets state, starts cursor animation |

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
      _qte_bar.start_qte(energy_cost)
          → _set_difficulty()              sets _ss_half, _cursor_duration
          → _animate_cursor()             slides cursor 0→1 over _cursor_duration
              → player input  → _register_hit() → _get_beat_result()
              → cursor expires → _on_cursor_expired() → result = 0.25
          → _process_result(result)
              → _show_feedback(result)    PERFECT DODGE / GOOD DODGE / WEAK DODGE / HIT
              → await 0.85 s → hide bar → qte_resolved.emit(result)
      roll = await _qte_bar.qte_resolved
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

## Notes

- The bar is always present in the scene tree (built by CombatManager3D in `_setup_ui()`), hidden until `start_qte()` is called.
- CombatManager uses `await _qte_bar.qte_resolved` (inline await) — no signal handler connection.
- `qte_resolved` fires **after** all feedback animations — intentional so the player sees their result before effects resolve.
- Session B will move the bar to world-space above the attacker's Unit3D; the CanvasLayer structure is temporary.
