class_name EffectData
extends Resource

## --- EffectData ---
## Typed record for a single effect within an ability.
## An ability carries Array[EffectData]; each entry is resolved in order
## using the same QTE accuracy float from the first effect's check.

## ======================================================
## Effect classification enums
## ======================================================

enum EffectType {
	HARM   = 0,  ## damage or direct stat reduction
	MEND   = 1,  ## healing or direct stat increase
	FORCE  = 2,  ## unit displacement (push/pull)
	TRAVEL = 3,  ## voluntary unit repositioning
	BUFF   = 4,  ## temporary stat bonus
	DEBUFF = 5,  ## temporary stat penalty
}

enum PoolType {
	HP     = 0,  ## health points
	ENERGY = 1,  ## action energy
}

enum MoveType {
	FREE = 0,  ## free repositioning (TRAVEL only)
	LINE = 1,  ## straight-line only (TRAVEL only)
}

## ======================================================
## --- Fields ---
## ======================================================

@export var effect_type:   EffectType = EffectType.HARM
@export var base_value:    int        = 0
## HARM / MEND only — which pool this effect modifies
@export var target_pool:   PoolType   = PoolType.HP
## BUFF / DEBUFF only — stores an AbilityData.Attribute int value (avoids circular ref)
@export var target_stat:   int        = 0
## TRAVEL only — movement constraint
@export var movement_type: MoveType   = MoveType.FREE
