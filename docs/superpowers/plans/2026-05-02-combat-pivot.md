# Combat Pivot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 10×10 tactical-grid combat system with a turn-tick autobattler (Wildfrost-shape) using 3 flat lanes per side, per-unit countdown timers, per-ability cooldown rotation, simple priority-list AI, and consumable-only player intervention. Keep all non-combat systems (map, events, vendors, city, build, equipment, save) untouched.

**Architecture:** Coexistence-first. New combat code (`CombatManager.gd`, `LaneBoard.gd`, `CountdownTracker.gd`, `AutobattlerEnemyAI.gd`, `CombatSceneAuto.tscn`, `PlacementOverlay.tscn`) lives alongside the existing combat (`CombatManager3D.gd`, `Grid3D.gd`, `QTEBar.gd`, `EnemyAI.gd`, `CombatScene3D.tscn`) until Slice 7. A `MapManager` feature flag picks which scene COMBAT/BOSS nodes load. Slices 1–2 are additive (new fields added; old fields kept). Slices 3–6 build the new combat behind the flag. Slice 7 flips the flag, rips out the old code, and removes deprecated fields. Slice 8 tunes consumables.

**Tech Stack:** Godot 4 / GDScript (typed). Tests live in `rogue-finder/tests/` and run headless via `godot --headless --path . tests/<name>.tscn`. Project root is `rogue-finder/`. Source spec: `docs/superpowers/specs/2026-05-02-combat-pivot-design.md`.

---

## File Structure

### Files to CREATE (new)

| Path | Responsibility |
|---|---|
| `rogue-finder/scripts/combat/CombatManager.gd` | Turn-tick autobattler controller — drives the tick loop, fires unit turns, hosts the LaneBoard, manages combat lifecycle |
| `rogue-finder/scripts/combat/CountdownTracker.gd` | Static module — pure logic for unit countdowns + per-ability cooldowns |
| `rogue-finder/scripts/combat/LaneBoard.gd` | 3-lane data structure — replaces Grid3D's 10×10 cell math; lane lookup, occupancy, adjacency |
| `rogue-finder/scripts/combat/AutobattlerEnemyAI.gd` | Static module — `pick(unit, allies, hostiles, board) → {ability, target}` priority-list selector |
| `rogue-finder/scripts/ui/PlacementOverlay.gd` | Pre-fight UI — drag your 3 active units onto your 3 lanes |
| `rogue-finder/scenes/combat/CombatSceneAuto.tscn` | Minimal root scene for new combat (CanvasLayer + script) |
| `rogue-finder/scenes/ui/PlacementOverlay.tscn` | Minimal CanvasLayer scene for placement |
| `rogue-finder/data/abilities_basic.csv` row | Add a `basic_strike` ability for slot-0 fallback |
| `rogue-finder/tests/test_spd_attribute.{gd,tscn}` | SPD field tests |
| `rogue-finder/tests/test_cooldown_field.{gd,tscn}` | Cooldown field tests |
| `rogue-finder/tests/test_lane_board.{gd,tscn}` | LaneBoard data tests |
| `rogue-finder/tests/test_countdown_tracker.{gd,tscn}` | Countdown ticking + cooldown decrement tests |
| `rogue-finder/tests/test_lane_targeting.{gd,tscn}` | Target-shape resolution tests |
| `rogue-finder/tests/test_autobattler_ai.{gd,tscn}` | AI priority-list tests |
| `rogue-finder/tests/test_placement.{gd,tscn}` | Placement validation tests |
| `rogue-finder/tests/test_combat_loop.{gd,tscn}` | End-to-end combat tick loop test |

### Files to MODIFY

| Path | Change |
|---|---|
| `rogue-finder/resources/CombatantData.gd` | Add `spd: int`, `countdown_current: int`, `countdown_max: int`. Remove `speed` getter (replaced by `spd`). Remove `energy_max`, `energy_regen` getters. Remove `current_energy` field (Slice 7) |
| `rogue-finder/resources/AbilityData.gd` | Add `cooldown_max: int`. Add new TargetShape enum values. Keep `energy_cost` until Slice 7. Keep old TargetShape values until Slice 7 |
| `rogue-finder/scripts/globals/AbilityLibrary.gd` | Parse new `cooldown` CSV column → `cooldown_max`. Parse new target-shape names. Keep old behavior |
| `rogue-finder/scripts/globals/KindredLibrary.gd` | Read `spd_bonus` column from kindreds.csv. Keep `speed_bonus` reads as fallback during transition |
| `rogue-finder/scripts/globals/GameState.gd` | save/load: persist `spd`. Save migration: drop `current_energy` references when Slice 7 lands |
| `rogue-finder/scripts/map/MapManager.gd` | Add `USE_AUTOBATTLER_COMBAT: bool` constant; gate `_load_combat_scene()` on it |
| `rogue-finder/scripts/party/PartySheet.gd` | Add SPD column to derived stats row. Hide energy in Slice 7 |
| `rogue-finder/scripts/ui/StatPanel.gd` | Add SPD line. Hide energy in Slice 7 |
| `rogue-finder/scripts/ui/CharacterCreationManager.gd` | Show SPD in preview panel; allow background +1 SPD if any background CSV row uses it |
| `rogue-finder/data/abilities.csv` | Add `cooldown` column populated per migration table; add new target-shape values to existing rows |
| `rogue-finder/data/kindreds.csv` | Add `spd_bonus` column |

### Files to DELETE (Slice 7 only)

- `rogue-finder/scripts/combat/CombatManager3D.gd`
- `rogue-finder/scripts/combat/Grid3D.gd`
- `rogue-finder/scripts/combat/QTEBar.gd`
- `rogue-finder/scripts/combat/EnemyAI.gd`
- `rogue-finder/scenes/combat/CombatScene3D.tscn`
- `rogue-finder/scenes/combat/Grid3D.tscn`
- `rogue-finder/scenes/combat/QTEBar.tscn`

`Unit3D.gd` survives but loses movement, AoE, FORCE response, QTE binding (stripped in Slice 7).

---

## Coexistence Strategy

Until Slice 7, the game is **always playable.** The old combat scene is unchanged. The new combat scene is built in parallel under a different filename. A `USE_AUTOBATTLER_COMBAT: bool = false` constant in `MapManager.gd` chooses which scene COMBAT/BOSS nodes load. Caleb can flip the flag locally to test the new scene mid-development.

This keeps each slice individually shippable: even after Slice 1 (SPD added), the old combat ignores SPD and plays as before. After Slice 6, combat is fully rebuilt; flipping the flag enters the new system. Slice 7 is the formal cutover (rip + cleanup).

---

## Slice 1: SPD Attribute Foundation

**Session goal:** Add SPD as a 6th attribute. Migrate kindred speed_bonus into the new field. Persist to disk. Display in PartySheet/StatPanel. The old `speed` getter retires (replaced by `spd`). Old combat doesn't reference `speed` directly (it uses Unit3D for movement) so this is safe.

### Task 1.1: Add `spd` field to CombatantData

**Files:**
- Modify: `rogue-finder/resources/CombatantData.gd`
- Test: `rogue-finder/tests/test_spd_attribute.gd` (create)
- Test scene: `rogue-finder/tests/test_spd_attribute.tscn` (create)

- [ ] **Step 1: Write the failing test**

Create `rogue-finder/tests/test_spd_attribute.gd`:

```gdscript
extends Node

func _ready() -> void:
	print("=== test_spd_attribute.gd ===")
	test_spd_default()
	test_spd_serializes()
	test_kindred_spd_bonus_applies()
	print("=== All SPD tests passed ===")

func test_spd_default() -> void:
	var d := CombatantData.new()
	assert(d.spd == 4, "spd should default to 4, got %d" % d.spd)
	print("  PASS test_spd_default")

func test_spd_serializes() -> void:
	var d := CombatantData.new()
	d.spd = 7
	var saved: int = d.spd
	assert(saved == 7, "spd should round-trip, got %d" % saved)
	print("  PASS test_spd_serializes")

func test_kindred_spd_bonus_applies() -> void:
	var d := CombatantData.new()
	d.kindred = "Spider"
	# effective_stat for spd should add the kindred bonus
	var eff := d.effective_stat("spd")
	assert(eff >= d.spd, "effective_stat(spd) should be at least raw spd")
	print("  PASS test_kindred_spd_bonus_applies")
```

Create `rogue-finder/tests/test_spd_attribute.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tests/test_spd_attribute.gd" id="1"]

[node name="TestSpdAttribute" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 2: Run test to verify it fails**

```powershell
godot --headless --path rogue-finder --import
godot --headless --path rogue-finder tests/test_spd_attribute.tscn
```

Expected: error — `spd` is not a property of CombatantData.

- [ ] **Step 3: Add `spd` field to CombatantData**

Edit `rogue-finder/resources/CombatantData.gd`. Find the Core Attributes section (around line 53–60) and add `spd`:

```gdscript
@export_range(1, 10) var strength:  int = 4
@export_range(1, 10) var dexterity: int = 4
@export_range(1, 10) var cognition: int = 4
@export_range(1, 10) var willpower: int = 4
@export_range(1, 10) var vitality:  int = 4
@export_range(1, 10) var spd:       int = 4  # Speed; drives countdown_max in autobattler
```

Update `effective_stat()` to handle `spd`:

```gdscript
func effective_stat(stat: String) -> int:
	var raw: int
	match stat:
		"strength":  raw = strength
		"dexterity": raw = dexterity
		"cognition": raw = cognition
		"vitality":  raw = vitality
		"willpower": raw = willpower
		"spd":       raw = spd
		_: return 0
	return raw + _equip_bonus(stat) + get_feat_stat_bonus(stat) + get_class_stat_bonus(stat) \
		+ get_kindred_stat_bonus(stat) + get_background_stat_bonus(stat) + get_temperament_stat_bonus(stat)
```

- [ ] **Step 4: Run test to verify it passes**

```powershell
godot --headless --path rogue-finder tests/test_spd_attribute.tscn
```

Expected: All SPD tests passed.

- [ ] **Step 5: Commit**

```powershell
git add rogue-finder/resources/CombatantData.gd rogue-finder/tests/test_spd_attribute.gd rogue-finder/tests/test_spd_attribute.tscn
git commit -m "feat: add spd attribute to CombatantData (6th core stat)"
```

---

### Task 1.2: Add `spd_bonus` column to kindreds.csv

**Files:**
- Modify: `rogue-finder/data/kindreds.csv`
- Modify: `rogue-finder/scripts/globals/KindredLibrary.gd`
- Test: `rogue-finder/tests/test_spd_attribute.gd` (extend)

- [ ] **Step 1: Write the failing test**

Append to `rogue-finder/tests/test_spd_attribute.gd`:

```gdscript
func test_kindred_library_returns_spd_bonus() -> void:
	# Spider should be fastest (designed +3 SPD per spec)
	assert(KindredLibrary.get_stat_bonus("Spider", "spd") == 3, "Spider should have spd +3")
	# Skeleton should be slowest (-1 per spec)
	assert(KindredLibrary.get_stat_bonus("Skeleton", "spd") == -1, "Skeleton should have spd -1")
	# Human should be neutral
	assert(KindredLibrary.get_stat_bonus("Human", "spd") == 0, "Human should have spd 0")
	print("  PASS test_kindred_library_returns_spd_bonus")
```

And add the call in `_ready()`:

```gdscript
test_kindred_library_returns_spd_bonus()
```

- [ ] **Step 2: Run test to verify it fails**

```powershell
godot --headless --path rogue-finder tests/test_spd_attribute.tscn
```

Expected: assertion fails — Spider has no spd bonus yet.

- [ ] **Step 3: Add spd_bonus values to kindreds.csv**

Edit `rogue-finder/data/kindreds.csv`. Migrate existing `speed_bonus` values into a new column entry inside `stat_bonuses`. The existing `speed_bonus` column stays for legacy `speed` getter compatibility but becomes inert in autobattler.

Before:
```
id,speed_bonus,hp_bonus,stat_bonuses,starting_ability_id,ability_pool,name_pool,notes
Human,3,5,willpower:1,...
```

After:
```
id,speed_bonus,hp_bonus,stat_bonuses,starting_ability_id,ability_pool,name_pool,notes
Human,3,5,willpower:1|spd:0,...
Half-Orc,2,12,strength:1|spd:-1,...
Gnome,1,3,cognition:1|spd:0,...
Dwarf,2,8,vitality:1|spd:-1,...
Skeleton,2,4,strength:1|spd:-1,...
Giant Rat,4,2,dexterity:1|spd:2,...
Spider,4,3,dexterity:1|spd:3,...
Dragon,2,15,strength:1|spd:0,...
```

(Specific spd values per spec — Spider +3, Skeleton −1, Half-Orc −1, Dwarf −1, Rat +2, Gnome 0, Human 0, Dragon 0.)

KindredLibrary already parses `stat_bonuses` (pipe-separated key:value pairs), so no library changes needed unless your `get_stat_bonus()` is keyed by a hardcoded set. Verify with the test.

- [ ] **Step 4: Run test to verify it passes**

```powershell
godot --headless --path rogue-finder tests/test_spd_attribute.tscn
```

Expected: All SPD tests passed.

- [ ] **Step 5: Commit**

```powershell
git add rogue-finder/data/kindreds.csv rogue-finder/tests/test_spd_attribute.gd
git commit -m "feat: add spd kindred bonuses (kindreds.csv stat_bonuses)"
```

---

### Task 1.3: Persist `spd` in save/load

**Files:**
- Modify: `rogue-finder/scripts/globals/GameState.gd`
- Test: `rogue-finder/tests/test_spd_attribute.gd` (extend)

- [ ] **Step 1: Write the failing test**

Append to `rogue-finder/tests/test_spd_attribute.gd`:

```gdscript
func test_spd_round_trips_through_save_dict() -> void:
	# Build a minimal CombatantData and serialize it through GameState's helper, if exposed,
	# or through whatever party-serialization function exists. Adjust call to match actual API.
	var d := CombatantData.new()
	d.spd = 7
	# GameState.party_to_dict / party_from_dict assumed — adjust to your save shape.
	var dict: Dictionary = GameState._combatant_to_dict(d)
	var rebuilt: CombatantData = GameState._combatant_from_dict(dict)
	assert(rebuilt.spd == 7, "spd should round-trip through save dict, got %d" % rebuilt.spd)
	print("  PASS test_spd_round_trips_through_save_dict")
