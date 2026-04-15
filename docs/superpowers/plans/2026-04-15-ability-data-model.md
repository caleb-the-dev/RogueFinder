# Ability Data Model Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the placeholder `AbilityData` model with a fully-typed system supporting multiple effects per ability, separated targeting shape/filter enums, and an attribute link — enabling real ability resolution in combat.

**Architecture:** New `EffectData` sub-resource holds one effect (HARM/MEND/FORCE/TRAVEL/BUFF/DEBUFF). `AbilityData` holds `Array[EffectData]` plus new `TargetShape`, `ApplicableTo`, and `Attribute` enums. `AbilityLibrary` authors all 12 abilities with full effect data in nested dicts; `get_ability()` builds `EffectData` instances at load time. `CombatManager3D` is updated to read the new enums and loop through effects on QTE resolution.

**Tech Stack:** Godot 4, GDScript, typed Resources, plain `assert()` tests via `extends SceneTree`.

> **Test runner:** From the repo root, run tests with:
> `godot --headless --path rogue-finder --script tests/<test_file>.gd`
> Godot must be on PATH. All test files extend SceneTree and call `quit()` at the end.

---

### Task 1: Create EffectData resource

**Files:**
- Create: `rogue-finder/resources/EffectData.gd`
- Create: `rogue-finder/tests/test_effect_data.gd`

- [ ] **Step 1: Write the failing test**

Create `rogue-finder/tests/test_effect_data.gd`:

```gdscript
extends SceneTree

func _initialize() -> void:
	_test_defaults()
	_test_enum_values()
	print("All EffectData tests PASSED.")
	quit()

func _test_defaults() -> void:
	var e := EffectData.new()
	assert(e.effect_type == EffectData.EffectType.HARM,
		"default effect_type should be HARM")
	assert(e.base_value == 0,
		"default base_value should be 0")
	assert(e.target_pool == EffectData.PoolType.HP,
		"default target_pool should be HP")
	assert(e.target_stat == 0,
		"default target_stat should be 0")
	assert(e.movement_type == EffectData.MoveType.FREE,
		"default movement_type should be FREE")

func _test_enum_values() -> void:
	# Verify all expected enum variants exist
	assert(EffectData.EffectType.HARM   == 0, "HARM should be 0")
	assert(EffectData.EffectType.MEND   == 1, "MEND should be 1")
	assert(EffectData.EffectType.FORCE  == 2, "FORCE should be 2")
	assert(EffectData.EffectType.TRAVEL == 3, "TRAVEL should be 3")
	assert(EffectData.EffectType.BUFF   == 4, "BUFF should be 4")
	assert(EffectData.EffectType.DEBUFF == 5, "DEBUFF should be 5")
	assert(EffectData.PoolType.HP     == 0, "HP should be 0")
	assert(EffectData.PoolType.ENERGY == 1, "ENERGY should be 1")
	assert(EffectData.MoveType.FREE == 0, "FREE should be 0")
	assert(EffectData.MoveType.LINE == 1, "LINE should be 1")
```

- [ ] **Step 2: Run test to verify it fails**

```
godot --headless --path rogue-finder --script tests/test_effect_data.gd
```

Expected: error — `EffectData` class not found.

- [ ] **Step 3: Create EffectData.gd**

Create `rogue-finder/resources/EffectData.gd`:

```gdscript
class_name EffectData
extends Resource

## --- EffectData ---
## Typed record for a single effect within an ability.
## An ability carries Array[EffectData]; each entry is resolved in order
## using the same QTE accuracy float from the first effect's check.

enum EffectType { HARM = 0, MEND = 1, FORCE = 2, TRAVEL = 3, BUFF = 4, DEBUFF = 5 }
enum PoolType   { HP = 0, ENERGY = 1 }   ## HARM / MEND: which pool to modify
enum MoveType   { FREE = 0, LINE = 1 }   ## TRAVEL: free repositioning or straight-line only

@export var effect_type:   EffectType = EffectType.HARM
@export var base_value:    int        = 0
## HARM / MEND only — which pool this effect modifies
@export var target_pool:   PoolType   = PoolType.HP
## BUFF / DEBUFF only — stores an AbilityData.Attribute int value (avoids circular ref)
@export var target_stat:   int        = 0
## TRAVEL only
@export var movement_type: MoveType   = MoveType.FREE
```

- [ ] **Step 4: Run test to verify it passes**

```
godot --headless --path rogue-finder --script tests/test_effect_data.gd
```

Expected: `All EffectData tests PASSED.`

- [ ] **Step 5: Commit**

```bash
git add rogue-finder/resources/EffectData.gd rogue-finder/tests/test_effect_data.gd
git commit -m "feat: add EffectData resource with typed effect/pool/move enums"
```

---

### Task 2: Rewrite AbilityData with new enums and fields

