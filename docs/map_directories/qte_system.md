# System: QTE System

> Last updated: 2026-04-16 (Session 8 — QTE Slice 1: 4-zone bar, multi-beat, multiplier output)

---

## Purpose

The QTE (Quick Time Event) system is a **standalone skill-check overlay**. It renders a sliding cursor bar over the game as a CanvasLayer and emits a multiplier float (0.25 / 0.75 / 1.0 / 1.25) when all beats complete.

This multiplier drives the damage/heal/stat formula in CombatManager. The system is completely self-contained — it neither knows nor cares what called it.

Enemy "QTE" is simulated by CombatManager directly using the unit's `qte_resolution` stat — the QTEBar is not shown for enemy turns.

---

## Core Nodes / Scripts

| File | Scene | Role |
|------|-------|------|
| `scripts/combat/QTEBar.gd` | `scenes/combat/QTEBar.tscn` | Sliding bar QTE, CanvasLayer layer 10 |

`.tscn` is minimal. All UI nodes are built in `_build_ui()`.

---

## Dependencies

None. QTEBar has **no runtime dependencies** on other game systems. It is purely input-in → multiplier-out.

---

## Signals Emitted

| Signal | Arguments | When |
|--------|-----------|------|
| `qte_resolved` | `multiplier: float` | All beats complete and final feedback has been displayed |

`multiplier` is one of: `1.25` (perfect), `1.0` (good), `0.75` (weak), `0.25` (miss/failure).

CombatManager subscribes to this signal before calling `start_qte()`.

---

## Public Methods

| Method | Signature | Purpose |
|--------|-----------|---------|
| `start_qte` | `(energy_cost: int, shape: AbilityData.TargetShape, effect_type: EffectData.EffectType) -> void` | Sets difficulty, beat count, then starts the first slider beat |

`effect_type` is the hook for future QTE type routing (see Visual Cue Convention). All types currently fall through to the slider.

---

## Dynamic Difficulty

`energy_cost` sets the difficulty tier once per `start_qte()` call:

| Tier | Energy cost | Sweet-spot half-width | Cursor duration |
|------|-------------|-----------------------|----------------|
| Low | 1–2 | 0.20 (40 % of bar) | 2.2 s |
| Medium | 3–4 | 0.12 (24 % of bar) | 1.6 s |
| High | 5+ | 0.07 (14 % of bar) | 1.1 s |

---

## 4-Zone Bar Layout

```
[=red===|===orange=|==green=|=GOLD=|=green==|===orange=|===red===]
         ←── sweet spot (ss_half × 2 wide) ──→
```

All zones are symmetric around bar center (0.5). `dist = |cursor_pos − 0.5|`.

| Zone | Condition | Multiplier | Colour |
|------|-----------|-----------|--------|
| Gold (perfect) | `dist < ss_half × 0.30` | **1.25** | Gold `#FFD900` |
| Green (major) | `ss_half×0.30 ≤ dist < ss_half×0.70` | **1.0** | Green `#2EC038` |
| Orange (minor) | `ss_half×0.70 ≤ dist ≤ ss_half` | **0.75** | Orange `#E68019` |
| Red (failure) | `dist > ss_half` | **0.25** | Dark red background |

Zone ColorRects are children of `_bar_bg`. `_rebuild_zones()` repositions them whenever difficulty changes.

---

## Multi-Beat Sequencing

Beat count is determined by `target_shape` at `start_qte()`:

| Shape | Beat count |
|-------|-----------|
| SELF | 1 |
| SINGLE | 1 |
| ARC | 1 |
| CONE | 2 |
| LINE | 3 |
| RADIAL | 4 |

When `beat_count > 1`, the instruction label shows **"Beat N / M"**.

Between beats: the per-beat result label flashes for **0.3 s** ("PERFECT" / "GOOD" / "WEAK" / "MISS"), then the next slider starts. After the final beat, the multiplier feedback label is shown for **0.85 s** before the bar hides and `qte_resolved` fires.

---

## Multiplier Aggregation

After all beats complete, per-beat results are averaged and mapped to the nearest tier:

| Average | Tier |
|---------|------|
| ≥ 1.2 | 1.25 (perfect) |
| ≥ 0.9 | 1.0 (good) |
| ≥ 0.6 | 0.75 (weak) |
| < 0.6 | 0.25 (miss) |

Example: a 4-beat RADIAL ability needs all-gold hits to reach 1.25× — one red drops the average below 1.2.

---

## Visual Cue Convention (Future QTE Types)

| QTE Type | Mechanic | Visual |
|----------|----------|--------|
| Slider (current) | Press input to stop cursor | 4-zone gold/green/orange/red bar |
| Timer QTE (QTE-2/3) | Press input within a window per beat | Depleting timer bar per beat |
| Power meter (QTE-4, TRAVEL) | Hold/release to set power level | Same 4-color zone scheme on meter target zone |

---

## Flow

```
start_qte(energy_cost, shape, effect_type)
  → _set_difficulty()         sets _ss_half, _cursor_duration, rebuilds zones
  → _beat_count_for_shape()
  → _start_next_beat()        [loops _beat_count times]
      → _animate_cursor()     slides cursor 0→1 over _cursor_duration
          → player input  → _register_hit() → _get_beat_result()
          → cursor expires → _on_cursor_expired() → result = 0.25
      → _process_beat_result(result)
          → more beats? flash 0.3 s, loop
          → last beat?  _aggregate_multiplier() → _show_final_feedback()
              → await 0.85 s → hide bar → emit qte_resolved(multiplier)
```

---

## Enemy Simulation

CombatManager3D maps `enemy.data.qte_resolution` to a multiplier tier without showing QTEBar:

| qte_resolution range | Multiplier |
|---------------------|-----------|
| 0.85–1.0 | 1.25 |
| 0.60–0.85 | 1.0 |
| 0.30–0.60 | 0.75 |
| 0.0–0.30 | 0.25 |

---

## Notes

- The bar is always present in the scene tree (built by CombatManager3D in `_setup_ui()`), hidden until `start_qte()` is called.
- CombatManager enters `QTE_RUNNING` state before calling `start_qte()` to block all other input.
- `qte_resolved` fires **after** all feedback animations — intentional so the player sees their result before effects resolve.