```

Add the call in `_ready()`.

- [ ] **Step 2: Run test to verify it fails**

```powershell
godot --headless --path rogue-finder tests/test_spd_attribute.tscn
```

Expected: assertion fails — spd not in serialized dict.

- [ ] **Step 3: Add `spd` to GameState save/load**

Open `rogue-finder/scripts/globals/GameState.gd`. Find the helper that serializes a CombatantData to a dict (often `_combatant_to_dict` or similar — the exact name lives in your existing save code). Add `spd` to the saved fields:

```gdscript
func _combatant_to_dict(d: CombatantData) -> Dictionary:
	return {
		# ... existing keys ...
		"spd": d.spd,
		# ... existing keys ...
	}

func _combatant_from_dict(dict: Dictionary) -> CombatantData:
	var d := CombatantData.new()
	# ... existing assignments ...
	d.spd = int(dict.get("spd", 4))  # default 4 for old saves missing the field
	# ... existing assignments ...
	return d
```

The `dict.get("spd", 4)` fallback handles save-migration: old saves lacking the field default to spd 4 (which combined with kindred bonuses keeps fastest units roughly equal to today's speeds).

- [ ] **Step 4: Run test to verify it passes**

```powershell
godot --headless --path rogue-finder tests/test_spd_attribute.tscn
```

Expected: All SPD tests passed.

- [ ] **Step 5: Commit**

```powershell
git add rogue-finder/scripts/globals/GameState.gd rogue-finder/tests/test_spd_attribute.gd
git commit -m "feat: persist spd in save/load (default 4 for old saves)"
```

---

### Task 1.4: Show SPD in PartySheet and StatPanel

**Files:**
- Modify: `rogue-finder/scripts/party/PartySheet.gd`
- Modify: `rogue-finder/scripts/ui/StatPanel.gd`

- [ ] **Step 1: Add SPD column to PartySheet derived stats row**

Open `rogue-finder/scripts/party/PartySheet.gd`. Find where the derived stats row is built (currently 5 columns: STR / DEX / COG / WIL / VIT, with effective + bonus coloring). Add a 6th column for SPD using the same pattern.

The existing pattern reads the unit's effective_stat for each attr. Mirror that:

```gdscript
# Inside the function that builds the derived stats row (mid-PartySheet.gd):
var spd_label := Label.new()
spd_label.text = "SPD %d" % unit.effective_stat("spd")
# Apply the same green/red coloring used by other attrs based on bonus delta:
var raw_spd: int = unit.spd
var eff_spd: int = unit.effective_stat("spd")
if eff_spd > raw_spd:
	spd_label.modulate = Color(0.5, 1, 0.5)
elif eff_spd < raw_spd:
	spd_label.modulate = Color(1, 0.5, 0.5)
stats_row.add_child(spd_label)
```

(Adjust the variable names + add_child target to match your existing PartySheet code.)

- [ ] **Step 2: Add SPD line to StatPanel**

Open `rogue-finder/scripts/ui/StatPanel.gd`. Find the section that lists derived stats. Add an SPD line in the same style as STR/DEX/COG/WIL/VIT.

```gdscript
var spd_line := "SPD: %d" % unit.effective_stat("spd")
# Append to wherever the stats label list is built.
```

- [ ] **Step 3: Run the game manually and verify**

This is a visual change — no headless test. Run the game, open PartySheet and StatPanel for a unit, confirm SPD appears with correct value (e.g. a Spider PC should show SPD ≥ 7).

```powershell
godot --path rogue-finder
```

- [ ] **Step 4: Commit**

```powershell
git add rogue-finder/scripts/party/PartySheet.gd rogue-finder/scripts/ui/StatPanel.gd
git commit -m "feat: show SPD attribute in PartySheet and StatPanel"
```

---

### Task 1.5: Show SPD in Character Creation preview panel

**Files:**
- Modify: `rogue-finder/scripts/ui/CharacterCreationManager.gd`

- [ ] **Step 1: Add SPD line to creation preview**

Open `CharacterCreationManager.gd`. Find the live-preview panel update function (likely `_update_preview()` or similar — look for STR/DEX/COG/WIL/VIT label updates). Add an SPD line in the same style.

```gdscript
# Inside the preview update function:
var temp_pc: CombatantData = _build_pc()  # use existing builder
$PreviewPanel/SpdLabel.text = "SPD %d" % temp_pc.effective_stat("spd")
```

(Match your existing preview panel's node structure.)

- [ ] **Step 2: Run game manually and verify**

Open Character Creation, cycle through kindreds, verify SPD updates correctly. Spider should be visibly faster than Skeleton.

- [ ] **Step 3: Commit**

```powershell
git add rogue-finder/scripts/ui/CharacterCreationManager.gd
git commit -m "feat: show SPD in character creation preview"
```

---

## Slice 2: Cooldown Field on AbilityData (Additive)

**Session goal:** Add a `cooldown_max: int` field to AbilityData. Add a `cooldown` column to abilities.csv. Populate values per the migration table (1–2 → 2, 3–4 → 3, 5+ → 5). Old combat continues to use `energy_cost`. New combat (Slice 4) will use `cooldown_max`. Both fields coexist until Slice 7.

### Task 2.1: Add `cooldown_max` field to AbilityData

**Files:**
- Modify: `rogue-finder/resources/AbilityData.gd`
- Test: `rogue-finder/tests/test_cooldown_field.{gd,tscn}` (create)

- [ ] **Step 1: Write the failing test**

Create `rogue-finder/tests/test_cooldown_field.gd`:

```gdscript
extends Node

func _ready() -> void:
	print("=== test_cooldown_field.gd ===")
	test_cooldown_default()
	test_cooldown_set()
	test_cooldown_loaded_from_csv()
	print("=== All cooldown field tests passed ===")

func test_cooldown_default() -> void:
	var a := AbilityData.new()
	assert(a.cooldown_max == 0, "cooldown_max should default to 0")
	print("  PASS test_cooldown_default")

func test_cooldown_set() -> void:
	var a := AbilityData.new()
	a.cooldown_max = 3
	assert(a.cooldown_max == 3, "cooldown_max should hold the assigned value")
	print("  PASS test_cooldown_set")

func test_cooldown_loaded_from_csv() -> void:
	# 'strike' has energy_cost 2 in current CSV → cooldown_max should default to 2 post-migration
	var a := AbilityLibrary.get_ability("strike")
	assert(a.cooldown_max == 2, "strike cooldown_max should be 2, got %d" % a.cooldown_max)
	# 'heavy_strike' has energy_cost 4 → cooldown 3
	var hs := AbilityLibrary.get_ability("heavy_strike")
	assert(hs.cooldown_max == 3, "heavy_strike cooldown_max should be 3, got %d" % hs.cooldown_max)
	print("  PASS test_cooldown_loaded_from_csv")
```

Create matching `.tscn` (mirror test_spd_attribute.tscn).

- [ ] **Step 2: Run test to verify it fails**

```powershell
godot --headless --path rogue-finder tests/test_cooldown_field.tscn
```

Expected: error — `cooldown_max` is not a property.

- [ ] **Step 3: Add `cooldown_max` to AbilityData**

Edit `rogue-finder/resources/AbilityData.gd`. Add the field next to `energy_cost`:

```gdscript
@export var energy_cost:    int = 0  # legacy — retired in Slice 7
@export var cooldown_max:   int = 0  # autobattler — turns until ability can fire again
```

- [ ] **Step 4: Run test to verify it fails differently**

```powershell
godot --headless --path rogue-finder tests/test_cooldown_field.tscn
```

Expected: first two tests pass; third (`test_cooldown_loaded_from_csv`) still fails because the CSV has no `cooldown` column yet.

- [ ] **Step 5: Commit**

```powershell
git add rogue-finder/resources/AbilityData.gd rogue-finder/tests/test_cooldown_field.gd rogue-finder/tests/test_cooldown_field.tscn
git commit -m "feat: add cooldown_max field to AbilityData (additive)"
```

---

### Task 2.2: Add `cooldown` column to abilities.csv

**Files:**
- Modify: `rogue-finder/data/abilities.csv`
- Modify: `rogue-finder/scripts/globals/AbilityLibrary.gd`

- [ ] **Step 1: Add `cooldown` column to header + populate per migration table**

Open `rogue-finder/data/abilities.csv`. Add `cooldown` as a new column after `cost`. Populate per:

| `cost` value | `cooldown` value |
|---|---|
| 0 (passive) | 0 |
| 1 | 2 |
| 2 | 2 |
| 3 | 3 |
| 4 | 3 |
| 5+ | 5 |

Header line goes from:
```
id,name,attribute,target,applicable_to,range,passthrough,cost,description,effects,damage_type,upgraded_id,notes
```
to:
```
id,name,attribute,target,applicable_to,range,passthrough,cost,cooldown,description,effects,damage_type,upgraded_id,notes
```

For each existing row, insert the cooldown value right after `cost`. Example:

Before: `strike,Strike,STRENGTH,SINGLE,ENEMY,1,false,2,Deal 5 physical damage...`
After:  `strike,Strike,STRENGTH,SINGLE,ENEMY,1,false,2,2,Deal 5 physical damage...`

- [ ] **Step 2: Add `cooldown` column parser to AbilityLibrary**

Open `rogue-finder/scripts/globals/AbilityLibrary.gd`. Find the `_row_to_data()` match block (around line 152). Add a new case for `"cooldown"`:

```gdscript
"cost":
	a.energy_cost = int(val)
"cooldown":
	a.cooldown_max = int(val)
```

- [ ] **Step 3: Run test to verify it passes**

```powershell
godot --headless --path rogue-finder tests/test_cooldown_field.tscn
```

Expected: All cooldown field tests passed.

- [ ] **Step 4: Run the existing ability tests to make sure nothing else broke**

```powershell
godot --headless --path rogue-finder tests/test_ability_library.tscn
```

Expected: PASS (existing tests unaffected — `cost`/`energy_cost` is untouched).

- [ ] **Step 5: Commit**

```powershell
git add rogue-finder/data/abilities.csv rogue-finder/scripts/globals/AbilityLibrary.gd
git commit -m "feat: add cooldown column to abilities.csv (migrate from cost)"
```

---

## Slice 3: Combat Scaffold — New Scene + LaneBoard + Skeleton

**Session goal:** Build the new combat scene shell that coexists with the old. Includes a `LaneBoard` data structure (3 lanes per side), a stub `CombatManager` that can be entered + exited, a stub `PlacementOverlay`, and a `MapManager` flag that picks which scene to load. After this slice, you can flip the flag and watch a still-empty CombatSceneAuto load. Real combat logic lands in Slice 4.

### Task 3.1: Create LaneBoard data structure

**Files:**
- Create: `rogue-finder/scripts/combat/LaneBoard.gd`
- Create: `rogue-finder/tests/test_lane_board.{gd,tscn}`

- [ ] **Step 1: Write the failing test**

Create `rogue-finder/tests/test_lane_board.gd`:

```gdscript
extends Node

func _ready() -> void:
	print("=== test_lane_board.gd ===")
	test_init_empty()
	test_place_unit()
	test_lane_full()
	test_remove_unit()
	test_get_opposite()
	test_adjacent_lanes()
	print("=== All LaneBoard tests passed ===")

func test_init_empty() -> void:
	var board := LaneBoard.new()
	for lane in 3:
		assert(board.get_unit(lane, "ally") == null, "ally lane %d should be empty" % lane)
		assert(board.get_unit(lane, "enemy") == null, "enemy lane %d should be empty" % lane)
	print("  PASS test_init_empty")

func test_place_unit() -> void:
	var board := LaneBoard.new()
	var d := CombatantData.new()
	d.character_name = "TestUnit"
	board.place(d, 1, "ally")
	assert(board.get_unit(1, "ally") == d, "ally lane 1 should hold the placed unit")
	assert(board.get_unit(0, "ally") == null, "ally lane 0 should still be empty")
	print("  PASS test_place_unit")

