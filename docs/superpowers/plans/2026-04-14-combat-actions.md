# Combat Actions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a D-pad radial action menu (4 abilities + consumable) to the 3D combat prototype, backed by a typed AbilityData/AbilityLibrary data model, with all abilities proxied through the existing QTE → damage flow so combat is immediately playable.

**Architecture:** `AbilityData` (Resource) + `AbilityLibrary` (static class, mirrors `ArchetypeLibrary`) define 12 placeholder abilities. `CombatantData.abilities: Array[String]` stores ability IDs already — no schema change needed. `ActionMenu` (CanvasLayer) projects the unit's 3D position to screen and renders a cross-shaped pop-up. `CombatManager3D` wires everything together: ability selection → `ABILITY_TARGET_MODE` → QTE → damage.

**Tech Stack:** Godot 4, GDScript (typed), plain `assert()` tests run headless via `godot --headless --script`

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `rogue-finder/resources/AbilityData.gd` | **CREATE** | Typed Resource: all ability fields + `TargetType` enum |
| `rogue-finder/scripts/globals/AbilityLibrary.gd` | **CREATE** | Static class: 12 ability definitions + `get_ability()` factory |
| `rogue-finder/scripts/ui/ActionMenu.gd` | **CREATE** | CanvasLayer: D-pad layout, hover tooltips, signals |
| `rogue-finder/tests/test_ability_library.gd` | **CREATE** | Headless tests for AbilityData + AbilityLibrary |
| `rogue-finder/scripts/globals/ArchetypeLibrary.gd` | **MODIFY** | Ability name strings → IDs; add `consumable` key per archetype |
| `rogue-finder/scripts/combat/Grid3D.gd` | **MODIFY** | Add `COLOR_ABILITY_TARGET` (purple) + `"ability_target"` match case |
| `rogue-finder/scripts/combat/CombatManager3D.gd` | **MODIFY** | Menu wiring, ABILITY_TARGET_MODE, remove [A] key, rename `_initiate_attack` → `_initiate_action` |
| `CLAUDE.md` | **MODIFY** | Add Godot icon placeholder art rule |
| `docs/map_directories/map.md` | **MODIFY** | Add ActionMenu, AbilityData, AbilityLibrary to index |
| `docs/map_directories/hud_system.md` | **MODIFY** | Add ActionMenu section |
| `docs/map_directories/combatant_data.md` | **MODIFY** | Add AbilityData + AbilityLibrary section |

---

## Task 0: Rename worktree branch

**Files:** none (git operations only)

- [ ] **Step 1: Rename the branch to the descriptive convention**

```bash
cd "C:\Users\caleb\.local\bin\Projects\RogueFinder\.claude\worktrees\adoring-ritchie"
git branch -m claude/adoring-ritchie claude/combat-actions-20260414
git push origin claude/combat-actions-20260414
git push origin --delete claude/adoring-ritchie
git branch -u origin/claude/combat-actions-20260414
```

Expected: no error; `git branch -vv` shows `claude/combat-actions-20260414` tracking `origin/claude/combat-actions-20260414`.

---

## Task 1: AbilityData Resource

**Files:**
- Create: `rogue-finder/resources/AbilityData.gd`
- Create: `rogue-finder/tests/test_ability_library.gd` (stub for now — see Task 2)

- [ ] **Step 1: Write the failing test (stub)**

Create `rogue-finder/tests/test_ability_library.gd`:

```gdscript
extends SceneTree

func _initialize() -> void:
	# Task 1: AbilityData can be instantiated with expected fields
	var ability := AbilityData.new()
	assert(ability.ability_id == "", "default ability_id should be empty")
	assert(ability.energy_cost == 0, "default energy_cost should be 0")
	assert(ability.range == 1, "default range should be 1")
	assert(ability.target_type == AbilityData.TargetType.SINGLE_ENEMY,
		"default target_type should be SINGLE_ENEMY")
	print("Task 1 PASSED: AbilityData defaults correct")
	quit()
```

- [ ] **Step 2: Run test — confirm it fails (class not found)**

```bash
cd "C:\Users\caleb\.local\bin\Projects\RogueFinder\.claude\worktrees\adoring-ritchie\rogue-finder"
godot --headless --script tests/test_ability_library.gd 2>&1
```

Expected: error about `AbilityData` not found.

- [ ] **Step 3: Create `rogue-finder/resources/AbilityData.gd`**

```gdscript
class_name AbilityData
extends Resource

## --- AbilityData ---
## Typed data record for a single ability.
## Instances are created by AbilityLibrary.get_ability() — never set fields directly.

## ======================================================
## TargetType enum — drives targeting highlight and auto-resolve logic.
## ======================================================
enum TargetType {
	SELF         = 0,  ## auto-targets the caster; no highlight step
	SINGLE_ENEMY = 1,  ## player picks one living enemy within range
	SINGLE_ALLY  = 2,  ## player picks one living ally within range
	AOE          = 3,  ## all valid cells in range (effect placeholder)
	CONE         = 4,  ## cells in a directional arc (effect placeholder)
}

## ======================================================
## --- Fields ---
## ======================================================

@export var ability_id:   String   = ""
@export var ability_name: String   = ""
@export var tags:         Array[String] = []
@export var energy_cost:  int      = 0
@export var range:        int      = 1
@export var target_type:  int      = TargetType.SINGLE_ENEMY
@export var description:  String   = ""
## Placeholder icon — defaults to the Godot icon at runtime in AbilityLibrary.
@export var ability_icon: Texture2D = null
```

- [ ] **Step 4: Run test — confirm it passes**

```bash
godot --headless --script tests/test_ability_library.gd 2>&1
```

Expected output: `Task 1 PASSED: AbilityData defaults correct`

- [ ] **Step 5: Commit**

```bash
cd "C:\Users\caleb\.local\bin\Projects\RogueFinder\.claude\worktrees\adoring-ritchie"
git add rogue-finder/resources/AbilityData.gd rogue-finder/tests/test_ability_library.gd
git commit -m "feat: add AbilityData resource with TargetType enum

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 2: AbilityLibrary

**Files:**
- Create: `rogue-finder/scripts/globals/AbilityLibrary.gd`
- Modify: `rogue-finder/tests/test_ability_library.gd` (add Task 2 assertions)

- [ ] **Step 1: Add failing tests to `test_ability_library.gd`**

Replace the entire file contents:

```gdscript
extends SceneTree

func _initialize() -> void:
	_test_ability_data_defaults()
	_test_known_ability()
	_test_unknown_ability_stub()
	_test_all_archetype_abilities_resolve()
	print("All AbilityLibrary tests PASSED.")
	quit()

func _test_ability_data_defaults() -> void:
	var ability := AbilityData.new()
	assert(ability.ability_id == "", "default ability_id should be empty")
	assert(ability.energy_cost == 0, "default energy_cost should be 0")
	assert(ability.range == 1, "default range should be 1")
	assert(ability.target_type == AbilityData.TargetType.SINGLE_ENEMY,
		"default target_type should be SINGLE_ENEMY")

