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
	if LevelCurve.get_required_experience_for_level(1) != 30:
		failures.append("level 1 requirement should keep initial HUD value 30")

func _check_milestone_totals() -> void:
	var total_to_6 := LevelCurve.get_total_required_experience_to_reach_level(6)
	var total_to_12 := LevelCurve.get_total_required_experience_to_reach_level(12)
	var total_to_18 := LevelCurve.get_total_required_experience_to_reach_level(18)
	var total_to_25 := LevelCurve.get_total_required_experience_to_reach_level(25)
	if total_to_6 < 470 or total_to_6 > 540:
		failures.append("level 6 total should keep first quality shift reachable, got %d" % total_to_6)
	if total_to_12 < 3000 or total_to_12 > 3400:
		failures.append("level 12 total should slow midgame without exploding, got %d" % total_to_12)
	if total_to_18 < 13500 or total_to_18 > 14200:
		failures.append("level 18 total should target roughly 12-minute level 18 pacing, got %d" % total_to_18)
	if total_to_25 < 62000 or total_to_25 > 67000:
		failures.append("level 25 total should strongly slow late endless progression, got %d" % total_to_25)

func _check_save_normalization() -> void:
	var old_required := 10366
	var normalized := LevelCurve.normalize_required_experience(16, old_required)
	if normalized != LevelCurve.get_required_experience_for_level(16):
		failures.append("old exponential save requirement should clamp down to new curve, got %d" % normalized)
	var low_required := 12
	if LevelCurve.normalize_required_experience(8, low_required) != low_required:
		failures.append("normalization should preserve lower in-progress custom requirement")