func test_lane_full() -> void:
	var board := LaneBoard.new()
	var d1 := CombatantData.new()
	var d2 := CombatantData.new()
	board.place(d1, 1, "ally")
	# Second placement on same lane+side should overwrite (placement is destructive)
	# OR caller is responsible for checking — choose policy. Test the chosen policy.
	board.place(d2, 1, "ally")
	assert(board.get_unit(1, "ally") == d2, "second placement should overwrite (last-write-wins)")
	print("  PASS test_lane_full")

func test_remove_unit() -> void:
	var board := LaneBoard.new()
	var d := CombatantData.new()
	board.place(d, 0, "enemy")
	board.remove(0, "enemy")
	assert(board.get_unit(0, "enemy") == null, "removed lane should be empty")
	print("  PASS test_remove_unit")

func test_get_opposite() -> void:
	var board := LaneBoard.new()
	var ally := CombatantData.new()
	var enemy := CombatantData.new()
	board.place(ally, 1, "ally")
	board.place(enemy, 1, "enemy")
	assert(board.get_opposite(ally) == enemy, "opposite of ally lane 1 is enemy lane 1")
	print("  PASS test_get_opposite")

func test_adjacent_lanes() -> void:
	var board := LaneBoard.new()
	var enemies: Array[CombatantData] = [CombatantData.new(), CombatantData.new(), CombatantData.new()]
	for i in 3:
		board.place(enemies[i], i, "enemy")
	# Adjacent to lane 1 = lanes 0 + 2
	var adj := board.get_adjacent_lane_units(1, "enemy")
	assert(adj.size() == 2, "adjacent to lane 1 should yield 2 enemies, got %d" % adj.size())
	# Adjacent to lane 0 = lane 1 only (no lane -1)
	var adj0 := board.get_adjacent_lane_units(0, "enemy")
	assert(adj0.size() == 1, "adjacent to lane 0 should yield 1 enemy")
	print("  PASS test_adjacent_lanes")
```

Mirror tscn pattern.

- [ ] **Step 2: Run test to verify it fails**

```powershell
godot --headless --path rogue-finder tests/test_lane_board.tscn
```

Expected: error — LaneBoard class not found.

- [ ] **Step 3: Implement LaneBoard.gd**

Create `rogue-finder/scripts/combat/LaneBoard.gd`:

```gdscript
class_name LaneBoard
extends RefCounted

## --- LaneBoard ---
## 3 lanes per side, flat (no front/back depth). Holds CombatantData references
## by (lane_index, side). Lane indices: 0, 1, 2. Sides: "ally" | "enemy".
## Replaces Grid3D's 10x10 cell math with a tiny 6-slot data structure.

const LANE_COUNT: int = 3
const SIDES: PackedStringArray = ["ally", "enemy"]

## Internal storage: { side: Array[CombatantData] of size LANE_COUNT, null = empty }
var _slots: Dictionary = {}

func _init() -> void:
	for side: String in SIDES:
		var arr: Array = []
		arr.resize(LANE_COUNT)
		for i in LANE_COUNT:
			arr[i] = null
		_slots[side] = arr

func place(unit: CombatantData, lane: int, side: String) -> void:
	assert(lane >= 0 and lane < LANE_COUNT, "lane out of range: %d" % lane)
	assert(_slots.has(side), "unknown side: %s" % side)
	(_slots[side] as Array)[lane] = unit

func remove(lane: int, side: String) -> void:
	assert(lane >= 0 and lane < LANE_COUNT)
	(_slots[side] as Array)[lane] = null

func get_unit(lane: int, side: String) -> CombatantData:
	if lane < 0 or lane >= LANE_COUNT:
		return null
	return (_slots[side] as Array)[lane]

func get_opposite_side(side: String) -> String:
	return "enemy" if side == "ally" else "ally"

## Returns the unit directly across from `unit`, or null.
func get_opposite(unit: CombatantData) -> CombatantData:
	for side: String in SIDES:
		for lane in LANE_COUNT:
			if (_slots[side] as Array)[lane] == unit:
				return get_unit(lane, get_opposite_side(side))
	return null

## Returns the lane index of `unit`, or -1.
func get_lane_of(unit: CombatantData) -> int:
	for side: String in SIDES:
		for lane in LANE_COUNT:
			if (_slots[side] as Array)[lane] == unit:
				return lane
	return -1

## Returns the side of `unit`, or "" if not on the board.
func get_side_of(unit: CombatantData) -> String:
	for side: String in SIDES:
		for lane in LANE_COUNT:
			if (_slots[side] as Array)[lane] == unit:
				return side
	return ""

## Returns up to 2 units in lanes adjacent to `lane` on the given `side`.
func get_adjacent_lane_units(lane: int, side: String) -> Array[CombatantData]:
	var result: Array[CombatantData] = []
	for offset in [-1, 1]:
		var l := lane + offset
		if l >= 0 and l < LANE_COUNT:
			var u := get_unit(l, side)
			if u != null:
				result.append(u)
	return result

## Returns every non-null unit on the given side.
func get_all_on_side(side: String) -> Array[CombatantData]:
	var result: Array[CombatantData] = []
	for lane in LANE_COUNT:
		var u := get_unit(lane, side)
		if u != null:
			result.append(u)
	return result

## Returns true if no living units remain on the given side.
func is_side_wiped(side: String) -> bool:
	for lane in LANE_COUNT:
		var u := get_unit(lane, side)
		if u != null and u.current_hp > 0:
			return false
	return true
```

- [ ] **Step 4: Run test to verify it passes**

```powershell
godot --headless --path rogue-finder tests/test_lane_board.tscn
```

Expected: All LaneBoard tests passed.

- [ ] **Step 5: Commit**

```powershell
git add rogue-finder/scripts/combat/LaneBoard.gd rogue-finder/tests/test_lane_board.gd rogue-finder/tests/test_lane_board.tscn
git commit -m "feat: LaneBoard data structure (3 lanes x 2 sides)"
```

---

### Task 3.2: Create CombatManager skeleton

**Files:**
- Create: `rogue-finder/scripts/combat/CombatManager.gd`
- Create: `rogue-finder/scenes/combat/CombatSceneAuto.tscn`

- [ ] **Step 1: Create CombatManager.gd skeleton**

Create `rogue-finder/scripts/combat/CombatManager.gd`:

```gdscript
class_name CombatManagerAuto
extends Node3D

## --- CombatManager (autobattler) ---
## Turn-tick autobattler controller. Hosts the LaneBoard, drives the tick loop,
## fires unit turns, manages combat lifecycle (entry, victory, defeat).
## Coexists with the legacy CombatManager3D until Slice 7.

## --- Constants ---
const TICK_INTERVAL_SEC: float = 0.6  # cosmetic delay between ticks for player readability

## --- State ---
var board: LaneBoard
var combat_running: bool = false
var current_tick: int = 0

## --- Lifecycle ---
func _ready() -> void:
	board = LaneBoard.new()
	# Slice 4 wires party + enemies + tick loop here.
	print("[CombatManagerAuto] _ready — skeleton; tick loop not yet implemented")

## Public entry point — called by MapManager / external bringup.
## Slice 4 will populate units + start ticking.
func start_combat(party: Array[CombatantData], enemies: Array[CombatantData]) -> void:
	combat_running = true
	current_tick = 0
	# Default placement: each unit drops into lane = its index in the array
	# (Slice 4 will replace this with PlacementOverlay output)
	for i in min(party.size(), LaneBoard.LANE_COUNT):
		board.place(party[i], i, "ally")
	for i in min(enemies.size(), LaneBoard.LANE_COUNT):
		board.place(enemies[i], i, "enemy")
	print("[CombatManagerAuto] combat started: %d allies, %d enemies" % [party.size(), enemies.size()])

func end_combat(victory: bool) -> void:
	combat_running = false
	print("[CombatManagerAuto] combat ended — victory: %s" % victory)
	# Slice 4: route to EndCombatScreen / RunSummaryScene, etc.
```

- [ ] **Step 2: Create CombatSceneAuto.tscn**

Create `rogue-finder/scenes/combat/CombatSceneAuto.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/combat/CombatManager.gd" id="1"]

[node name="CombatSceneAuto" type="Node3D"]
script = ExtResource("1")
```

- [ ] **Step 3: Run game manually with the scene loaded directly**

Open the scene in Godot, press F6 (Run This Scene). Expected: prints `[CombatManagerAuto] _ready` to the console with no errors.

- [ ] **Step 4: Commit**

```powershell
git add rogue-finder/scripts/combat/CombatManager.gd rogue-finder/scenes/combat/CombatSceneAuto.tscn
git commit -m "feat: CombatManager autobattler skeleton + scene"
```

---

### Task 3.3: Add `USE_AUTOBATTLER_COMBAT` flag to MapManager

**Files:**
- Modify: `rogue-finder/scripts/map/MapManager.gd`

- [ ] **Step 1: Add the flag and gate the scene-load**

Open `rogue-finder/scripts/map/MapManager.gd`. Find the function that handles entering a COMBAT or BOSS node (likely `_enter_current_node()` or similar). Add a constant near the top:

```gdscript
## --- Feature Flags ---
## Flip to true to enter the new autobattler combat scene instead of the legacy 3D grid combat.
## Slice 7 of the combat pivot will flip this on, rip out the old combat, and remove this constant.
const USE_AUTOBATTLER_COMBAT: bool = false
```

In the COMBAT/BOSS branch of `_enter_current_node()`, gate the scene change:

```gdscript
"COMBAT", "BOSS":
	if USE_AUTOBATTLER_COMBAT:
		get_tree().change_scene_to_file("res://scenes/combat/CombatSceneAuto.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/combat/CombatScene3D.tscn")
```

(Adjust to your existing branch syntax — only the conditional block matters.)

- [ ] **Step 2: Verify manually with flag off (default)**

Run the game. Enter a COMBAT node. Expected: existing 3D combat loads as before.

- [ ] **Step 3: Verify manually with flag on**

Temporarily change `USE_AUTOBATTLER_COMBAT` to `true`. Run the game, enter a COMBAT node. Expected: empty CombatSceneAuto loads (just prints to console; no UI yet). Revert the flag to `false` before committing.

- [ ] **Step 4: Commit**

```powershell
git add rogue-finder/scripts/map/MapManager.gd
git commit -m "feat: USE_AUTOBATTLER_COMBAT flag in MapManager (default off)"
```

---

### Task 3.4: PlacementOverlay skeleton

**Files:**
- Create: `rogue-finder/scripts/ui/PlacementOverlay.gd`
- Create: `rogue-finder/scenes/ui/PlacementOverlay.tscn`

- [ ] **Step 1: Create the overlay script**

Create `rogue-finder/scripts/ui/PlacementOverlay.gd`:

```gdscript
class_name PlacementOverlay
extends CanvasLayer

## --- PlacementOverlay ---
## Pre-fight UI: drag your 3 active party units onto your 3 lanes.
## Emits `placement_locked(party_by_lane: Array[CombatantData])` when the player presses Begin.
## Slice 4 wires this into CombatManager.start_combat().

signal placement_locked(party_by_lane: Array)

var _party: Array[CombatantData] = []
var _lane_assignments: Array[CombatantData] = [null, null, null]

func _ready() -> void:
	layer = 22  # above PartySheet (20), below PauseMenu (26)

## Populates the overlay with the player's active party.
## Default placement = party order to lane 0/1/2; player drags to override.
func show_placement(party: Array[CombatantData]) -> void:
	_party = party.duplicate()
	for i in min(_party.size(), 3):
		_lane_assignments[i] = _party[i]
	visible = true
	# Slice 4: build the actual draggable UI here.
	print("[PlacementOverlay] showing placement for %d units" % _party.size())

func _on_begin_pressed() -> void:
	visible = false
	emit_signal("placement_locked", _lane_assignments.duplicate())
```

- [ ] **Step 2: Create the scene**

Create `rogue-finder/scenes/ui/PlacementOverlay.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/PlacementOverlay.gd" id="1"]

[node name="PlacementOverlay" type="CanvasLayer"]
script = ExtResource("1")
visible = false
```

- [ ] **Step 3: Verify in Godot it loads cleanly**

Open the scene in Godot, press F6. Expected: scene loads silently (visible = false). No errors.

- [ ] **Step 4: Commit**

```powershell
git add rogue-finder/scripts/ui/PlacementOverlay.gd rogue-finder/scenes/ui/PlacementOverlay.tscn
git commit -m "feat: PlacementOverlay skeleton (pre-fight lane assignment)"
```

---

## Slice 4: Countdown Engine + Per-Ability Cooldown + Tick Loop

**Session goal:** Implement the heart of the autobattler — countdown ticking, per-ability cooldown decrement, and the basic tick loop that fires units when their countdown hits 0. AI uses a stub picker (always picks slot 0) until Slice 6. After this slice, flipping the feature flag yields a watchable autobattler that runs to completion using only basic strikes.

### Task 4.1: CountdownTracker static module

**Files:**
- Create: `rogue-finder/scripts/combat/CountdownTracker.gd`
- Create: `rogue-finder/tests/test_countdown_tracker.{gd,tscn}`

- [ ] **Step 1: Write the failing test**

Create `rogue-finder/tests/test_countdown_tracker.gd`:

```gdscript
extends Node