func _test_known_ability() -> void:
	var a: AbilityData = AbilityLibrary.get_ability("strike")
	assert(a != null, "strike should not be null")
	assert(a.ability_id == "strike", "ID mismatch: " + a.ability_id)
	assert(a.ability_name == "Strike", "name mismatch: " + a.ability_name)
	assert(a.energy_cost == 2, "strike energy_cost should be 2, got " + str(a.energy_cost))
	assert(a.range == 1, "strike range should be 1")
	assert(a.target_type == AbilityData.TargetType.SINGLE_ENEMY, "strike should target SINGLE_ENEMY")
	assert(a.description != "", "description should not be empty")

	var b: AbilityData = AbilityLibrary.get_ability("taunt")
	assert(b.energy_cost == 1, "taunt energy_cost should be 1")
	assert(b.range == 3, "taunt range should be 3")

	var c: AbilityData = AbilityLibrary.get_ability("healing_draught")
	assert(c.target_type == AbilityData.TargetType.SELF, "healing_draught should target SELF")

func _test_unknown_ability_stub() -> void:
	var stub: AbilityData = AbilityLibrary.get_ability("nonexistent_xyz")
	assert(stub != null, "unknown ID should return stub, not null")
	assert(stub.ability_id == "unknown", "stub id should be 'unknown', got: " + stub.ability_id)
	assert(stub.energy_cost == 0, "stub energy_cost should be 0")

func _test_all_archetype_abilities_resolve() -> void:
	# Every non-empty ability ID used in ArchetypeLibrary must resolve without null
	var all_ids: Array[String] = [
		"strike", "guard", "inspire",
		"quick_shot", "disengage",
		"heavy_strike",
		"acid_splash", "smoke_bomb", "healing_draught",
		"shield_bash", "counter", "taunt",
	]
	for id in all_ids:
		var a: AbilityData = AbilityLibrary.get_ability(id)
		assert(a != null, "ability should not be null: " + id)
		assert(a.ability_id == id, "ID roundtrip failed for: " + id)
```

- [ ] **Step 2: Run — confirm tests fail (AbilityLibrary not found)**

```bash
cd "C:\Users\caleb\.local\bin\Projects\RogueFinder\.claude\worktrees\adoring-ritchie\rogue-finder"
godot --headless --script tests/test_ability_library.gd 2>&1
```

Expected: error about `AbilityLibrary` not found.

- [ ] **Step 3: Create `rogue-finder/scripts/globals/AbilityLibrary.gd`**

```gdscript
class_name AbilityLibrary
extends RefCounted

## --- AbilityLibrary ---
## Static definitions for all abilities in the game.
## Mirrors ArchetypeLibrary's pattern: a Dictionary of dicts keyed by ability_id.
## A future CSV import will replace ABILITIES — get_ability() signature stays the same.
##
## Adding a new ability: add one entry to ABILITIES; nothing else changes.

## --- Schema ---
## "name"        : String
## "tags"        : Array[String]
## "cost"        : int
## "range"       : int
## "target"      : AbilityData.TargetType  (int)
## "description" : String

const ABILITIES: Dictionary = {
	"strike": {
		"name":        "Strike",
		"tags":        ["Melee"],
		"cost":        2,
		"range":       1,
		"target":      AbilityData.TargetType.SINGLE_ENEMY,
		"description": "Step into range and put your weight behind the blow — deal damage to one adjacent enemy.",
	},
	"heavy_strike": {
		"name":        "Heavy Strike",
		"tags":        ["Melee"],
		"cost":        4,
		"range":       1,
		"target":      AbilityData.TargetType.SINGLE_ENEMY,
		"description": "Wind up and swing with everything you have — hit one adjacent enemy for serious damage, but leave yourself wide open.",
	},
	"quick_shot": {
		"name":        "Quick Shot",
		"tags":        ["Ranged"],
		"cost":        2,
		"range":       4,
		"target":      AbilityData.TargetType.SINGLE_ENEMY,
		"description": "Draw and loose before the moment passes — deal damage to one enemy within 4 tiles.",
	},
	"disengage": {
		"name":        "Disengage",
		"tags":        ["Utility"],
		"cost":        2,
		"range":       1,
		"target":      AbilityData.TargetType.SELF,
		"description": "Step back with practiced care — reposition 1 tile without triggering opportunity attacks. (effect placeholder)",
	},
	"acid_splash": {
		"name":        "Acid Splash",
		"tags":        ["Magic", "Ranged"],
		"cost":        3,
		"range":       3,
		"target":      AbilityData.TargetType.SINGLE_ENEMY,
		"description": "Hurl a flask of sizzling reagent at one enemy within 3 tiles — their skin will remember it.",
	},
	"smoke_bomb": {
		"name":        "Smoke Bomb",
		"tags":        ["Utility"],
		"cost":        2,
		"range":       2,
		"target":      AbilityData.TargetType.AOE,
		"description": "Shatter a smoke-filled vial at a point within 2 tiles — obscure the area, granting concealment to all within. (effect placeholder)",
	},
	"healing_draught": {
		"name":        "Healing Draught",
		"tags":        ["Utility"],
		"cost":        3,
		"range":       1,
		"target":      AbilityData.TargetType.SELF,
		"description": "Uncork a bitter medicinal brew and down it — restore a measure of your own health. (effect placeholder)",
	},
	"shield_bash": {
		"name":        "Shield Bash",
		"tags":        ["Melee"],
		"cost":        3,
		"range":       1,
		"target":      AbilityData.TargetType.SINGLE_ENEMY,
		"description": "Lead with the rim of your shield — deal damage to one adjacent enemy and disrupt their footing.",
	},
	"counter": {
		"name":        "Counter",
		"tags":        ["Melee"],
		"cost":        2,
		"range":       1,
		"target":      AbilityData.TargetType.SELF,
		"description": "Plant your feet and watch for an opening — prepare a retaliatory strike against the next enemy that swings at you. (effect placeholder)",
	},
	"taunt": {
		"name":        "Taunt",
		"tags":        ["Utility"],
		"cost":        1,
		"range":       3,
		"target":      AbilityData.TargetType.SINGLE_ENEMY,
		"description": "Bark choice insults at a nearby enemy — force them to direct their next action at you, if able. (effect placeholder)",
	},
	"inspire": {
		"name":        "Inspire",
		"tags":        ["Utility"],
		"cost":        3,
		"range":       3,
		"target":      AbilityData.TargetType.SINGLE_ALLY,
		"description": "Shout a rallying cry — bolster one ally within 3 tiles, granting a bonus to their next attack. (effect placeholder)",
	},
	"guard": {
		"name":        "Guard",
		"tags":        ["Utility"],
		"cost":        2,
		"range":       1,
		"target":      AbilityData.TargetType.SELF,
		"description": "Adopt a defensive stance — reduce all incoming damage until the start of your next turn. (effect placeholder)",
	},
}

