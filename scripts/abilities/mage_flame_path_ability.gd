extends RefCounted

const SKILL_ID := "flame_path"
const PLAYER_SKILL_LEVEL_EFFECT_FLOW := preload("res://scripts/player/player_skill_level_effect_flow.gd")
const COOLDOWN := 20.0
const ACTIVE_DURATION := 8.0
const PATH_DURATION := 15.0
const DAMAGE_PER_SECOND_RATIO := 0.50
const MOVE_SPEED_MULTIPLIER := 1.15

var cooldown_remaining: float = 0.0
var active_remaining: float = 0.0
var path_remaining: float = 0.0
var path_node: Node2D

func update(owner, delta: float) -> void:
	if active_remaining > 0.0:
		active_remaining = max(0.0, active_remaining - delta)
		if path_node != null and is_instance_valid(path_node) and path_node.has_method("record_position"):
			path_node.record_position(owner.global_position)
	if path_remaining > 0.0:
		path_remaining = max(0.0, path_remaining - delta)
	if path_remaining <= 0.0 and path_node != null:
		if is_instance_valid(path_node):
			path_node.queue_free()
		path_node = null
		if active_remaining <= 0.0 and cooldown_remaining <= 0.0:
			cooldown_remaining = COOLDOWN
	if cooldown_remaining > 0.0:
		cooldown_remaining = max(0.0, cooldown_remaining - delta)

func on_role_switched(previous_role_id: String, active_role_id: String) -> void:
	if previous_role_id == "mage" and active_role_id != "mage":
		active_remaining = 0.0


func can_trigger(owner, role_id: String) -> bool:
	return owner != null and is_instance_valid(owner) and role_id == "mage" and not bool(owner.get("is_dead")) and not bool(owner.get("level_up_active")) and _is_unlocked(owner) and active_remaining <= 0.0 and path_remaining <= 0.0 and cooldown_remaining <= 0.0

func try_trigger(owner) -> bool:
	if not can_trigger(owner, "mage"):
		return false
	active_remaining = ACTIVE_DURATION
	path_remaining = PATH_DURATION
	var scene: Node = owner.get_tree().current_scene
	if scene == null:
		return false
	path_node = Node2D.new()
	path_node.name = "MageFlamePath"
	path_node.set_script(preload("res://scripts/player/mage_flame_path.gd"))
	path_node.configure(owner, float(owner._get_role_damage("mage")) * (DAMAGE_PER_SECOND_RATIO + PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_mage_flame_path_damage_per_second_bonus(owner)))
	path_node.record_position(owner.global_position)
	scene.add_child(path_node)
	owner._spawn_ring_effect(owner.global_position, 48.0, Color(1.0, 0.34, 0.10, 0.5), 7.0, 0.18)
	return true

func get_move_speed_multiplier(owner) -> float:
	if active_remaining <= 0.0 or owner == null or str(owner._get_active_role().get("id", "")) != "mage":
		return 1.0
	var mult: float = MOVE_SPEED_MULTIPLIER + PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_mage_flame_path_move_speed_bonus(owner)
	if owner.has_method("_has_level_talent") and owner._has_level_talent("mage_level_talent_flame_path_2"):
		mult += 0.30
	return mult

func is_active() -> bool:
	return active_remaining > 0.0

func get_cooldown_slot(owner = null) -> Dictionary:
	var remaining: float = cooldown_remaining
	if active_remaining > 0.0 or path_remaining > 0.0:
		remaining = max(active_remaining, path_remaining)
	return {
		"name": "火焰之径",
		"remaining": remaining,
		"duration": COOLDOWN,
		"color": Color(1.0, 0.34, 0.10, 1.0),
		"description": "移动时留下火焰路径；持续 8 秒，路径持续 15 秒后开始 20 秒冷却。"
	}
func get_save_data() -> Dictionary:
	return {"cooldown_remaining": cooldown_remaining, "active_remaining": active_remaining, "path_remaining": path_remaining}

func apply_save_data(data: Dictionary) -> void:
	cooldown_remaining = max(0.0, float(data.get("cooldown_remaining", 0.0)))
	active_remaining = max(0.0, float(data.get("active_remaining", 0.0)))
	path_remaining = max(0.0, float(data.get("path_remaining", 0.0)))

func _is_unlocked(owner) -> bool:
	return owner != null and owner.has_method("_is_blessing_skill_unlocked") and bool(owner._is_blessing_skill_unlocked(SKILL_ID))
