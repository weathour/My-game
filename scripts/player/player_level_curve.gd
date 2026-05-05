extends RefCounted

const BASE_REQUIRED_EXPERIENCE := 30.0
const LINEAR_STEP := 10.0
const POWER_STEP := 14.0
const POWER_EXPONENT := 1.54
const MIDGAME_STEP := 340.0
const LATEGAME_STEP := 850.0
const MIDGAME_LEVEL := 12
const LATEGAME_LEVEL := 18


static func get_required_experience_for_level(level: int) -> int:
	var safe_level: int = max(1, level)
	var index: float = float(safe_level - 1)
	var required: float = BASE_REQUIRED_EXPERIENCE
	required += index * LINEAR_STEP
	required += pow(index, POWER_EXPONENT) * POWER_STEP
	required += float(max(0, safe_level - MIDGAME_LEVEL)) * MIDGAME_STEP
	required += float(max(0, safe_level - LATEGAME_LEVEL)) * LATEGAME_STEP
	return max(1, int(round(required)))


static func get_next_required_experience_after_level_up(new_level: int) -> int:
	return get_required_experience_for_level(max(1, new_level))


static func normalize_required_experience(current_level: int, current_required: int) -> int:
	var target: int = get_required_experience_for_level(max(1, current_level))
	if current_required <= 0:
		return target
	return max(1, min(current_required, target))


static func get_total_required_experience_to_reach_level(target_level: int) -> int:
	var total := 0
	for level in range(1, max(1, target_level)):
		total += get_required_experience_for_level(level)
	return total
