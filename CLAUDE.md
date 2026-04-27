# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Project Overview

**RogueFinder** is a tactical turn-based roguelite / creature collector built in **Godot 4.6** (GDScript). References: Into the Breach (grid combat), Slay the Spire (roguelite loop), Pokémon (creature collector party framing).

- **Engine:** Godot 4.6, Forward Plus rendering, Jolt Physics
- **Godot project root:** `rogue-finder/` — all `res://` paths resolve there
- **Autoload singleton:** `GameState` (run-wide state, save/load)
- **Entry point:** `main.tscn` → `MainMenuScene` → `CharacterCreationScene` → `MapScene` / `CombatScene3D`
- **Design authority:** `GAME_BIBLE_roguefinder.md`
- **System index:** `docs/map_directories/map.md` → per-system bucket files in `docs/map_directories/`
- **Backlog:** `docs/backlog.md`

---

## Commands

There is no build system outside Godot. Open `rogue-finder/` as a Godot 4.6 project in the editor to develop interactively.

**First-time import (required before running headless):**
```bash
godot --headless --path rogue-finder --import
```

**Run a single test suite:**
```bash
godot --headless --path rogue-finder res://tests/test_combatant_data.tscn
godot --headless --path rogue-finder res://tests/test_equipment.tscn
```

Each test file in `rogue-finder/tests/` has a paired `.tscn` runner. There is no test runner that executes all suites at once — run suites individually or chain them.

**No linter is configured.** Typing and convention correctness are enforced by code review.

---

## Architecture

### Scene Structure

All `.tscn` files are **root node + script only** — children are built in `_ready()`. Never add nested scene children in the editor; keep all logic in the script.

### Data-Driven Libraries

All game content lives in `rogue-finder/data/*.csv`. Each CSV has a matching singleton loader at `rogue-finder/scripts/globals/*Library.gd`. **Never use inline `const` dicts for game data** — add a CSV row and extend the library.

**Library shape (use `BackgroundLibrary.gd` as the template):**
- `static var _cache: Dictionary = {}` — lazy-populated on first access
- `static func _ensure_loaded()` — parses once and fills cache
- `static func get_<name>(id)` — returns stub (never null) on unknown id
- `static func all_<names>()` — full array
- `static func reload()` — clear + re-parse (used in tests)

**CSV cell conventions:**
- Pipe-separated string arrays: `ability_pool = fireball|ice_shard|heal`
- JSON for nested structures: `effects = [{"type":"HARM","base_value":5}]`

`EventLibrary` intentionally splits across two CSVs (`events.csv` + `event_choices.csv`) because events have repeating child rows. Every other dataset uses one CSV.

### Character Pillar System

A character is defined by three pillars:

| Pillar | Owns | Contributes |
|--------|------|-------------|
| **Class** | Slot 0 defining ability + ability_pool + feat_pool | stat_bonuses |
| **Kindred** | Slot 1 natural attack + ability_pool | speed/HP bonuses + stat_bonuses |
| **Background** | starting_feat_id + 2-feat pool | stat_bonuses |

Base stat = 4 + class bonus + kindred bonus + background bonus (deterministic, no rolling). Derived stats (hp_max, energy_max, speed, attack, defense) are computed from base attributes + active feats + equipped gear.

### Signal-Driven Communication

Systems signal *up*; managers listen. Never call down from a manager into a subsystem directly. Signals are named as past-tense events: `unit_moved`, `qte_resolved`, `combat_ended`.

### Save System

`GameState` owns all run state and serializes to `user://save.json`. **Every new feature that introduces persistent run state must extend `save()`/`load_save()` in the same PR — never defer.** Use `Array(..., TYPE_T, "", null)` for typed arrays when deserializing.

Currently saved: `player_node_id`, `visited_nodes`, `map_seed`, `node_types`, `cleared_nodes`, `threat_level`, `party`, `inventory`.  
Transient (never saved): `pending_node_type`, `current_combat_node_id`.

### Combat Rules (do not deviate)

- **3v3:** 3 player units vs 3 enemy units on a logical 2D grid projected to 3D world space
- **Team initiative:** all players act, then all enemies
- **Action economy per turn:** Stride (free) + Active Ability (costs Energy) + Consumable (optional)
- **QTE:** defender-driven slider bar, HARM abilities only — all other effect types auto-resolve. Damage multiplier scales from 0.5× (perfect dodge) to 1.25× (miss). Enemies instant-sim via hidden `qte_resolution` stat (grunt 0.3, elite 0.8).

---

## Code Conventions

- **Typed GDScript always:** `var speed: int = 3`, not `var speed = 3`
- `snake_case` for vars/funcs, `PascalCase` for class/node names, `ALL_CAPS` for constants
- `@export` for inspector-tweakable values; `@onready` for node refs
- Section headers: `## --- Section Name ---`
- Placeholder art: use `load("res://icon.svg")` as the default for all 2D placeholders

---

## Testing

Tests live in `rogue-finder/tests/`. Each test is a `.gd` script extending `Node` with logic in `_ready()`, plus a matching empty `.tscn` runner.

- Use plain `assert()` — no external framework
- Write implementation + tests in one session
- **Test:** state transitions, damage formulas, grid math, library lookups, win/lose triggers
- **Do not test:** rendering, input events, anything requiring a live scene tree

---

## Version Control Workflow

- Branch naming: `claude/<feature>-<YYYYMMDD>`
- Create and push a branch before starting any work
- **Never commit directly to `main`** without explicit user approval
- When work is ready: commit + push, then report what was built and list numbered test points for the user
- On approval: `git checkout main && git merge <branch> --no-ff && git push origin main`

---

## Documentation Protocol

Before working on any system, read `docs/map_directories/map.md` to find the relevant bucket file, then read only that bucket. After a significant change, update the relevant bucket `.md` and `map.md` (signals, public methods, dependencies, structural decisions). Cross-system changes require updating all affected buckets.

Do not use this file for session history, scratch notes, or feature status tracking — that lives in `claude.md` (session handoff) and `docs/`.