## Returns a populated AbilityData for the given ID.
## Falls back to a blank stub if the ID is unknown — never returns null.
static func get_ability(ability_id: String) -> AbilityData:
	var godot_icon: Texture2D = load("res://icon.svg")
	if not ABILITIES.has(ability_id):
		var stub := AbilityData.new()
		stub.ability_id   = "unknown"
		stub.ability_name = "Unknown"
		stub.description  = "No ability data found for ID: " + ability_id
		stub.ability_icon = godot_icon
		return stub

	var def: Dictionary = ABILITIES[ability_id]
	var a := AbilityData.new()
	a.ability_id   = ability_id
	a.ability_name = def["name"]
	a.tags         = def["tags"].duplicate()
	a.energy_cost  = def["cost"]
	a.range        = def["range"]
	a.target_type  = def["target"]
	a.description  = def["description"]
	a.ability_icon = godot_icon
	return a
```

- [ ] **Step 4: Run tests — confirm all pass**

```bash
cd "C:\Users\caleb\.local\bin\Projects\RogueFinder\.claude\worktrees\adoring-ritchie\rogue-finder"
godot --headless --script tests/test_ability_library.gd 2>&1
```

Expected output: `All AbilityLibrary tests PASSED.`

- [ ] **Step 5: Commit**

```bash
cd "C:\Users\caleb\.local\bin\Projects\RogueFinder\.claude\worktrees\adoring-ritchie"
git add rogue-finder/scripts/globals/AbilityLibrary.gd rogue-finder/tests/test_ability_library.gd
git commit -m "feat: add AbilityLibrary with 12 placeholder abilities

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 3: Update ArchetypeLibrary

**Files:**
- Modify: `rogue-finder/scripts/globals/ArchetypeLibrary.gd`
- Modify: `rogue-finder/tests/test_ability_library.gd` (add Task 3 assertions)

- [ ] **Step 1: Add failing tests**

Append a new test function to `test_ability_library.gd`. Add the call in `_initialize()` before `quit()`:

```gdscript
# Add this call in _initialize() before quit():
_test_archetype_library_updates()
```

```gdscript
func _test_archetype_library_updates() -> void:
	var rogue: CombatantData = ArchetypeLibrary.create("RogueFinder", "Vael", true)
	assert(rogue.consumable == "Smoke Vial",
		"RogueFinder consumable should be 'Smoke Vial', got: " + rogue.consumable)
	assert(rogue.abilities[0] == "strike",
		"RogueFinder abilities[0] should be 'strike', got: " + rogue.abilities[0])

	var alch: CombatantData = ArchetypeLibrary.create("alchemist", "", false)
	assert(alch.consumable == "Healing Potion",
		"alchemist consumable should be 'Healing Potion', got: " + alch.consumable)
	assert(alch.abilities[0] == "acid_splash",
		"alchemist abilities[0] should be 'acid_splash', got: " + alch.abilities[0])

	var grunt: CombatantData = ArchetypeLibrary.create("grunt", "", false)
	assert(grunt.consumable == "",
		"grunt consumable should be empty, got: " + grunt.consumable)
	assert(grunt.abilities[0] == "heavy_strike",
		"grunt abilities[0] should be 'heavy_strike', got: " + grunt.abilities[0])
```

- [ ] **Step 2: Run — confirm tests fail**

```bash
cd "C:\Users\caleb\.local\bin\Projects\RogueFinder\.claude\worktrees\adoring-ritchie\rogue-finder"
godot --headless --script tests/test_ability_library.gd 2>&1
```

Expected: assertion failures about consumable / ability IDs.

- [ ] **Step 3: Replace `rogue-finder/scripts/globals/ArchetypeLibrary.gd` with updated version**

Replace only the `ARCHETYPES` constant and add consumable to `create()`. Full updated file:

```gdscript
class_name ArchetypeLibrary
extends RefCounted

## --- ArchetypeLibrary ---
## Static archetype definitions and a factory that builds randomized CombatantData.
##
## Each archetype entry fixes: class, artwork paths, available backgrounds, ability pool.
## Numeric fields are given as [min, max] ranges — the factory rolls within them.
##
## Placeholder data only — a future CSV import will replace these constants.
## Adding a new archetype: add an entry to ARCHETYPES, nothing else needs to change.

## --- Archetype definition schema ---
## "class"          : String            — fixed class label
## "artwork_idle"   : String            — res:// path placeholder
## "artwork_attack" : String            — res:// path placeholder
## "backgrounds"    : Array[String]     — pool; one is chosen at random
## "abilities"      : Array             — fixed 4-slot list of ability IDs ("" = empty slot)
## "consumable"     : String            — consumable item name ("" = none)
## "str_range"      : [min, max] int
## "dex_range"      : [min, max] int
## "cog_range"      : [min, max] int
## "wil_range"      : [min, max] int
## "vit_range"      : [min, max] int    — clamped to min 1 at creation
## "armor_range"    : [min, max] int    — placeholder until item system exists
## "qte_range"      : [min, max] float  — enemy-only auto-accuracy

const ARCHETYPES: Dictionary = {
	## RogueFinder — the player character. One per party; wide ranges for variety.
	"RogueFinder": {
		"class":          "Custom",
		"artwork_idle":   "",
		"artwork_attack": "",
		"backgrounds":    ["Noble", "Peasant", "Scholar", "Soldier", "Merchant"],
		"abilities":      ["strike", "guard", "inspire", ""],
		"consumable":     "Smoke Vial",
		"str_range":      [1, 4],
		"dex_range":      [1, 4],
		"cog_range":      [1, 4],
		"wil_range":      [1, 4],
		"vit_range":      [2, 5],
		"armor_range":    [4, 8],
		"qte_range":      [0.0, 0.0],
	},
	## Quick, nimble brigand. High dex, low strength.
	"archer_bandit": {
		"class":          "Rogue",
		"artwork_idle":   "",
		"artwork_attack": "",
		"backgrounds":    ["Crook", "Soldier"],
		"abilities":      ["quick_shot", "disengage", "", ""],
		"consumable":     "",
		"str_range":      [1, 2],
		"dex_range":      [3, 4],
		"cog_range":      [1, 2],
		"wil_range":      [0, 2],
		"vit_range":      [1, 3],
		"armor_range":    [3, 5],
		"qte_range":      [0.3, 0.5],
	},
	## Brawny melee fighter. High strength and vitality, low cognition.
	"grunt": {
		"class":          "Barbarian",
		"artwork_idle":   "",
		"artwork_attack": "",
		"backgrounds":    ["Crook", "Soldier"],
		"abilities":      ["heavy_strike", "", "", ""],
		"consumable":     "",
		"str_range":      [2, 4],
		"dex_range":      [1, 2],
		"cog_range":      [0, 1],
		"wil_range":      [0, 2],
		"vit_range":      [2, 4],
		"armor_range":    [4, 7],
		"qte_range":      [0.2, 0.5],
	},
	## Crafty support caster. High cognition, low strength.
	"alchemist": {
		"class":          "Wizard",
		"artwork_idle":   "",
		"artwork_attack": "",
		"backgrounds":    ["Baker", "Scholar", "Merchant"],
		"abilities":      ["acid_splash", "smoke_bomb", "healing_draught", ""],
		"consumable":     "Healing Potion",
		"str_range":      [0, 1],
		"dex_range":      [1, 3],
		"cog_range":      [3, 5],
		"wil_range":      [2, 4],
		"vit_range":      [1, 2],
		"armor_range":    [2, 4],
		"qte_range":      [0.5, 0.8],
	},
	## Heavily armored veteran. High strength, willpower, and vitality.
	"elite_guard": {
		"class":          "Warrior",
		"artwork_idle":   "",
		"artwork_attack": "",
		"backgrounds":    ["Soldier", "Noble"],
		"abilities":      ["shield_bash", "counter", "taunt", ""],
		"consumable":     "",
		"str_range":      [3, 5],
		"dex_range":      [1, 3],
		"cog_range":      [1, 2],
		"wil_range":      [2, 4],
		"vit_range":      [3, 5],
		"armor_range":    [7, 10],
		"qte_range":      [0.6, 0.9],
	},
}

## --- Flavor name pools ---
const _NAME_POOLS: Dictionary = {
	"RogueFinder":   ["Hero"],
	"archer_bandit": ["Kale", "Sora", "Wren", "Dax", "Mira", "Fenn"],
	"grunt":         ["Brak", "Mord", "Thug", "Krak", "Uge", "Dorn"],
	"alchemist":     ["Finch", "Alda", "Quill", "Senna", "Pip", "Loris"],
	"elite_guard":   ["Sven", "Holt", "Cara", "Brix", "Edda", "Vale"],
}

## ======================================================
## Public API
## ======================================================

static func create(archetype_id: String, character_name: String = "",
		is_player: bool = false) -> CombatantData:
	var def: Dictionary = ARCHETYPES.get(archetype_id, ARCHETYPES["grunt"])
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var data := CombatantData.new()
	data.archetype_id   = archetype_id
	data.is_player_unit = is_player
	data.unit_class     = def["class"]
	data.artwork_idle   = def["artwork_idle"]
	data.artwork_attack = def["artwork_attack"]

	# Ability pool: copy so each instance is independent
	var ability_src: Array = def["abilities"]
	data.abilities.clear()
	for ab in ability_src:
		data.abilities.append(str(ab))
	while data.abilities.size() < 4:
		data.abilities.append("")

	# Consumable item (empty string = none)
	data.consumable = def.get("consumable", "")

	var bgs: Array = def["backgrounds"]
	data.background = bgs[rng.randi_range(0, bgs.size() - 1)]

	data.strength  = rng.randi_range(def["str_range"][0], def["str_range"][1])
	data.dexterity = rng.randi_range(def["dex_range"][0], def["dex_range"][1])
	data.cognition = rng.randi_range(def["cog_range"][0], def["cog_range"][1])
	data.willpower = rng.randi_range(def["wil_range"][0], def["wil_range"][1])
	data.vitality  = rng.randi_range(def["vit_range"][0], def["vit_range"][1])
	data.vitality  = maxi(1, data.vitality)

	data.armor_defense  = rng.randi_range(def["armor_range"][0], def["armor_range"][1])
	data.qte_resolution = rng.randf_range(def["qte_range"][0], def["qte_range"][1])

	if character_name != "":
		data.character_name = character_name
	elif is_player:
		var pool: Array = _NAME_POOLS.get(archetype_id, ["Unit"])
		data.character_name = pool[rng.randi_range(0, pool.size() - 1)]
	else:
		data.character_name = ""

	return data
```

