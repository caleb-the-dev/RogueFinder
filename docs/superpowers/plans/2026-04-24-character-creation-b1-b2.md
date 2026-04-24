# Character Creation (B1 + B2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a single-screen character creation flow between "Start New Run" and MapScene, letting the player pick name, kindred, class, background, and portrait for a solo PC.

**Architecture:** `CharacterCreationManager` (CanvasLayer) builds OptionButton-based UI in `_ready()`, derives a starting `CombatantData` from picks via a static `_build_pc()` function, appends it to `GameState.party`, then transitions to MapScene. `GameState.init_party()` is revised to spawn only the PC as a safety fallback (dead code on the new-run path after creation is live).

**Tech Stack:** GDScript 4, Godot 4. No new dependencies. All data from existing CSV libraries: `KindredLibrary`, `ClassLibrary`, `BackgroundLibrary`, `PortraitLibrary`, `AbilityLibrary`.

**Spec:** `docs/superpowers/specs/2026-04-23-character-creation-design.md`

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `rogue-finder/scripts/globals/GameState.gd` | Modify | `init_party()` — remove archer_bandit + grunt; spawn only PC |
| `rogue-finder/scripts/ui/CharacterCreationManager.gd` | Create | CanvasLayer manager: `_build_pc()` (static, testable), `_build_ui()`, `_on_confirm()`, `_calc_preview()` stub |
| `rogue-finder/scenes/ui/CharacterCreationScene.tscn` | Create | Minimal root CanvasLayer + script, no children |
| `rogue-finder/tests/test_character_creation.gd` | Create | Unit tests for `_build_pc()` |
| `rogue-finder/tests/test_character_creation.tscn` | Create | Headless test scene wrapper |
| `rogue-finder/scripts/ui/MainMenuManager.gd` | Modify | `_on_new_run()` — route to CharacterCreationScene instead of MapScene |

---

## Task 1: Revise GameState.init_party() (B1)

**Files:**
- Modify: `rogue-finder/scripts/globals/GameState.gd` (lines 45–52)

- [ ] **Step 1: Replace init_party() body**

In `GameState.gd`, replace the existing `init_party()` (which spawns 3 units) with:

```gdscript
## Populates party with a default PC. Guard ensures it is idempotent — safe to
## call from MapManager._ready() after load_save() regardless of save state.
## After character creation is live this path fires only as a safety fallback.
func init_party() -> void:
	if not party.is_empty():
		return
	party.append(ArchetypeLibrary.create("RogueFinder", "Hero", true))
```

- [ ] **Step 2: Commit**

```bash
git add rogue-finder/scripts/globals/GameState.gd
git commit -m "refactor(game-state): init_party spawns PC only — allies removed (B1)"
```

---

## Task 2: CharacterCreationManager stub + test scaffold (TDD)

**Files:**
- Create: `rogue-finder/scripts/ui/CharacterCreationManager.gd`
- Create: `rogue-finder/tests/test_character_creation.gd`
- Create: `rogue-finder/tests/test_character_creation.tscn`

- [ ] **Step 1: Create CharacterCreationManager with stub _build_pc()**

Create `rogue-finder/scripts/ui/CharacterCreationManager.gd`:

```gdscript
class_name CharacterCreationManager
extends CanvasLayer

## --- CharacterCreationManager ---
## Single-screen character creation. Player picks name, kindred, class,
## background, and portrait. Builds CombatantData and hands off to MapScene.
## B2: OptionButton controls. B3 will replace with Dial widgets.

const MAP_SCENE_PATH := "res://scenes/map/MapScene.tscn"

## Parallel arrays: index N in _xxx_ids matches item N in its OptionButton.
var _kindred_ids:      Array[String] = []
var _class_ids:        Array[String] = []
var _class_display:    Array[String] = []
var _bg_ids:           Array[String] = []
var _bg_display:       Array[String] = []
var _portrait_ids:     Array[String] = []
var _portrait_display: Array[String] = []

var _name_field:   LineEdit     = null
var _kindred_opt:  OptionButton = null
var _class_opt:    OptionButton = null
var _bg_opt:       OptionButton = null
var _portrait_opt: OptionButton = null

## Builds a CombatantData for the PC from the given picks.
## Static so unit tests can call it without a live scene.
static func _build_pc(char_name: String, kindred_id: String, class_id: String,
		bg_id: String, _portrait_id: String) -> CombatantData:
	return CombatantData.new()  # stub — tests will fail here; implement in Task 3
```