**Files:**
- Modify: `rogue-finder/resources/AbilityData.gd` (full rewrite)
- Modify: `rogue-finder/tests/test_ability_library.gd` (update broken enum refs)

- [ ] **Step 1: Update the test file first (write failing assertions)**

Replace the entire contents of `rogue-finder/tests/test_ability_library.gd`:

```gdscript
extends SceneTree

func _initialize() -> void:
	_test_ability_data_defaults()
	_test_known_ability()
	_test_unknown_ability_stub()
	_test_all_archetype_abilities_resolve()
	_test_archetype_library_updates()
	_test_multi_effect_ability()
	_test_applicable_to()
	print("All AbilityLibrary tests PASSED.")
	quit()

func _test_ability_data_defaults() -> void:
	var ability := AbilityData.new()
	assert(ability.ability_id == "", "default ability_id should be empty")
	assert(ability.energy_cost == 0, "default energy_cost should be 0")
	assert(ability.tile_range == 1, "default range should be 1")
	assert(ability.target_shape == AbilityData.TargetShape.SINGLE,
		"default target_shape should be SINGLE")
	assert(ability.applicable_to == AbilityData.ApplicableTo.ENEMY,
		"default applicable_to should be ENEMY")
	assert(ability.attribute == AbilityData.Attribute.NONE,
		"default attribute should be NONE")
	assert(ability.effects.is_empty(), "default effects should be empty")
	assert(ability.passthrough == false, "default passthrough should be false")

func _test_known_ability() -> void:
	var a: AbilityData = AbilityLibrary.get_ability("strike")
	assert(a != null, "strike should not be null")
	assert(a.ability_id == "strike", "ID mismatch: " + a.ability_id)
	assert(a.ability_name == "Strike", "name mismatch: " + a.ability_name)
	assert(a.energy_cost == 2, "strike energy_cost should be 2, got " + str(a.energy_cost))
	assert(a.tile_range == 1, "strike range should be 1")
	assert(a.target_shape == AbilityData.TargetShape.SINGLE,
		"strike target_shape should be SINGLE")
	assert(a.applicable_to == AbilityData.ApplicableTo.ENEMY,
		"strike applicable_to should be ENEMY")
	assert(a.attribute == AbilityData.Attribute.STRENGTH,
		"strike attribute should be STRENGTH")
	assert(a.description != "", "description should not be empty")
	assert(a.effects.size() == 1, "strike should have 1 effect, got " + str(a.effects.size()))
	assert(a.effects[0].effect_type == EffectData.EffectType.HARM,
		"strike effect[0] should be HARM")
	assert(a.effects[0].base_value == 5,
		"strike HARM base_value should be 5, got " + str(a.effects[0].base_value))

	var b: AbilityData = AbilityLibrary.get_ability("taunt")
	assert(b.energy_cost == 1, "taunt energy_cost should be 1")
	assert(b.tile_range == 3, "taunt range should be 3")

	var c: AbilityData = AbilityLibrary.get_ability("healing_draught")
	assert(c.target_shape == AbilityData.TargetShape.SELF,
		"healing_draught target_shape should be SELF")

func _test_unknown_ability_stub() -> void:
	var stub: AbilityData = AbilityLibrary.get_ability("nonexistent_xyz")
	assert(stub != null, "unknown ID should return stub, not null")
	assert(stub.ability_id == "unknown", "stub id should be 'unknown', got: " + stub.ability_id)
	assert(stub.energy_cost == 0, "stub energy_cost should be 0")

func _test_all_archetype_abilities_resolve() -> void:
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
		assert(a.effects.size() > 0,
			"every ability must have at least one effect, missing for: " + id)

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

func _test_multi_effect_ability() -> void:
	var a: AbilityData = AbilityLibrary.get_ability("acid_splash")
	assert(a.effects.size() == 2,
		"acid_splash should have 2 effects, got " + str(a.effects.size()))
	assert(a.effects[0].effect_type == EffectData.EffectType.HARM,
		"acid_splash effect[0] should be HARM")
	assert(a.effects[0].base_value == 3,
		"acid_splash HARM base_value should be 3, got " + str(a.effects[0].base_value))
	assert(a.effects[1].effect_type == EffectData.EffectType.DEBUFF,
		"acid_splash effect[1] should be DEBUFF")
	assert(a.effects[1].base_value == 1,
		"acid_splash DEBUFF base_value should be 1, got " + str(a.effects[1].base_value))
	assert(a.effects[1].target_stat == AbilityData.Attribute.DEXTERITY,
		"acid_splash DEBUFF should target DEXTERITY, got " + str(a.effects[1].target_stat))

func _test_applicable_to() -> void:
	var inspire: AbilityData = AbilityLibrary.get_ability("inspire")
	assert(inspire.applicable_to == AbilityData.ApplicableTo.ALLY,
		"inspire applicable_to should be ALLY")
	assert(inspire.target_shape == AbilityData.TargetShape.SINGLE,
		"inspire target_shape should be SINGLE")

	var smoke: AbilityData = AbilityLibrary.get_ability("smoke_bomb")
	assert(smoke.target_shape == AbilityData.TargetShape.RADIAL,
		"smoke_bomb target_shape should be RADIAL")
```

