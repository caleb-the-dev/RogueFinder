# System: [System Name]
<!-- Load this file only when working in this system. -->

---

> Last updated: YYYY-MM-DD (Session N — brief note)

---

## What This System Owns

<!-- 1-3 sentences. What is this system responsible for? Where does its responsibility end? -->
<!-- Use this form: "Owns X and Y. Does NOT own Z (see system_foo.md)." -->

---

## Core Files

<!-- Purpose over location. Explain WHY each file exists, not just where it is. -->

| File | Purpose |
|---|---|
| `scripts/combat/FooBar.gd` | Core logic — what it does and why it exists here |

---

## Where NOT to Look

<!-- Only include if there's a genuinely misleading anti-location. Delete section if nothing applies. -->

- **X is NOT here** — it lives in `other_system.md`. This system only does Y.

---

## Dependencies

| System | Why |
|---|---|
| Grid System | Calls `get_cells_in_range()` to highlight valid targets |

---

## State Machine / Key Flows

<!-- Optional but valuable for systems with complex state or multi-step workflows. -->

```
STATE_A
  └─[event]─→ STATE_B
STATE_B
  └─[event]─→ STATE_A
```

---

## Signals

| Signal | When emitted |
|---|---|
| `signal_name(arg: Type)` | Description of when / why |

---

## Public Methods

| Method | Purpose |
|---|---|
| `method_name(args) -> ReturnType` | What callers use this for |

---

## Key Patterns & Gotchas

<!-- Non-obvious things that will trip someone up. Think: "I wish I'd known X before touching this." -->

- **Pattern name** — explanation of what it does and why it has to work this way.

---

## Recent Changes

| Date | Change |
|---|---|
| YYYY-MM-DD | What changed and why |