- [ ] **Step 4: Run tests — confirm all pass**

```bash
cd "C:\Users\caleb\.local\bin\Projects\RogueFinder\.claude\worktrees\adoring-ritchie\rogue-finder"
godot --headless --script tests/test_ability_library.gd 2>&1
```

Expected output: `All AbilityLibrary tests PASSED.`

- [ ] **Step 5: Commit**

```bash
cd "C:\Users\caleb\.local\bin\Projects\RogueFinder\.claude\worktrees\adoring-ritchie"
git add rogue-finder/scripts/globals/ArchetypeLibrary.gd rogue-finder/tests/test_ability_library.gd
git commit -m "feat: update ArchetypeLibrary with ability IDs and consumable field

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 4: Grid3D Ability Target Highlight

**Files:**
- Modify: `rogue-finder/scripts/combat/Grid3D.gd`

No test needed — highlight colors are rendering state.

- [ ] **Step 1: Add `COLOR_ABILITY_TARGET` constant and `"ability_target"` match case**

In `Grid3D.gd`, add the constant after the existing color constants (around line 19):

```gdscript
const COLOR_ABILITY_TARGET: Color = Color(0.65, 0.20, 0.90, 0.85)  # purple
```

In `_refresh_cell_color()`, add the new case before the default `_:` case:

```gdscript
func _refresh_cell_color(pos: Vector2i) -> void:
	if not is_valid(pos):
		return
	var idx: int = pos.y * COLS + pos.x
	if idx >= _cell_materials.size():
		return
	var mat: StandardMaterial3D = _cell_materials[idx]
	match highlighted_cells.get(pos, ""):
		"move":           mat.albedo_color = COLOR_MOVE
		"attack":         mat.albedo_color = COLOR_ATTACK
		"selected":       mat.albedo_color = COLOR_SELECTED
		"ability_target": mat.albedo_color = COLOR_ABILITY_TARGET
		_:                mat.albedo_color = COLOR_DEFAULT
```

- [ ] **Step 2: Commit**

```bash
cd "C:\Users\caleb\.local\bin\Projects\RogueFinder\.claude\worktrees\adoring-ritchie"
git add rogue-finder/scripts/combat/Grid3D.gd
git commit -m "feat: add ability_target purple highlight to Grid3D

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 5: ActionMenu UI

**Files:**
- Create: `rogue-finder/scripts/ui/ActionMenu.gd`

No headless test — requires CanvasLayer/Control nodes.

- [ ] **Step 1: Create `rogue-finder/scripts/ui/ActionMenu.gd`**

