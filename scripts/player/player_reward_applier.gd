extends RefCounted

const PLAYER_LEVEL_CURVE := preload("res://scripts/player/player_level_curve.gd")

const SMALL_BOSS_TRAINING_LEVEL_UP := "small_boss_training_level_up"
const SMALL_BOSS_CHOOSE_BLESSING := "small_boss_choose_blessing"


static func is_noop_upgrade(option_id: String) -> bool:
	return option_id == "final_blank_upgrade" \
		or option_id == "endless_blank_upgrade" \
		or option_id == "blessing_blank_continue" \
		or option_id.begins_with("small_boss_blank_")


static func apply_small_boss_reward(owner, option_id: String) -> bool:
	match option_id:
		SMALL_BOSS_TRAINING_LEVEL_UP:
			_grant_training_level(owner)
			return true
		SMALL_BOSS_CHOOSE_BLESSING:
			_prepare_blessing_choice(owner)
			return true
	return false


static func _grant_training_level(owner) -> void:
	owner.level += 1
	owner.experience_to_next_level = PLAYER_LEVEL_CURVE.get_next_required_experience_after_level_up(owner.level)
	owner.pending_level_ups += 1
	owner.experience_changed.emit(owner.experience, owner.experience_to_next_level, owner.level)
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -62.0), "潜心修炼 Lv.+1", Color(0.66, 1.0, 0.58, 1.0))
	owner._spawn_ring_effect(owner.global_position, 88.0, Color(0.58, 1.0, 0.48, 0.45), 8.0, 0.22)


static func _prepare_blessing_choice(owner) -> void:
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -62.0), "自选祝福", Color(0.66, 1.0, 0.58, 1.0))
	owner._spawn_ring_effect(owner.global_position, 88.0, Color(0.58, 1.0, 0.48, 0.45), 8.0, 0.22)