- [ ] **Step 2: Run tests to verify they fail**

```
godot --headless --path rogue-finder --script tests/test_ability_library.gd
```

Expected: errors — `TargetShape`, `ApplicableTo`, `Attribute` not found on `AbilityData`.

- [ ] **Step 3: Rewrite AbilityData.gd**

Overwrite `rogue-finder/resources/AbilityData.gd` entirely:

```gdscript
class_name AbilityData
extends Resource

## --- AbilityData ---
## Typed data record for a single ability.
## Instances are created by AbilityLibrary.get_ability() — never set fields directly.

## ======================================================
## Attribute enum — which stat this ability scales with.
## Also used by EffectData.target_stat (stored as int) for BUFF/DEBUFF targets.
## ======================================================
enum Attribute {
	STRENGTH  = 0,
	DEXTERITY = 1,
	COGNITION = 2,
	VITALITY  = 3,
	WILLPOWER = 4,
	NONE      = 5,
}

## ======================================================
## TargetShape enum — the geometry of the targeting area.
## Separated from ApplicableTo so shape and filter are independent.
## ======================================================
enum TargetShape {
	SELF   = 0,  ## auto-targets the caster; no highlight step
	SINGLE = 1,  ## player picks one valid unit within range
	CONE   = 2,  ## T-shape: 1 cell adjacent to caster + 3 cells forming the top of the T
	LINE   = 3,  ## straight line extending from the caster in a chosen direction
	RADIAL = 4,  ## diamond AoE — 5 wide × 5 tall
}

## ======================================================
## ApplicableTo enum — which units the ability can affect.
## Irrelevant when target_shape is SELF (always affects caster).
## ======================================================
enum ApplicableTo {
	ALLY  = 0,  ## allied units only
	ENEMY = 1,  ## enemy units only
	ANY   = 2,  ## all units
}

## ======================================================
## --- Fields ---
## ======================================================

@export var ability_id:    String       = ""
@export var ability_name:  String       = ""
@export var attribute:     Attribute    = Attribute.NONE
@export var target_shape:  TargetShape  = TargetShape.SINGLE
@export var applicable_to: ApplicableTo = ApplicableTo.ENEMY
## 0–10 tiles; -1 = whole map
@export var tile_range:    int          = 1
## Only meaningful for LINE, CONE, RADIAL — effect continues past first collision if true
@export var passthrough:   bool         = false
@export var energy_cost:   int          = 0
@export var effects:       Array[EffectData] = []
@export var description:   String       = ""
## Placeholder icon — replaced with real art when assets arrive
@export var ability_icon:  Texture2D    = null
```

- [ ] **Step 4: Run tests to verify they fail only on AbilityLibrary data (not AbilityData fields)**

```
godot --headless --path rogue-finder --script tests/test_ability_library.gd
```

Expected: test failures on `effects.size()`, `target_shape`, `attribute` — the new fields on AbilityData are found, but AbilityLibrary hasn't been updated yet.

- [ ] **Step 5: Commit**

```bash
git add rogue-finder/resources/AbilityData.gd rogue-finder/tests/test_ability_library.gd
git commit -m "feat: rewrite AbilityData with TargetShape, ApplicableTo, Attribute enums and effects array"
```

---

### Task 3: Rewrite AbilityLibrary with full effect data

**Files:**
- Modify: `rogue-finder/scripts/globals/AbilityLibrary.gd` (full rewrite)

- [ ] **Step 1: Rewrite AbilityLibrary.gd**

Overwrite `rogue-finder/scripts/globals/AbilityLibrary.gd` entirely:

```gdscript
class_name AbilityLibrary
extends RefCounted

## --- AbilityLibrary ---
## Static definitions for all abilities in the game.
## Each entry has full effect data. A future CSV import will replace ABILITIES
## without changing the get_ability() signature.
##
## Adding an ability: add one entry to ABILITIES; nothing else changes.

## --- Schema ---
## "name"         : String
## "attribute"    : AbilityData.Attribute
## "target"       : AbilityData.TargetShape
## "applicable_to": AbilityData.ApplicableTo
## "range"        : int  (-1 = whole map)
## "passthrough"  : bool (optional, default false)
## "cost"         : int
## "description"  : String
## "effects"      : Array[Dictionary]
##   Each effect dict keys:
##     "type"       : EffectData.EffectType  (required)
##     "base_value" : int                    (required)
##     "pool"       : EffectData.PoolType    (HARM / MEND only)
##     "stat"       : AbilityData.Attribute  (BUFF / DEBUFF only)
##     "move"       : EffectData.MoveType    (TRAVEL only)

const ABILITIES: Dictionary = {
	"strike": {
		"name":          "Strike",
		"attribute":     AbilityData.Attribute.STRENGTH,
		"target":        AbilityData.TargetShape.SINGLE,
		"applicable_to": AbilityData.ApplicableTo.ENEMY,
		"range":         1,
		"cost":          2,
		"description":   "Step into range and put your weight behind the blow — deal damage to one adjacent enemy.",
		"effects": [
			{ "type": EffectData.EffectType.HARM, "base_value": 5, "pool": EffectData.PoolType.HP },
		],
	},
	"heavy_strike": {
		"name":          "Heavy Strike",
		"attribute":     AbilityData.Attribute.STRENGTH,
		"target":        AbilityData.TargetShape.SINGLE,
		"applicable_to": AbilityData.ApplicableTo.ENEMY,
		"range":         1,
		"cost":          4,
		"description":   "Wind up and swing with everything you have — hit one adjacent enemy for serious damage.",
		"effects": [
			{ "type": EffectData.EffectType.HARM, "base_value": 9, "pool": EffectData.PoolType.HP },
		],
	},
	"quick_shot": {
		"name":          "Quick Shot",
		"attribute":     AbilityData.Attribute.DEXTERITY,
		"target":        AbilityData.TargetShape.SINGLE,
		"applicable_to": AbilityData.ApplicableTo.ENEMY,
		"range":         4,
		"cost":          2,
		"description":   "Draw and loose before the moment passes — deal damage to one enemy within 4 tiles.",
		"effects": [
			{ "type": EffectData.EffectType.HARM, "base_value": 4, "pool": EffectData.PoolType.HP },
		],
	},
	"disengage": {
		"name":          "Disengage",
		"attribute":     AbilityData.Attribute.DEXTERITY,
		"target":        AbilityData.TargetShape.SELF,
		"applicable_to": AbilityData.ApplicableTo.ANY,
		"range":         1,
		"cost":          2,
		"description":   "Step back with practiced care — reposition 1 tile without triggering opportunity attacks.",
		"effects": [
			{ "type": EffectData.EffectType.TRAVEL, "base_value": 1, "move": EffectData.MoveType.FREE },
		],
	},
	"acid_splash": {
		"name":          "Acid Splash",
		"attribute":     AbilityData.Attribute.COGNITION,
		"target":        AbilityData.TargetShape.SINGLE,
		"applicable_to": AbilityData.ApplicableTo.ENEMY,
		"range":         3,
		"cost":          3,
		"description":   "Hurl a flask of sizzling reagent — damages on contact and eats through the target's dexterity.",
		"effects": [
			{ "type": EffectData.EffectType.HARM,   "base_value": 3, "pool": EffectData.PoolType.HP },
			{ "type": EffectData.EffectType.DEBUFF, "base_value": 1, "stat": AbilityData.Attribute.DEXTERITY },
		],
	},
	"smoke_bomb": {
		"name":          "Smoke Bomb",
		"attribute":     AbilityData.Attribute.COGNITION,
		"target":        AbilityData.TargetShape.RADIAL,
		"applicable_to": AbilityData.ApplicableTo.ANY,
		"range":         2,
		"cost":          2,
		"description":   "Shatter a smoke-filled vial — all units in the blast radius lose footing and dexterity.",
		"effects": [
			{ "type": EffectData.EffectType.DEBUFF, "base_value": 1, "stat": AbilityData.Attribute.DEXTERITY },
		],
	},
	"healing_draught": {
		"name":          "Healing Draught",
		"attribute":     AbilityData.Attribute.VITALITY,
		"target":        AbilityData.TargetShape.SELF,
		"applicable_to": AbilityData.ApplicableTo.ANY,
		"range":         0,
		"cost":          3,
		"description":   "Uncork a bitter medicinal brew and down it — restore a measure of your own health.",
		"effects": [
			{ "type": EffectData.EffectType.MEND, "base_value": 5, "pool": EffectData.PoolType.HP },
		],
	},
	"shield_bash": {
		"name":          "Shield Bash",
		"attribute":     AbilityData.Attribute.STRENGTH,
		"target":        AbilityData.TargetShape.SINGLE,
		"applicable_to": AbilityData.ApplicableTo.ENEMY,
		"range":         1,
		"cost":          3,
		"description":   "Lead with the rim of your shield — deal damage and disrupt the target's offensive strength.",
		"effects": [
			{ "type": EffectData.EffectType.HARM,   "base_value": 3, "pool": EffectData.PoolType.HP },
			{ "type": EffectData.EffectType.DEBUFF, "base_value": 1, "stat": AbilityData.Attribute.STRENGTH },
		],
	},
	"counter": {
		"name":          "Counter",
		"attribute":     AbilityData.Attribute.WILLPOWER,
		"target":        AbilityData.TargetShape.SELF,
		"applicable_to": AbilityData.ApplicableTo.ANY,
		"range":         0,
		"cost":          2,
		"description":   "Plant your feet and channel your resolve — temporarily sharpen your offensive strength.",
		"effects": [
			{ "type": EffectData.EffectType.BUFF, "base_value": 2, "stat": AbilityData.Attribute.STRENGTH },
		],
	},
	"taunt": {
		"name":          "Taunt",
		"attribute":     AbilityData.Attribute.WILLPOWER,
		"target":        AbilityData.TargetShape.SINGLE,
		"applicable_to": AbilityData.ApplicableTo.ENEMY,
		"range":         3,
		"cost":          1,
		"description":   "Bark choice insults at a nearby enemy — sap their resolve and force their attention onto you.",
		"effects": [
			{ "type": EffectData.EffectType.DEBUFF, "base_value": 1, "stat": AbilityData.Attribute.WILLPOWER },
		],
	},
	"inspire": {
		"name":          "Inspire",
		"attribute":     AbilityData.Attribute.WILLPOWER,
		"target":        AbilityData.TargetShape.SINGLE,
		"applicable_to": AbilityData.ApplicableTo.ALLY,
		"range":         3,
		"cost":          3,
		"description":   "Shout a rallying cry — bolster one ally's strength for the fight ahead.",
		"effects": [
			{ "type": EffectData.EffectType.BUFF, "base_value": 1, "stat": AbilityData.Attribute.STRENGTH },
		],
	},
	"guard": {
		"name":          "Guard",
		"attribute":     AbilityData.Attribute.VITALITY,
		"target":        AbilityData.TargetShape.SELF,
		"applicable_to": AbilityData.ApplicableTo.ANY,
		"range":         0,
		"cost":          2,
		"description":   "Adopt a defensive stance — bolster your vitality to weather incoming blows.",
		"effects": [
			{ "type": EffectData.EffectType.BUFF, "base_value": 2, "stat": AbilityData.Attribute.VITALITY },
		],
	},
}

## Cached Godot icon — loaded once on first ability lookup.
static var _icon: Texture2D = null

static func _get_icon() -> Texture2D:
	if _icon == null:
		_icon = load("res://icon.svg")
	return _icon

## Returns a populated AbilityData for the given ID.
## Falls back to a blank stub if the ID is unknown — never returns null.
static func get_ability(ability_id: String) -> AbilityData:
	var godot_icon: Texture2D = _get_icon()
	if not ABILITIES.has(ability_id):
		var stub := AbilityData.new()
		stub.ability_id   = "unknown"
		stub.ability_name = "Unknown"
		stub.description  = "No ability data found for ID: " + ability_id
		stub.ability_icon = godot_icon
		return stub

	var def: Dictionary = ABILITIES[ability_id]
	var a := AbilityData.new()
	a.ability_id    = ability_id
	a.ability_name  = def["name"]
	a.attribute     = def["attribute"]
	a.target_shape  = def["target"]
	a.applicable_to = def["applicable_to"]
	a.tile_range    = def["range"]
	a.passthrough   = def.get("passthrough", false)
	a.energy_cost   = def["cost"]
	a.description   = def["description"]
	a.ability_icon  = godot_icon

	## Build EffectData instances from nested dicts
	for effect_def: Dictionary in def["effects"]:
		var e := EffectData.new()
		e.effect_type = effect_def["type"]
		e.base_value  = effect_def.get("base_value", 0)
		if effect_def.has("pool"):
			e.target_pool = effect_def["pool"]
		if effect_def.has("stat"):
			e.target_stat = effect_def["stat"]
		if effect_def.has("move"):
			e.movement_type = effect_def["move"]
		a.effects.append(e)

	return a
```

