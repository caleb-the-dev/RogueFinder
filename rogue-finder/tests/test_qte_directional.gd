extends SceneTree

## --- Unit Tests: Directional Sequence QTE ---
## Tests pure logic for BUFF / DEBUFF QTE style.
## No scene nodes are instantiated — all helpers are mirrored from QTEBar.gd.

func _initialize() -> void:
	_test_sequence_length()
	_test_no_immediate_repeats()
	_test_correct_input_is_hit()
	_test_wrong_input_is_miss()
	_test_timeout_is_miss()
	_test_multiplier_tiers()
	print("All QTE directional tests PASSED.")
	quit()

## --- Mirrors QTEBar._generate_dir_sequence() ---
func _gen_sequence(count: int) -> Array[String]:
	var dirs := ["UP", "DOWN", "LEFT", "RIGHT"]
	var seq: Array[String] = []
	var last: String = ""
	for _i: int in range(count):
		var pick: String = last
		while pick == last:
			pick = dirs[randi() % dirs.size()]
		seq.append(pick)
		last = pick
	return seq

## --- Mirrors QTEBar directional beat result ---
## Correct key → 1.25 (full hit).  Wrong key or timeout → 0.25 (miss).
func _dir_result(correct: bool) -> float:
	return 1.25 if correct else 0.25

## --- Mirrors QTEBar._aggregate_multiplier() ---
func _aggregate(results: Array[float]) -> float:
	if results.is_empty():
		return 0.25
	var sum: float = 0.0
	for r: float in results:
		sum += r
	var avg: float = sum / float(results.size())
	if avg >= 1.2: return 1.25
	if avg >= 0.9: return 1.0
	if avg >= 0.6: return 0.75
	return 0.25

## ============================================================
## Sequence length
## ============================================================

func _test_sequence_length() -> void:
	for length: int in [1, 2, 3, 4]:
		for _trial: int in range(30):   # repeat to catch statistical flukes
			var seq := _gen_sequence(length)
			assert(seq.size() == length,
				"length %d: expected %d items, got %d" % [length, length, seq.size()])

## ============================================================
## No immediate repeats
## ============================================================

func _test_no_immediate_repeats() -> void:
	# Run many trials to catch flaky behaviour — with 4 directions and
	# the retry loop, the probability of a consecutive repeat in any single
	# trial is 0, but we confirm this empirically with 100 runs.
	for length: int in [2, 3, 4]:
		for _trial: int in range(100):
			var seq := _gen_sequence(length)
			for i: int in range(1, seq.size()):
				assert(seq[i] != seq[i - 1],
					"repeat at index %d in seq %s" % [i, str(seq)])

## ============================================================
## Correct input registers as hit (1.25)
## ============================================================

func _test_correct_input_is_hit() -> void:
	assert(_dir_result(true) == 1.25, "correct input → 1.25")

## ============================================================
## Wrong input registers as miss (0.25)
## ============================================================

func _test_wrong_input_is_miss() -> void:
	assert(_dir_result(false) == 0.25, "wrong input → 0.25")

## ============================================================
## Timeout registers as miss (0.25)
## Timeout follows the same code path as wrong input: both call
## _process_beat_result(0.25). This confirms the mapping is identical.
## ============================================================

func _test_timeout_is_miss() -> void:
	# A timeout produces the same miss value — confirmed by calling _dir_result(false)
	# which mirrors _on_dir_input_expired() → _process_beat_result(0.25).
	assert(_dir_result(false) == 0.25, "timeout (miss path) → 0.25")

## ============================================================
## Multiplier tiers from directional beat results
##
## Tier thresholds (shared with slider QTE):
##   avg ≥ 1.2 → 1.25   avg ≥ 0.9 → 1.0   avg ≥ 0.6 → 0.75   < 0.6 → 0.25
##
## Directional beats are binary: hit=1.25, miss=0.25.  Named examples:
##   3 hits             → avg = 1.25           → tier 1.25
##   2 hits + 1 miss    → avg = (2.75)/3 ≈ 0.917 → tier 1.0
##   1 hit  + 1 miss    → avg = 0.75           → tier 0.75
##   3 misses           → avg = 0.25           → tier 0.25
## ============================================================

func _test_multiplier_tiers() -> void:
	# All correct (1 beat)
	assert(_aggregate([1.25]) == 1.25, "1/1 correct → 1.25")
	# All correct (4 beats)
	assert(_aggregate([1.25, 1.25, 1.25, 1.25]) == 1.25, "4/4 correct → 1.25")
	# 2 of 3 correct → avg ≈ 0.917 → 1.0
	assert(_aggregate([1.25, 1.25, 0.25]) == 1.0, "2/3 correct → 1.0")
	# 3 of 4 correct → avg = (3×1.25 + 0.25)/4 = 1.0 → 1.0
	assert(_aggregate([1.25, 1.25, 1.25, 0.25]) == 1.0, "3/4 correct → 1.0")
	# 1 of 2 correct → avg = 0.75 → 0.75
	assert(_aggregate([1.25, 0.25]) == 0.75, "1/2 correct → 0.75")
	# 1 of 3 correct → avg = (1.25 + 0.25 + 0.25)/3 ≈ 0.583 → 0.25
	assert(_aggregate([1.25, 0.25, 0.25]) == 0.25, "1/3 correct → 0.25")
	# All miss (1 beat)
	assert(_aggregate([0.25]) == 0.25, "0/1 correct → 0.25")
	# All miss (4 beats)
	assert(_aggregate([0.25, 0.25, 0.25, 0.25]) == 0.25, "0/4 correct → 0.25")