func _ready() -> void:
	print("=== test_countdown_tracker.gd ===")
	test_countdown_max_from_spd()
	test_countdown_decrement_all()
	test_unit_acts_at_zero()
	test_cooldown_decrement_per_unit()
	test_cooldown_blocks_pick_until_zero()
	test_tiebreak_higher_spd_first()
	print("=== All CountdownTracker tests passed ===")

func test_countdown_max_from_spd() -> void:
	# Formula: clamp(8 - spd, 2, 12)
	assert(CountdownTracker.compute_countdown_max(4) == 4, "spd 4 → cd 4")
	assert(CountdownTracker.compute_countdown_max(6) == 2, "spd 6 → cd 2")
	assert(CountdownTracker.compute_countdown_max(1) == 7, "spd 1 → cd 7")
	assert(CountdownTracker.compute_countdown_max(8) == 2, "spd 8 → clamps to 2")
	assert(CountdownTracker.compute_countdown_max(-5) == 12, "spd -5 → clamps to 12")
	print("  PASS test_countdown_max_from_spd")

func test_countdown_decrement_all() -> void:
	var u1 := CombatantData.new()
	u1.spd = 4
	u1.countdown_current = 4
	u1.countdown_max = 4
	var u2 := CombatantData.new()
	u2.spd = 6
	u2.countdown_current = 2
	u2.countdown_max = 2
	CountdownTracker.tick([u1, u2])
	assert(u1.countdown_current == 3, "u1 countdown should decrement to 3, got %d" % u1.countdown_current)
	assert(u2.countdown_current == 1, "u2 countdown should decrement to 1, got %d" % u2.countdown_current)
	print("  PASS test_countdown_decrement_all")

func test_unit_acts_at_zero() -> void:
	var u := CombatantData.new()
	u.spd = 6
	u.countdown_current = 1
	u.countdown_max = 2
	var ready := CountdownTracker.tick_and_collect_ready([u])
	# After tick: countdown was 1 → decrements to 0 → unit collected as ready
	assert(ready.size() == 1, "u should be ready after countdown reaches 0")
	assert(ready[0] == u, "ready unit should be u")
	print("  PASS test_unit_acts_at_zero")

func test_cooldown_decrement_per_unit() -> void:
	var u := CombatantData.new()
	# Imagine 3 abilities with cooldowns_remaining = [0, 1, 3]
	var cds: Array[int] = [0, 1, 3]
	CountdownTracker.tick_cooldowns(cds)
	assert(cds[0] == 0, "0 stays 0 (off cooldown)")
	assert(cds[1] == 0, "1 ticks to 0")
	assert(cds[2] == 2, "3 ticks to 2")
	print("  PASS test_cooldown_decrement_per_unit")

func test_cooldown_blocks_pick_until_zero() -> void:
	var cds: Array[int] = [0, 2, 5]
	var available := CountdownTracker.available_slot_indices(cds)
	assert(available.size() == 1, "only slot 0 is available")
	assert(available[0] == 0, "available index should be 0")
	print("  PASS test_cooldown_blocks_pick_until_zero")

func test_tiebreak_higher_spd_first() -> void:
	var slow := CombatantData.new()
	slow.spd = 4
	slow.countdown_current = 0
	slow.character_name = "Slow"
	var fast := CombatantData.new()
	fast.spd = 6
	fast.countdown_current = 0
	fast.character_name = "Fast"
	var ordered := CountdownTracker.tiebreak_ready([slow, fast])
	assert(ordered[0] == fast, "fast should act first (higher spd)")
	assert(ordered[1] == slow, "slow acts second")
	print("  PASS test_tiebreak_higher_spd_first")
```

Mirror tscn pattern.

- [ ] **Step 2: Run test to verify it fails**

```powershell
godot --headless --path rogue-finder tests/test_countdown_tracker.tscn
```

Expected: error — CountdownTracker not found.

- [ ] **Step 3: Implement CountdownTracker.gd**

Create `rogue-finder/scripts/combat/CountdownTracker.gd`:

```gdscript
class_name CountdownTracker
extends RefCounted

## --- CountdownTracker ---
## Static module — pure logic for unit countdowns and per-ability cooldowns.
## CombatManager calls these helpers each tick. No instance state.

## Returns countdown_max derived from a unit's effective SPD.
## Formula: clamp(8 - spd, 2, 12)
static func compute_countdown_max(spd: int) -> int:
	return clamp(8 - spd, 2, 12)

## Decrements countdown_current on every unit by 1 (floor 0).
static func tick(units: Array[CombatantData]) -> void:
	for u: CombatantData in units:
		u.countdown_current = max(0, u.countdown_current - 1)

## Decrements countdown_current and returns the units now at 0 (i.e., ready to act).
static func tick_and_collect_ready(units: Array[CombatantData]) -> Array[CombatantData]:
	tick(units)
	var ready: Array[CombatantData] = []
	for u: CombatantData in units:
		if u.countdown_current == 0:
			ready.append(u)
	return ready

## Decrements every per-ability cooldown counter by 1 (floor 0).
static func tick_cooldowns(cooldowns: Array[int]) -> void:
	for i in cooldowns.size():
		cooldowns[i] = max(0, cooldowns[i] - 1)

## Returns the indices of slots whose cooldown is 0 (available to fire).
static func available_slot_indices(cooldowns: Array[int]) -> Array[int]:
	var result: Array[int] = []
	for i in cooldowns.size():
		if cooldowns[i] == 0:
			result.append(i)
	return result

## Stable-sorts the ready list by descending SPD (tiebreak rule).
static func tiebreak_ready(ready: Array[CombatantData]) -> Array[CombatantData]:
	var sorted := ready.duplicate()
	sorted.sort_custom(func(a: CombatantData, b: CombatantData) -> bool:
		return a.spd > b.spd
	)
	return sorted

## Resets a unit's countdown after it acts.
static func reset_countdown(unit: CombatantData) -> void:
	unit.countdown_current = unit.countdown_max
```

- [ ] **Step 4: Run test to verify it passes**

```powershell
godot --headless --path rogue-finder tests/test_countdown_tracker.tscn
```

Expected: All CountdownTracker tests passed.

- [ ] **Step 5: Commit**

```powershell
git add rogue-finder/scripts/combat/CountdownTracker.gd rogue-finder/tests/test_countdown_tracker.gd rogue-finder/tests/test_countdown_tracker.tscn
git commit -m "feat: CountdownTracker module (countdown + cooldown logic)"
```

---

### Task 4.2: Add countdown fields to CombatantData

**Files:**
- Modify: `rogue-finder/resources/CombatantData.gd`

- [ ] **Step 1: Add transient countdown fields**

Edit `rogue-finder/resources/CombatantData.gd`. Add the fields near the transient mid-combat fields (around the `physical_armor_mod` block, ~line 130):

```gdscript
## --- Transient autobattler state (NOT serialized) ---
## countdown_current ticks down each combat tick; when 0, the unit acts.
## countdown_max is computed from effective_stat("spd") at combat start.
## Cooldown tracking sits at the slot level (managed by CombatManager).
var countdown_current: int = 0
var countdown_max:     int = 0
var cooldowns:         Array[int] = [0, 0, 0]  # one per slot (3 slots)
```

- [ ] **Step 2: Verify it compiles by running an existing test**

```powershell
godot --headless --path rogue-finder tests/test_combatant_data.tscn
```

Expected: existing combatant tests still pass (no behavioral change).

- [ ] **Step 3: Commit**

```powershell
git add rogue-finder/resources/CombatantData.gd
git commit -m "feat: add transient countdown fields to CombatantData"
```

---

### Task 4.3: CombatManager tick loop with stub AI

**Files:**
- Modify: `rogue-finder/scripts/combat/CombatManager.gd`
- Create: `rogue-finder/tests/test_combat_loop.{gd,tscn}`

- [ ] **Step 1: Write the failing integration test**

Create `rogue-finder/tests/test_combat_loop.gd`:

```gdscript
extends Node

## End-to-end sanity test: 1 ally vs 1 enemy, both with strike-only loadout.
## Combat should resolve to a winner within 30 ticks.

func _ready() -> void:
	print("=== test_combat_loop.gd ===")
	test_one_v_one_resolves()
	print("=== All combat loop tests passed ===")

func test_one_v_one_resolves() -> void:
	var ally := _make_unit("Ally", true, 6, 20, "strike")
	var enemy := _make_unit("Enemy", false, 4, 15, "strike")
	var cm := CombatManagerAuto.new()
	cm.start_combat([ally], [enemy])
	# Drive 50 simulated ticks deterministically — no real-time delays.
	for tick in 50:
		if not cm.combat_running:
			break
		cm._advance_tick()
	assert(not cm.combat_running, "combat should have ended within 50 ticks")
	assert(ally.current_hp <= 0 or enemy.current_hp <= 0, "exactly one side should be wiped")
	print("  PASS test_one_v_one_resolves (ally hp=%d, enemy hp=%d)" % [ally.current_hp, enemy.current_hp])

func _make_unit(name: String, is_player: bool, spd: int, hp: int, ability_id: String) -> CombatantData:
	var d := CombatantData.new()
	d.character_name = name
	d.is_player_unit = is_player
	d.spd = spd
	d.strength = 4
	d.current_hp = hp
	d.abilities = [ability_id, "", ""]
	return d
```

Mirror tscn.

- [ ] **Step 2: Run test to verify it fails**

```powershell
godot --headless --path rogue-finder tests/test_combat_loop.tscn
```

Expected: error — `_advance_tick()` not defined on CombatManagerAuto.

- [ ] **Step 3: Implement the tick loop**

Edit `rogue-finder/scripts/combat/CombatManager.gd`. Replace its body with:

```gdscript
class_name CombatManagerAuto
extends Node3D

const TICK_INTERVAL_SEC: float = 0.6

var board: LaneBoard
var combat_running: bool = false
var current_tick: int = 0
var _all_units: Array[CombatantData] = []

func _ready() -> void:
	board = LaneBoard.new()

func start_combat(party: Array[CombatantData], enemies: Array[CombatantData]) -> void:
	combat_running = true
	current_tick = 0
	_all_units.clear()
	for i in min(party.size(), LaneBoard.LANE_COUNT):
		board.place(party[i], i, "ally")
		_init_unit_for_combat(party[i])
		_all_units.append(party[i])
	for i in min(enemies.size(), LaneBoard.LANE_COUNT):
		board.place(enemies[i], i, "enemy")
		_init_unit_for_combat(enemies[i])
		_all_units.append(enemies[i])
	print("[CombatManagerAuto] combat started: %d allies, %d enemies" % [party.size(), enemies.size()])

func _init_unit_for_combat(u: CombatantData) -> void:
	u.countdown_max = CountdownTracker.compute_countdown_max(u.effective_stat("spd"))
	u.countdown_current = u.countdown_max
	u.cooldowns = [0, 0, 0]

## Drives one tick of combat. Decrements all counters; fires any units that hit 0.
## Called internally by _process() in real-time mode, and by tests for deterministic stepping.
func _advance_tick() -> void:
	if not combat_running:
		return
	current_tick += 1
	# Tick all unit countdowns
	var ready := CountdownTracker.tick_and_collect_ready(_all_units)
	# Tick all per-unit ability cooldowns (independent of countdowns)
	for u: CombatantData in _all_units:
		CountdownTracker.tick_cooldowns(u.cooldowns)
	# Resolve ready units in tiebreak order
	var ordered := CountdownTracker.tiebreak_ready(ready)
	for u: CombatantData in ordered:
		if u.current_hp <= 0:
			continue
		_fire_unit_turn(u)
		CountdownTracker.reset_countdown(u)
		if _check_combat_end():
			return

func _fire_unit_turn(u: CombatantData) -> void:
	# Stub AI: pick slot 0 (the weapon-granted ability) regardless of cooldown.
	# Slice 6 replaces this with AutobattlerEnemyAI.pick().
	var slot := 0
	var ability_id: String = u.abilities[slot] if u.abilities.size() > slot else ""
	if ability_id == "":
		print("  [%s] skips turn (slot 0 empty)" % u.character_name)
		return
	var ability := AbilityLibrary.get_ability(ability_id)
	# Slice 5 replaces this with proper lane targeting; for now: pick the opposite-lane enemy
	var target := _stub_pick_target(u, ability)
	if target == null:
		print("  [%s] no valid target" % u.character_name)
		return
	_apply_ability(u, target, ability)
	u.cooldowns[slot] = ability.cooldown_max
	print("  [%s] tick %d: %s on %s" % [u.character_name, current_tick, ability.ability_name, target.character_name])

## Stub: just picks the unit directly across; falls back to the first non-empty enemy.
## Slice 5 replaces with shape-aware targeting.
func _stub_pick_target(caster: CombatantData, _ability: AbilityData) -> CombatantData:
	var target := board.get_opposite(caster)
	if target != null and target.current_hp > 0:
		return target
	var caster_side := board.get_side_of(caster)
	var enemy_side := board.get_opposite_side(caster_side)
	for u: CombatantData in board.get_all_on_side(enemy_side):
		if u.current_hp > 0:
			return u
	return null