- [ ] **Step 2: Run tests to verify they pass**

```
godot --headless --path rogue-finder --script tests/test_ability_library.gd
```

Expected: `All AbilityLibrary tests PASSED.`

- [ ] **Step 3: Also run EffectData tests to verify no regressions**

```
godot --headless --path rogue-finder --script tests/test_effect_data.gd
```

Expected: `All EffectData tests PASSED.`

- [ ] **Step 4: Commit**

```bash
git add rogue-finder/scripts/globals/AbilityLibrary.gd
git commit -m "feat: rewrite AbilityLibrary with full effect data for all 12 abilities"
```

---

### Task 4: Update Unit3D and CombatManager3D to use new model

**Files:**
- Modify: `rogue-finder/scripts/combat/Unit3D.gd` (add `heal()`)
- Modify: `rogue-finder/scripts/combat/CombatManager3D.gd` (new enum refs + effect resolution)

> Note: These changes touch scene-dependent code and cannot be unit tested. Functional verification is done by opening the project in Godot and playing a combat encounter.

- [ ] **Step 1: Add `heal()` to Unit3D**

In `rogue-finder/scripts/combat/Unit3D.gd`, add this method directly after `take_damage()` (after line 106):

```gdscript
func heal(amount: int) -> void:
	current_hp = mini(current_hp + amount, data.hp_max)
	_refresh_visuals()
```