- [ ] **Step 2: Create test file**

Create `rogue-finder/tests/test_character_creation.gd`:

```gdscript
extends Node

## --- Unit Tests: CharacterCreationManager._build_pc() ---
## No scene nodes required — _build_pc() is a static function.
## Run via test_character_creation.tscn headlessly.

func _ready() -> void:
	print("=== test_character_creation.gd ===")
	test_archetype_and_player_flag()
	test_kindred_feat_id()
	test_unit_class_from_class_pick()
	test_background_stored_as_id()
	test_abilities_four_slots()
	test_abilities_from_class_and_background()
	test_ability_pool_superset_of_slots()
	test_ability_pool_deduplicated()
	test_hp_and_energy_seeded_at_max()
	print("=== All character creation tests passed ===")

func test_archetype_and_player_flag() -> void:
	var pc := CharacterCreationManager._build_pc("Tess", "Human", "wizard", "crook", "portrait_human_f")
	assert(pc.archetype_id == "RogueFinder",
		"archetype_id must be 'RogueFinder', got '%s'" % pc.archetype_id)
	assert(pc.is_player_unit == true, "is_player_unit must be true")
	assert(pc.character_name == "Tess",
		"character_name must match input, got '%s'" % pc.character_name)
	print("  PASS test_archetype_and_player_flag")

func test_kindred_feat_id() -> void:
	var pc := CharacterCreationManager._build_pc("Tess", "Human", "wizard", "crook", "portrait_human_f")
	var expected := KindredLibrary.get_feat_id("Human")
	assert(pc.kindred_feat_id == expected,
		"kindred_feat_id must be '%s' for Human, got '%s'" % [expected, pc.kindred_feat_id])
	print("  PASS test_kindred_feat_id")

func test_unit_class_from_class_pick() -> void:
	var pc := CharacterCreationManager._build_pc("Tess", "Human", "wizard", "crook", "portrait_human_f")
	var expected := ClassLibrary.get_class_data("wizard").display_name
	assert(pc.unit_class == expected,
		"unit_class must be '%s', got '%s'" % [expected, pc.unit_class])
	print("  PASS test_unit_class_from_class_pick")

func test_background_stored_as_id() -> void:
	var pc := CharacterCreationManager._build_pc("Tess", "Human", "wizard", "crook", "portrait_human_f")
	assert(pc.background == "crook",
		"background must be snake_case id 'crook', got '%s'" % pc.background)
	print("  PASS test_background_stored_as_id")

func test_abilities_four_slots() -> void:
	var pc := CharacterCreationManager._build_pc("Tess", "Human", "wizard", "crook", "portrait_human_f")
	assert(pc.abilities.size() == 4,
		"abilities must have exactly 4 slots, got %d" % pc.abilities.size())
	assert(pc.abilities[2] == "", "slot 2 must be empty, got '%s'" % pc.abilities[2])
	assert(pc.abilities[3] == "", "slot 3 must be empty, got '%s'" % pc.abilities[3])
	print("  PASS test_abilities_four_slots")

func test_abilities_from_class_and_background() -> void:
	var pc := CharacterCreationManager._build_pc("Tess", "Human", "wizard", "crook", "portrait_human_f")
	# wizard → fireball; crook → smoke_bomb (from classes.csv / backgrounds.csv)
	assert(pc.abilities[0] == "fireball",
		"slot 0 must be wizard starting ability 'fireball', got '%s'" % pc.abilities[0])
	assert(pc.abilities[1] == "smoke_bomb",
		"slot 1 must be crook starting ability 'smoke_bomb', got '%s'" % pc.abilities[1])
	print("  PASS test_abilities_from_class_and_background")

func test_ability_pool_superset_of_slots() -> void:
	var pc := CharacterCreationManager._build_pc("Tess", "Human", "wizard", "crook", "portrait_human_f")
	for ab in pc.abilities:
		if ab != "":
			assert(pc.ability_pool.has(ab),
				"ability_pool must contain active slot ability '%s'" % ab)
	print("  PASS test_ability_pool_superset_of_slots")

func test_ability_pool_deduplicated() -> void:
	# warrior → shield_bash; soldier → shield_bash — same ability, pool must have it once
	var pc := CharacterCreationManager._build_pc("Tess", "Dwarf", "warrior", "soldier", "portrait_dwarf")
	var seen: Dictionary = {}
	for ab in pc.ability_pool:
		assert(not seen.has(ab), "ability_pool must not contain duplicate '%s'" % ab)
		seen[ab] = true
	print("  PASS test_ability_pool_deduplicated")

func test_hp_and_energy_seeded_at_max() -> void:
	var pc := CharacterCreationManager._build_pc("Tess", "Human", "wizard", "crook", "portrait_human_f")
	assert(pc.current_hp == pc.hp_max,
		"current_hp must equal hp_max at creation (got %d, max %d)" % [pc.current_hp, pc.hp_max])
	assert(pc.current_energy == pc.energy_max,
		"current_energy must equal energy_max (got %d, max %d)" % [pc.current_energy, pc.energy_max])
	print("  PASS test_hp_and_energy_seeded_at_max")
```

