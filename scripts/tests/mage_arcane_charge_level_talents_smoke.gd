extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const TIDAL_SURGE_ABILITY := preload("res://scripts/abilities/mage_tidal_surge_ability.gd")
const ULTIMATE_FLOW := preload("res://scripts/player/player_ultimate_flow.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var player = PLAYER_SCENE.instantiate()
	scene.add_child(player)
	await process_frame

	_set_active_role(player, "mage")
	var base_proc_chance: float = player._get_mage_kill_energy_proc_chance()
	_set_level_talents(player, "mage", ["mage_level_talent_arcane_charge_1"])
	assert(is_equal_approx(player._get_mage_kill_energy_proc_chance(), base_proc_chance + 0.05))

	player.mage_arcane_charge_stacks = 4
	assert(is_equal_approx(player._get_mage_arcane_charge_skill_cooldown_multiplier("mage"), 0.96))
	var surge = TIDAL_SURGE_ABILITY.new()
	assert(is_equal_approx(surge._get_cooldown(player), 26.0 * 0.96))

	_set_level_talents(player, "mage", ["mage_level_talent_arcane_charge_2"])
	player.mage_arcane_charge_stacks = 5
	assert(is_equal_approx(player._get_mage_arcane_charge_ultimate_damage_multiplier("mage"), 1.10))

	player.mage_arcane_charge_stacks = 4
	player._transfer_mage_arcane_charge_to_role_on_switch("gunner")
	_set_active_role(player, "gunner")
	assert(is_equal_approx(player._get_mage_arcane_charge_ultimate_damage_multiplier("gunner"), 1.08))
	var payload: Dictionary = ULTIMATE_FLOW.build_ultimate_cast_payload(player)
	assert(is_equal_approx(float(payload.get("damage_multiplier", 1.0)), ULTIMATE_FLOW.get_ultimate_level_damage_multiplier(player) * 1.08))

	scene.queue_free()
	await process_frame
	current_scene = null
	print("MAGE_ARCANE_CHARGE_LEVEL_TALENTS_SMOKE_OK")
	quit(0)


func _set_level_talents(player: Node, role_id: String, talent_ids: Array) -> void:
	var state: Dictionary = player.role_special_states.get(role_id, {})
	state["level_talents"] = talent_ids.duplicate()
	player.role_special_states[role_id] = state


func _set_active_role(player: Node, role_id: String) -> void:
	for index in range(player.roles.size()):
		if str(player.roles[index].get("id", "")) == role_id:
			player.active_role_index = index
			player._update_active_role_state()
			return
