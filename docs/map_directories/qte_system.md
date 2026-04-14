# System: QTE System

> Last updated: 2026-04-14 (Session 2 — Stage 1.5)

---

## Purpose

The QTE (Quick Time Event) system is a **standalone skill-check overlay**. It renders a sliding cursor bar over the game as a CanvasLayer and emits an accuracy float (0.0–1.0) when the player hits Space/click or the cursor expires.

This accuracy value drives the damage formula in CombatManager. The system is completely self-contained — it neither knows nor cares what called it.

Enemy "QTE" is simulated by CombatManager directly using the unit's `qte_resolution` stat — the QTEBar is not shown for enemy turns.

---

## Core Nodes / Scripts

| File | Scene | Role |
|------|-------|------|
| `scripts/combat/QTEBar.gd` | `scenes/combat/QTEBar.tscn` | Sliding bar QTE, CanvasLayer layer 10 |

`.tscn` is minimal. All UI nodes (bar background, sweet-spot panel, cursor, feedback label) are built in `_build_ui()`.

---

## Dependencies

None. QTEBar has **no runtime dependencies** on other game systems. It is purely input-in → accuracy-out.

---

## Signals Emitted

| Signal | Arguments | When |
|--------|-----------|------|
| `qte_resolved` | `accuracy: float` | Player presses action key, or cursor reaches the end without input |

CombatManager subscribes to this signal before calling `start_qte()`.

---

## Public Methods

| Method | Signature | Purpose |
|--------|-----------|---------|
| `start_qte` | `() -> void` | Makes the bar visible and starts the cursor animation coroutine |

All other methods are internal.

---

## Bar Layout

```
[===========================|=======|==========================]
         dead zone        sweet spot        dead zone
         (0.0–0.35)       (0.35–0.65)       (0.65–1.0)

                            ↑ cursor slides left → right
```

| Constant | Value | Meaning |
|----------|-------|---------|
| `BAR_WIDTH` | 480.0 px | Total bar width |
| `CURSOR_WIDTH` | 10.0 px | Visual cursor width |
| `SWEET_SPOT_START` | 0.35 | Normalized start of sweet spot |
| `SWEET_SPOT_END` | 0.65 | Normalized end of sweet spot |
| `CURSOR_DURATION` | 1.8 s | Time for cursor to travel full bar |

---

## Accuracy Formula

```
pos = cursor normalized position (0.0 = left, 1.0 = right)
center = 0.5

if pos in [SWEET_SPOT_START, SWEET_SPOT_END]:
    accuracy = 1.0 - abs(pos - center) * 2.0
    # → 1.0 at dead center (0.5), 0.5 at sweet-spot edges
else:
    accuracy = 0.2   # missed sweet spot — glancing blow
```

**Result range:** 0.2 (miss) to 1.0 (perfect center hit).

On cursor expiry (no input), `accuracy = 0.0` is passed — a complete miss.

---

## Input

The QTE listens for:
- `Space` keypress
- Left mouse button click

Input is only consumed when the bar is visible (`visible == true`). After registering a hit, input is blocked until the feedback animation completes and the bar hides itself.

---

## Flow

```
start_qte()
  → show bar
  → _animate_cursor() [coroutine]
      → slides cursor from 0 → 1 over CURSOR_DURATION seconds
      → if player hits input: _register_hit() → _finish_qte(accuracy)
      → if cursor expires:    _on_cursor_expired() → _finish_qte(0.0)

_finish_qte(accuracy)
  → _show_feedback(accuracy)   # brief color flash + label
  → await 0.45s
  → hide bar
  → emit qte_resolved(accuracy)
```

---

## Feedback Display

| Accuracy | Label text | Color |
|----------|-----------|-------|
| ≥ 0.8 | "PERFECT!" | Green |
| ≥ 0.5 | "GOOD" | Yellow |
| > 0.0 | "OK" | Orange |
| 0.0 | "MISS" | Red |

---

## Notes

- The bar is always present in the scene tree (built by CombatManager3D in `_setup_ui()`), hidden until `start_qte()` is called.
- CombatManager enters `QTE_RUNNING` state before calling `start_qte()` to block all other input during the QTE.
- The `qte_resolved` signal fires **after** the feedback animation, not immediately on input — this is intentional so the player sees their result before the attack resolves.