- [ ] **Step 3: Create test scene wrapper**

Create `rogue-finder/tests/test_character_creation.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tests/test_character_creation.gd" id="1_test_cc"]

[node name="TestCharacterCreation" type="Node"]
script = ExtResource("1_test_cc")
```

- [ ] **Step 4: Import project to assign UIDs**

```powershell
godot --headless --path rogue-finder --import
```

Expected: no errors, project imports cleanly.

- [ ] **Step 5: Run tests — verify they fail (confirms TDD baseline)**

```powershell
godot --headless --path rogue-finder res://tests/test_character_creation.tscn
```

Expected: assertion failure in `test_archetype_and_player_flag` — stub returns `CombatantData` with `archetype_id == ""`. Failing is correct here.

- [ ] **Step 6: Commit stub + tests**

```bash
git add rogue-finder/scripts/ui/CharacterCreationManager.gd rogue-finder/tests/test_character_creation.gd rogue-finder/tests/test_character_creation.tscn
git commit -m "test(creation): add _build_pc() unit tests (failing — TDD stub)"
```

---

## Task 3: Implement _build_pc() — make tests pass

**Files:**
- Modify: `rogue-finder/scripts/ui/CharacterCreationManager.gd`

- [ ] **Step 1: Replace the stub _build_pc() with the real implementation**

In `CharacterCreationManager.gd`, replace the one-line stub body of `_build_pc()`:

```gdscript
static func _build_pc(char_name: String, kindred_id: String, class_id: String,
		bg_id: String, _portrait_id: String) -> CombatantData:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var d := CombatantData.new()
	d.archetype_id    = "RogueFinder"
	d.is_player_unit  = true
	d.character_name  = char_name
	d.kindred         = kindred_id
	d.kindred_feat_id = KindredLibrary.get_feat_id(kindred_id)
	d.unit_class      = ClassLibrary.get_class_data(class_id).display_name
	d.background      = bg_id
	var class_ab: String = ClassLibrary.get_class_data(class_id).starting_ability_id
	var bg_ab: String    = BackgroundLibrary.get_background(bg_id).starting_ability_id
	d.abilities = [class_ab, bg_ab, "", ""]
	d.ability_pool = []
	if class_ab != "":
		d.ability_pool.append(class_ab)
	if bg_ab != "" and not d.ability_pool.has(bg_ab):
		d.ability_pool.append(bg_ab)
	d.strength       = rng.randi_range(1, 4)
	d.dexterity      = rng.randi_range(1, 4)
	d.cognition      = rng.randi_range(1, 4)
	d.willpower      = rng.randi_range(1, 4)
	d.vitality       = rng.randi_range(1, 4)
	d.armor_defense  = rng.randi_range(4, 8)
	d.qte_resolution = 0.5
	d.current_hp     = d.hp_max
	d.current_energy = d.energy_max
	return d
```

- [ ] **Step 2: Run tests — verify all pass**

```powershell
godot --headless --path rogue-finder res://tests/test_character_creation.tscn
```

Expected output:
```
=== test_character_creation.gd ===
  PASS test_archetype_and_player_flag
  PASS test_kindred_feat_id
  PASS test_unit_class_from_class_pick
  PASS test_background_stored_as_id
  PASS test_abilities_four_slots
  PASS test_abilities_from_class_and_background
  PASS test_ability_pool_superset_of_slots
  PASS test_ability_pool_deduplicated
  PASS test_hp_and_energy_seeded_at_max
=== All character creation tests passed ===
```

- [ ] **Step 3: Commit**

```bash
git add rogue-finder/scripts/ui/CharacterCreationManager.gd
git commit -m "feat(creation): implement _build_pc() — 9 tests pass"
```

