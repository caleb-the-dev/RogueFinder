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

- **Stage:** Stage 1.5 — 3D combat prototype + traversable world map
- **Last session:** Session 8 (MapScene Feature 2) — 2026-04-18
- **Working:** Full 3D combat loop; MapScene with traversal — click adjacent nodes to move, CURRENT/REACHABLE/VISITED/LOCKED node visual states, visited ✓ stamp, Badurga hover always readable; GameState tracks player_node_id + visited_nodes
- **Broken / deferred:** MapScene has no scene transitions (Feature 3 — launch combat from node); ability effects still placeholder; no per-ability QTEs
- **Next task:** Feature 3 — scene transitions on node click, or per-ability QTEs (check backlog)

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
│       └── HUD.tscn             # CanvasLayer overlay (layer 5) — legacy 2D only
├── scripts/
│   ├── camera/
│   │   └── CameraController.gd  # DOS2-style orbit, Q/E rotate, shake
│   ├── combat/
│   │   ├── CombatManager3D.gd   # Turn SM, builds whole scene in _ready()
│   │   ├── Unit3D.gd            # Box mesh, lunge anim, hit flash, 8-dir
│   │   ├── Grid3D.gd            # PlaneMesh tiles, raycast picking, highlights
│   │   ├── QTEBar.gd            # Sliding-bar QTE
│   │   ├── CombatManager.gd     # Legacy 2D
│   │   ├── Unit.gd              # Legacy 2D
│   │   └── Grid.gd              # Legacy 2D
│   ├── ui/
│   │   ├── ActionMenu.gd        # Radial ability/consumable pop-up (layer 12)
│   │   ├── StatPanel.gd         # Full examine window (double-click, layer 8)
│   │   ├── UnitInfoBar.gd       # Condensed strip (single-click, layer 4)
│   │   └── HUD.gd               # Legacy 2D only
│   └── globals/
│       ├── AbilityLibrary.gd    # 12 placeholder abilities, static factory
│       ├── ArchetypeLibrary.gd  # 5 archetypes, CombatantData factory
│       └── GameState.gd         # Autoload stub
├── resources/
│   ├── AbilityData.gd           # Ability resource (TargetType enum + fields)
│   ├── CombatantData.gd         # Active stat resource (3D)
│   └── UnitData.gd              # Legacy stat resource (2D only)
├── scenes/map/
│   └── MapScene.tscn            # World map (root + script only)
├── scripts/map/
│   └── MapManager.gd            # Builds map scene in _ready(); owns traversal logic
└── main.tscn                    # Entry point → CombatScene3D
```

---

## Code Conventions

- **Typed GDScript** — always declare types (`var speed: int = 3`)
- `snake_case` vars/funcs, `PascalCase` class/node names, `ALL_CAPS` constants
- One script per scene; prefer **signals** over direct calls
- `@export` for inspector-tweakable values; `@onready` for node refs
- **Placeholder art:** Use the Godot icon (`load("res://icon.svg")`) as the default for all 2D placeholder artwork (portraits, ability icons, item icons). Replace with real art when assets arrive.
- Section headers: `## --- Section Name ---`; comment the *why*, not the *what*
- All .tscn files stay **minimal** (root + script only) — build children in `_ready()`
- Signals named as past-tense events: `unit_moved`, `qte_resolved`

---

## Key Design Rules (do not deviate)

- **3v3 combat** — 3 player units vs 3 enemies units
- **Team-based initiative** — all players act, then all enemies
- **Action economy per turn:** Stride (free) + Active Action/Ability (costs Energy) + Consumable (if combatant has one)
- **QTE:** example: sliding bar — hit accuracy × stat delta = damage
- **Enemy AI:** hidden `qte_resolution` stat (grunt 0.3, elite 0.8)

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

## Version Control Workflow

Claude Code is used in the terminal, working directly in the repo. No worktrees are created.

### The intended workflow (main stays protected)

```
1. User gives prompt
2. Claude creates a feature branch and does all work there
3. Claude commits, pushes, and tells the user the branch is ready to test
4. User opens Godot from the normal project folder to test
5. User approves → Claude merges to main and pushes
   User rejects  → Claude keeps iterating on the same branch (go to step 3)
```

Main is **never touched until the user explicitly approves.**

### Branch naming convention

Every session branch must be named: `claude/<short-feature-description>-<YYYYMMDD>`

Examples: `claude/combatant-data-model-20260414`, `claude/combat-ui-polish-20260415`

At the start of every session, Claude must create and push the branch:
```bash
git checkout -b claude/<feature>-<YYYYMMDD>
git push -u origin claude/<feature>-<YYYYMMDD>
```

### When work is ready to test

1. Commit all changes and push the branch.
2. Tell the user:
   ```
   Branch ready: claude/<feature>-<YYYYMMDD>
   Open Godot from C:\Users\caleb\.local\bin\Projects\RogueFinder\ to test. Tell me to merge when you're happy.
   ```

### When the user approves

```bash
git checkout main
git merge claude/<feature>-<YYYYMMDD> --no-ff
git push origin main
```

## Documentation & Context Maintenance

### The Map Protocol
- **Always** read `/docs/map_directories/map.md` first when starting a new session, but only if working on a system you are unfamiliar with.
- `map.md` is the high-level index of all game systems. Use it to navigate to the relevant system bucket file before reading source code.
- Each system bucket file in `/docs/map_directories/` is the authoritative prose description of that system's purpose, dependencies, signals, and public API.
- Only read through the directories that you need to; this strategy is meant to give a map without overburdening with unnecessary context

### This claude.md file
- Do not use this doc to house workflow, placeholder information, scratchwork, or a session log .
- Write or read C:\Users\caleb\.local\bin\Projects\RogueFinder\docs\backlog.md for any future plans, but do not read this file automatically. The user will keep track of the backlog. 

### Automatic Updates
After implementing any significant logic change or new system, Claude must update the relevant `.md` file(s) in `/docs/map_directories/` to reflect:
- Changed or new signals
- Changed or new public methods
- New dependencies on other systems
- Structural or design decisions made during implementation
If a change affects multiple systems (e.g., a new signal crosses two systems), update **both** bucket files and the index in `map.md` if a new system was added.

### Session Wrap-Up Skill (`/wrapup`)
A global `/wrapup` skill lives at `C:\Users\caleb\.claude\skills\wrapup\SKILL.md`. When the user invokes `/wrapup` (or says "wrap up", "close out", "done for today", etc.), this skill takes over and:
1. Commits any uncommitted work, pushes the feature branch, and merges to main
2. Reads every `.gd` file changed this session and exhaustively updates all relevant map directory files — signals, public API, dependencies, gotchas, recent-changes rows, and `map.md` index/session log

The skill is the authoritative end-of-session workflow. Do not do wrap-up work ad-hoc outside of it.

## Teaching Mode
- Ask user for permission before triggering anything from the superpowers plugin.

### Future Structure
- Saving will eventually be a core feature of this game. Consider how this will affect systems as they are built.