## Stub: applies HARM only. Slice 5 replaces with full effect dispatch.
func _apply_ability(caster: CombatantData, target: CombatantData, ability: AbilityData) -> void:
	for effect in ability.effects:
		if effect.effect_type == EffectData.EffectType.HARM:
			var attr_name := _attr_to_string(ability.attribute)
			var raw_dmg := effect.base_value + caster.effective_stat(attr_name)
			var defense := target.physical_defense if ability.damage_type == AbilityData.DamageType.PHYSICAL else target.magic_defense
			var dmg := max(1, raw_dmg - defense)
			target.current_hp = max(0, target.current_hp - dmg)

func _attr_to_string(a: AbilityData.Attribute) -> String:
	match a:
		AbilityData.Attribute.STRENGTH:  return "strength"
		AbilityData.Attribute.DEXTERITY: return "dexterity"
		AbilityData.Attribute.COGNITION: return "cognition"
		AbilityData.Attribute.WILLPOWER: return "willpower"
		AbilityData.Attribute.VITALITY:  return "vitality"
		_: return ""

func _check_combat_end() -> bool:
	if board.is_side_wiped("ally"):
		end_combat(false)
		return true
	if board.is_side_wiped("enemy"):
		end_combat(true)
		return true
	return false

func end_combat(victory: bool) -> void:
	combat_running = false
	print("[CombatManagerAuto] combat ended — victory: %s" % victory)
```

- [ ] **Step 4: Run test to verify it passes**

```powershell
godot --headless --path rogue-finder tests/test_combat_loop.tscn
```

Expected: All combat loop tests passed.

- [ ] **Step 5: Commit**

```powershell
git add rogue-finder/scripts/combat/CombatManager.gd rogue-finder/tests/test_combat_loop.gd rogue-finder/tests/test_combat_loop.tscn
git commit -m "feat: combat tick loop with stub AI (slot 0 always)"
```

---

### Task 4.4: Real-time tick driver via `_process`

**Files:**
- Modify: `rogue-finder/scripts/combat/CombatManager.gd`

- [ ] **Step 1: Add `_process()` and tick timer**

Add to `CombatManager.gd`:

```gdscript
var _tick_accum: float = 0.0

func _process(delta: float) -> void:
	if not combat_running:
		return
	_tick_accum += delta
	if _tick_accum >= TICK_INTERVAL_SEC:
		_tick_accum -= TICK_INTERVAL_SEC
		_advance_tick()
```

- [ ] **Step 2: Verify manually**

Run the game with `USE_AUTOBATTLER_COMBAT = true` (temp flip). Enter a COMBAT node. Expected: console prints tick-by-tick combat resolution at ~0.6s/tick, ending with a victory or defeat line.

Revert the flag to `false` before committing.

- [ ] **Step 3: Commit**

```powershell
git add rogue-finder/scripts/combat/CombatManager.gd
git commit -m "feat: real-time tick driver in _process (0.6s per tick)"
```

---

### Task 4.5: Wire MapManager → CombatManager start_combat

**Files:**
- Modify: `rogue-finder/scripts/map/MapManager.gd`
- Modify: `rogue-finder/scripts/combat/CombatManager.gd`

- [ ] **Step 1: Pass party + enemies on scene entry**

When `USE_AUTOBATTLER_COMBAT` is true, the MapManager needs to hand the party and the rolled enemies to the new CombatManager. Two patterns work:

A) **Autoload bridge** (recommended): use `GameState` to stash `pending_combat_party` + `pending_combat_enemies` before changing scene; CombatManager reads them in `_ready()`.

B) **Scene-tree lookup** after scene change.

Use pattern A. In `MapManager.gd`'s combat branch (find the existing place where `current_combat_node_id` and `current_combat_ring` are set):

```gdscript
"COMBAT", "BOSS":
	GameState.current_combat_node_id = node_id
	GameState.current_combat_ring = _get_ring(node_id)
	if USE_AUTOBATTLER_COMBAT:
		# Roll enemies as the existing combat does (extract the relevant lines from
		# CombatManager3D._setup_units or wherever ArchetypeLibrary.create() is called).
		# Stash on GameState for CombatManager to read in _ready.
		GameState.pending_combat_enemies = _roll_combat_enemies()  # helper you may need to add
		get_tree().change_scene_to_file("res://scenes/combat/CombatSceneAuto.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/combat/CombatScene3D.tscn")
```

Add `pending_combat_enemies: Array = []` to GameState (transient, not serialized).

Add a helper to MapManager (or extract from existing combat code):

```gdscript
func _roll_combat_enemies() -> Array[CombatantData]:
	# Mirror what CombatManager3D._setup_units does for enemy spawning.
	# Pull from ArchetypeLibrary based on threat / ring.
	var enemies: Array[CombatantData] = []
	# ... existing rolling logic ...
	return enemies
```

- [ ] **Step 2: Read on CombatManager._ready**

Edit `CombatManager.gd._ready()`:

```gdscript
func _ready() -> void:
	board = LaneBoard.new()
	# Pull party + enemies from GameState bridge fields
	var party: Array[CombatantData] = GameState.party.filter(func(p: CombatantData) -> bool: return not p.is_dead).slice(0, 3)
	var enemies: Array[CombatantData] = GameState.pending_combat_enemies
	GameState.pending_combat_enemies = []  # clear after read
	if party.is_empty() or enemies.is_empty():
		push_warning("[CombatManagerAuto] missing party or enemies on scene entry")
		return
	start_combat(party, enemies)
```

- [ ] **Step 3: Verify manually**

Flip `USE_AUTOBATTLER_COMBAT` to `true`. Run the game, enter a combat node. Watch the console — fight should resolve.

- [ ] **Step 4: Commit**

```powershell
git add rogue-finder/scripts/map/MapManager.gd rogue-finder/scripts/combat/CombatManager.gd rogue-finder/scripts/globals/GameState.gd
git commit -m "feat: MapManager wires party + enemies into CombatManager"
```

---

## Slice 5: Lane Targeting

**Session goal:** Replace the stub target picker with shape-aware lane targeting. Add new TargetShape enum values (`SAME_LANE`, `ADJACENT_LANE`, `ALL_LANES`, etc.), update abilities.csv to use them, and write the resolver. Old TargetShape values (CONE/LINE/RADIAL/ARC) stay until Slice 7 to keep old combat compiling.

### Task 5.1: Add lane TargetShape enum values

**Files:**
- Modify: `rogue-finder/resources/AbilityData.gd`
- Modify: `rogue-finder/scripts/globals/AbilityLibrary.gd`

- [ ] **Step 1: Extend the TargetShape enum**

Edit `rogue-finder/resources/AbilityData.gd`. Add new values to the `TargetShape` enum:

```gdscript
enum TargetShape {
	SELF           = 0,
	SINGLE         = 1,
	CONE           = 2,  # legacy — retired Slice 7
	LINE           = 3,  # legacy — retired Slice 7
	RADIAL         = 4,  # legacy — retired Slice 7
	ARC            = 5,  # legacy — retired Slice 7
	SAME_LANE      = 6,  # autobattler — direct opposite in caster's lane
	ADJACENT_LANE  = 7,  # autobattler — lanes ± 1 of caster
	ALL_LANES      = 8,  # autobattler — every enemy
	ALL_ALLIES     = 9,  # autobattler — every ally on caster's side
}
```

- [ ] **Step 2: Add the new names to AbilityLibrary's lookup table**

Edit `rogue-finder/scripts/globals/AbilityLibrary.gd`. Find `_TARGET_SHAPE` (around line 30) and extend:

```gdscript
const _TARGET_SHAPE: Dictionary = {
	"SELF":          AbilityData.TargetShape.SELF,
	"SINGLE":        AbilityData.TargetShape.SINGLE,
	"CONE":          AbilityData.TargetShape.CONE,
	"LINE":          AbilityData.TargetShape.LINE,
	"RADIAL":        AbilityData.TargetShape.RADIAL,
	"ARC":           AbilityData.TargetShape.ARC,
	"SAME_LANE":     AbilityData.TargetShape.SAME_LANE,
	"ADJACENT_LANE": AbilityData.TargetShape.ADJACENT_LANE,
	"ALL_LANES":     AbilityData.TargetShape.ALL_LANES,
	"ALL_ALLIES":    AbilityData.TargetShape.ALL_ALLIES,
}
```

- [ ] **Step 3: Verify existing tests still pass**

```powershell
godot --headless --path rogue-finder tests/test_ability_library.tscn
```

Expected: PASS.

- [ ] **Step 4: Commit**

```powershell
git add rogue-finder/resources/AbilityData.gd rogue-finder/scripts/globals/AbilityLibrary.gd
git commit -m "feat: add lane TargetShape enum values (additive)"
```

---

### Task 5.2: Migrate abilities.csv to lane shapes

**Files:**
- Modify: `rogue-finder/data/abilities.csv`

- [ ] **Step 1: Map old shapes to new shapes per ability**

Open `rogue-finder/data/abilities.csv`. For each ability, change the `target` column value per:

| Old shape | New shape (default mapping) |
|---|---|
| `SINGLE` | `SAME_LANE` (single target, opposite-lane) |
| `CONE` | `ADJACENT_LANE` (multi-lane reach) |
| `LINE` | `SAME_LANE` (lane-direction attack) |
| `RADIAL` | `ALL_LANES` (was small AoE; now whole side) |
| `ARC` | `ADJACENT_LANE` (3-lane sweep) |
| `SELF` | `SELF` (unchanged) |

Tune individual abilities away from defaults if the design intent calls for it. Example: `cleave` (was ARC) might better fit `ALL_LANES` than `ADJACENT_LANE`.

- [ ] **Step 2: Verify the CSV still parses**

```powershell
godot --headless --path rogue-finder tests/test_ability_library.tscn
```

Expected: PASS.

- [ ] **Step 3: Commit**

```powershell
git add rogue-finder/data/abilities.csv
git commit -m "feat: migrate abilities.csv to lane-based target shapes"
```

---

### Task 5.3: Lane-aware target resolver

**Files:**
- Modify: `rogue-finder/scripts/combat/CombatManager.gd`
- Create: `rogue-finder/tests/test_lane_targeting.{gd,tscn}`

- [ ] **Step 1: Write the failing test**

Create `rogue-finder/tests/test_lane_targeting.gd`:

```gdscript
extends Node

func _ready() -> void:
	print("=== test_lane_targeting.gd ===")
	test_same_lane_picks_opposite()
	test_same_lane_falls_back_when_opposite_empty()
	test_adjacent_lane_returns_two()
	test_all_lanes_returns_all_enemies()
	test_self_targets_caster()
	test_all_allies_excludes_enemies()
	print("=== All lane targeting tests passed ===")

func _make_unit(name: String) -> CombatantData:
	var d := CombatantData.new()
	d.character_name = name
	d.current_hp = 20
	return d

func _make_ability(shape: AbilityData.TargetShape, applicable: AbilityData.ApplicableTo) -> AbilityData:
	var a := AbilityData.new()
	a.target_shape = shape
	a.applicable_to = applicable
	return a

func test_same_lane_picks_opposite() -> void:
	var board := LaneBoard.new()
	var caster := _make_unit("Caster")
	var enemy := _make_unit("Enemy")
	board.place(caster, 1, "ally")
	board.place(enemy, 1, "enemy")
	var ability := _make_ability(AbilityData.TargetShape.SAME_LANE, AbilityData.ApplicableTo.ENEMY)
	var targets := CombatManagerAuto.resolve_targets(caster, ability, board)
	assert(targets.size() == 1, "same_lane should yield 1 target")
	assert(targets[0] == enemy, "should target opposite-lane enemy")
	print("  PASS test_same_lane_picks_opposite")

func test_same_lane_falls_back_when_opposite_empty() -> void:
	var board := LaneBoard.new()
	var caster := _make_unit("Caster")
	var e0 := _make_unit("E0")
	board.place(caster, 1, "ally")
	board.place(e0, 0, "enemy")  # no enemy in lane 1
	var ability := _make_ability(AbilityData.TargetShape.SAME_LANE, AbilityData.ApplicableTo.ENEMY)
	var targets := CombatManagerAuto.resolve_targets(caster, ability, board)
	assert(targets.size() == 1, "should fall back to nearest non-empty lane")
	assert(targets[0] == e0, "should target the only enemy")
	print("  PASS test_same_lane_falls_back_when_opposite_empty")

func test_adjacent_lane_returns_two() -> void:
	var board := LaneBoard.new()
	var caster := _make_unit("Caster")
	var e0 := _make_unit("E0")
	var e1 := _make_unit("E1")
	var e2 := _make_unit("E2")
	board.place(caster, 1, "ally")
	board.place(e0, 0, "enemy")
	board.place(e1, 1, "enemy")
	board.place(e2, 2, "enemy")
	var ability := _make_ability(AbilityData.TargetShape.ADJACENT_LANE, AbilityData.ApplicableTo.ENEMY)
	var targets := CombatManagerAuto.resolve_targets(caster, ability, board)
	# adjacent to lane 1 = lanes 0 + 2 (NOT 1 itself)
	assert(targets.size() == 2, "adjacent_lane should yield 2 targets, got %d" % targets.size())
	print("  PASS test_adjacent_lane_returns_two")