- [ ] **Step 2: Update `_on_ability_selected` in CombatManager3D**

In `rogue-finder/scripts/combat/CombatManager3D.gd`, replace `_on_ability_selected` (lines 311–348) with:

```gdscript
## Called when the player picks an ability from the ActionMenu.
func _on_ability_selected(ability_id: String) -> void:
	if not _selected_unit:
		return
	_pending_ability = AbilityLibrary.get_ability(ability_id)

	# SELF-targeting abilities skip the target-pick step and go straight to QTE
	if _pending_ability.target_shape == AbilityData.TargetShape.SELF:
		_initiate_action(_selected_unit, _selected_unit)
		return

	# Collect valid targets based on applicable_to
	var targets: Array[Unit3D] = []
	match _pending_ability.applicable_to:
		AbilityData.ApplicableTo.ALLY:
			for pu in _player_units:
				if pu.is_alive:
					targets.append(pu)
		AbilityData.ApplicableTo.ENEMY:
			for eu in _enemy_units:
				if eu.is_alive:
					targets.append(eu)
		AbilityData.ApplicableTo.ANY:
			for pu in _player_units:
				if pu.is_alive:
					targets.append(pu)
			for eu in _enemy_units:
				if eu.is_alive:
					targets.append(eu)

	if targets.is_empty():
		_pending_ability = null
		return

	# Highlight valid target cells in purple (ability_target)
	# AoE shapes (CONE, LINE, RADIAL) still use single-target pick as a placeholder
	# until per-shape resolution is implemented.
	mode = PlayerMode.ABILITY_TARGET_MODE
	_grid.clear_highlights()
	_grid.set_highlight(_selected_unit.grid_pos, "selected")
	for target in targets:
		var dx: int = abs(target.grid_pos.x - _selected_unit.grid_pos.x)
		var dy: int = abs(target.grid_pos.y - _selected_unit.grid_pos.y)
		var dist: int = dx + dy
		var in_range: bool = (_pending_ability.tile_range == -1) or (dist <= _pending_ability.tile_range)
		if in_range:
			_grid.set_highlight(target.grid_pos, "ability_target")
	_update_status()
```

- [ ] **Step 3: Replace `_on_qte_resolved` and add effect helpers**

In `rogue-finder/scripts/combat/CombatManager3D.gd`, replace `_on_qte_resolved` (lines 391–420) with the following four functions. Place them in the same region of the file. Leave `_calculate_damage` in place for now — it is still called by the enemy turn; Step 4 removes that call, after which the method becomes unused and can be left or deleted.