---

## Task 4: Add UI methods to CharacterCreationManager

**Files:**
- Modify: `rogue-finder/scripts/ui/CharacterCreationManager.gd`

No new unit tests — this is pure UI code (OptionButtons, Labels, Buttons). Covered by the manual checklist.

- [ ] **Step 1: Append all UI methods after the existing _build_pc() static func**

```gdscript
func _ready() -> void:
	layer = 1
	_load_data()
	_build_ui()

func _load_data() -> void:
	for k in KindredLibrary.all_kindreds():
		_kindred_ids.append(k.kindred_id)  # kindred_id IS the display name (Human, Dwarf, etc.)
	for c in ClassLibrary.all_classes():
		_class_ids.append(c.class_id)
		_class_display.append(c.display_name)
	for b in BackgroundLibrary.all_backgrounds():
		_bg_ids.append(b.background_id)
		_bg_display.append(b.background_name)
	for p in PortraitLibrary.all_portraits():
		_portrait_ids.append(p.portrait_id)
		_portrait_display.append(p.portrait_name)

func _build_ui() -> void:
	var bg_rect := ColorRect.new()
	bg_rect.color = Color(0.05, 0.06, 0.12)
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg_rect)

	var title := Label.new()
	title.text = "Create Your Character"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.position = Vector2(0.0, 60.0)
	add_child(title)

	var cx  := 640.0
	var lx  := cx - 320.0
	var ox  := cx - 150.0
	var y   := 180.0
	var gap := 72.0

	# --- Name ---
	_add_row_label("Name", lx, y)
	_name_field = LineEdit.new()
	_name_field.placeholder_text    = "Enter name..."
	_name_field.position            = Vector2(ox, y)
	_name_field.custom_minimum_size = Vector2(240.0, 40.0)
	add_child(_name_field)
	var dice_name := Button.new()
	dice_name.text                = "🎲"
	dice_name.position            = Vector2(ox + 248.0, y)
	dice_name.custom_minimum_size = Vector2(40.0, 40.0)
	dice_name.pressed.connect(_on_dice_name)
	add_child(dice_name)
	y += gap

	# --- Kindred ---
	_add_row_label("Kindred", lx, y)
	_kindred_opt = _make_option(_kindred_ids, ox, y)
	_kindred_opt.item_selected.connect(func(_i: int) -> void: _on_pick_changed())
	add_child(_kindred_opt)
	y += gap

	# --- Class ---
	_add_row_label("Class", lx, y)
	_class_opt = _make_option(_class_display, ox, y)
	_class_opt.item_selected.connect(func(_i: int) -> void: _on_pick_changed())
	add_child(_class_opt)
	y += gap

	# --- Background ---
	_add_row_label("Background", lx, y)
	_bg_opt = _make_option(_bg_display, ox, y)
	_bg_opt.item_selected.connect(func(_i: int) -> void: _on_pick_changed())
	add_child(_bg_opt)
	y += gap

	# --- Portrait ---
	_add_row_label("Portrait", lx, y)
	_portrait_opt = _make_option(_portrait_display, ox, y)
	_portrait_opt.item_selected.connect(func(_i: int) -> void: _on_pick_changed())
	add_child(_portrait_opt)
	y += gap + 20.0

	# --- Confirm ---
	var confirm := Button.new()
	confirm.text                  = "Confirm"
	confirm.position              = Vector2(cx - 100.0, y)
	confirm.custom_minimum_size   = Vector2(200.0, 54.0)
	confirm.add_theme_font_size_override("font_size", 24)
	confirm.pressed.connect(_on_confirm)
	add_child(confirm)

	_on_pick_changed()

func _add_row_label(text: String, x: float, y: float) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	lbl.position = Vector2(x, y + 8.0)
	add_child(lbl)

func _make_option(items: Array[String], x: float, y: float) -> OptionButton:
	var opt := OptionButton.new()
	opt.position            = Vector2(x, y)
	opt.custom_minimum_size = Vector2(240.0, 40.0)
	opt.add_theme_font_size_override("font_size", 18)
	for item in items:
		opt.add_item(item)
	return opt

func _on_pick_changed() -> void:
	if _kindred_opt == null or _class_opt == null or _bg_opt == null or _portrait_opt == null:
		return
	_calc_preview()

func _calc_preview() -> void:
	# B4 slot — stub in B2. Replace with real preview panel update when B4 lands.
	pass

func _on_dice_name() -> void:
	if _kindred_opt == null:
		return
	var kindred_id := _kindred_ids[_kindred_opt.selected]
	var pool := KindredLibrary.get_name_pool(kindred_id)
	if pool.is_empty():
		_name_field.text = "Unit"
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_name_field.text = pool[rng.randi_range(0, pool.size() - 1)]

func _on_confirm() -> void:
	var char_name := _name_field.text.strip_edges()
	if char_name == "":
		char_name = "Unit"
	var kindred_id  := _kindred_ids[_kindred_opt.selected]
	var class_id    := _class_ids[_class_opt.selected]
	var bg_id       := _bg_ids[_bg_opt.selected]
	var portrait_id := _portrait_ids[_portrait_opt.selected]
	var pc := _build_pc(char_name, kindred_id, class_id, bg_id, portrait_id)
	GameState.party.append(pc)
	get_tree().change_scene_to_file(MAP_SCENE_PATH)
```