```gdscript
class_name ActionMenu
extends CanvasLayer

## --- ActionMenu ---
## D-pad radial pop-up: 4 ability buttons (up/right/bottom/left) + 1 consumable (center).
## Shown when a player unit is selected; hidden on deselect or action choice.
## Layer 12: above UnitInfoBar (4) and StatPanel (8), below confirm dialog (20).
##
## open_for() positions the menu at the unit's projected screen position.
## ability_selected(ability_id) and consumable_selected() are the only outputs.

signal ability_selected(ability_id: String)
signal consumable_selected()

const BTN_SIZE:    float = 80.0
const CON_SIZE:    float = 64.0
const BTN_OFFSET:  float = 100.0  ## distance from center to ability button center
const TOOLTIP_W:   float = 240.0
const TOOLTIP_H:   float = 72.0

## Approximate viewport dimensions for clamping (matches current project setup)
const VP_W: float = 1280.0
const VP_H: float = 720.0

var _root:             Control         = null
var _ability_buttons:  Array[Button]   = []
var _consumable_btn:   Button          = null
var _tooltip_panel:    ColorRect       = null
var _tooltip_label:    Label           = null
var _current_unit:     Unit3D          = null
var _ability_ids:      Array[String]   = []

## Cardinal offsets: top, right, bottom, left
const _OFFSETS: Array = [
	Vector2(0.0,         -BTN_OFFSET),
	Vector2(BTN_OFFSET,   0.0),
	Vector2(0.0,          BTN_OFFSET),
	Vector2(-BTN_OFFSET,  0.0),
]

func _ready() -> void:
	layer = 12
	_build_ui()
	visible = false

## --- UI Construction ---

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# 4 ability buttons
	for i in range(4):
		var btn := Button.new()
		btn.size = Vector2(BTN_SIZE, BTN_SIZE)
		btn.add_theme_font_size_override("font_size", 10)
		btn.mouse_entered.connect(_on_ability_hover.bind(i))
		btn.mouse_exited.connect(_on_hover_exit)
		btn.pressed.connect(_on_ability_pressed.bind(i))
		_root.add_child(btn)
		_ability_buttons.append(btn)

	# Center consumable button (slightly smaller)
	_consumable_btn = Button.new()
	_consumable_btn.size = Vector2(CON_SIZE, CON_SIZE)
	_consumable_btn.add_theme_font_size_override("font_size", 9)
	_consumable_btn.mouse_entered.connect(_on_consumable_hover)
	_consumable_btn.mouse_exited.connect(_on_hover_exit)
	_consumable_btn.pressed.connect(_on_consumable_pressed)
	_root.add_child(_consumable_btn)

	# Tooltip: dark panel + label, rendered above everything in the menu
	_tooltip_panel = ColorRect.new()
	_tooltip_panel.color   = Color(0.04, 0.05, 0.12, 0.95)
	_tooltip_panel.size    = Vector2(TOOLTIP_W, TOOLTIP_H)
	_tooltip_panel.visible = false
	_root.add_child(_tooltip_panel)

	_tooltip_label = Label.new()
	_tooltip_label.position = Vector2(6.0, 4.0)
	_tooltip_label.size     = Vector2(TOOLTIP_W - 12.0, TOOLTIP_H - 8.0)
	_tooltip_label.add_theme_font_size_override("font_size", 10)
	_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_panel.add_child(_tooltip_label)

## --- Public API ---

## Show the menu centered on the unit's projected screen position.
## camera: pass _camera_rig.get_camera() from CombatManager3D.
func open_for(unit: Unit3D, camera: Camera3D) -> void:
	_current_unit = unit
	_ability_ids  = unit.data.abilities.duplicate()

	# Project 3D world pos to 2D screen, then clamp so menu never clips
	var raw: Vector2    = camera.unproject_position(unit.global_position)
	var half: float     = BTN_OFFSET + BTN_SIZE * 0.5
	var center: Vector2 = Vector2(
		clampf(raw.x, half, VP_W - half),
		clampf(raw.y, half, VP_H - half)
	)

	# Position ability buttons
	for i in range(4):
		var btn: Button      = _ability_buttons[i]
		var offset: Vector2  = _OFFSETS[i]
		var btn_center: Vector2 = center + offset
		btn.position = btn_center - Vector2(BTN_SIZE * 0.5, BTN_SIZE * 0.5)
		_refresh_ability_button(btn, i, unit)

	# Position consumable button
	_consumable_btn.position = center - Vector2(CON_SIZE * 0.5, CON_SIZE * 0.5)
	_refresh_consumable_button(unit)

	_tooltip_panel.visible = false
	visible = true

func close() -> void:
	_tooltip_panel.visible = false
	visible                = false
	_current_unit          = null

## --- Button population helpers ---

func _refresh_ability_button(btn: Button, index: int, unit: Unit3D) -> void:
	var ability_id: String = _ability_ids[index] if index < _ability_ids.size() else ""
	if ability_id == "":
		btn.text     = "—"
		btn.disabled = true
		btn.modulate = Color(0.5, 0.5, 0.5, 0.7)
		return

	var ability: AbilityData = AbilityLibrary.get_ability(ability_id)
	# Grey out if the unit has already used their action OR can't afford the cost
	var can_use: bool = (not unit.has_acted) and (unit.current_energy >= ability.energy_cost)
	btn.text     = "%s\n%dE" % [ability.ability_name, ability.energy_cost]
	btn.disabled = not can_use
	btn.modulate = Color.WHITE if can_use else Color(0.5, 0.5, 0.5, 0.7)

func _refresh_consumable_button(unit: Unit3D) -> void:
	var has_item: bool       = unit.data.consumable != ""
	_consumable_btn.text     = unit.data.consumable if has_item else "—"
	_consumable_btn.disabled = not has_item
	_consumable_btn.modulate = Color.WHITE if has_item else Color(0.5, 0.5, 0.5, 0.7)

## --- Button callbacks ---

func _on_ability_pressed(index: int) -> void:
	var ability_id: String = _ability_ids[index] if index < _ability_ids.size() else ""
	if ability_id == "":
		return
	close()
	ability_selected.emit(ability_id)

func _on_consumable_pressed() -> void:
	close()
	consumable_selected.emit()

## --- Tooltip ---

func _on_ability_hover(index: int) -> void:
	var ability_id: String = _ability_ids[index] if index < _ability_ids.size() else ""
	if ability_id == "":
		return
	var ability: AbilityData = AbilityLibrary.get_ability(ability_id)
	var tags_str: String     = ", ".join(ability.tags) if not ability.tags.is_empty() else ""
	var text: String = "%s  [%s]  %dE\n%s" % [
		ability.ability_name, tags_str, ability.energy_cost, ability.description
	]
	_show_tooltip(text, _ability_buttons[index].position + Vector2(BTN_SIZE * 0.5, -TOOLTIP_H - 6.0))

func _on_consumable_hover() -> void:
	if not _current_unit or _current_unit.data.consumable == "":
		return
	_show_tooltip(
		_current_unit.data.consumable + "\n(Consumable — use to activate effect)",
		_consumable_btn.position + Vector2(CON_SIZE * 0.5, -TOOLTIP_H - 6.0)
	)

func _on_hover_exit() -> void:
	_tooltip_panel.visible = false

func _show_tooltip(text: String, pos: Vector2) -> void:
	_tooltip_label.text    = text
	_tooltip_panel.position = Vector2(
		clampf(pos.x - TOOLTIP_W * 0.5, 0.0, VP_W - TOOLTIP_W),
		clampf(pos.y, 0.0, VP_H - TOOLTIP_H)
	)
	_tooltip_panel.visible = true
```

- [ ] **Step 2: Commit**

```bash
cd "C:\Users\caleb\.local\bin\Projects\RogueFinder\.claude\worktrees\adoring-ritchie"
git add rogue-finder/scripts/ui/ActionMenu.gd
git commit -m "feat: add ActionMenu radial UI (D-pad layout, tooltips, signals)

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 6: CombatManager3D Wiring

**Files:**
- Modify: `rogue-finder/scripts/combat/CombatManager3D.gd`

No headless test — requires a live scene. Manual playtest verifies behavior.

- [ ] **Step 1: Replace the top-level declarations (vars, enums, constants)**

Replace everything from the top of the file through the `_ready()` function. The new version removes `ATTACK_ENERGY_COST`, updates `PlayerMode`, and adds the two new variables:

```gdscript
class_name CombatManager3D
extends Node3D

