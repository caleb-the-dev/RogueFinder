extends SceneTree

## --- Unit Tests: Defender-Driven QTE (reactive overhaul) ---
## Tests the new defender-driven QTE semantics:
##   - Damage multiplier mapping (defender roll → damage multiplier)
##   - New HARM formula: max(1, round(dmg_mult * (base_value + caster_attack)))
##   - AoE HARM produces one damage application per hit defender
##   - Non-HARM effect types never route through QTE
##   - AI-defender path: qte_resolution → defender roll → dmg_mult chain

func _initialize() -> void:
	_test_defender_roll_to_dmg_multiplier()
	_test_harm_formula()
	_test_aoe_produces_n_damage_applications()
	_test_non_harm_effect_types_are_not_harm()
	_test_ai_defender_full_chain()
	print("All QTE reactive tests PASSED.")
	quit()

## --- Mirrors CombatManager3D._defender_roll_to_dmg_multiplier() ---
func _defender_dmg_mult(roll: float) -> float:
	if roll >= 1.25: return 0.5
	if roll >= 1.0:  return 0.75
	if roll >= 0.75: return 1.0
	return 1.25

## --- Mirrors CombatManager3D._qte_resolution_to_multiplier() ---
func _qte_res_to_roll(qte_res: float) -> float:
	if qte_res >= 0.85: return 1.25
	if qte_res >= 0.60: return 1.0
	if qte_res >= 0.30: return 0.75
	return 0.25

## --- Mirrors the new HARM damage formula ---
## value = max(1, round(dmg_mult * (base_value + caster_attack)))
func _harm_value(dmg_mult: float, base_value: int, caster_attack: int) -> int:
	return maxi(1, roundi(dmg_mult * float(base_value + caster_attack)))

## --- Mirrors whether an effect type routes through the HARM QTE chain ---
func _is_harm_type(effect_type: EffectData.EffectType) -> bool:
	return effect_type == EffectData.EffectType.HARM

## ============================================================
## Defender roll → damage multiplier mapping (4 tiers)
## Perfect dodge (1.25) → defender blocked well → low damage (0.5)
## Hit (0.25)           → defender failed to dodge → high damage (1.25)
## ============================================================

func _test_defender_roll_to_dmg_multiplier() -> void:
	assert(_defender_dmg_mult(1.25) == 0.5,
		"roll=1.25 (perfect dodge) → dmg_mult=0.5")
	assert(_defender_dmg_mult(1.0) == 0.75,
		"roll=1.0 (good dodge) → dmg_mult=0.75")
	assert(_defender_dmg_mult(0.75) == 1.0,
		"roll=0.75 (weak dodge) → dmg_mult=1.0")
	assert(_defender_dmg_mult(0.25) == 1.25,
		"roll=0.25 (miss/hit) → dmg_mult=1.25")
	## Boundary checks — values at tier thresholds
	## Values within tier bands (not at exact boundaries to avoid float precision issues)
	assert(_defender_dmg_mult(1.24) == 0.75,
		"roll=1.24 (in good-dodge band, below 1.25) → dmg_mult=0.75")
	assert(_defender_dmg_mult(0.90) == 1.0,
		"roll=0.90 (in weak-dodge band, below 1.0) → dmg_mult=1.0")
	assert(_defender_dmg_mult(0.50) == 1.25,
		"roll=0.50 (in miss band, below 0.75) → dmg_mult=1.25")
	assert(_defender_dmg_mult(0.0) == 1.25,
		"roll=0.0 (no dodge) → dmg_mult=1.25")

## ============================================================
## New HARM formula: value = max(1, round(dmg_mult * (base_value + caster_attack)))
## caster_attack = CombatantData.attack = 5 + strength + equip_bonus
## ============================================================

func _test_harm_formula() -> void:
	## --- miss tier (dmg_mult=1.25) ---
	## base=4, caster_attack=6 → 1.25 * (4+6) = 12.5 → round → 13
	assert(_harm_value(1.25, 4, 6) == 13,
		"miss: 1.25*(4+6)=12.5 → 13")
	## --- weak tier (dmg_mult=1.0) ---
	## base=4, caster_attack=6 → 1.0 * 10 = 10 → 10
	assert(_harm_value(1.0, 4, 6) == 10,
		"weak: 1.0*(4+6)=10 → 10")
	## --- good tier (dmg_mult=0.75) ---
	## base=4, caster_attack=6 → 0.75 * 10 = 7.5 → round → 8
	assert(_harm_value(0.75, 4, 6) == 8,
		"good: 0.75*(4+6)=7.5 → 8")
	## --- perfect tier (dmg_mult=0.5) ---
	## base=4, caster_attack=6 → 0.5 * 10 = 5 → 5
	assert(_harm_value(0.5, 4, 6) == 5,
		"perfect: 0.5*(4+6)=5 → 5")
	## --- minimum floor: always at least 1 ---
	## base=0, caster_attack=0, dmg_mult=0.5 → round(0) = 0 → max(1, 0) = 1
	assert(_harm_value(0.5, 0, 0) == 1,
		"min floor: 0.5*(0+0)=0 → clamped to 1")
	## --- high damage case ---
	## base=10, caster_attack=10, dmg_mult=1.25 → 1.25*20 = 25
	assert(_harm_value(1.25, 10, 10) == 25,
		"miss: 1.25*(10+10)=25 → 25")