- [ ] **Step 2: Re-run creation tests to confirm _build_pc() still passes**

```powershell
godot --headless --path rogue-finder res://tests/test_character_creation.tscn
```

Expected: all 9 tests still pass (UI methods don't touch `_build_pc`).

- [ ] **Step 3: Commit**

```bash
git add rogue-finder/scripts/ui/CharacterCreationManager.gd
git commit -m "feat(creation): add _build_ui(), _on_confirm(), _on_dice_name() (B2 UI layer)"
```

---

## Task 5: Create CharacterCreationScene.tscn

**Files:**
- Create: `rogue-finder/scenes/ui/CharacterCreationScene.tscn`

- [ ] **Step 1: Create the minimal scene file**

Create `rogue-finder/scenes/ui/CharacterCreationScene.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/CharacterCreationManager.gd" id="1_ccmanager"]

[node name="CharacterCreationScene" type="CanvasLayer"]
script = ExtResource("1_ccmanager")
```

- [ ] **Step 2: Re-import to assign UIDs**

```powershell
godot --headless --path rogue-finder --import
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add rogue-finder/scenes/ui/CharacterCreationScene.tscn
git commit -m "feat(creation): add CharacterCreationScene.tscn (minimal root)"
```

---

## Task 6: Hook MainMenuManager into the creation scene

**Files:**
- Modify: `rogue-finder/scripts/ui/MainMenuManager.gd`

- [ ] **Step 1: Add CREATION_SCENE_PATH constant**

In `MainMenuManager.gd`, add after the existing `MAP_SCENE_PATH` constant:

```gdscript
const MAP_SCENE_PATH      := "res://scenes/map/MapScene.tscn"
const CREATION_SCENE_PATH := "res://scenes/ui/CharacterCreationScene.tscn"
```

- [ ] **Step 2: Update _on_new_run() to route to creation**

Replace `_on_new_run()`:

```gdscript
func _on_new_run() -> void:
	GameState.delete_save()
	GameState.reset()
	get_tree().change_scene_to_file(CREATION_SCENE_PATH)
```

- [ ] **Step 3: Run all headless test suites**

```powershell
godot --headless --path rogue-finder res://tests/test_character_creation.tscn
godot --headless --path rogue-finder res://tests/test_combatant_data.tscn
godot --headless --path rogue-finder res://tests/test_class_library.tscn
godot --headless --path rogue-finder res://tests/test_game_state_party.tscn
```

Expected: all tests pass across all four suites.

- [ ] **Step 4: Commit**

```bash
git add rogue-finder/scripts/ui/MainMenuManager.gd
git commit -m "feat(creation): wire MainMenuManager to CharacterCreationScene (B2 complete)"
```

---

## Manual Test Checklist (in-game, after all tasks complete)

- [ ] "Start New Run" from the main menu navigates to the character creation screen (not directly to MapScene).
- [ ] All four dropdowns populate with the correct number of options: 4 kindreds, 4 classes, 4 backgrounds, 6 portraits.
- [ ] 🎲 button next to the name field generates a name from the selected kindred's pool. Changing kindred and re-rolling yields pool-appropriate names.
- [ ] "Confirm" with all defaults navigates to MapScene. `GameState.party` contains exactly 1 PC — no allies.
- [ ] PC's `kindred`, `unit_class`, `background`, and `abilities[0]`/`abilities[1]` match the picks made on the creation screen.
- [ ] Save-then-reload ("Continue" from main menu) restores the PC correctly — correct kindred, class, background, and abilities.