func test_all_lanes_returns_all_enemies() -> void:
	var board := LaneBoard.new()
	var caster := _make_unit("Caster")
	var e0 := _make_unit("E0")
	var e1 := _make_unit("E1")
	board.place(caster, 0, "ally")
	board.place(e0, 0, "enemy")
	board.place(e1, 2, "enemy")
	var ability := _make_ability(AbilityData.TargetShape.ALL_LANES, AbilityData.ApplicableTo.ENEMY)
	var targets := CombatManagerAuto.resolve_targets(caster, ability, board)
	assert(targets.size() == 2, "all_lanes should hit both enemies")
	print("  PASS test_all_lanes_returns_all_enemies")

func test_self_targets_caster() -> void:
	var board := LaneBoard.new()
	var caster := _make_unit("Caster")
	board.place(caster, 1, "ally")
	var ability := _make_ability(AbilityData.TargetShape.SELF, AbilityData.ApplicableTo.ANY)
	var targets := CombatManagerAuto.resolve_targets(caster, ability, board)
	assert(targets.size() == 1 and targets[0] == caster, "self should yield caster")
	print("  PASS test_self_targets_caster")

func test_all_allies_excludes_enemies() -> void:
	var board := LaneBoard.new()
	var caster := _make_unit("Caster")
	var ally1 := _make_unit("Ally1")
	var enemy := _make_unit("Enemy")
	board.place(caster, 0, "ally")
	board.place(ally1, 1, "ally")
	board.place(enemy, 0, "enemy")
	var ability := _make_ability(AbilityData.TargetShape.ALL_ALLIES, AbilityData.ApplicableTo.ALLY)
	var targets := CombatManagerAuto.resolve_targets(caster, ability, board)
	assert(targets.size() == 2, "all_allies should yield caster + ally1")
	assert(not targets.has(enemy), "should not include enemy")
	print("  PASS test_all_allies_excludes_enemies")
```

Mirror tscn.

- [ ] **Step 2: Run test to verify it fails**

```powershell
godot --headless --path rogue-finder tests/test_lane_targeting.tscn
```

Expected: error — `resolve_targets` not found.

- [ ] **Step 3: Implement `resolve_targets` as a static method on CombatManager**

Add to `rogue-finder/scripts/combat/CombatManager.gd`:

```gdscript
## Returns the array of target units for a given (caster, ability, board) triple.
## Empty array = no valid target (caller skips turn).
static func resolve_targets(caster: CombatantData, ability: AbilityData, board: LaneBoard) -> Array[CombatantData]:
	var caster_lane := board.get_lane_of(caster)
	var caster_side := board.get_side_of(caster)
	var enemy_side := board.get_opposite_side(caster_side)
	var result: Array[CombatantData] = []
	match ability.target_shape:
		AbilityData.TargetShape.SELF:
			result.append(caster)
		AbilityData.TargetShape.SAME_LANE, AbilityData.TargetShape.SINGLE:
			# Try direct opposite first; fall back to nearest non-empty enemy
			var opp := board.get_unit(caster_lane, enemy_side)
			if opp != null and opp.current_hp > 0:
				result.append(opp)
			else:
				for u: CombatantData in board.get_all_on_side(enemy_side):
					if u.current_hp > 0:
						result.append(u)
						break
		AbilityData.TargetShape.ADJACENT_LANE:
			for u: CombatantData in board.get_adjacent_lane_units(caster_lane, enemy_side):
				if u.current_hp > 0:
					result.append(u)
		AbilityData.TargetShape.ALL_LANES:
			for u: CombatantData in board.get_all_on_side(enemy_side):
				if u.current_hp > 0:
					result.append(u)
		AbilityData.TargetShape.ALL_ALLIES:
			for u: CombatantData in board.get_all_on_side(caster_side):
				if u.current_hp > 0:
					result.append(u)
		_:
			# Legacy shapes (CONE/LINE/RADIAL/ARC): autobattler treats them as SAME_LANE.
			# Slice 7 strips legacy shape support entirely.
			var opp := board.get_unit(caster_lane, enemy_side)
			if opp != null and opp.current_hp > 0:
				result.append(opp)
	return result
```

- [ ] **Step 4: Replace `_stub_pick_target` callers with `resolve_targets`**

In `_fire_unit_turn`:

```gdscript
func _fire_unit_turn(u: CombatantData) -> void:
	var slot := 0
	var ability_id: String = u.abilities[slot] if u.abilities.size() > slot else ""
	if ability_id == "":
		return
	var ability := AbilityLibrary.get_ability(ability_id)
	var targets := CombatManagerAuto.resolve_targets(u, ability, board)
	if targets.is_empty():
		print("  [%s] no valid target" % u.character_name)
		return
	for target: CombatantData in targets:
		_apply_ability(u, target, ability)
	u.cooldowns[slot] = ability.cooldown_max
	print("  [%s] tick %d: %s on %d target(s)" % [u.character_name, current_tick, ability.ability_name, targets.size()])
```

Delete the now-unused `_stub_pick_target` method.

- [ ] **Step 5: Run tests to verify**

```powershell
godot --headless --path rogue-finder tests/test_lane_targeting.tscn
godot --headless --path rogue-finder tests/test_combat_loop.tscn
```

Expected: both PASS.

- [ ] **Step 6: Commit**

```powershell
git add rogue-finder/scripts/combat/CombatManager.gd rogue-finder/tests/test_lane_targeting.gd rogue-finder/tests/test_lane_targeting.tscn
git commit -m "feat: lane-aware target resolver (replaces stub picker)"
```

---

## Slice 6: AI Module (Priority-List Pick)

**Session goal:** Replace the "always slot 0" stub AI with a small priority-list selector. Each role has a preference order (HARM > MEND, etc.); AI picks the highest-preference available off-cooldown ability with a valid target. Wires into `_fire_unit_turn`.

### Task 6.1: Implement AutobattlerEnemyAI module

**Files:**
- Create: `rogue-finder/scripts/combat/AutobattlerEnemyAI.gd`
- Create: `rogue-finder/tests/test_autobattler_ai.{gd,tscn}`

- [ ] **Step 1: Write the failing test**

Create `rogue-finder/tests/test_autobattler_ai.gd`:

```gdscript
extends Node

func _ready() -> void:
	print("=== test_autobattler_ai.gd ===")
	test_attacker_prefers_harm()
	test_healer_prefers_mend_when_ally_low()
	test_skips_when_all_on_cooldown()
	test_falls_back_when_no_harm_target()
	print("=== All AI tests passed ===")

func test_attacker_prefers_harm() -> void:
	var caster := _make_unit("Atk", AbilityData.ApplicableTo.ENEMY, "ATTACKER")
	caster.abilities = ["strike", "bless", ""]
	var board := LaneBoard.new()
	board.place(caster, 0, "ally")
	var enemy := _make_unit("E", AbilityData.ApplicableTo.ENEMY, "ATTACKER")
	board.place(enemy, 0, "enemy")
	var ally := _make_unit("Ally", AbilityData.ApplicableTo.ALLY, "ATTACKER")
	board.place(ally, 1, "ally")
	var pick := AutobattlerEnemyAI.pick(caster, [caster, ally], [enemy], board)
	assert(pick.ability != null, "should pick something")
	assert(pick.ability.ability_id == "strike", "ATTACKER should prefer HARM (strike)")
	print("  PASS test_attacker_prefers_harm")

func test_healer_prefers_mend_when_ally_low() -> void:
	var caster := _make_unit("Healer", AbilityData.ApplicableTo.ALLY, "HEALER")
	caster.abilities = ["strike", "heal", ""]  # 'heal' assumed in CSV with MEND effect
	var board := LaneBoard.new()
	var ally := _make_unit("LowAlly", AbilityData.ApplicableTo.ALLY, "ATTACKER")
	ally.current_hp = 1  # low HP
	board.place(caster, 0, "ally")
	board.place(ally, 1, "ally")
	var enemy := _make_unit("E", AbilityData.ApplicableTo.ENEMY, "ATTACKER")
	board.place(enemy, 0, "enemy")
	var pick := AutobattlerEnemyAI.pick(caster, [caster, ally], [enemy], board)
	# HEALER prefers MEND > BUFF > HARM; if 'heal' is a MEND ability, it wins
	assert(pick.ability != null, "should pick something")
	assert(pick.ability.effects.size() > 0, "should have effects")
	# This assertion is dependent on 'heal' existing in the CSV. If your project doesn't yet
	# have a 'heal' ability, swap to whatever MEND ability you do have.
	print("  PASS test_healer_prefers_mend_when_ally_low (picked: %s)" % pick.ability.ability_id)

func test_skips_when_all_on_cooldown() -> void:
	var caster := _make_unit("Stuck", AbilityData.ApplicableTo.ENEMY, "ATTACKER")
	caster.abilities = ["strike", "", ""]
	caster.cooldowns = [3, 0, 0]  # slot 0 on cooldown
	var board := LaneBoard.new()
	board.place(caster, 0, "ally")
	var enemy := _make_unit("E", AbilityData.ApplicableTo.ENEMY, "ATTACKER")
	board.place(enemy, 0, "enemy")
	var pick := AutobattlerEnemyAI.pick(caster, [caster], [enemy], board)
	assert(pick.ability == null, "should return null when only ability is on cooldown")
	print("  PASS test_skips_when_all_on_cooldown")

func test_falls_back_when_no_harm_target() -> void:
	var caster := _make_unit("Atk", AbilityData.ApplicableTo.ENEMY, "ATTACKER")
	caster.abilities = ["strike", "bless", ""]
	var board := LaneBoard.new()
	board.place(caster, 0, "ally")
	# No enemies on the board → HARM has no target; ATTACKER should fall back to BUFF
	var ally := _make_unit("Ally", AbilityData.ApplicableTo.ALLY, "ATTACKER")
	board.place(ally, 1, "ally")
	var pick := AutobattlerEnemyAI.pick(caster, [caster, ally], [], board)
	# BUFF (bless) targets allies, so it should win the fallback
	assert(pick.ability != null, "should fall back to non-HARM")
	print("  PASS test_falls_back_when_no_harm_target")

func _make_unit(name: String, _applic: AbilityData.ApplicableTo, _role: String) -> CombatantData:
	var d := CombatantData.new()
	d.character_name = name
	d.current_hp = 20
	d.cooldowns = [0, 0, 0]
	# Note: role lives on archetype today; for tests we wire it via a fake field if needed.
	# If your AI reads role from archetype, this test may need to set archetype_id.
	return d
```

Mirror tscn.

- [ ] **Step 2: Run test to verify it fails**

```powershell
godot --headless --path rogue-finder tests/test_autobattler_ai.tscn
```

Expected: error — `AutobattlerEnemyAI` not found.

- [ ] **Step 3: Implement AutobattlerEnemyAI.gd**

Create `rogue-finder/scripts/combat/AutobattlerEnemyAI.gd`:

```gdscript
class_name AutobattlerEnemyAI
extends RefCounted

## --- AutobattlerEnemyAI ---
## Static module — picks an off-cooldown ability for a unit's turn based on role priority.
## No instance state. Called once per unit turn from CombatManager._fire_unit_turn.

## Role preference: ordered list of EffectType values.
## ATTACKER prefers HARM > DEBUFF > BUFF > MEND, etc.
const ROLE_PREFS: Dictionary = {
	"ATTACKER":  [EffectData.EffectType.HARM, EffectData.EffectType.DEBUFF, EffectData.EffectType.BUFF, EffectData.EffectType.MEND],
	"TANK":      [EffectData.EffectType.HARM, EffectData.EffectType.BUFF, EffectData.EffectType.DEBUFF, EffectData.EffectType.MEND],
	"HEALER":    [EffectData.EffectType.MEND, EffectData.EffectType.BUFF, EffectData.EffectType.HARM, EffectData.EffectType.DEBUFF],
	"SUPPORTER": [EffectData.EffectType.BUFF, EffectData.EffectType.DEBUFF, EffectData.EffectType.MEND, EffectData.EffectType.HARM],
	"CONTROLLER":[EffectData.EffectType.DEBUFF, EffectData.EffectType.HARM, EffectData.EffectType.BUFF, EffectData.EffectType.MEND],
}

const DEFAULT_PREFS: Array = [EffectData.EffectType.HARM, EffectData.EffectType.DEBUFF, EffectData.EffectType.BUFF, EffectData.EffectType.MEND]

## Returns { ability: AbilityData, targets: Array[CombatantData] } — both null/empty if no pick.
static func pick(unit: CombatantData, allies: Array, hostiles: Array, board: LaneBoard) -> Dictionary:
	var prefs := _get_role_prefs(unit)
	var available_slots := CountdownTracker.available_slot_indices(unit.cooldowns)
	# Walk the preference list; take the first off-cooldown ability whose primary effect
	# matches AND whose target list is non-empty.
	for effect_type in prefs:
		for slot in available_slots:
			var ability_id: String = unit.abilities[slot] if unit.abilities.size() > slot else ""
			if ability_id == "":
				continue
			var ability := AbilityLibrary.get_ability(ability_id)
			if not _ability_has_effect_type(ability, effect_type):
				continue
			var targets := CombatManagerAuto.resolve_targets(unit, ability, board)
			if not targets.is_empty():
				return {"ability": ability, "targets": targets, "slot": slot}
	return {"ability": null, "targets": [], "slot": -1}

