# Combat Actions — Design Spec
**Date:** 2026-04-14
**Session:** 3
**Status:** Approved

---

## Overview

Add a radial action menu to the 3D combat prototype. When a player unit is selected, a D-pad-style pop-up appears showing its 4 slotted abilities and equipped consumable. Abilities are backed by a proper data model (`AbilityData` + `AbilityLibrary`). For this session all abilities proxy through the existing QTE → damage flow so combat is playable immediately. Functional targeting per ability type and per-ability QTEs come in a future session.

---

## Section 1 — Data Layer

### `resources/AbilityData.gd`
New `Resource` subclass. Fields:

| Field | Type | Notes |
|-------|------|-------|
| `ability_id` | `String` | Snake_case logic key, e.g. `"heavy_strike"` |
| `ability_name` | `String` | Display name, e.g. `"Heavy Strike"` |
| `tags` | `Array[String]` | e.g. `["Melee"]`, `["Ranged", "Magic"]` |
| `energy_cost` | `int` | Subtracted from unit energy on use |
| `range` | `int` | Tile distance for target highlighting |
| `target_type` | `int` | Enum `TargetType` defined in this file (see below) |
| `description` | `String` | Flavor + mechanical tooltip text |
| `ability_icon` | `Texture2D` | Defaults to Godot icon placeholder |

**`TargetType` enum** (defined in `AbilityData.gd`):
```
SELF = 0
SINGLE_ENEMY = 1
SINGLE_ALLY = 2
AOE = 3
CONE = 4
```

### `scripts/globals/AbilityLibrary.gd`
Static class mirroring `ArchetypeLibrary`. Contains:
- `ABILITIES: Dictionary` — keyed by `ability_id`, each entry holds all AbilityData field values
- `static func get_ability(id: String) -> AbilityData` — returns a populated `AbilityData` instance; falls back to a blank stub for unknown IDs (future-proofs missing CSV rows)

**12 placeholder abilities defined:**

| ID | Name | Tags | Cost | Range | Target | Description |
|----|------|------|------|-------|--------|-------------|
| `strike` | Strike | Melee | 2 | 1 | SingleEnemy | "Step into range and put your weight behind the blow — deal damage to one adjacent enemy." |
| `heavy_strike` | Heavy Strike | Melee | 4 | 1 | SingleEnemy | "Wind up and swing with everything you have — hit one adjacent enemy for serious damage, but leave yourself open." |
| `quick_shot` | Quick Shot | Ranged | 2 | 4 | SingleEnemy | "Draw and loose before the moment passes — deal damage to one enemy within 4 tiles." |
| `disengage` | Disengage | Utility | 2 | 1 | Self | "Step back with practiced care — reposition 1 tile without triggering opportunity attacks." |
| `acid_splash` | Acid Splash | Magic, Ranged | 3 | 3 | SingleEnemy | "Hurl a flask of sizzling reagent — deal damage to one enemy within 3 tiles." |
| `smoke_bomb` | Smoke Bomb | Utility | 2 | 2 | AOE | "Shatter a smoke-filled vial — obscure a small area, granting concealment to all within (effect placeholder)." |
| `healing_draught` | Healing Draught | Utility | 3 | 1 | Self | "Uncork a bitter medicinal brew and down it — restore HP to yourself (effect placeholder)." |
| `shield_bash` | Shield Bash | Melee | 3 | 1 | SingleEnemy | "Lead with the rim of your shield — deal damage to one adjacent enemy and disrupt their footing." |
| `counter` | Counter | Melee | 2 | 1 | Self | "Plant your feet and watch for an opening — prepare to retaliate against the next melee strike you receive (effect placeholder)." |
| `taunt` | Taunt | Utility | 1 | 3 | SingleEnemy | "Bark insults at a nearby enemy — draw their attention and force them to target you next, if able (effect placeholder)." |
| `inspire` | Inspire | Utility | 3 | 3 | SingleAlly | "Shout a rallying cry — bolster an ally within 3 tiles, granting a bonus to their next attack (effect placeholder)." |
| `guard` | Guard | Utility | 2 | 1 | Self | "Adopt a defensive stance — reduce incoming damage until the start of your next turn (effect placeholder)." |

---

## Section 2 — CombatantData & ArchetypeLibrary Changes

### `resources/CombatantData.gd`
- `abilities: Array[String]` — **no change**, strings are now ability IDs (already correct structure)
- `consumable: String` — **no change**, holds display name (`"Healing Potion"`, `"Smoke Vial"`, or `""`)
- ~~`consumable_used: bool`~~ — **dropped**. Setting `consumable = ""` on use is sufficient; empty string means unavailable.

### `scripts/globals/ArchetypeLibrary.gd`
Two changes:
1. Ability name strings → ability IDs (e.g. `"Strike"` → `"strike"`, `"Quick Shot"` → `"quick_shot"`)
2. Add `"consumable"` key per archetype entry, copied into `data.consumable` in `create()`:
   - `RogueFinder`: `"Smoke Vial"`
   - `alchemist`: `"Healing Potion"`
   - All others: `""`

---

## Section 3 — ActionMenu UI

### `scripts/ui/ActionMenu.gd`
New `CanvasLayer` (layer 12). Built entirely in code — no `.tscn`.

