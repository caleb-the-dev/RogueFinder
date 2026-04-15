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

- **Stage:** Stage 1.5 — 3D combat prototype, playtested and working
- **Last session:** Session 6 (combat actions) — 2026-04-15
- **Working:** Full 3D combat loop — select unit → radial ability menu → target → QTE → damage; consumables; auto-end turn
- **Broken / deferred:** Ability effects are all placeholders (proxy through QTE damage); no per-ability QTEs yet
- **Next task:** Functional ability effects, per-ability QTEs, or CSV ability import

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

- **3v3 combat** — 3 player units vs up to 3 enemies
- **Team-based initiative** — all players act, then all enemies
- **Action economy per turn:** Stride (free) + Active Action/Ability (costs Energy) + Consumable (if combatant has one)
- **QTE:** example: sliding bar — hit accuracy × stat delta = damage
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

### Sessions 3–5 — 2026-04-14 — Combatant Data Model + UI Polish
- **CombatantData** resource: identity, attributes, derived stats, ability slots, consumable; replaces UnitData for 3D
- **ArchetypeLibrary:** 5 archetypes (RogueFinder, archer_bandit, grunt, alchemist, elite_guard), randomized factory
- **Unit3D:** floating 8-block HP bar (color-coded), archetype label fallback when name empty
- **Grid3D:** expanded to 10×10; diagonal movement costs 1.5 speed
- **UnitInfoBar:** condensed CanvasLayer strip (layer 4), shown on single-click
- **StatPanel:** full examine window (layer 8), shown on double-click, scrollable, ESC/✕ to close
- Camera + CM3D both use `_unhandled_input()` — GUI takes priority; Space + confirm dialog to end turn

### Session 6 — 2026-04-15 — Combat Actions (Radial Menu + Ability System)
- **AbilityData:** typed Resource with TargetType enum (SELF/SINGLE_ENEMY/SINGLE_ALLY/AOE/CONE) and `tile_range` field
- **AbilityLibrary:** 12 placeholder abilities, static factory, CSV-ready `get_ability()` API
- **ActionMenu:** D-pad radial CanvasLayer (layer 12) — 4 ability buttons + center consumable; screen-projected from unit; hover tooltips; greyed when unaffordable or `has_acted`
- **CombatManager3D:** ABILITY_TARGET_MODE (purple highlights, Manhattan distance range), `_pending_ability` flow, consumable use, `_unit_can_still_act()` for auto-end; [A] key removed
- All abilities proxy through existing QTE → damage (playable; effects are placeholder)

---

## Session & Worktree Cleanup

Claude Code runs each session inside a git worktree (a linked checkout under `.claude/worktrees/`). This is architectural — it cannot be disabled via settings. The worktree branch is **exclusively locked** to that directory: attempting to switch to it in GitHub Desktop will always fail with "already used by worktree".

### The intended workflow (fast iteration, main stays protected)

```
1. User gives prompt
2. Claude works in the worktree, commits, and pushes the worktree branch
3. Claude tells the user the worktree test path for this session
4. User opens Godot from the WORKTREE folder to test — main is untouched
5. User approves → Claude merges to main and pushes
   User rejects  → Claude keeps iterating in the same worktree (go to step 2)
6. User closes the Claude Code session
7. User runs cleanup commands (see below)
```

Main is **never touched until the user explicitly approves.** The worktree folder is the staging environment.

### Branch naming convention

Every session branch must be named: `claude/<short-feature-description>-<YYYYMMDD>`

Examples: `claude/combatant-data-model-20260414`, `claude/combat-ui-polish-20260415`

Claude Code auto-generates a random branch name (e.g. `claude/eager-lumiere`). At the **start of every session**, Claude must immediately rename it:
```bash
git branch -m <auto-generated-name> claude/<feature>-<YYYYMMDD>
git push origin claude/<feature>-<YYYYMMDD>
git push origin --delete <auto-generated-name>
git branch -u origin/claude/<feature>-<YYYYMMDD>
```
The worktree folder keeps the auto-generated name for the life of the session (renaming it while active would break the session) — only the branch name matters for history.

### What Claude must do when work is ready to test

1. Commit all changes in the worktree.
2. Push the worktree branch to origin.
3. Tell the user the Godot test path for this session, e.g.:
   ```
   Test path: C:\Users\caleb\.local\bin\Projects\RogueFinder\.claude\worktrees\<name>\rogue-finder\
   Open that folder in Godot to test. Tell me to merge when you're happy.
   ```

### What Claude must do when the user approves

```bash
# Merge the worktree branch into main from the main repo directory
git -C "C:\Users\caleb\.local\bin\Projects\RogueFinder" merge <worktree-branch> --no-ff

# Push main
git -C "C:\Users\caleb\.local\bin\Projects\RogueFinder" push origin main
```

After this, the user's normal project folder is up to date.

### User cleanup (after closing the Claude Code session)

Run from the repo root (`C:\Users\caleb\.local\bin\Projects\RogueFinder`).
Note: the worktree folder uses the auto-generated name; the branch uses the descriptive name.
```powershell
cd C:\Users\caleb\.local\bin\Projects\RogueFinder
git worktree remove .claude/worktrees/<auto-generated-folder-name> --force
git branch -d claude/<feature>-<YYYYMMDD>
```
Then Fetch Origin in GitHub Desktop to confirm `main` is clean.

**For this session specifically:**
```powershell
cd C:\Users\caleb\.local\bin\Projects\RogueFinder
git worktree remove .claude/worktrees/eager-lumiere --force
git branch -d claude/combatant-data-model-20260414
```

### Key rule: never switch to the Claude branch in GitHub Desktop

The worktree branch is exclusively locked while the session is open — switching to it in GitHub Desktop always fails. Stay on `main` at all times.

---

## Documentation & Context Maintenance

### The Map Protocol
- **Always** read `/docs/map_directories/map.md` first when starting a new session or before working on any system you are unfamiliar with.
- `map.md` is the high-level index of all game systems. Use it to navigate to the relevant system bucket file before reading source code.
- Each system bucket file in `/docs/map_directories/` is the authoritative prose description of that system's purpose, dependencies, signals, and public API.
- Only read through the directories that you need to; this strategy is meant to give a map without overburdening with unnecessary context

### This claude.md file
- Do not use this doc to house workflow, placeholder information, or scratchwork
- Write or read C:\Users\caleb\.local\bin\Projects\RogueFinder\docs\backlog.md for any future plans, but do not read this file automatically. The user will keep track of the backlog. 

### Automatic Updates
After implementing any significant logic change or new system, Claude must update the relevant `.md` file(s) in `/docs/map_directories/` to reflect:
- Changed or new signals
- Changed or new public methods
- New dependencies on other systems
- Structural or design decisions made during implementation

If a change affects multiple systems (e.g., a new signal crosses two systems), update **both** bucket files and the index in `map.md` if a new system was added.

### Future Structure
- Saving will eventually be a core feature of this game. Consider how this will affect systems as they are built.