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
@export var tile_range:   int      = 1
@export var target_type:  TargetType = TargetType.SINGLE_ENEMY
@export var description:  String   = ""
## Placeholder icon — defaults to the Godot icon at runtime in AbilityLibrary.
@export var ability_icon: Texture2D = null