## --- CombatManager3D ---
## Turn state machine for the 3D combat prototype.
## Builds the entire scene in _ready() — no child nodes needed in the .tscn.
## Controls: Click to select/move, radial action menu for abilities/consumables,
##           [Enter] end turn, [ESC] deselect.
## Camera: [Q] rotate CCW, [E] rotate CW, scroll wheel zoom.
##
## "Redo" button at bottom-left reloads the scene with freshly randomized units.

const ENEMY_TURN_DELAY: float = 0.65

enum CombatState { PLAYER_TURN, QTE_RUNNING, ENEMY_TURN, WIN, LOSE }
enum PlayerMode  { IDLE, STRIDE_MODE, ABILITY_TARGET_MODE }

var state: CombatState = CombatState.PLAYER_TURN
var mode:  PlayerMode  = PlayerMode.IDLE

var _player_units:   Array[Unit3D]      = []
var _enemy_units:    Array[Unit3D]      = []
var _selected_unit:  Unit3D             = null
var _attack_target:  Unit3D             = null
var _pending_ability: AbilityData       = null   ## set when ability chosen from menu

var _grid:           Grid3D             = null
var _camera_rig:     CameraController   = null
var _qte_bar:        QTEBar             = null
var _stat_panel:     StatPanel          = null
var _info_bar:       UnitInfoBar        = null
var _action_menu:    ActionMenu         = null
var _info_bar_unit:  Unit3D             = null
var _confirm_panel:  ColorRect          = null
var _status_label:   Label              = null

## --- Initialization ---

func _ready() -> void:
	_setup_environment()
	_setup_camera()
	_setup_grid()
	_setup_units()
	_setup_ui()
	_update_status()
```

- [ ] **Step 2: Update `_setup_ui()` — add ActionMenu**

After the existing `_info_bar` setup block (after `add_child(_info_bar)`), add:

```gdscript
	# Radial action menu — shown on player unit selection
	_action_menu = ActionMenu.new()
	add_child(_action_menu)
	_action_menu.ability_selected.connect(_on_ability_selected)
	_action_menu.consumable_selected.connect(_on_consumable_selected)
```

- [ ] **Step 3: Replace `_unhandled_input()` — remove KEY_A, add ABILITY_TARGET_MODE**

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if _stat_panel.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				_stat_panel.hide_panel()
		get_viewport().set_input_as_handled()
		return

	if state != CombatState.PLAYER_TURN:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				_deselect()
				get_viewport().set_input_as_handled()
			KEY_SPACE:
				_request_end_player_turn()
				get_viewport().set_input_as_handled()

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.double_click:
			_handle_double_click()
		else:
			_handle_left_click()
```

- [ ] **Step 4: Replace `_handle_left_click()` — add ABILITY_TARGET_MODE case**

```gdscript
func _handle_left_click() -> void:
	var camera: Camera3D = _camera_rig.get_camera()
	if not camera:
		return
	var cell: Vector2i = _grid.get_clicked_cell(camera, get_viewport())
	if cell == Vector2i(-1, -1):
		return

	match mode:
		PlayerMode.IDLE:
			_try_select_unit(cell)
		PlayerMode.STRIDE_MODE:
			_try_move(cell)
		PlayerMode.ABILITY_TARGET_MODE:
			_try_ability_target(cell)
```

- [ ] **Step 5: Update `_try_select_unit()` — open menu on player selection**

```gdscript
func _try_select_unit(cell: Vector2i) -> void:
	var obj: Object = _grid.get_unit_at(cell)
	if obj is Unit3D and obj.is_alive:
		var unit := obj as Unit3D
		if unit.data.is_player_unit:
			_select_unit(unit)
			_show_info_bar(unit)
		else:
			_deselect()
			_show_info_bar(unit)
	else:
		_deselect()
```

- [ ] **Step 6: Update `_select_unit()` — open menu here so it refreshes after QTE too**

```gdscript
func _select_unit(unit: Unit3D) -> void:
	if _selected_unit:
		_selected_unit.set_selected(false)
	_selected_unit = unit
	unit.set_selected(true)
	_grid.clear_highlights()
	_grid.set_highlight(unit.grid_pos, "selected")
	if unit.can_stride():
		for cell in _grid.get_move_range(unit.grid_pos, unit.data.speed):
			_grid.set_highlight(cell, "move")
	mode = PlayerMode.STRIDE_MODE if unit.can_stride() else PlayerMode.IDLE
	# Open (or refresh) the radial menu for this unit
	_action_menu.open_for(unit, _camera_rig.get_camera())
	_update_status()
```

- [ ] **Step 7: Update `_deselect()` — close menu**

```gdscript
func _deselect() -> void:
	if _selected_unit:
		_selected_unit.set_selected(false)
		_selected_unit = null
	_grid.clear_highlights()
	_stat_panel.hide_panel()
	_info_bar.hide_bar()
	_action_menu.close()
	_info_bar_unit = null
	_pending_ability = null
	mode = PlayerMode.IDLE
	_update_status()
```

- [ ] **Step 8: Remove `_enter_attack_mode()` and `_try_attack()` entirely**

Delete both functions from the file.

- [ ] **Step 9: Add `_on_ability_selected()`, `_on_consumable_selected()`, and `_try_ability_target()`**

Add these three functions after `_try_move()`:

```gdscript
## Called when the player picks an ability from the ActionMenu.
func _on_ability_selected(ability_id: String) -> void:
	if not _selected_unit:
		return
	_pending_ability = AbilityLibrary.get_ability(ability_id)

	# Self-targeting abilities skip the target-pick step and go straight to QTE
	if _pending_ability.target_type == AbilityData.TargetType.SELF:
		_initiate_action(_selected_unit, _selected_unit)
		return

	# Collect valid target cells based on target_type and range
	var targets: Array[Unit3D] = []
	if _pending_ability.target_type == AbilityData.TargetType.SINGLE_ALLY:
		for pu in _player_units:
			if pu.is_alive:
				targets.append(pu)
	else:
		# SINGLE_ENEMY, AOE, CONE — all use enemy cells for now (effect logic comes later)
		for eu in _enemy_units:
			if eu.is_alive:
				targets.append(eu)

	if targets.is_empty():
		# No valid targets — cancel the selection silently
		_pending_ability = null
		return

	# Highlight valid target cells in purple (ability_target)
	mode = PlayerMode.ABILITY_TARGET_MODE
	_grid.clear_highlights()
	_grid.set_highlight(_selected_unit.grid_pos, "selected")
	for target in targets:
		var dx: int = abs(target.grid_pos.x - _selected_unit.grid_pos.x)
		var dy: int = abs(target.grid_pos.y - _selected_unit.grid_pos.y)
		var dist: float = float(maxi(dx, dy)) + float(mini(dx, dy)) * 0.5
		if dist <= float(_pending_ability.range):
			_grid.set_highlight(target.grid_pos, "ability_target")
	_update_status()

## Resolve the player clicking a cell while in ABILITY_TARGET_MODE.
func _try_ability_target(cell: Vector2i) -> void:
	if not _selected_unit or not _pending_ability:
		return
	if _grid.highlighted_cells.get(cell, "") != "ability_target":
		# Clicked a non-target cell — cancel ability mode, return to IDLE
		_pending_ability = null
		_select_unit(_selected_unit)   # re-opens menu and refreshes highlights
		return
	var obj: Object = _grid.get_unit_at(cell)
	if not obj is Unit3D:
		return
	_initiate_action(_selected_unit, obj as Unit3D)  # _attack_target set inside _initiate_action

## Consume the equipped item (sets consumable to "" so the button greys out).
func _on_consumable_selected() -> void:
	if not _selected_unit:
		return
	_selected_unit.data.consumable = ""
	# Refresh info bar and re-open menu so consumable button updates immediately
	_info_bar.refresh(_selected_unit)
	_action_menu.open_for(_selected_unit, _camera_rig.get_camera())
```

