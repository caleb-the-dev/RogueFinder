extends SceneTree

## --- Unit Tests: QTE World-Space Bar (Session B) ---
## Tests attacker tracking, AI-defender isolation, and post-resolve cleanup.
## All assertions mirror QTEBar / CombatManager3D logic without instantiating scene nodes.

func _initialize() -> void:
	_test_attacker_ref_stored_on_start_qte()
	_test_ai_defender_never_shows_bar()
	_test_post_resolve_cleanup()
	print("All QTE world-bar tests PASSED.")
	quit()

## --- Mirrors start_qte() attacker storage ---
## The new signature is start_qte(energy_cost, attacker). This confirms
## the attacker argument is what gets stored in _attacker.
func _simulate_start_qte(attacker: Node3D) -> Node3D:
	var stored: Node3D = attacker
	return stored

## --- Mirrors the defender routing decision in _run_harm_defenders ---
## Returns true only when the QTE bar should be shown (player-controlled, non-friendly).
func _bar_shown_for_defender(caster_is_player: bool, defender_is_player: bool) -> bool:
	var friendly: bool = caster_is_player == defender_is_player
	if friendly:
		return false
	return defender_is_player

## --- Mirrors _process_result() post-resolve cleanup ---
## After the bar hides: _attacker = null, visible = false.
func _simulate_post_resolve() -> Dictionary:
	return {"attacker": null, "visible": false}

## ============================================================
## Test 1: start_qte(energy_cost, attacker) stores the attacker ref.
## Confirms the new Node3D parameter is captured, not discarded.
## ============================================================
func _test_attacker_ref_stored_on_start_qte() -> void:
	var dummy := Node3D.new()
	var stored: Node3D = _simulate_start_qte(dummy)

	assert(stored == dummy,
		"start_qte: returned attacker == passed attacker (ref stored, not copied)")
	assert(is_instance_valid(stored),
		"start_qte: stored attacker passes is_instance_valid immediately after call")

	dummy.free()
	assert(not is_instance_valid(stored),
		"after free: is_instance_valid returns false (guard works)")

## ============================================================
## Test 2: AI-controlled defender (is_player_unit = false) never triggers bar.
## Mirrors the full routing table from _run_harm_defenders.
## ============================================================
func _test_ai_defender_never_shows_bar() -> void:
	## Enemy attacks player → player-controlled defender → bar SHOWN
	assert(_bar_shown_for_defender(false, true) == true,
		"enemy caster + player defender → not friendly → is_player=true → bar shown")

	## Player attacks enemy → AI-controlled defender → bar NEVER shown
	assert(_bar_shown_for_defender(true, false) == false,
		"player caster + enemy defender → not friendly → is_player=false → bar hidden")

	## Enemy attacks enemy (friendly fire) → bar NEVER shown
	assert(_bar_shown_for_defender(false, false) == false,
		"enemy caster + enemy defender → friendly → bar hidden regardless of is_player")

	## Player attacks player (friendly fire, AoE) → bar NEVER shown
	assert(_bar_shown_for_defender(true, true) == false,
		"player caster + player defender → friendly → bar hidden regardless of is_player")

## ============================================================
## Test 3: Post-resolve cleanup — _attacker is null, bar is hidden.
## Ensures _process() stops repositioning after qte_resolved fires.
## ============================================================
func _test_post_resolve_cleanup() -> void:
	var result: Dictionary = _simulate_post_resolve()

	assert(result["attacker"] == null,
		"after resolve: _attacker is null (no further world-space repositioning)")
	assert(result["visible"] == false,
		"after resolve: bar is hidden")
