class_name UnitData
extends Resource

## --- Unit Stat Resource ---
## Attach this resource to a Unit node to configure its stats.
## All placeholder values from the Stage 1 spec; balance is TBD.

@export var unit_name: String = "Unit"
@export var is_player_unit: bool = true

## --- Combat Stats ---
@export var hp_max: int = 20
@export var speed: int = 3         # Cells reachable per Stride (Manhattan distance)
@export var attack: int = 10       # Offensive power — raises QTE outcome ceiling
@export var defense: int = 10      # Resistive power — lowers QTE outcome floor

## --- Energy Stats ---
@export var energy_max: int = 10
@export var energy_regen: int = 3  # Restored at the start of each of this unit's turns

## --- Enemy-Only ---
## Auto-resolve accuracy for the enemy's QTE (0.0 = always misses, 1.0 = always perfect)
@export_range(0.0, 1.0) var qte_resolution: float = 0.3
