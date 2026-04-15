extends SceneTree

func _initialize() -> void:
	# Task 1: AbilityData can be instantiated with expected fields
	var ability := AbilityData.new()
	assert(ability.ability_id == "", "default ability_id should be empty")
	assert(ability.energy_cost == 0, "default energy_cost should be 0")
	assert(ability.range == 1, "default range should be 1")
	assert(ability.target_type == AbilityData.TargetType.SINGLE_ENEMY,
		"default target_type should be SINGLE_ENEMY")
	print("Task 1 PASSED: AbilityData defaults correct")
	quit()
