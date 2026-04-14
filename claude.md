# RogueFinder — Claude Session Context

> Drop this file at the start of every session. GAME_BIBLE is the design authority; this file is the build authority.

---

## Project Identity

- **Game:** RogueFinder — tactical turn-based roguelite / creature collector
- **Engine:** Godot 4 (GDScript)
- **Repo:** https://github.com/caleb-the-dev/RogueFinder
- **Docs:** https://docs.godotengine.org/en/stable/
- **Solo dev** — one programmer, one artist (pixel art + learning Blender)

---

## Current Build State

- **Stage:** Stage 1.5 — 3D combat prototype ✅ built, on `main`, needs first playtest
- **Last session:** Session 2 — 2026-04-14
- **Working:** Full 3D refactor complete (CameraController, Unit3D, Grid3D, CombatManager3D)
- **Broken / deferred:** Not yet run in Godot — UIDs will be assigned on first open
- **Next task:** Open in Godot, playtest, report failures → then move to Stage 2 polish

---

## Scene Structure

```
res://
├── scenes/
│   ├── combat/
│   │   ├── CombatScene3D.tscn   # Active entry point (3D)
│   │   ├── Unit3D.tscn          # Minimal — all children built in code
│   │   ├── Grid3D.tscn          # Minimal
│   │   ├── QTEBar.tscn          # CanvasLayer overlay (layer 10)
│   │   ├── CombatScene.tscn     # Legacy 2D (kept for reference)
│   │   ├── Unit.tscn            # Legacy 2D
│   │   └── Grid.tscn            # Legacy 2D
│   └── ui/
│       └── HUD.tscn             # CanvasLayer overlay (layer 5)
├── scripts/
│   ├── camera/
│   │   └── CameraController.gd  # DOS2-style orbit, Q/E rotate, shake
│   ├── combat/
│   │   ├── CombatManager3D.gd   # Turn SM, builds whole scene in _ready()
│   │   ├── Unit3D.gd            # Box mesh, lunge anim, hit flash, 8-dir
│   │   ├── Grid3D.gd            # PlaneMesh tiles, raycast picking
│   │   ├── QTEBar.gd            # Sliding-bar QTE
│   │   ├── CombatManager.gd     # Legacy 2D
│   │   ├── Unit.gd              # Legacy 2D
│   │   └── Grid.gd              # Legacy 2D
│   ├── ui/
│   │   └── HUD.gd               # ASCII HP/Energy bars (duck-typed, works 2D+3D)
│   └── globals/
│       └── GameState.gd         # Autoload stub
├── resources/
│   └── UnitData.gd              # Stat resource (@export fields)
└── main.tscn                    # Entry point → CombatScene3D
```

---

## Code Conventions

- **Typed GDScript** — always declare types (`var speed: int = 3`)
- `snake_case` vars/funcs, `PascalCase` class/node names, `ALL_CAPS` constants
- One script per scene; prefer **signals** over direct calls
- `@export` for inspector-tweakable values; `@onready` for node refs
- Section headers: `## --- Section Name ---`; comment the *why*, not the *what*
- All .tscn files stay **minimal** (root + script only) — build children in `_ready()`
- Signals named as past-tense events: `unit_moved`, `qte_resolved`

---

## Key Design Rules (do not deviate)

- **3v3 combat** — 3 player units vs up to 3 enemies
- **Team-based initiative** — all players act, then all enemies
- **Action economy per turn:** Stride (free) + Active Action (costs Energy)
- **QTE:** sliding bar — hit accuracy × stat delta = damage
- **Enemy AI:** hidden `qte_resolution` stat (grunt 0.3, elite 0.8)
- **NPC death is permanent** within a run
- **Player character survives at 1 HP** if party wins the fight they die in

---

## Stat Reference

| Stat | Placeholder |
|------|------------|
| HP | 20 player, 15 grunt |
| Speed | 3 player, 2 grunt |
| Attack / Defense | 10 base |
| Energy Max / Regen | 10 / 3 |
| QTE Resolution | Grunt 0.3, Elite 0.8 |

---

## Testing Approach

Write implementation + tests in one response. Tests go in `/tests/`. Use plain `assert()` — no scene required.

Test: state transitions, damage formula, grid math, win/lose triggers.
Do NOT test: rendering, input, anything needing a live scene.

---

## Teaching Mode

- Comment non-obvious logic; note structural decisions (why a signal, etc.)
- Explain in plain terms when asked — dev knows GML/SQL, learning GDScript
- Do NOT explain things not asked about

---

## Session Log

### Session 1 — 2026-04-13 — Stage 1 Combat Prototype (2D)
6×4 grid, click-to-move, 3v3, turn SM, sliding QTE, energy economy, HUD, test suite.

### Session 2 — 2026-04-14 — Stage 1.5: 3D Refactor
- **CameraController:** DOS2 orbit camera, Q/E rotate 45°, scroll zoom, `trigger_shake()`
- **Unit3D:** MeshInstance3D box (blue=player, red=enemy), CylinderMesh selection ring, Label3D billboard, attack lunge anim, white hit flash, 8-dir sprite index helper
- **Grid3D:** PlaneMesh floor tiles, per-cell StandardMaterial3D highlights, math raycast cell picking (Y=0 plane, no physics bodies)
- **CombatManager3D:** full state machine matching 2D version; builds env + camera + grid + units entirely in code; attack plays lunge then QTE; hit triggers shake
- **HUD.gd:** `refresh()` made untyped for Unit / Unit3D duck-typing compat
- All .tscn files kept minimal; `main.tscn` points to CombatScene3D

---

## Documentation & Context Maintenance

### The Map Protocol
- **Always** read `/docs/map_directories/map.md` first when starting a new session or before working on any system you are unfamiliar with.
- `map.md` is the high-level index of all game systems. Use it to navigate to the relevant system bucket file before reading source code.
- Each system bucket file in `/docs/map_directories/` is the authoritative prose description of that system's purpose, dependencies, signals, and public API.

### Automatic Updates
After implementing any significant logic change or new system, Claude must update the relevant `.md` file(s) in `/docs/map_directories/` to reflect:
- Changed or new signals
- Changed or new public methods
- New dependencies on other systems
- Structural or design decisions made during implementation

If a change affects multiple systems (e.g., a new signal crosses two systems), update **both** bucket files and the index in `map.md` if a new system was added.

---

## Open Questions / Deferred

- Grid size: 6×4 — may adjust after playtest
- QTE variety: sliding bar only in Stage 1; more types TBD
- Balance numbers: TBD after Stage 1.5 validation
- Stage 2 scope: TBD (node map? recruitment? enemy variety?)