```gdscript
func _on_qte_resolved(accuracy: float) -> void:
	if not _pending_ability:
		push_error("CombatManager3D: _on_qte_resolved called with no _pending_ability")
		state = CombatState.PLAYER_TURN
		_update_status()
		return

	if _selected_unit and _attack_target:
		_selected_unit.spend_energy(_pending_ability.energy_cost)
		_selected_unit.has_acted = true
		_apply_effects(_pending_ability, _selected_unit, _attack_target, accuracy)
		_camera_rig.trigger_shake()

	_pending_ability = null
	_attack_target   = null

	if state == CombatState.WIN or state == CombatState.LOSE:
		return

	state = CombatState.PLAYER_TURN
	if _selected_unit and _selected_unit.is_alive:
		_select_unit(_selected_unit)
		_info_bar.refresh(_selected_unit)
	else:
		_deselect()
	_update_status()
	_check_auto_end_turn()

## Resolves every effect in ability.effects against target using the shared accuracy float.
## accuracy comes from the QTE result (0.0–1.0); all effects share the same roll.
func _apply_effects(ability: AbilityData, caster: Unit3D, target: Unit3D, accuracy: float) -> void:
	var attr_val: int = _get_attribute_value(caster, ability.attribute)
	for effect: EffectData in ability.effects:
		match effect.effect_type:
			EffectData.EffectType.HARM:
				var dmg: int = maxi(1, roundi(accuracy * float(effect.base_value + attr_val)))
				target.take_damage(dmg)
			EffectData.EffectType.MEND:
				var heal: int = maxi(1, roundi(accuracy * float(effect.base_value + attr_val)))
				target.heal(heal)
			EffectData.EffectType.BUFF:
				# accuracy < 0.3 = whiff; flat value otherwise
				if accuracy >= 0.3:
					_apply_stat_delta(target, effect.target_stat, effect.base_value)
			EffectData.EffectType.DEBUFF:
				if accuracy >= 0.3:
					_apply_stat_delta(target, effect.target_stat, -effect.base_value)
			EffectData.EffectType.FORCE:
				# TODO: push target N tiles; deal collision damage
				pass
			EffectData.EffectType.TRAVEL:
				# TODO: move caster to a valid destination tile
				pass

## Returns the raw attribute int value from a unit's CombatantData.
func _get_attribute_value(unit: Unit3D, attribute: AbilityData.Attribute) -> int:
	match attribute:
		AbilityData.Attribute.STRENGTH:  return unit.data.strength
		AbilityData.Attribute.DEXTERITY: return unit.data.dexterity
		AbilityData.Attribute.COGNITION: return unit.data.cognition
		AbilityData.Attribute.VITALITY:  return unit.data.vitality
		AbilityData.Attribute.WILLPOWER: return unit.data.willpower
		_: return 0

## Applies a +/- delta to one of a unit's core attributes.
## Clamped to [0, 5] — the defined range for all attributes.
## NOTE: stat changes are not currently reset at combat end; that is a future task.
func _apply_stat_delta(unit: Unit3D, stat: int, delta: int) -> void:
	match stat:
		AbilityData.Attribute.STRENGTH:
			unit.data.strength  = clampi(unit.data.strength  + delta, 0, 5)
		AbilityData.Attribute.DEXTERITY:
			unit.data.dexterity = clampi(unit.data.dexterity + delta, 0, 5)
		AbilityData.Attribute.COGNITION:
			unit.data.cognition = clampi(unit.data.cognition + delta, 0, 5)
		AbilityData.Attribute.VITALITY:
			unit.data.vitality  = clampi(unit.data.vitality  + delta, 0, 5)
		AbilityData.Attribute.WILLPOWER:
			unit.data.willpower = clampi(unit.data.willpower + delta, 0, 5)
```

- [ ] **Step 4: Update the enemy turn to use `_apply_effects`**

In `_process_enemy_actions` (around line 486), replace the direct `_calculate_damage` call:

Old code to find and replace:
```gdscript
		var dmg: int = _calculate_damage(
			enemy.data.attack, target.data.defense, enemy.data.qte_resolution)
```

New code:
```gdscript
		## Enemy uses its first ability (index 0) for the attack, falling back to "strike"
		var enemy_ability_id: String = enemy.data.abilities[0] if enemy.data.abilities[0] != "" else "strike"
		var enemy_ability: AbilityData = AbilityLibrary.get_ability(enemy_ability_id)
		## Enemy accuracy simulated by qte_resolution stat
		var accuracy: float = enemy.data.qte_resolution
```

Then replace the `target.take_damage(dmg)` call (a few lines later) with:
```gdscript
		_apply_effects(enemy_ability, enemy, target, accuracy)
```

- [ ] **Step 5: Commit**

```bash
git add rogue-finder/scripts/combat/Unit3D.gd rogue-finder/scripts/combat/CombatManager3D.gd
git commit -m "feat: wire CombatManager3D to EffectData array; add Unit3D.heal()"
```

---

### Task 5: Update documentation

**Files:**
- Modify: `docs/map_directories/combatant_data.md`

- [ ] **Step 1: Replace the AbilityData section in combatant_data.md**

In `docs/map_directories/combatant_data.md`, find the `## AbilityData` section (starting at line 144) and replace everything from `## AbilityData` to end of file with:

```markdown
## AbilityData

`resources/AbilityData.gd` — Resource subclass. One instance per ability. Created by `AbilityLibrary.get_ability()`.

### Enums

**Attribute** — which stat an ability scales with; also used by EffectData as `target_stat` for BUFF/DEBUFF:
`STRENGTH(0)`, `DEXTERITY(1)`, `COGNITION(2)`, `VITALITY(3)`, `WILLPOWER(4)`, `NONE(5)`

**TargetShape** — the geometry of the targeting area:

| Value | Behavior |
|-------|---------|
| `SELF` | Auto-targets the caster; no highlight step |
| `SINGLE` | Player picks one valid unit within range |
| `CONE` | T-shape: 1 cell adjacent to caster + 3 cells forming the top of the T |
| `LINE` | Straight line extending from the caster in a chosen direction |
| `RADIAL` | Diamond AoE — 5 wide × 5 tall |

**ApplicableTo** — which units can be targeted (irrelevant when `target_shape` is `SELF`):
`ALLY(0)`, `ENEMY(1)`, `ANY(2)`

### Fields

| Field | Type | Notes |
|-------|------|-------|
| `ability_id` | `String` | Snake_case key, e.g. `"heavy_strike"` |
| `ability_name` | `String` | Display name |
| `attribute` | `Attribute` | Stat this ability scales with |
| `target_shape` | `TargetShape` | Area/geometry of targeting |
| `applicable_to` | `ApplicableTo` | Which units can be targeted |
| `tile_range` | `int` | 0–10; `-1` = whole map |
| `passthrough` | `bool` | Effect continues past first collision (LINE/CONE/RADIAL only) |
| `energy_cost` | `int` | Subtracted from unit energy on use |
| `effects` | `Array[EffectData]` | Ordered list of effects; first effect determines QTE type |
| `description` | `String` | Flavor + mechanical tooltip text |
| `ability_icon` | `Texture2D` | Defaults to Godot icon (placeholder) |

---

## EffectData

`resources/EffectData.gd` — Resource subclass. One instance per effect within an ability. Created by `AbilityLibrary.get_ability()` from nested dicts — never instantiated directly.

### Enums

**EffectType:** `HARM(0)`, `MEND(1)`, `FORCE(2)`, `TRAVEL(3)`, `BUFF(4)`, `DEBUFF(5)`

**PoolType** (HARM / MEND only): `HP(0)`, `ENERGY(1)`

**MoveType** (TRAVEL only): `FREE(0)`, `LINE(1)`

### Fields

| Field | Type | Used by |
|-------|------|---------|
| `effect_type` | `EffectType` | All |
| `base_value` | `int` | All |
| `target_pool` | `PoolType` | HARM, MEND |
| `target_stat` | `int` | BUFF, DEBUFF — stores `AbilityData.Attribute` int value |
| `movement_type` | `MoveType` | TRAVEL |

### QTE Resolution Rules

One QTE fires per ability (typed to the first effect). The `accuracy: float` result is shared across all effects:

| Effect Type | Formula |
|-------------|---------|
| HARM / MEND | `result = max(1, round(accuracy × (base_value + caster.attribute_value)))` |
| BUFF / DEBUFF | `result = base_value` flat; accuracy < 0.3 = whiff |
| FORCE | `tiles_pushed = round(accuracy × base_value)` — not yet implemented |
| TRAVEL | `tiles_moved = base_value`; accuracy is threshold only — not yet implemented |

---

## AbilityLibrary

`scripts/globals/AbilityLibrary.gd` — static class, mirrors `ArchetypeLibrary`.

### Defined Abilities (12)

| ID | Name | Attribute | Shape | Applicable To | Cost | Range | Effects |
|----|------|-----------|-------|---------------|------|-------|---------|
| `strike` | Strike | STR | SINGLE | ENEMY | 2 | 1 | HARM HP 5 |
| `heavy_strike` | Heavy Strike | STR | SINGLE | ENEMY | 4 | 1 | HARM HP 9 |
| `quick_shot` | Quick Shot | DEX | SINGLE | ENEMY | 2 | 4 | HARM HP 4 |
| `disengage` | Disengage | DEX | SELF | ANY | 2 | 1 | TRAVEL FREE 1 |
| `acid_splash` | Acid Splash | COG | SINGLE | ENEMY | 3 | 3 | HARM HP 3, DEBUFF DEX 1 |
| `smoke_bomb` | Smoke Bomb | COG | RADIAL | ANY | 2 | 2 | DEBUFF DEX 1 |
| `healing_draught` | Healing Draught | VIT | SELF | ANY | 3 | 0 | MEND HP 5 |
| `shield_bash` | Shield Bash | STR | SINGLE | ENEMY | 3 | 1 | HARM HP 3, DEBUFF STR 1 |
| `counter` | Counter | WIL | SELF | ANY | 2 | 0 | BUFF STR 2 |
| `taunt` | Taunt | WIL | SINGLE | ENEMY | 1 | 3 | DEBUFF WIL 1 |
| `inspire` | Inspire | WIL | SINGLE | ALLY | 3 | 3 | BUFF STR 1 |
| `guard` | Guard | VIT | SELF | ANY | 2 | 0 | BUFF VIT 2 |

### Public API

```gdscript
## Returns a populated AbilityData. Never returns null — falls back to a stub for unknown IDs.
static func get_ability(ability_id: String) -> AbilityData
```

### Notes
- A future CSV import will replace the `ABILITIES` dictionary without changing `get_ability()`.
- Every non-empty string in `CombatantData.abilities` must be a valid key in `ABILITIES`.
- Stat changes from BUFF/DEBUFF are applied directly to `CombatantData` attributes. Reset-on-combat-end is a future task.
```

- [ ] **Step 2: Commit**

```bash
git add docs/map_directories/combatant_data.md
git commit -m "docs: update combatant_data.md for new AbilityData, EffectData, and AbilityLibrary"
```