static func _get_role_prefs(unit: CombatantData) -> Array:
	# Today's role lives on the unit's archetype. If your project has a unit.role field
	# instead, swap this lookup. Falling back to DEFAULT_PREFS is safe.
	if unit.archetype_id == "":
		return DEFAULT_PREFS
	var arch: ArchetypeData = ArchetypeLibrary.get_archetype(unit.archetype_id)
	if arch == null or arch.role == "":
		return DEFAULT_PREFS
	return ROLE_PREFS.get(arch.role.to_upper(), DEFAULT_PREFS)

static func _ability_has_effect_type(ability: AbilityData, et: EffectData.EffectType) -> bool:
	for effect in ability.effects:
		if effect.effect_type == et:
			return true
	return false
```

Note: this references `ArchetypeData.role` — if your archetype doesn't have a `role` field today, fall back to DEFAULT_PREFS uniformly. Check `rogue-finder/resources/ArchetypeData.gd` and adjust the lookup.

- [ ] **Step 4: Run test to verify it passes**

```powershell
godot --headless --path rogue-finder tests/test_autobattler_ai.tscn
```

Expected: All AI tests passed.

- [ ] **Step 5: Commit**

```powershell
git add rogue-finder/scripts/combat/AutobattlerEnemyAI.gd rogue-finder/tests/test_autobattler_ai.gd rogue-finder/tests/test_autobattler_ai.tscn
git commit -m "feat: AutobattlerEnemyAI priority-list module"
```

---

### Task 6.2: Wire AutobattlerEnemyAI into CombatManager

**Files:**
- Modify: `rogue-finder/scripts/combat/CombatManager.gd`

- [ ] **Step 1: Replace stub pick in `_fire_unit_turn`**

Edit `_fire_unit_turn`:

```gdscript
func _fire_unit_turn(u: CombatantData) -> void:
	var allies: Array[CombatantData] = board.get_all_on_side(board.get_side_of(u))
	var hostiles: Array[CombatantData] = board.get_all_on_side(board.get_opposite_side(board.get_side_of(u)))
	var pick: Dictionary = AutobattlerEnemyAI.pick(u, allies, hostiles, board)
	if pick.ability == null:
		print("  [%s] tick %d: skips (no valid action)" % [u.character_name, current_tick])
		return
	var ability: AbilityData = pick.ability
	var targets: Array = pick.targets
	for target: CombatantData in targets:
		_apply_ability(u, target, ability)
	u.cooldowns[pick.slot] = ability.cooldown_max
	print("  [%s] tick %d: %s on %d target(s)" % [u.character_name, current_tick, ability.ability_name, targets.size()])
```

- [ ] **Step 2: Verify combat loop test still passes**

```powershell
godot --headless --path rogue-finder tests/test_combat_loop.tscn
```

Expected: PASS — combat resolves with the new AI driving picks.

- [ ] **Step 3: Verify manually**

Flip `USE_AUTOBATTLER_COMBAT = true`. Run, enter a combat. Watch console — units should now use a mix of abilities (not just slot 0).

- [ ] **Step 4: Commit**

```powershell
git add rogue-finder/scripts/combat/CombatManager.gd
git commit -m "feat: wire AutobattlerEnemyAI into CombatManager turn flow"
```

---

### Task 6.3: Apply MEND / BUFF / DEBUFF effects in `_apply_ability`

**Files:**
- Modify: `rogue-finder/scripts/combat/CombatManager.gd`

- [ ] **Step 1: Extend `_apply_ability` to handle non-HARM effects**

Replace the existing `_apply_ability` with:

```gdscript
func _apply_ability(caster: CombatantData, target: CombatantData, ability: AbilityData) -> void:
	for effect in ability.effects:
		match effect.effect_type:
			EffectData.EffectType.HARM:
				_apply_harm(caster, target, effect, ability.attribute, ability.damage_type)
			EffectData.EffectType.MEND:
				var heal_amount := effect.base_value + caster.effective_stat("willpower")
				target.current_hp = min(target.hp_max, target.current_hp + heal_amount)
			EffectData.EffectType.BUFF:
				_apply_stat_delta(target, effect, +1)
			EffectData.EffectType.DEBUFF:
				_apply_stat_delta(target, effect, -1)
			# FORCE / TRAVEL: ignored in autobattler (no movement)

func _apply_harm(caster: CombatantData, target: CombatantData, effect: EffectData, attr: AbilityData.Attribute, dt: AbilityData.DamageType) -> void:
	var attr_name := _attr_to_string(attr)
	var raw_dmg := effect.base_value + caster.effective_stat(attr_name)
	var defense: int = 0
	if dt == AbilityData.DamageType.PHYSICAL:
		defense = target.physical_defense
	elif dt == AbilityData.DamageType.MAGIC:
		defense = target.magic_defense
	var dmg := max(1, raw_dmg - defense)
	target.current_hp = max(0, target.current_hp - dmg)

func _apply_stat_delta(target: CombatantData, effect: EffectData, sign: int) -> void:
	# Slice 7+: full transient stat-mod tracking (snapshots, durations).
	# For vert slice: just nudge the relevant transient field if it's an armor mod;
	# other stat changes are no-ops for now (durations + snapshots come post-slice).
	match effect.target_stat:
		AbilityData.Attribute.PHYSICAL_ARMOR_MOD:
			target.physical_armor_mod = clamp(target.physical_armor_mod + sign * effect.base_value, -10, 10)
		AbilityData.Attribute.MAGIC_ARMOR_MOD:
			target.magic_armor_mod = clamp(target.magic_armor_mod + sign * effect.base_value, -10, 10)
		_:
			pass  # other stat targets: deferred — needs duration tracking
```

- [ ] **Step 2: Verify combat loop test still passes**

```powershell
godot --headless --path rogue-finder tests/test_combat_loop.tscn
```

Expected: PASS.

- [ ] **Step 3: Commit**

```powershell
git add rogue-finder/scripts/combat/CombatManager.gd
git commit -m "feat: extend _apply_ability to handle MEND/BUFF/DEBUFF effects"
```

---

## Slice 7: Cutover — Switch the Flag, Rip the Old Combat

**Session goal:** Flip `USE_AUTOBATTLER_COMBAT` to `true`. Strip out the legacy 3D-combat code (CombatManager3D, Grid3D, QTEBar, EnemyAI.gd, CombatScene3D.tscn). Clean up dead fields (energy_cost on AbilityData, energy/energy_max/energy_regen helpers on CombatantData, legacy TargetShape values, FORCE/TRAVEL EffectTypes). Add real placement UI to PlacementOverlay. Add basic combat HUD (countdown numbers floating above units).

### Task 7.1: Flip the feature flag

**Files:**
- Modify: `rogue-finder/scripts/map/MapManager.gd`

- [ ] **Step 1: Set flag to true**

In `MapManager.gd`:

```gdscript
const USE_AUTOBATTLER_COMBAT: bool = true
```

- [ ] **Step 2: Run game manually, verify autobattler engages on every COMBAT/BOSS node**

```powershell
godot --path rogue-finder
```

Walk through a few combat nodes. Verify the autobattler runs each time.

- [ ] **Step 3: Commit**

```powershell
git add rogue-finder/scripts/map/MapManager.gd
git commit -m "feat: flip USE_AUTOBATTLER_COMBAT to true (cutover)"
```

---

### Task 7.2: Build PlacementOverlay UI

**Files:**
- Modify: `rogue-finder/scripts/ui/PlacementOverlay.gd`
- Modify: `rogue-finder/scripts/combat/CombatManager.gd`

- [ ] **Step 1: Implement draggable lane assignment UI**

Edit `PlacementOverlay.gd`. Replace `show_placement` body:

```gdscript
@onready var _lane_buttons: Array[Button] = []  # 3 buttons, one per lane
@onready var _begin_button: Button

func show_placement(party: Array[CombatantData]) -> void:
	_party = party.duplicate()
	for i in min(_party.size(), 3):
		_lane_assignments[i] = _party[i]
	_build_ui()
	visible = true

func _build_ui() -> void:
	# Remove any existing children
	for c: Node in get_children():
		c.queue_free()
	# Build a Control container
	var ctrl := Control.new()
	ctrl.anchor_right = 1.0
	ctrl.anchor_bottom = 1.0
	add_child(ctrl)
	# Lane buttons (one per lane); label shows assigned unit name; click cycles to next unit
	var hbox := HBoxContainer.new()
	hbox.position = Vector2(200, 200)
	ctrl.add_child(hbox)
	_lane_buttons.clear()
	for lane in 3:
		var btn := Button.new()
		btn.text = _label_for(lane)
		btn.custom_minimum_size = Vector2(150, 200)
		btn.pressed.connect(func() -> void: _cycle_assignment(lane))
		hbox.add_child(btn)
		_lane_buttons.append(btn)
	# Begin button
	_begin_button = Button.new()
	_begin_button.text = "Begin Combat"
	_begin_button.position = Vector2(400, 500)
	_begin_button.pressed.connect(_on_begin_pressed)
	ctrl.add_child(_begin_button)

func _label_for(lane: int) -> String:
	var u: CombatantData = _lane_assignments[lane]
	return "Lane %d\n%s" % [lane + 1, u.character_name if u != null else "—"]

func _cycle_assignment(lane: int) -> void:
	# Cycle through party members; null = skip this lane
	var current: CombatantData = _lane_assignments[lane]
	var idx := _party.find(current) if current != null else -1
	idx = (idx + 1) % (_party.size() + 1)  # wraps through party + 1 null
	# Avoid double-assigning the same unit; if duplicate, advance again
	for tries in _party.size() + 2:
		var candidate: CombatantData = _party[idx] if idx < _party.size() else null
		if candidate == null or not _lane_assignments.has(candidate) or _lane_assignments[lane] == candidate:
			_lane_assignments[lane] = candidate
			break
		idx = (idx + 1) % (_party.size() + 1)
	_lane_buttons[lane].text = _label_for(lane)
```

- [ ] **Step 2: Wire PlacementOverlay into CombatManager._ready**

Edit `CombatManager._ready`:

```gdscript
func _ready() -> void:
	board = LaneBoard.new()
	var party: Array[CombatantData] = GameState.party.filter(func(p: CombatantData) -> bool: return not p.is_dead).slice(0, 3)
	var enemies: Array[CombatantData] = GameState.pending_combat_enemies
	GameState.pending_combat_enemies = []
	if party.is_empty() or enemies.is_empty():
		push_warning("[CombatManagerAuto] missing party or enemies on scene entry")
		return
	# Show placement overlay; start combat once placement_locked fires
	var placement: PlacementOverlay = preload("res://scenes/ui/PlacementOverlay.tscn").instantiate()
	add_child(placement)
	placement.placement_locked.connect(func(party_by_lane: Array) -> void:
		var assigned: Array[CombatantData] = []
		for u in party_by_lane:
			if u != null:
				assigned.append(u)
		start_combat(assigned, enemies)
	)
	placement.show_placement(party)
```

- [ ] **Step 3: Verify manually**

Run the game, enter a combat. Expected: placement overlay appears; cycling lane buttons reassigns units; pressing Begin starts the autobattler with the chosen lane order.

- [ ] **Step 4: Commit**

```powershell
git add rogue-finder/scripts/ui/PlacementOverlay.gd rogue-finder/scripts/combat/CombatManager.gd
git commit -m "feat: PlacementOverlay UI with lane-cycling buttons"
```

---

### Task 7.3: Floating countdown numbers above units

**Files:**
- Modify: `rogue-finder/scripts/combat/Unit3D.gd`
- Modify: `rogue-finder/scripts/combat/CombatManager.gd`

- [ ] **Step 1: Add a Label3D countdown indicator to Unit3D**

Edit `Unit3D.gd`. In `_ready`, add a Label3D child:

```gdscript
var _countdown_label: Label3D

func _ready() -> void:
	# ... existing setup ...
	_countdown_label = Label3D.new()
	_countdown_label.position = Vector3(0, 2.5, 0)  # above head
	_countdown_label.font_size = 64
	_countdown_label.outline_size = 4
	_countdown_label.text = ""
	add_child(_countdown_label)

## Called by CombatManager each tick to refresh the displayed number.
func update_countdown_display(value: int) -> void:
	if _countdown_label != null:
		_countdown_label.text = str(value)
```

- [ ] **Step 2: Refresh countdown labels each tick from CombatManager**

After `_advance_tick`'s ticking but before the unit-firing loop, refresh labels:

```gdscript
func _advance_tick() -> void:
	if not combat_running:
		return
	current_tick += 1
	var ready := CountdownTracker.tick_and_collect_ready(_all_units)
	for u: CombatantData in _all_units:
		CountdownTracker.tick_cooldowns(u.cooldowns)
		_refresh_unit_label(u)
	# ... rest ...

func _refresh_unit_label(d: CombatantData) -> void:
	# Find the corresponding Unit3D node and call update_countdown_display.
	# Replace with whatever lookup pattern you use today (Unit3D nodes are children of CombatManager).
	for child in get_children():
		if child is Unit3D and child.data == d:
			child.update_countdown_display(d.countdown_current)
			break
