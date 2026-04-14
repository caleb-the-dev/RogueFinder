# RogueFinder — Claude Session Context

> Drop this file + GAME_BIBLE_roguefinder.md at the start of every Claude Code session.
> This file is maintained after each session. GAME_BIBLE is the design authority; this file is the build authority.

---

## Project Identity

- **Game:** RogueFinder — tactical turn-based roguelite / creature collector
- **Engine:** Godot 4 (GDScript)
- **Repo:** https://github.com/caleb-the-dev/RogueFinder
- **Docs reference:** https://docs.godotengine.org/en/stable/
- **Solo dev** — one programmer, one artist (pixel art + learning Blender)

---

## Current Build State

> ⚠️ Updated after each session. Everything below reflects the ACTUAL state of the repo.

- **Stage:** Stage 1 — Combat Prototype (built, needs first run + test verification)
- **Last session:** Session 1 — 2026-04-13
- **Working:** All Stage 1 scripts and scenes written; project.godot updated with main scene + autoload
- **Broken / deferred:** Not yet run in Godot — first open may require Godot to assign UIDs and resolve imports. Run tests (tests/) before playtesting.
- **Next task:** Open in Godot editor, run tests, playtest, report any failures

---

## Immediate Goal — Stage 1 Combat Prototype

Build ONLY the following. Do not implement anything outside this scope.

1. Static grid (size TBD — start with 6x4)
2. 3 player units + 3 enemy placeholder units on the grid
3. Turn state machine: Player Phase → Enemy Phase → repeat
4. Stride action: click a cell to move a unit (respects speed stat)
5. One Active Action with a basic sliding-bar QTE (Gears of War reload style)
6. Energy tracking per unit (spend on Active Action, regenerate each turn)
7. HP tracking + basic win/lose condition (all enemies dead = win, all players dead = lose)
8. Enemy AI: auto-resolves attacks using a hidden QTE resolution stat (grunt = low, elite = high)

**Not in scope for Stage 1:**
- Node map / roguelite loop
- Recruitment / party management
- Equipment / inventory
- Multiple action types (one placeholder action is enough)
- City, factions, bulletin board
- Art / visuals beyond colored rectangles and labels
- Meta-progression

---

## Scene Structure

> Update this section as scenes are created.

```
res://
├── scenes/
│   ├── combat/
│   │   ├── CombatScene.tscn        # Main combat scene
│   │   ├── Grid.tscn               # Grid node
│   │   ├── Unit.tscn               # Reusable unit scene (player + enemy)
│   │   └── QTEBar.tscn             # QTE overlay
│   ├── ui/
│   │   └── HUD.tscn                # HP / Energy display
├── scripts/
│   ├── combat/
│   │   ├── CombatManager.gd        # Turn state machine, win/lose logic
│   │   ├── Grid.gd                 # Grid logic, cell selection, pathfinding
│   │   ├── Unit.gd                 # Unit data + behavior
│   │   └── QTEBar.gd               # QTE resolution logic
│   ├── ui/
│   │   └── HUD.gd
│   └── globals/
│       └── GameState.gd            # Autoload — run-wide state
├── resources/
│   └── UnitData.tres               # Base resource type for unit stats
└── main.tscn                       # Entry point
```

---

## Code Conventions

### GDScript Style
- Use **typed GDScript** — always declare variable types (`var speed: int = 3`)
- `snake_case` for variables and functions
- `PascalCase` for class names and node names
- Constants in `ALL_CAPS`
- One script per scene — keep scripts focused
- Prefer **signals** over direct node references for cross-system communication
- Use `@export` for values that should be tweakable in the Inspector

### Comments
- Add a **one-line comment** above any non-obvious logic
- Add a **section header comment** (`## --- Section Name ---`) at the top of logical blocks
- Do NOT comment obvious one-liners — only where the *why* isn't clear from the code

### Node References
- Use `@onready var` for node references, not `get_node()` inline
- Example: `@onready var grid: Grid = $Grid`

### Signals
- Declare signals at the top of each script
- Name signals as past-tense events: `unit_moved`, `turn_ended`, `qte_resolved`

### Scene Organization
- Every scene should have a clearly named root node matching the scene file name
- Keep scene trees flat where possible — avoid deep nesting

---

