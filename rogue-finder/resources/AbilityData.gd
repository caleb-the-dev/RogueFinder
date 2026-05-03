class_name AbilityData
extends Resource

## --- AbilityData ---
## Typed data record for a single ability.
## Instances are created by AbilityLibrary.get_ability() — never set fields directly.

## ======================================================
## Attribute enum — which stat this ability scales with.
## Also used by EffectData.target_stat (stored as int) for BUFF/DEBUFF targets.
## PHYSICAL_ARMOR_MOD / MAGIC_ARMOR_MOD are runtime-only BUFF targets — they tweak the
## transient armor mod fields on CombatantData and are not used as ability scaling stats.
## ======================================================
enum Attribute {
	STRENGTH           = 0,
	DEXTERITY          = 1,
	COGNITION          = 2,
	VITALITY           = 3,
	WILLPOWER          = 4,
	NONE               = 5,
	PHYSICAL_ARMOR_MOD = 6,
	MAGIC_ARMOR_MOD    = 7,
}

## ======================================================
## TargetShape enum — the geometry of the targeting area.
## Separated from ApplicableTo so shape and filter are independent.
## ======================================================
enum TargetShape {
	SELF          = 0,
	SINGLE        = 1,  ## deprecated alias — treated as SAME_LANE by resolve_targets()
	CONE          = 2,  ## deprecated alias — treated as SAME_LANE
	LINE          = 3,  ## deprecated alias — treated as SAME_LANE
	RADIAL        = 4,  ## deprecated alias — treated as SAME_LANE
	ARC           = 5,  ## deprecated alias — treated as SAME_LANE
	SAME_LANE     = 6,
	ADJACENT_LANE = 7,
	ALL_LANES     = 8,
	ALL_ALLIES    = 9,
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
## DamageType enum — governs which armor stat resists this ability.
## Only meaningful for abilities that have a HARM effect.
## NONE = no armor reduction (non-HARM abilities, or HARM that bypasses armor).
## ======================================================
enum DamageType {
	PHYSICAL = 0,
	MAGIC    = 1,
	NONE     = 2,
}

## ======================================================
## --- Fields ---
## ======================================================

@export var ability_id:    String       = ""
@export var ability_name:  String       = ""
@export var attribute:     Attribute    = Attribute.NONE
@export var target_shape:  TargetShape  = TargetShape.SINGLE
@export var applicable_to: ApplicableTo = ApplicableTo.ENEMY
@export var damage_type:   DamageType   = DamageType.NONE
## 0–10 tiles; -1 = whole map
@export var tile_range:    int          = 1
## CONE: if false, a unit at depth-1 blocks the depth-2 crossbar.
## RADIAL: if false, a unit at distance-1 blocks distance-2 cells behind it.
## LINE: if false, effect stops at the first occupied cell.
@export var passthrough:   bool         = false
@export var cooldown_max:  int          = 0
@export var effects:       Array[EffectData] = []
@export var description:   String       = ""
## ID of the upgraded form of this ability; empty if no upgrade exists.
## Set on the base ability row — the upgraded row is itself a regular ability.
@export var upgraded_id:   String       = ""
## Placeholder icon — replaced with real art when assets arrive
@export var ability_icon:  Texture2D    = null