- [ ] **Step 10: Rename `_initiate_attack()` → `_initiate_action()` and use `_pending_ability.energy_cost`**

Replace the old `_initiate_attack()`:

```gdscript
## Kicks off the QTE sequence. Uses _pending_ability.energy_cost for spending.
## Must only be called after _pending_ability is set.
## Stores target in _attack_target so _on_qte_resolved() can access it regardless
## of whether the entry path was self-targeting or player-picked.
func _initiate_action(attacker: Unit3D, target: Unit3D) -> void:
	_attack_target = target        ## always set here — not at call sites
	state = CombatState.QTE_RUNNING
	mode  = PlayerMode.IDLE
	_grid.clear_highlights()
	_action_menu.close()
	_update_status()
	attacker.play_attack_anim(target.global_position)
	await get_tree().create_timer(0.09).timeout
	_qte_bar.start_qte()
```

- [ ] **Step 11: Update `_on_qte_resolved()` — use `_pending_ability.energy_cost`, add null guard**

```gdscript
func _on_qte_resolved(accuracy: float) -> void:
	# Guard: _pending_ability must always be set before the QTE runs
	if not _pending_ability:
		push_error("CombatManager3D: _on_qte_resolved called with no _pending_ability")
		state = CombatState.PLAYER_TURN
		_update_status()
		return

	if _selected_unit and _attack_target:
		var dmg: int = _calculate_damage(
			_selected_unit.data.attack, _attack_target.data.defense, accuracy)
		_selected_unit.spend_energy(_pending_ability.energy_cost)
		_selected_unit.has_acted = true
		_attack_target.take_damage(dmg)
		_camera_rig.trigger_shake()

	_pending_ability = null
	_attack_target   = null

	if state == CombatState.WIN or state == CombatState.LOSE:
		return

	state = CombatState.PLAYER_TURN
	if _selected_unit and _selected_unit.is_alive:
		_select_unit(_selected_unit)    # re-opens menu; abilities will be greyed (has_acted)
		_info_bar.refresh(_selected_unit)
	else:
		_deselect()
	_update_status()
	_check_auto_end_turn()
```

- [ ] **Step 12: Add `_unit_can_still_act()` helper and update auto-end logic**

Add the helper function:

```gdscript
## Returns true if the unit has not yet acted AND can afford at least one slotted ability.
func _unit_can_still_act(unit: Unit3D) -> bool:
	if unit.has_acted:
		return false
	for ability_id in unit.data.abilities:
		if ability_id == "":
			continue
		var ability: AbilityData = AbilityLibrary.get_ability(ability_id)
		if unit.current_energy >= ability.energy_cost:
			return true
	return false
```

Replace `_request_end_player_turn()`:

```gdscript
func _request_end_player_turn() -> void:
	for unit in _player_units:
		if unit.is_alive and _unit_can_still_act(unit):
			_confirm_panel.visible = true
			return
	_end_player_turn()
```

Replace `_check_auto_end_turn()`:

```gdscript
func _check_auto_end_turn() -> void:
	if state != CombatState.PLAYER_TURN:
		return
	for unit in _player_units:
		if unit.is_alive and _unit_can_still_act(unit):
			return
	_end_player_turn()
```

- [ ] **Step 13: Update `_update_status()` — add ABILITY_TARGET_MODE message**

Replace the full function:

```gdscript
func _update_status() -> void:
	if not _status_label:
		return
	match state:
		CombatState.PLAYER_TURN:
			match mode:
				PlayerMode.IDLE:
					_status_label.text = "PLAYER TURN — click a unit  |  double-click = examine  |  Space = end turn"
				PlayerMode.STRIDE_MODE:
					_status_label.text = "STRIDE — click blue cell to move  |  ESC cancel"
				PlayerMode.ABILITY_TARGET_MODE:
					var aname: String = _pending_ability.ability_name if _pending_ability else "Ability"
					_status_label.text = "%s — click a purple target  |  ESC cancel" % aname
		CombatState.QTE_RUNNING:
			_status_label.text = "QTE — press SPACE or click to strike!"
		CombatState.ENEMY_TURN:
			_status_label.text = "ENEMY TURN..."
		CombatState.WIN:
			_status_label.text = "** VICTORY! ** — all enemies defeated"
		CombatState.LOSE:
			_status_label.text = "** DEFEAT... ** — all allies fallen"
```

- [ ] **Step 14: Commit**

```bash
cd "C:\Users\caleb\.local\bin\Projects\RogueFinder\.claude\worktrees\adoring-ritchie"
git add rogue-finder/scripts/combat/CombatManager3D.gd
git commit -m "feat: wire ActionMenu into CombatManager3D, add ABILITY_TARGET_MODE

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 7: Docs & CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`
- Modify: `docs/map_directories/map.md`
- Modify: `docs/map_directories/hud_system.md`
- Modify: `docs/map_directories/combatant_data.md`

- [ ] **Step 1: Add Godot icon rule to `CLAUDE.md`**

In the `## Code Conventions` section, add after the `@export` / `@onready` line:

```markdown
- **Placeholder art:** Use the Godot icon (`load("res://icon.svg")`) as the default for all 2D placeholder artwork (portraits, ability icons, item icons). Replace with real art when assets arrive.
```

- [ ] **Step 2: Update `docs/map_directories/map.md`**

Add three rows to the System Index table:

```markdown
| [Action Menu](#action-menu) | [hud_system.md](hud_system.md) | ✅ Active | Presentation |
| [Ability Data Model](#ability-data-model) | [combatant_data.md](combatant_data.md) | ✅ Active | Data |
| [Ability Library](#ability-library) | [combatant_data.md](combatant_data.md) | ✅ Active | Data |
```

Add to the dependency graph under `CombatManager3D`:

```
  ├── ActionMenu       (radial pop-up; signals ability_selected, consumable_selected)
```

Add to the dependency graph under `Unit3D`:

```
  └── AbilityLibrary   (looked up by ActionMenu and CombatManager3D)
```

Add system summaries at the bottom:

```markdown
### Action Menu
CanvasLayer (layer 12) pop-up shown when a player unit is selected. D-pad layout: 4 ability buttons + 1 consumable center button. Projects the unit's 3D position to screen space. Emits `ability_selected(ability_id)` and `consumable_selected()`. Buttons grey out based on energy and `has_acted` state.

### Ability Data Model
`AbilityData` (Resource) stores all fields for a single ability: ID, name, tags, energy cost, range, target type, description, icon. `TargetType` enum: `SELF`, `SINGLE_ENEMY`, `SINGLE_ALLY`, `AOE`, `CONE`.

### Ability Library
`AbilityLibrary` (static class) defines 12 placeholder abilities and provides `get_ability(id) -> AbilityData`. Returns a safe stub for unknown IDs. Future CSV import will replace the inline dictionary without changing the API.
```

