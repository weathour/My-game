extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const GAME_SETTINGS := preload("res://scripts/game_settings.gd")
const PLAYER_BLESSING_SKILL_STATE := preload("res://scripts/player/player_blessing_skill_state.gd")
const PLAYER_ABILITY_FLOW := preload("res://scripts/player/player_ability_flow.gd")
const PLAYER_SKILL_COOLDOWN_FLOW := preload("res://scripts/player/player_skill_cooldown_flow.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	# 1) 设置层：默认自动、切换可反转、随设置持久（与存档无关）
	var previous_manual := GAME_SETTINGS.is_skill_manual("blade_storm")
	var previous_reload_manual := GAME_SETTINGS.is_skill_manual("infinite_reload")
	GAME_SETTINGS.set_skill_manual("blade_storm", false)
	assert(not GAME_SETTINGS.is_skill_manual("blade_storm"), "skills should default to auto release")
	assert(GAME_SETTINGS.toggle_skill_manual("blade_storm"), "toggle should switch to manual")
	assert(GAME_SETTINGS.is_skill_manual("blade_storm"), "manual state should persist in settings")
	assert(not GAME_SETTINGS.toggle_skill_manual("blade_storm"), "toggle should switch back to auto")
	assert(not GAME_SETTINGS.is_skill_manual("blade_storm"), "auto state should persist in settings")

	# 2) 事件映射：槽位动作按设置的键位解析
	var key_event := InputEventKey.new()
	key_event.pressed = true
	key_event.keycode = GAME_SETTINGS.load_keycode(GAME_SETTINGS.get_skill_slot_action_id(2))
	assert(GAME_SETTINGS.get_skill_slot_index_for_event(key_event) == 2, "slot key should map to its slot index")

	# 3) 分发层：自动状态快捷键不施放；手动状态快捷键施放；手动状态不自动施放
	var holder := Node2D.new()
	root.add_child(holder)
	current_scene = holder
	var player = PLAYER_SCENE.instantiate()
	holder.add_child(player)
	await process_frame
	assert(PLAYER_BLESSING_SKILL_STATE.force_unlock_skill(player, "blade_storm", 1), "blade storm should unlock")
	var slot_index := _find_slot_index(player, "blade_storm")
	assert(slot_index > 0, "blade storm should occupy a hotkey slot")
	GAME_SETTINGS.set_skill_manual("blade_storm", false)
	assert(PLAYER_ABILITY_FLOW.try_handle_manual_skill_slot(player, slot_index), "auto state should consume the hotkey and show a hint")
	assert(not player.swordsman_blade_storm_ability.is_active(), "auto state hotkey should not cast the skill")
	assert(PLAYER_ABILITY_FLOW.toggle_skill_manual(player, "blade_storm"), "toggle should turn manual on")
	assert(GAME_SETTINGS.is_skill_manual("blade_storm"), "blade storm should now be manual")
	PLAYER_ABILITY_FLOW.try_trigger_swordsman_blade_storm(player)
	assert(not player.swordsman_blade_storm_ability.is_active(), "manual skill should not auto cast")
	assert(PLAYER_ABILITY_FLOW.try_handle_manual_skill_slot(player, slot_index), "manual state should cast from the hotkey")
	assert(player.swordsman_blade_storm_ability.is_active(), "hotkey cast should activate the skill")
	PLAYER_ABILITY_FLOW.toggle_manual_skill_slot(player, slot_index)
	assert(not GAME_SETTINGS.is_skill_manual("blade_storm"), "slot toggle should turn manual off again")

	# 4) 槽位交换：拖动交换等价于重排该角色的技能槽顺序（全局设置，测试前后保存还原）
	var previous_order: Array[String] = GAME_SETTINGS.get_skill_slot_order("swordsman")
	GAME_SETTINGS.set_skill_slot_order("swordsman", [])
	assert(PLAYER_BLESSING_SKILL_STATE.force_unlock_skill(player, "knight_thrust", 1), "knight thrust should unlock")
	var order_before: Array[String] = PLAYER_SKILL_COOLDOWN_FLOW.get_role_active_skill_ids(player, "swordsman")
	assert(order_before.size() >= 2, "swordsman should have at least two skill slots")
	var first_skill: String = order_before[0]
	var second_skill: String = order_before[1]
	assert(player._swap_skill_slot_order("swordsman", 1, 2), "slot swap should succeed")
	var order_after: Array[String] = PLAYER_SKILL_COOLDOWN_FLOW.get_role_active_skill_ids(player, "swordsman")
	assert(order_after[0] == second_skill and order_after[1] == first_skill, "slots should exchange positions")
	GAME_SETTINGS.set_skill_slot_order("swordsman", [])
	var order_restored: Array[String] = PLAYER_SKILL_COOLDOWN_FLOW.get_role_active_skill_ids(player, "swordsman")
	assert(order_restored[0] == first_skill, "clearing the custom order should restore the unlock order")
	GAME_SETTINGS.set_skill_slot_order("swordsman", previous_order)

	# 5) 无天赋的无限装填按普通技能处理：手动状态下快捷键应能单次施放（不再是只能开关）
	assert(PLAYER_BLESSING_SKILL_STATE.force_unlock_skill(player, "infinite_reload", 1), "infinite reload should unlock")
	player.active_role_index = 1
	GAME_SETTINGS.set_skill_manual("infinite_reload", true)
	var reload_slot := _find_slot_index(player, "infinite_reload", "gunner")
	assert(reload_slot > 0, "infinite reload should occupy a gunner slot")
	assert(PLAYER_ABILITY_FLOW.try_handle_manual_skill_slot(player, reload_slot), "manual infinite reload without talent should cast from the hotkey")
	assert(player.gunner_infinite_reload_ability.is_active(), "infinite reload should be active after the hotkey cast")
	GAME_SETTINGS.set_skill_manual("infinite_reload", false)

	_check_mechanic_casts(holder)
	_check_all_registered_skills(player)
	GAME_SETTINGS.set_skill_manual("blade_storm", previous_manual)
	GAME_SETTINGS.set_skill_manual("infinite_reload", previous_reload_manual)
	print("SKILL_MANUAL_MODE_SMOKE_OK")
	quit(0)


func _find_slot_index(player, skill_id: String, role_id: String = "swordsman") -> int:
	var skill_ids: Array[String] = PLAYER_SKILL_COOLDOWN_FLOW.get_role_active_skill_ids(player, role_id)
	for index in range(skill_ids.size()):
		if skill_ids[index] == skill_id:
			return index + 1
	return 0


func _check_mechanic_casts(scene: Node2D) -> void:
	var player = PLAYER_SCENE.instantiate()
	scene.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.fire_timer.stop()
	player.configure_story_loadout(["mechanic", "gunner", "mage"])
	for skill_id in PLAYER_SKILL_COOLDOWN_FLOW.ROLE_ACTIVE_SKILL_PROPERTIES.mechanic:
		var previous := GAME_SETTINGS.is_skill_manual(skill_id)
		assert(PLAYER_BLESSING_SKILL_STATE.force_unlock_skill(player, skill_id, 1))
		var property_name: String = PLAYER_SKILL_COOLDOWN_FLOW.ROLE_ACTIVE_SKILL_PROPERTIES.mechanic[skill_id]
		var ability: Variant = player.get(property_name)
		var auto_method := "_try_trigger_" + property_name.trim_suffix("_ability")
		GAME_SETTINGS.set_skill_manual(skill_id, true)
		player.call(auto_method)
		assert(is_zero_approx(ability.cooldown_remaining), "%s does not deploy automatically in manual mode" % skill_id)
		assert(PLAYER_ABILITY_FLOW.try_handle_manual_skill_slot(player, _find_slot_index(player, skill_id, "mechanic")))
		assert(ability.cooldown_remaining > 0.0, "%s really deploys from the hotkey" % skill_id)
		ability.cooldown_remaining = 0.0
		GAME_SETTINGS.set_skill_manual(skill_id, false)
		player.call(auto_method)
		assert(ability.cooldown_remaining > 0.0, "%s really deploys automatically after switching back" % skill_id)
		GAME_SETTINGS.set_skill_manual(skill_id, previous)
	player.queue_free()
	print("MECHANIC_REAL_CAST_CONTRACT_OK: five skills")


func _check_all_registered_skills(player) -> void:
	player.set_process(false)
	player.set_physics_process(false)
	player.fire_timer.stop()
	player.roles = preload("res://scripts/player/roles/role_database.gd").get_role_data()
	# 只替换施放端，保留真实角色、解锁顺序、模式设置、自动入口与快捷键分发。
	for role_id in PLAYER_SKILL_COOLDOWN_FLOW.ROLE_ACTIVE_SKILL_PROPERTIES:
		for property_name in PLAYER_SKILL_COOLDOWN_FLOW.ROLE_ACTIVE_SKILL_PROPERTIES[role_id].values():
			player.set(property_name, CastProbe.new())
	for unsupported_id in ["", "missing_skill", "mechanic_basic_attack", "mechanic_ultimate"]:
		var previous := GAME_SETTINGS.is_skill_manual(unsupported_id)
		assert(not PLAYER_ABILITY_FLOW.toggle_skill_manual(player, unsupported_id), "unsupported skill IDs cannot change manual-mode settings")
		assert(GAME_SETTINGS.is_skill_manual(unsupported_id) == previous, "rejected toggles preserve existing settings")
	var checked := 0
	for role_index in player.roles.size():
		player.active_role_index = role_index
		var role_id: String = player.roles[role_index].id
		for skill_id in PLAYER_SKILL_COOLDOWN_FLOW.ROLE_ACTIVE_SKILL_PROPERTIES[role_id]:
			var previous := GAME_SETTINGS.is_skill_manual(skill_id)
			var property_name: String = PLAYER_SKILL_COOLDOWN_FLOW.ROLE_ACTIVE_SKILL_PROPERTIES[role_id][skill_id]
			var probe: CastProbe = player.get(property_name)
			assert(PLAYER_BLESSING_SKILL_STATE.force_unlock_skill(player, skill_id, 1))
			var slot := _find_slot_index(player, skill_id, role_id)
			assert(slot > 0, "%s has a real slot" % skill_id)
			var auto_method := "try_trigger_" + property_name.trim_suffix("_ability")
			GAME_SETTINGS.set_skill_manual(skill_id, true)
			player.call("_" + auto_method)
			assert(probe.casts == 0, "%s manual mode blocks auto casting" % skill_id)
			assert(PLAYER_ABILITY_FLOW.try_handle_manual_skill_slot(player, slot), "%s manual dispatch exists" % skill_id)
			assert(probe.casts == 1, "%s hotkey casts once" % skill_id)
			GAME_SETTINGS.set_skill_manual(skill_id, false)
			assert(PLAYER_ABILITY_FLOW.try_handle_manual_skill_slot(player, slot))
			assert(probe.casts == 1, "%s auto-mode hotkey does not cast" % skill_id)
			player.call("_" + auto_method)
			assert(probe.casts == 2, "%s returns to auto casting" % skill_id)
			GAME_SETTINGS.set_skill_manual(skill_id, previous)
			checked += 1
	assert(checked == PLAYER_BLESSING_SKILL_STATE.ACTIVE_SLOT_SKILL_IDS.size(), "every authored active skill is registered and exercised")
	print("ACTIVE_SKILL_DISPATCH_CONTRACT_OK: %d skills, four roles" % checked)


class CastProbe:
	extends RefCounted
	var casts := 0
	func can_trigger(_owner, _role_id: String) -> bool:
		return true
	func try_trigger(_owner, _direction: Vector2 = Vector2.ZERO) -> bool:
		casts += 1
		return true
	func is_manual_toggle_enabled(_owner) -> bool:
		return false
	func is_blocking_actions(_owner) -> bool:
		return false
