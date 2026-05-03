extends Node

func _ready() -> void:
	print("=== test_autobattler_ai.gd ===")
	test_attacker_prefers_harm()
	test_healer_prefers_mend()
	test_skips_when_all_on_cooldown()
	test_falls_back_when_no_harm_target()
	print("=== All AI tests passed ===")
	get_tree().quit()

## ATTACKER role: HARM > DEBUFF > BUFF > MEND. With both strike (HARM) and
## bless (BUFF) available and an enemy present, should pick strike.
func test_attacker_prefers_harm() -> void:
	var caster := _make_unit("Atk", "grunt")
	caster.abilities = ["strike", "bless", "", ""]
	var board := LaneBoard.new()
	board.place(caster, 0, "ally")
	var enemy := _make_unit("E", "grunt")
	board.place(enemy, 0, "enemy")
	var ally := _make_unit("Ally", "grunt")
	board.place(ally, 1, "ally")
	var pick := AutobattlerEnemyAI.pick(caster, [caster, ally], [enemy], board)
	assert(pick.ability != null, "should pick something")
	assert(pick.ability.ability_id == "strike",
		"ATTACKER should prefer HARM (strike) but got: " + pick.ability.ability_id)
	print("  PASS test_attacker_prefers_harm")

## HEALER role: MEND > BUFF > HARM > DEBUFF. With healing_draught (MEND) and
## strike (HARM) both available, should pick the MEND ability.
func test_healer_prefers_mend() -> void:
	var caster := _make_unit("Healer", "alchemist")
	caster.abilities = ["healing_draught", "strike", "", ""]
	var board := LaneBoard.new()
	var ally := _make_unit("LowAlly", "grunt")
	ally.current_hp = 1
	board.place(caster, 0, "ally")
	board.place(ally, 1, "ally")
	var enemy := _make_unit("E", "grunt")
	board.place(enemy, 0, "enemy")
	var pick := AutobattlerEnemyAI.pick(caster, [caster, ally], [enemy], board)
	assert(pick.ability != null, "should pick something")
	var has_mend := false
	for eff: EffectData in pick.ability.effects:
		if eff.effect_type == EffectData.EffectType.MEND:
			has_mend = true
	assert(has_mend, "HEALER should prefer MEND but got: " + pick.ability.ability_id)
	print("  PASS test_healer_prefers_mend (picked: %s)" % pick.ability.ability_id)

## Slot 0 is on cooldown; slots 1 and 2 are empty. Nothing can fire.
func test_skips_when_all_on_cooldown() -> void:
	var caster := _make_unit("Stuck", "grunt")
	caster.abilities = ["strike", "", "", ""]
	caster.cooldowns = [3, 0, 0]
	var board := LaneBoard.new()
	board.place(caster, 0, "ally")
	var enemy := _make_unit("E", "grunt")
	board.place(enemy, 0, "enemy")
	var pick := AutobattlerEnemyAI.pick(caster, [caster], [enemy], board)
	assert(pick.ability == null, "should return null when only ability is on cooldown")
	print("  PASS test_skips_when_all_on_cooldown")

## No enemies on board; strike (HARM) has no target. ATTACKER falls back to
## bless (BUFF) which targets allies (always valid).
func test_falls_back_when_no_harm_target() -> void:
	var caster := _make_unit("Atk", "grunt")
	caster.abilities = ["strike", "bless", "", ""]
	var board := LaneBoard.new()
	board.place(caster, 0, "ally")
	var ally := _make_unit("Ally", "grunt")
	board.place(ally, 1, "ally")
	var pick := AutobattlerEnemyAI.pick(caster, [caster, ally], [], board)
	assert(pick.ability != null, "should fall back to non-HARM")
	assert(pick.ability.ability_id == "bless",
		"should fall back to BUFF (bless) but got: " + pick.ability.ability_id)
	print("  PASS test_falls_back_when_no_harm_target")

func _make_unit(uname: String, archetype_id: String) -> CombatantData:
	var d := CombatantData.new()
	d.character_name = uname
	d.current_hp = 20
	d.archetype_id = archetype_id
	d.cooldowns = [0, 0, 0]
	return d
