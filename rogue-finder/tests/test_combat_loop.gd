extends Node

## End-to-end sanity test: 1 ally vs 1 enemy, both with strike-only loadout.
## Combat should resolve to a winner within 50 ticks.

func _ready() -> void:
	print("=== test_combat_loop.gd ===")
	test_one_v_one_resolves()
	print("=== All combat loop tests passed ===")

func test_one_v_one_resolves() -> void:
	var ally := _make_unit("Ally", true, 6, 20, "strike")
	var enemy := _make_unit("Enemy", false, 4, 15, "strike")
	var cm := CombatManagerAuto.new()
	var party: Array[CombatantData] = [ally]
	var enemies: Array[CombatantData] = [enemy]
	cm.start_combat(party, enemies)
	for _tick in 50:
		if not cm.combat_running:
			break
		cm._advance_tick()
	assert(not cm.combat_running, "combat should have ended within 50 ticks")
	assert(ally.current_hp <= 0 or enemy.current_hp <= 0, "exactly one side should be wiped")
	print("  PASS test_one_v_one_resolves (ally hp=%d, enemy hp=%d)" % [ally.current_hp, enemy.current_hp])

func _make_unit(uname: String, is_player: bool, spd: int, hp: int, ability_id: String) -> CombatantData:
	var d := CombatantData.new()
	d.character_name = uname
	d.is_player_unit = is_player
	d.spd = spd
	d.strength = 4
	d.current_hp = hp
	d.abilities = [ability_id, "", "", ""]
	return d