**Layout (D-pad cross):**
- 4 ability buttons: 80×80px, positioned ±100px from menu center on each cardinal axis (top/right/bottom/left)
- 1 consumable button: 64×64px, centered (slightly smaller, per reference)
- Total bounding area: ~260×260px

**Positioning:**
- On `open_for(unit: Unit3D)`: project `unit.global_position` to screen via `Camera3D.unproject_position()`, clamp to viewport bounds, center menu there

**Button content:**
- Ability button: icon (Godot icon placeholder) + ability name + energy cost on two lines, e.g. `"Strike\n2E"`
- Empty slot: greyed out, disabled, labelled `"—"`
- Consumable button: icon + consumable name, or `"—"` if empty

**Button states:**
- **Disabled + modulated grey** — energy cost > unit's current energy, slot is `""`, or consumable is `""`
- **Normal** — available to click

**Tooltip:**
- Single `Panel` + `Label` node, repositioned to appear above the hovered button
- Content: `"[Name]\n[Description]\nCost: [N]E"`
- Hidden when not hovering

**Public API:**
```gdscript
func open_for(unit: Unit3D, camera: Camera3D) -> void   # show, populate, and position
func close() -> void                                      # hide

signal ability_selected(ability_id: String)
signal consumable_selected()
```

---

## Section 4 — CombatManager3D Flow Changes

### New variables
```gdscript
var _action_menu: ActionMenu = null
var _pending_ability: AbilityData = null
```

### Removed
- `const ATTACK_ENERGY_COST: int = 3` — replaced by `_pending_ability.energy_cost` per action
- `KEY_A` attack shortcut — menu is now the only action entry point

### Updated `PlayerMode` enum
```gdscript
enum PlayerMode { IDLE, STRIDE_MODE, ABILITY_TARGET_MODE }
```
`ATTACK_MODE` replaced by `ABILITY_TARGET_MODE`.

### Updated `_setup_ui()`
```gdscript
_action_menu = ActionMenu.new()
add_child(_action_menu)
_action_menu.ability_selected.connect(_on_ability_selected)
_action_menu.consumable_selected.connect(_on_consumable_selected)
```

### Grid3D highlight addition
New `"ability_target"` highlight type → **purple** colour. Added alongside existing `"selected"` (yellow), `"move"` (blue), `"attack"` (red — kept for now but unused post-refactor).

### Revised click flow

```
Click player unit
  → _select_unit()           (unchanged — stride highlights appear)
  → _show_info_bar()         (unchanged)
  → _action_menu.open_for(unit, _camera_rig.get_camera())  (NEW)

Ability button pressed
  → _on_ability_selected(ability_id)
      _pending_ability = AbilityLibrary.get_ability(ability_id)
      _action_menu.close()
      if target_type == SELF:
          _initiate_action(_selected_unit, _selected_unit)   # auto-target caster
      elif target_type == SINGLE_ALLY:
          enter ABILITY_TARGET_MODE, highlight living player units within range in purple
      else:
          enter ABILITY_TARGET_MODE
          highlight living enemies within _pending_ability.range in purple

Click purple cell (ABILITY_TARGET_MODE)
  → _try_ability_target(cell)
      resolve to Unit3D target
      _initiate_action(_selected_unit, target)

_initiate_action(attacker, target)
  → same as _initiate_attack() but uses _pending_ability.energy_cost
  → QTE runs, resolves via _on_qte_resolved() unchanged

QTE resolves
  → guard: if _pending_ability == null, return early (safety)
  → spend _pending_ability.energy_cost
  → _pending_ability = null
  → existing post-QTE flow continues unchanged

Consumable button pressed
  → _on_consumable_selected()
      _selected_unit.data.consumable = ""
      _action_menu.open_for(_selected_unit)   # refresh to show greyed-out state

ESC / deselect
  → _action_menu.close()
  → _pending_ability = null
  → existing _deselect() flow unchanged
```

### Status bar messages
```
ABILITY_TARGET_MODE → "ABILITY — click a purple target  |  ESC cancel"
```

---

## Section 5 — Files Changed / Created

| File | Change |
|------|--------|
| `resources/AbilityData.gd` | **NEW** |
| `scripts/globals/AbilityLibrary.gd` | **NEW** |
| `scripts/ui/ActionMenu.gd` | **NEW** |
| `scripts/combat/CombatManager3D.gd` | Modified — menu wiring, flow changes, remove [A] key |
| `resources/CombatantData.gd` | Minor — no field changes; `consumable` semantics clarified |
| `scripts/globals/ArchetypeLibrary.gd` | Modified — ability IDs, add consumable per archetype |
| `scripts/combat/Grid3D.gd` | Minor — add `"ability_target"` purple highlight type |
| `CLAUDE.md` | Add rule: Godot icon is default for all 2D placeholder art |
| `docs/map_directories/map.md` | Add ActionMenu and AbilityLibrary to system index |
| `docs/map_directories/hud_system.md` | Document ActionMenu |
| `docs/map_directories/combatant_data.md` | Document AbilityData + AbilityLibrary |

---

## Out of Scope (Next Sessions)

- Functional ability effects (damage multipliers, AoE, cone, self-heal, etc.)
- Per-ability QTE variants
- CSV import for ability definitions
- Consumable item effects
- Ability unlock / progression system