Update `map.md` last-updated header to: `Last updated: 2026-04-14 (Session 3 — ActionMenu, AbilityData, AbilityLibrary added)`

- [ ] **Step 3: Update `docs/map_directories/hud_system.md`**

Add a new section after StatPanel:

```markdown
## ActionMenu

**Layer 12.** Shown when a player unit is selected. Closed on deselect, ESC, or when an action is chosen.

D-pad layout: 4 ability buttons (top / right / bottom / left, 80×80 px each) surrounding a slightly smaller consumable button (64×64 px, center). Positioned at the selected unit's projected screen coordinates.

Buttons are greyed out and disabled when:
- Ability slot is empty (`""`)
- `unit.has_acted == true`
- `unit.current_energy < ability.energy_cost`
- `unit.data.consumable == ""`  (consumable button only)

Hover shows a tooltip with ability name, tags, energy cost, and description.

### Public API

| Method | Signature | Purpose |
|--------|-----------|---------|
| `open_for` | `(unit: Unit3D, camera: Camera3D) -> void` | Populate, position, and show |
| `close` | `() -> void` | Hide the menu |

### Signals

| Signal | Args | Fired when |
|--------|------|-----------|
| `ability_selected` | `ability_id: String` | Player clicks an ability button |
| `consumable_selected` | — | Player clicks the consumable button |
```

Update last-updated header: `Last updated: 2026-04-14 (Session 3 — ActionMenu added)`

- [ ] **Step 4: Update `docs/map_directories/combatant_data.md`**

Replace the `### Ability Pool` row in the Fields table:

```markdown
### Ability Pool
`abilities: Array[String]` — exactly 4 slots. Stores **ability IDs** (e.g. `"strike"`, `"heavy_strike"`). Fixed per archetype. Empty string = unfilled slot. Looked up via `AbilityLibrary.get_ability()` at runtime.
```

Replace the `### Equipment Slots` note:

```markdown
### Equipment Slots (placeholder strings — item system TBD)
`weapon`, `armor`, `accessory` — currently empty strings.
`consumable` — display name of the equipped consumable item (e.g. `"Healing Potion"`). Set to `""` when used in combat. `"" ` = no consumable available.
```

Add a new top-level section at the bottom of the file:

```markdown
---

## AbilityData

`resources/AbilityData.gd` — Resource subclass. One instance per ability. Created by `AbilityLibrary.get_ability()`.

### Fields

| Field | Type | Notes |
|-------|------|-------|
| `ability_id` | `String` | Snake_case key, e.g. `"heavy_strike"` |
| `ability_name` | `String` | Display name |
| `tags` | `Array[String]` | e.g. `["Melee"]`, `["Magic", "Ranged"]` |
| `energy_cost` | `int` | Subtracted from unit energy on use |
| `range` | `int` | Max tile distance to a valid target |
| `target_type` | `int` | `AbilityData.TargetType` enum (see below) |
| `description` | `String` | Flavor + mechanical tooltip text |
| `ability_icon` | `Texture2D` | Defaults to Godot icon (placeholder) |

### TargetType Enum

| Value | Int | Behavior |
|-------|-----|---------|
| `SELF` | 0 | Auto-targets the caster; no target pick step |
| `SINGLE_ENEMY` | 1 | Player picks one living enemy within range |
| `SINGLE_ALLY` | 2 | Player picks one living ally within range |
| `AOE` | 3 | Placeholder — uses enemy cells for now |
| `CONE` | 4 | Placeholder — uses enemy cells for now |

---

## AbilityLibrary

`scripts/globals/AbilityLibrary.gd` — static class, mirrors `ArchetypeLibrary`.

### Defined Abilities (12 placeholders)

| ID | Name | Tags | Cost | Range | Target |
|----|------|------|------|-------|--------|
| `strike` | Strike | Melee | 2 | 1 | SingleEnemy |
| `heavy_strike` | Heavy Strike | Melee | 4 | 1 | SingleEnemy |
| `quick_shot` | Quick Shot | Ranged | 2 | 4 | SingleEnemy |
| `disengage` | Disengage | Utility | 2 | 1 | Self |
| `acid_splash` | Acid Splash | Magic, Ranged | 3 | 3 | SingleEnemy |
| `smoke_bomb` | Smoke Bomb | Utility | 2 | 2 | AOE |
| `healing_draught` | Healing Draught | Utility | 3 | 1 | Self |
| `shield_bash` | Shield Bash | Melee | 3 | 1 | SingleEnemy |
| `counter` | Counter | Melee | 2 | 1 | Self |
| `taunt` | Taunt | Utility | 1 | 3 | SingleEnemy |
| `inspire` | Inspire | Utility | 3 | 3 | SingleAlly |
| `guard` | Guard | Utility | 2 | 1 | Self |

### Public API

```gdscript
## Returns a populated AbilityData. Never returns null — falls back to a stub for unknown IDs.
static func get_ability(ability_id: String) -> AbilityData
```

### Notes
- A future CSV import will replace the `ABILITIES` dictionary without changing the `get_ability()` signature.
- Every non-empty string in `CombatantData.abilities` must be a valid key in `AbilityLibrary.ABILITIES`.
```

Update last-updated header: `Last updated: 2026-04-14 (Session 3 — AbilityData, AbilityLibrary added; ability IDs replace name strings)`

- [ ] **Step 5: Commit docs and CLAUDE.md**

```bash
cd "C:\Users\caleb\.local\bin\Projects\RogueFinder\.claude\worktrees\adoring-ritchie"
git add CLAUDE.md docs/map_directories/map.md docs/map_directories/hud_system.md docs/map_directories/combatant_data.md
git commit -m "docs: update map and CLAUDE.md for combat actions feature

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Playtest Checklist (after Task 6)

Open Godot from the worktree folder and verify:

- [ ] Clicking a player unit opens the radial menu (4 ability buttons + center consumable)
- [ ] Stride highlights (blue) still appear simultaneously with the menu
- [ ] Clicking a blue cell moves the unit; menu remains open
- [ ] Ability buttons show name + energy cost; grey out when `has_acted = true` or insufficient energy
- [ ] Hovering an ability button shows tooltip (name, tags, cost, description)
- [ ] Clicking an ability (e.g. Strike) closes the menu, highlights valid targets purple
- [ ] Clicking a purple cell runs the QTE → damage → camera shake
- [ ] After QTE resolves, menu re-opens with ability greyed (has_acted); stride available if not yet moved
- [ ] Self-targeting ability (e.g. Disengage, Guard, Counter, Healing Draught) skips targeting and goes straight to QTE
- [ ] RogueFinder and Alchemist show a consumable in the center button; others show "—" (greyed)
- [ ] Clicking the consumable button clears it (button greys out immediately)
- [ ] ESC closes menu and deselects
- [ ] Double-click still opens StatPanel
- [ ] Enemy turn still works (AI attacks as before)
- [ ] "Redo (Reroll)" button still rerolls all units