## Key Design Rules (from Game Bible — do not deviate)

- **3v3 combat** — 3 player units vs up to 3 enemies
- **Player character always occupies one of the 3 active slots**
- **Team-based initiative** — all player units act, then all enemies act
- **Per-turn action economy:** Stride (free) + Consumable (optional, free) + Active Action (costs Energy)
- **QTE resolution:** sliding bar mechanic — hit accuracy × stat delta = effectiveness
- **Enemy AI uses a hidden QTE stat** — grunts auto-resolve at low accuracy, elites at high
- **NPC death is permanent** within a run
- **Player character survives at 1 HP** if party wins the fight they die in
- **Party composition changes only at the city** (not relevant for Stage 1)

---

## Stat Reference (Stage 1 placeholder values — subject to change)

| Stat | Description | Placeholder Value |
|------|-------------|-------------------|
| HP | Health points | 20 (player/ally), 15 (grunt enemy) |
| Speed | Cells movable per Stride | 3 |
| Attack | Offensive power — affects QTE outcome ceiling | 10 |
| Defense | Resistive power — affects QTE outcome floor | 10 |
| Energy Max | Maximum energy pool | 10 |
| Energy Regen | Energy restored at start of each turn | 3 |
| QTE Resolution | (Enemies only) Auto-resolve accuracy 0.0–1.0 | Grunt: 0.3, Elite: 0.8 |

---

## Testing Approach — Draft then Verify

For every non-trivial system, write the implementation and its tests in a single response. Do not wait to be asked.

**What to test:**
- State machine transitions (e.g. Player Phase → Enemy Phase → back)
- Stat calculations (damage formula, QTE outcome, energy math)
- Grid logic (movement range, valid cell checks, boundary conditions)
- Win/lose condition triggers

**What NOT to test:**
- Rendering / visual output
- Input handling
- Anything that requires a running Godot scene to evaluate

**Format:** Deliver the implementation script first, then a companion `test_*.gd` file using Godot's built-in [GdUnit4](https://github.com/MikeSchulze/gdUnit4) or plain `assert()` checks in a standalone test script. Keep tests in a `/tests/` folder at the repo root.

**The workflow:**
1. Claude writes logic + tests together in one response
2. Dev runs tests locally before moving on
3. If tests fail, paste the failure output back — Claude fixes in one follow-up
4. Only move to the next system once tests pass

This catches bugs at the source rather than debugging emergent behavior later in a running scene.

---

## Teaching Mode

When writing code, please:
1. Add brief inline comments on any logic that isn't immediately obvious
2. If you make a structural decision (e.g. why you used a signal instead of a direct call), add a one-line note explaining it
3. When asked, explain concepts in plain terms — I'm learning GDScript coming from GML/SQL
4. Do NOT explain things I didn't ask about — keep explanations targeted

---

## Session Log

> Append a short entry after each session. Format: `## Session N — [date] — [what was built]`

## Session 1 — 2026-04-13 — Stage 1 Combat Prototype

Built the full Stage 1 combat system from scratch:
- 6×4 grid with click-to-move (Manhattan distance, speed 3)
- 3 player units (Vael, Kira, Brom) vs 3 grunt enemies
- Turn state machine: PLAYER_TURN → ENEMY_TURN → repeat
- Stride action: select unit, blue highlights, click to move
- Active Action: press [A] for red highlights, click enemy → sliding-bar QTE fires
- QTE bar: cursor slides L→R in 1.8s; sweet spot 35–65%; Space/click to register
- Energy economy: 10 max, 3 regen/turn, 3 cost/attack
- HP tracking + win (all enemies dead) / lose (all players dead) conditions
- Enemy AI: auto-resolves at `qte_resolution` accuracy (grunt = 0.3)
- HUD: HP/Energy ASCII bars for all 6 units (right side panel)
- Test suite: test_unit.gd, test_grid.gd, test_combat_manager.gd (plain assert, no scene required)

---

## Open Questions / Deferred Decisions

- Grid size: starting with 6×4, may adjust after first playtest
- QTE prompt variety: only sliding bar in Stage 1; more types TBD
- Energy stat names: using "Energy" / "EnergyRegen" as placeholders
- Exact action designs and balance numbers: TBD after Stage 1 validation
