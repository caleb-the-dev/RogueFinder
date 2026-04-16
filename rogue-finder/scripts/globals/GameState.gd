extends Node

## --- Global Game State ---
## Autoloaded singleton (name: GameState) — tracks run-wide data.
## Stage 1: minimal scaffold. Will hold run metadata, reputation, etc. in later stages.

## Toggle with [T] in combat. When true, left-clicking any unit opens its full stat panel
## instead of performing normal game actions. Useful for verifying ability effects mid-fight.
var testing_mode: bool = false