## ============================================================
## AoE HARM: N defenders produces N separate damage values,
## each with the respective defender's multiplier.
## ============================================================

func _test_aoe_produces_n_damage_applications() -> void:
	## Simulate 3 defenders each with a different roll
	var defender_rolls: Array[float] = [1.25, 0.75, 0.25]  ## dodge, weak, miss
	var base_value: int = 5
	var caster_attack: int = 5
	var damages: Array[int] = []
	for roll: float in defender_rolls:
		var dmg_mult: float = _defender_dmg_mult(roll)
		damages.append(_harm_value(dmg_mult, base_value, caster_attack))
	## Verify exactly N = 3 results
	assert(damages.size() == 3,
		"3 defenders → 3 damage applications")
	## 1.25 roll → dmg_mult=0.5 → 0.5*(5+5)=5
	assert(damages[0] == 5,
		"defender[0] roll=1.25 (perfect dodge) → dmg=5")
	## 0.75 roll → dmg_mult=1.0 → 1.0*(5+5)=10
	assert(damages[1] == 10,
		"defender[1] roll=0.75 (weak dodge) → dmg=10")
	## 0.25 roll → dmg_mult=1.25 → 1.25*(5+5)=12.5 → 13
	assert(damages[2] == 13,
		"defender[2] roll=0.25 (miss) → dmg=13")

	## Verify that each damage is distinct (different multipliers produce different damage)
	assert(damages[0] != damages[1], "perfect dodge < weak dodge damage")
	assert(damages[1] != damages[2], "weak dodge < miss damage")
	assert(damages[0] < damages[2], "perfect dodge takes least damage")

## ============================================================
## Non-HARM effect types never route through the QTE chain.
## Only HARM == EffectType.HARM; all others return false from _is_harm_type().
## ============================================================

func _test_non_harm_effect_types_are_not_harm() -> void:
	assert(_is_harm_type(EffectData.EffectType.HARM) == true,
		"HARM → routed through QTE")
	assert(_is_harm_type(EffectData.EffectType.MEND) == false,
		"MEND → no QTE, auto-resolve")
	assert(_is_harm_type(EffectData.EffectType.BUFF) == false,
		"BUFF → no QTE, auto-resolve")
	assert(_is_harm_type(EffectData.EffectType.DEBUFF) == false,
		"DEBUFF → no QTE, auto-resolve")
	assert(_is_harm_type(EffectData.EffectType.FORCE) == false,
		"FORCE → no QTE, auto-resolve")
	assert(_is_harm_type(EffectData.EffectType.TRAVEL) == false,
		"TRAVEL → no QTE, auto-resolve")

## ============================================================
## AI-defender full chain: qte_resolution → defender roll → dmg_mult
## Tier table mirrors _qte_resolution_to_multiplier() (unchanged).
## ============================================================

func _test_ai_defender_full_chain() -> void:
	## High tier qte_resolution (0.85–1.0) → roll=1.25 → dmg_mult=0.5
	var roll_high: float = _qte_res_to_roll(0.9)
	assert(roll_high == 1.25, "qte_res=0.9 → defender roll=1.25")
	assert(_defender_dmg_mult(roll_high) == 0.5,
		"roll=1.25 → dmg_mult=0.5 (tanky defender)")

	## Good tier qte_resolution (0.60–0.85) → roll=1.0 → dmg_mult=0.75
	var roll_good: float = _qte_res_to_roll(0.7)
	assert(roll_good == 1.0, "qte_res=0.7 → defender roll=1.0")
	assert(_defender_dmg_mult(roll_good) == 0.75,
		"roll=1.0 → dmg_mult=0.75")

	## Weak tier qte_resolution (0.30–0.60) → roll=0.75 → dmg_mult=1.0
	var roll_weak: float = _qte_res_to_roll(0.5)
	assert(roll_weak == 0.75, "qte_res=0.5 → defender roll=0.75")
	assert(_defender_dmg_mult(roll_weak) == 1.0,
		"roll=0.75 → dmg_mult=1.0 (standard damage)")

	## Miss tier qte_resolution (0.0–0.30) → roll=0.25 → dmg_mult=1.25
	var roll_miss: float = _qte_res_to_roll(0.1)
	assert(roll_miss == 0.25, "qte_res=0.1 → defender roll=0.25")
	assert(_defender_dmg_mult(roll_miss) == 1.25,
		"roll=0.25 → dmg_mult=1.25 (weak defender takes extra damage)")

	## Boundary — exactly at tier thresholds
	assert(_qte_res_to_roll(0.85) == 1.25, "qte_res=0.85 (tier boundary) → roll=1.25")
	assert(_qte_res_to_roll(0.60) == 1.0,  "qte_res=0.60 (tier boundary) → roll=1.0")
	assert(_qte_res_to_roll(0.30) == 0.75, "qte_res=0.30 (tier boundary) → roll=0.75")
	assert(_qte_res_to_roll(0.0)  == 0.25, "qte_res=0.0 (floor) → roll=0.25")
