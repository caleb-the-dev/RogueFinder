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
