# System: QTE System

> Last updated: 2026-04-16 (Session 11 — QTE-4: click-targets for FORCE)

---

## Purpose

The QTE (Quick Time Event) system is a **standalone skill-check overlay**. It renders a skill-check UI over the game as a CanvasLayer and emits a multiplier float (0.25 / 0.75 / 1.0 / 1.25) when all beats complete.

This multiplier drives the damage/heal/stat formula in CombatManager. The system is completely self-contained — it neither knows nor cares what called it.

Enemy "QTE" is simulated by CombatManager directly using the unit's `qte_resolution` stat — the QTEBar is not shown for enemy turns.

---

## Core Nodes / Scripts

| File | Scene | Role |
|------|-------|------|
| `scripts/combat/QTEBar.gd` | `scenes/combat/QTEBar.tscn` | Slider QTE + directional sequence QTE + power meter QTE + click-targets QTE, CanvasLayer layer 10 |

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
| `start_qte` | `(energy_cost: int, shape: AbilityData.TargetShape, effect_type: EffectData.EffectType, target_screen_pos: Vector2 = Vector2.ZERO) -> void` | Routes to the correct QTE style, sets difficulty, then starts the first beat |

`effect_type` routing:
- `BUFF` / `DEBUFF` → directional arrow sequence (`_start_directional_qte`)
- `TRAVEL` → hold-release power meter (`_start_power_meter_qte`)
- `FORCE` → rapid click-targets (`_start_click_targets_qte`); `target_screen_pos` required
- all others → 4-zone sliding bar (`_start_slider_qte`)

---

## Dynamic Difficulty

`energy_cost` sets the difficulty tier once per `start_qte()` call:

| Tier | Energy cost | Slider ss_half | Cursor duration | Dir input window | PM zone centre | PM zone half-width | CT window |
|------|-------------|----------------|-----------------|------------------|----------------|-------------------|-----------|
| Low | 1–2 | 0.20 (40 %) | 2.2 s | 2.0 s | 65 % | 18 % | 1.8 s |
| Medium | 3–4 | 0.12 (24 %) | 1.6 s | 1.5 s | 72 % | 12 % | 1.3 s |
| High | 5+ | 0.07 (14 %) | 1.1 s | 1.0 s | 78 % |  7 % | 0.9 s |

Power meter fill rate = `1.0 / cursor_duration` (same speed scale as the slider timing).

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

Beat count depends on **QTE style**:

**Slider (HARM / MEND)** — classic 1–4 scale:

| Shape | Beat count |
|-------|-----------|
| SELF / SINGLE / ARC | 1 |
| CONE | 2 |
| LINE | 3 |
| RADIAL | 4 |

**Click-targets (FORCE) and Directional (BUFF / DEBUFF)** — base-3 × area scale:

| Shape | Beat count |
|-------|-----------|
| SELF / SINGLE / ARC | 3 |
| CONE | 6 |
| LINE | 9 |
| RADIAL | 12 |

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

## Visual Cue Convention

| QTE Type | Mechanic | Effect types | Visual |
|----------|----------|--------------|--------|
| Slider (current) | Press input to stop cursor | HARM, MEND | 4-zone gold/green/orange/red horizontal bar |
| Directional sequence (current) | Press arrow keys in order | BUFF, DEBUFF | Arrow char + shrinking timing bar |
| Power meter (current) | Hold input to fill; release in zone | TRAVEL | Vertical bar with 4-zone coloured band; white cursor line |
| Click-targets (current) | Click circular targets within window | FORCE | Orange circles scattered within 80 px of target; green flash on hit |
| Timer QTE (future) | Press input within a window per beat | TBD | Depleting timer bar per beat |

---

## Flow

**Slider (HARM / MEND / FORCE):**
```
start_qte(energy_cost, shape, effect_type)
  → _start_slider_qte()
      → _set_difficulty()         sets _ss_half, _cursor_duration, _dir_input_window
      → _beat_count_for_shape()
      → _start_next_beat()        [loops _beat_count times]
          → _animate_cursor()     slides cursor 0→1 over _cursor_duration
              → player input  → _register_hit() → _get_beat_result()
              → cursor expires → _on_cursor_expired() → result = 0.25
          → _process_beat_result(result)
              → more beats? flash 0.3 s, _start_next_beat()
              → last beat?  _aggregate_multiplier() → _show_final_feedback()
                  → await 0.85 s → hide bar → emit qte_resolved(multiplier)
```

**Power meter (TRAVEL):**
```
start_qte(energy_cost, shape, effect_type=TRAVEL)
  → _start_power_meter_qte(energy_cost)
      → _set_difficulty()         sets _cursor_duration (used as fill time)
      → _set_pm_difficulty()      sets _pm_zone_center, _pm_zone_half
      → _rebuild_pm_zones()       positions gold/green/orange bands on vertical bar
      → shows bar; _pm_fill_pos = 0, cursor at bottom
      → _process(delta)           fills meter while Space/LMB held; reverses at 100 %
      → player releases input → _get_pm_result(_pm_fill_pos) → _process_beat_result()
          → _show_final_feedback()   hides bar, shows verdict for 0.85 s
          → hide CanvasLayer → emit qte_resolved(multiplier)

CombatManager3D receives qte_resolved(multiplier):
  → multiplier == 0.25 → FAILED label 1.5 s → IDLE (energy spent, no reposition)
  → multiplier > 0.25  → TRAVEL_DESTINATION mode (player picks destination tile)
```

**Click-targets (FORCE):**
```
start_qte(energy_cost, shape, effect_type=FORCE, target_screen_pos)
  → _start_click_targets_qte(energy_cost, shape, target_screen_pos)
      → sets _ct_window from difficulty tier (1.8 / 1.3 / 0.9 s)
      → _beat_count_for_shape()
      → for each beat: create_timer(i × 0.3 s) → _spawn_click_target(origin)
          → spawns ColorRect at random offset ≤ 80 px from origin
          → starts _ct_window timer → _on_ct_timeout(idx) → miss (0.25)
      → _handle_ct_input():
          LMB click within CT_RADIUS (12 px) → _resolve_ct_beat(idx, 1.25)
          click outside → no action
      → _resolve_ct_beat(idx, result):
          flashes node green/red, records result, increments _current_beat
          when all beats done → _aggregate_multiplier() → _show_final_feedback()
              → await 0.85 s → hide bar → emit qte_resolved(multiplier)

CombatManager3D receives qte_resolved(multiplier):
  → multiplier < 0.3 → FAILED label 1.5 s → IDLE (energy spent, no knockback)
  → multiplier ≥ 0.3 → _apply_force() executes knockback
```

**Directional sequence (BUFF / DEBUFF):**
```
start_qte(energy_cost, shape, effect_type)
  → _start_directional_qte()
      → _set_difficulty()         sets _dir_input_window
      → _beat_count_for_shape()
      → _generate_dir_sequence()  random non-repeating list of "UP"/"DOWN"/"LEFT"/"RIGHT"
      → _start_dir_beat()         [loops _beat_count times]
          → shows arrow char + starts shrinking timing bar (_dir_input_window s)
          → _handle_dir_input()   correct key → 1.25; wrong key → 0.25
          → _on_dir_input_expired() → 0.25 (timeout)
          → _process_beat_result(result)
              → more beats? flash 0.3 s, _start_dir_beat()
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