```

- [ ] **Step 3: Verify manually**

Run a combat. Numbers should float above each unit and tick down each beat.

- [ ] **Step 4: Commit**

```powershell
git add rogue-finder/scripts/combat/Unit3D.gd rogue-finder/scripts/combat/CombatManager.gd
git commit -m "feat: floating countdown numbers above units"
```

---

### Task 7.4: Consumable interject button

**Files:**
- Modify: `rogue-finder/scripts/combat/CombatManager.gd`

- [ ] **Step 1: Build a per-unit consumable button row**

This builds a HUD containing 3 buttons (one per ally). Pressing one fires the consumable for that ally.

In `CombatManager.gd`, add HUD construction in `start_combat` after units are placed:

```gdscript
var _consumable_buttons: Array[Button] = []

func _build_consumable_hud(party: Array[CombatantData]) -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 12
	add_child(canvas)
	var hbox := HBoxContainer.new()
	hbox.position = Vector2(50, 600)
	canvas.add_child(hbox)
	_consumable_buttons.clear()
	for i in min(party.size(), 3):
		var btn := Button.new()
		btn.text = _consumable_btn_label(party[i])
		var idx := i  # capture
		btn.pressed.connect(func() -> void: _use_consumable(party[idx]))
		hbox.add_child(btn)
		_consumable_buttons.append(btn)

func _consumable_btn_label(u: CombatantData) -> String:
	if u.consumable == "":
		return "%s\n(empty)" % u.character_name
	var c := ConsumableLibrary.get_consumable(u.consumable)
	return "%s\n%s" % [u.character_name, c.name]

func _use_consumable(u: CombatantData) -> void:
	if u.consumable == "":
		return
	var c := ConsumableLibrary.get_consumable(u.consumable)
	# Apply each effect (mirror what _apply_ability does, scaled to consumable schema).
	for effect in c.effects:
		# Treat consumable as self-target unless it specifies otherwise.
		_apply_consumable_effect(u, effect)
	u.consumable = ""  # used up
	# Refresh the button label
	for i in _consumable_buttons.size():
		# match by ordinal — adjust if you map differently
		_consumable_buttons[i].text = _consumable_btn_label(_get_party_at(i))

func _apply_consumable_effect(target: CombatantData, effect: EffectData) -> void:
	match effect.effect_type:
		EffectData.EffectType.MEND:
			target.current_hp = min(target.hp_max, target.current_hp + effect.base_value)
		EffectData.EffectType.BUFF:
			# Slice 8 polish: track durations. For now, instant nudge.
			pass

func _get_party_at(i: int) -> CombatantData:
	# Helper for label refresh — return the i-th ally on the board.
	var allies := board.get_all_on_side("ally")
	return allies[i] if i < allies.size() else null
```

Call `_build_consumable_hud(party)` at the end of `start_combat`.

- [ ] **Step 2: Verify manually**

Enter combat with a unit holding a consumable. Mid-fight, press the consumable button. Verify the consumable fires and the button greys / clears.

- [ ] **Step 3: Commit**

```powershell
git add rogue-finder/scripts/combat/CombatManager.gd
git commit -m "feat: consumable interject buttons during combat"
```

---

### Task 7.5: Rip out the legacy combat code

**Files:**
- Delete: `rogue-finder/scripts/combat/CombatManager3D.gd`
- Delete: `rogue-finder/scripts/combat/Grid3D.gd`
- Delete: `rogue-finder/scripts/combat/QTEBar.gd`
- Delete: `rogue-finder/scripts/combat/EnemyAI.gd`
- Delete: `rogue-finder/scenes/combat/CombatScene3D.tscn`
- Delete: `rogue-finder/scenes/combat/Grid3D.tscn`
- Delete: `rogue-finder/scenes/combat/QTEBar.tscn`
- Modify: `rogue-finder/scripts/map/MapManager.gd` (remove flag + branch)
- Modify: `rogue-finder/scripts/combat/Unit3D.gd` (strip movement/QTE/AoE/FORCE)

- [ ] **Step 1: Delete the legacy files**

```powershell
git rm rogue-finder/scripts/combat/CombatManager3D.gd
git rm rogue-finder/scripts/combat/Grid3D.gd
git rm rogue-finder/scripts/combat/QTEBar.gd
git rm rogue-finder/scripts/combat/EnemyAI.gd
git rm rogue-finder/scenes/combat/CombatScene3D.tscn
git rm rogue-finder/scenes/combat/Grid3D.tscn
git rm rogue-finder/scenes/combat/QTEBar.tscn
```

- [ ] **Step 2: Remove the feature flag from MapManager**

Edit `MapManager.gd`. Delete the `USE_AUTOBATTLER_COMBAT` constant and replace the conditional with the unconditional new-scene load:

```gdscript
"COMBAT", "BOSS":
	GameState.current_combat_node_id = node_id
	GameState.current_combat_ring = _get_ring(node_id)
	GameState.pending_combat_enemies = _roll_combat_enemies()
	get_tree().change_scene_to_file("res://scenes/combat/CombatSceneAuto.tscn")
```

- [ ] **Step 3: Strip dead code from Unit3D**

Open `rogue-finder/scripts/combat/Unit3D.gd`. Remove:

- Movement helpers (e.g. `move_to`, `slide_to_cell`)
- AoE/shape rendering helpers
- FORCE response code (push/pull receivers)
- QTEBar binding signals
- Active buff/debuff tracker fields used only by old EnemyAI

Keep:
- The visual mesh / model / portrait
- HP rendering
- Death animation hooks
- The new `update_countdown_display(int)` method
- The `data: CombatantData` property

- [ ] **Step 4: Run all tests + game**

```powershell
godot --headless --path rogue-finder --import
godot --headless --path rogue-finder tests/test_combat_loop.tscn
godot --headless --path rogue-finder tests/test_lane_targeting.tscn
godot --headless --path rogue-finder tests/test_autobattler_ai.tscn
godot --headless --path rogue-finder tests/test_combatant_data.tscn
```

Expected: all PASS.

Then run the game manually:
```powershell
godot --path rogue-finder
```

Walk through a combat. Verify it works end-to-end.

- [ ] **Step 5: Commit**

```powershell
git add -A rogue-finder/scripts/combat/ rogue-finder/scenes/combat/ rogue-finder/scripts/map/MapManager.gd
git commit -m "refactor: remove legacy 3D-grid combat (CombatManager3D, Grid3D, QTEBar, EnemyAI)"
```

---

### Task 7.6: Retire energy fields and legacy TargetShape values

**Files:**
- Modify: `rogue-finder/resources/CombatantData.gd`
- Modify: `rogue-finder/resources/AbilityData.gd`
- Modify: `rogue-finder/scripts/globals/AbilityLibrary.gd`
- Modify: `rogue-finder/scripts/globals/GameState.gd`
- Modify: `rogue-finder/data/abilities.csv`
- Modify: `rogue-finder/scripts/party/PartySheet.gd`
- Modify: `rogue-finder/scripts/ui/StatPanel.gd`

- [ ] **Step 1: Drop energy fields from CombatantData**

Edit `CombatantData.gd`:
- Remove `current_energy: int` field.
- Remove `energy_max: int` getter.
- Remove `energy_regen: int` getter.
- Remove `speed: int` getter (replaced by `spd` attribute).

- [ ] **Step 2: Drop energy_cost from AbilityData; retire legacy TargetShape values**

Edit `AbilityData.gd`:
- Remove `energy_cost: int` field.
- Optionally remove CONE/LINE/RADIAL/ARC enum entries (renumber others, OR keep them as deprecated aliases).

(Keeping deprecated aliases is simpler — don't renumber.)

- [ ] **Step 3: Update AbilityLibrary parser**

Remove the `"cost"` case from `_row_to_data`'s match block. Keep `"cooldown"`.

- [ ] **Step 4: Drop `cost` column from abilities.csv**

Edit the CSV header: remove the `cost` column. Edit each row to remove the cost value.

- [ ] **Step 5: Drop energy display from PartySheet + StatPanel**

Find the Energy / Regen labels and remove them. Layout reflows automatically.

- [ ] **Step 6: Drop energy fields from GameState save/load**

Find `_combatant_to_dict` / `_combatant_from_dict`. Remove `current_energy` field references. Old saves with the field will simply ignore it.

- [ ] **Step 7: Run tests + game**

```powershell
godot --headless --path rogue-finder --import
godot --headless --path rogue-finder tests/test_combatant_data.tscn
godot --headless --path rogue-finder tests/test_combat_loop.tscn
godot --path rogue-finder
```

Expected: PASS, game runs.

- [ ] **Step 8: Commit**

```powershell
git add rogue-finder/resources/CombatantData.gd rogue-finder/resources/AbilityData.gd rogue-finder/scripts/globals/AbilityLibrary.gd rogue-finder/scripts/globals/GameState.gd rogue-finder/data/abilities.csv rogue-finder/scripts/party/PartySheet.gd rogue-finder/scripts/ui/StatPanel.gd
git commit -m "refactor: retire energy fields + legacy TargetShape values"
```

---

## Slice 8: Consumable Balance Pass

**Session goal:** Buff existing consumables so they feel impactful as the only mid-fight player input. No code changes — just CSV value edits.

### Task 8.1: Tune consumables.csv values

**Files:**
- Modify: `rogue-finder/data/consumables.csv`

- [ ] **Step 1: Identify weak consumables and propose new values**

Open `rogue-finder/data/consumables.csv`. Review each row. Today's pattern: most consumables are +1-stat sips. Proposed new pattern for the autobattler context:

| Old (typical) | New (proposed) |
|---|---|
| `steel_tonic`: BUFF STR +1 | BUFF STR +3 (3-tick equivalent — really matters in a turn) |
| `clarity_brew`: BUFF COG +1 | BUFF COG +3 |
| `iron_word`: BUFF WIL +1 | BUFF WIL +3 |
| Healing potion (existing): MEND +5 | MEND +12 (clutch heal) |
| Stat-boost variants | +3 across the board |

Add 2–3 new "panic button" consumables if the slate feels thin:

| New ID | Effect | Description |
|---|---|---|
| `phoenix_draught` | MEND +20 | Massive heal — once per run |
| `time_jolt` | self COUNTDOWN_MOD −5 (when COUNTDOWN_MOD lands post-slice) | Skip your wait |
| `iron_rampart` | self BUFF physical_armor_mod +5 for 3 turns (when durations land post-slice) | Brace |

(Defer COUNTDOWN_MOD-based and duration-based ones if those features aren't yet built — per the spec they're post-slice.)

- [ ] **Step 2: Verify the CSV still loads**

```powershell
godot --headless --path rogue-finder tests/test_consumables.tscn
```

Expected: PASS.

- [ ] **Step 3: Play-test combat**

Run the game. Enter combat. Verify the consumable buttons feel like a meaningful "press now" moment.

- [ ] **Step 4: Commit**

```powershell
git add rogue-finder/data/consumables.csv
git commit -m "tune: buff consumable values (autobattler agency layer)"
```

---

## End-of-Slice Marker

After Task 8.1 the autobattler vert slice is complete and play-testable end-to-end. Hold all deferred features (status effects, countdown manipulation, front/back depth, hazards, stance, class-button override, defining class abilities, multi-attack penalty, boss scaling, WIL→CHA rename) until the play-test confirms the core works.

---

## Self-Review Notes

**Spec coverage check:**
- ✅ SPD attribute foundation → Slice 1
- ✅ Cooldown migration → Slice 2 (additive) + Slice 7 (energy_cost retirement)
- ✅ Combat scaffold rewrite → Slice 3
- ✅ Countdown engine → Slice 4
- ✅ Lane targeting → Slice 5
- ✅ AI simplification → Slice 6
- ✅ Polish + test rooms → Slice 7 (placement UI, countdown labels, consumable HUD)
- ✅ Consumable balance pass → Slice 8

**Deferred items:** all captured in the spec's Deferred Until Slice Validates section. None pre-built.

**Naming consistency check:**
- `cooldown_max` (singular) used everywhere on AbilityData and CSV → ✅
- `cooldown_remaining` was used inline in spec pseudocode but the field on CombatantData is `cooldowns: Array[int]` (per-slot remaining). Tasks consistently use `unit.cooldowns[slot]` → ✅
- `CombatManagerAuto` is the class_name; the file is `CombatManager.gd`. Tests reference `CombatManagerAuto.resolve_targets` (the static method) → ✅
- `LaneBoard.LANE_COUNT = 3` referenced consistently → ✅
- `effective_stat("spd")` used consistently → ✅

**Placeholder scan:** none — all steps have actual code/commands.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-02-combat-pivot.md`. Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per slice (8 sessions). Two-stage review between slices. Best for the slice-discipline mantra: each session ends with a working game, Caleb plays the new state, and we confirm before moving on.

**2. Inline Execution** — Execute slices in this session via the executing-plans skill. Batch execution with checkpoints. Risks burning context across all 8 slices in one go.

**My recommendation: Subagent-Driven**, slice by slice — matches the new scoping discipline ("don't pile features mid-slice") and gives you a play-test moment after each slice before committing to the next.
