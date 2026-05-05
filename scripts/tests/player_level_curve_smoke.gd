extends SceneTree

const LevelCurve := preload("res://scripts/player/player_level_curve.gd")

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_check_curve_shape()
	_check_milestone_totals()
	_check_save_normalization()
	if failures.is_empty():
		print("PLAYER_LEVEL_CURVE_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check_curve_shape() -> void:
	var previous := 0
	for level in range(1, 31):
		var required := LevelCurve.get_required_experience_for_level(level)
		if required <= previous:
			failures.append("level curve should be strictly increasing at level %d: %d <= %d" % [level, required, previous])
		previous = required
	if LevelCurve.get_required_experience_for_level(1) != 20:
		failures.append("level 1 requirement should allow very fast first blessing, got %d" % LevelCurve.get_required_experience_for_level(1))

func _check_milestone_totals() -> void:
	var total_to_6 := LevelCurve.get_total_required_experience_to_reach_level(6)
	var total_to_12 := LevelCurve.get_total_required_experience_to_reach_level(12)
	var total_to_18 := LevelCurve.get_total_required_experience_to_reach_level(18)
	var total_to_25 := LevelCurve.get_total_required_experience_to_reach_level(25)
	if total_to_6 < 290 or total_to_6 > 340:
		failures.append("level 6 total should make early blessing setup fast, got %d" % total_to_6)
	if total_to_12 < 2100 or total_to_12 > 2400:
		failures.append("level 12 total should still be reachable before midgame slowdown, got %d" % total_to_12)
	if total_to_18 < 16500 or total_to_18 > 17200:
		failures.append("level 18 total should target roughly 12-minute level 18 pacing, got %d" % total_to_18)
	if total_to_25 < 69500 or total_to_25 > 74500:
		failures.append("level 25 total should strongly slow late endless progression, got %d" % total_to_25)

func _check_save_normalization() -> void:
	var old_required := 10366
	var normalized := LevelCurve.normalize_required_experience(16, old_required)
	if normalized != LevelCurve.get_required_experience_for_level(16):
		failures.append("old exponential save requirement should clamp down to new curve, got %d" % normalized)
	var low_required := 12
	if LevelCurve.normalize_required_experience(8, low_required) != low_required:
		failures.append("normalization should preserve lower in-progress custom requirement")
