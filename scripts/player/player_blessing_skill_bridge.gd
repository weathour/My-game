extends RefCounted

const PLAYER_BLESSING_SYSTEM := preload("res://scripts/player/player_blessing_system.gd")
const PLAYER_BLESSING_SKILL_STATE := preload("res://scripts/player/player_blessing_skill_state.gd")


static func get_role_stat_bonus(owner, role_id: String, stat: String) -> float:
	return PLAYER_BLESSING_SYSTEM.get_role_stat_bonus(owner, role_id, stat)


static func get_skill_stat_bonus(owner, stat: String) -> float:
	return PLAYER_BLESSING_SYSTEM.get_skill_stat_bonus(owner, stat)


static func get_skill_effect_scales(owner, stat: String) -> Array[float]:
	return PLAYER_BLESSING_SYSTEM.get_skill_effect_scales(owner, stat)


static func get_skill_effect_scales_for_skill(owner, skill_id: String, stat: String) -> Array[float]:
	return PLAYER_BLESSING_SKILL_STATE.get_skill_effect_scales(owner, skill_id, stat)


static func get_role_blessing_levels(owner, role_id: String) -> Dictionary:
	PLAYER_BLESSING_SYSTEM.sync_shared_role_blessings(owner)
	return (owner.role_blessing_levels.get(role_id, {}) as Dictionary).duplicate(true)


static func get_skill_blessing_levels(owner) -> Dictionary:
	owner.skill_blessing_levels = PLAYER_BLESSING_SYSTEM.normalize_skill_state(owner.skill_blessing_levels)
	return owner.skill_blessing_levels.duplicate(true)


static func can_compose_role_blessing(owner, role_id: String, blessing_id: String) -> bool:
	return PLAYER_BLESSING_SYSTEM.can_compose_role_blessing(owner, role_id, blessing_id)


static func can_compose_skill_blessing(owner, blessing_id: String) -> bool:
	return PLAYER_BLESSING_SYSTEM.can_compose_skill_blessing(owner, blessing_id)


static func compose_role_blessing(owner, role_id: String, blessing_id: String) -> bool:
	return PLAYER_BLESSING_SYSTEM.compose_role_blessing(owner, role_id, blessing_id)


static func compose_skill_blessing(owner, blessing_id: String) -> bool:
	return PLAYER_BLESSING_SYSTEM.compose_skill_blessing(owner, blessing_id)


static func refresh_unlocks(owner, selected_blessing_id: String = "", selected_tier: int = 0, selected_binding: String = "") -> void:
	for event in PLAYER_BLESSING_SKILL_STATE.refresh_unlocks(owner, selected_blessing_id, selected_tier, selected_binding):
		if str((event as Dictionary).get("type", "")) == "binding_choice":
			owner.pending_blessing_binding_choices.append(event)
			continue
		show_skill_event_tag(owner, event)
	owner.stats_changed.emit(owner.get_stat_summary())


static func consume_pending_binding_choice(owner) -> Dictionary:
	if owner.pending_blessing_binding_choices.is_empty():
		return {}
	return owner.pending_blessing_binding_choices.pop_front()


static func build_binding_options(_owner, choice: Dictionary) -> Array:
	var options: Array = []
	var candidates: Array = choice.get("candidates", [])
	for index in range(candidates.size()):
		var candidate: Dictionary = candidates[index]
		var skill_id := str(candidate.get("skill_id", ""))
		if not PLAYER_BLESSING_SKILL_STATE.is_blessing_bindable_skill(skill_id):
			continue
		var title := PLAYER_BLESSING_SKILL_STATE.get_skill_title(skill_id)
		var action_text := "解锁" if str(candidate.get("action", "")) == "unlock" else "进化"
		var target_tier := int(candidate.get("tier", 1))
		options.append({
			"id": "blessing_bind:%d" % index,
			"title": "%s：%s%s" % [action_text, title, "II" if target_tier >= 2 else ""],
			"description": "把本次祝福材料绑定到 %s，用于%s该技能。被绑定的祝福会从可用数量中扣除。" % [title, action_text],
			"preview_description": "绑定到 %s。" % title,
			"exact_description": "该选择会锁定本次配方材料；其他需要同祝福的技能不会获得这份材料。"
		})
	options.append({
		"id": "blessing_bind_skip",
		"title": "暂不绑定",
		"description": "保留本次祝福的数值加成，但不把这份材料绑定给任何技能。该份材料会从技能配方可用数量中扣除。",
		"preview_description": "不绑定给技能。",
		"exact_description": "跳过本次技能解锁/进化，并锁定这份材料，避免同一份祝福反复弹出绑定选择。"
	})
	return options


static func apply_binding_choice(owner, choice: Dictionary, option_id: String) -> bool:
	if option_id == "blessing_bind_skip":
		PLAYER_BLESSING_SKILL_STATE.lock_one_blessing_material(
			owner,
			str(choice.get("binding", "")),
			str(choice.get("blessing_id", "")),
			int(choice.get("tier", 0))
		)
		return true
	if not option_id.begins_with("blessing_bind:"):
		return false
	var index := int(option_id.trim_prefix("blessing_bind:"))
	var candidates: Array = choice.get("candidates", [])
	if index < 0 or index >= candidates.size():
		return false
	for event in PLAYER_BLESSING_SKILL_STATE.apply_recipe_candidate(owner, candidates[index]):
		show_skill_event_tag(owner, event)
	owner.stats_changed.emit(owner.get_stat_summary())
	return true


static func show_skill_event_tag(owner, event: Dictionary) -> void:
	var title := str(event.get("title", "技能"))
	var tier := int(event.get("tier", 1))
	var suffix := "已激活" if tier <= 1 else "已升级"
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -78.0), "%s%s" % [title, suffix], Color(0.58, 0.95, 0.86, 1.0))
	if bool(event.get("consumes_blessing_material", false)) and owner.has_signal("blessing_skill_event_announced"):
		owner.blessing_skill_event_announced.emit(event.duplicate(true))


static func is_skill_unlocked(owner, skill_id: String) -> bool:
	return PLAYER_BLESSING_SKILL_STATE.is_skill_unlocked(owner, skill_id)


static func get_skill_tier(owner, skill_id: String) -> int:
	return PLAYER_BLESSING_SKILL_STATE.get_skill_tier(owner, skill_id)


static func get_entry_rescue_regen_per_second(owner) -> float:
	return PLAYER_BLESSING_SKILL_STATE.get_entry_rescue_regen_per_second(owner)


static func get_hero_entry_effect(owner) -> Dictionary:
	return PLAYER_BLESSING_SKILL_STATE.get_hero_entry_effect(owner)


static func get_quantity_count(owner, skill_id: String) -> int:
	return PLAYER_BLESSING_SKILL_STATE.get_quantity_extra_count(owner, skill_id)


static func get_combo_scales(owner, skill_id: String) -> Array[float]:
	return PLAYER_BLESSING_SKILL_STATE.get_combo_extra_scales(owner, skill_id)


static func get_duration_multiplier(owner, skill_id: String) -> float:
	return PLAYER_BLESSING_SKILL_STATE.get_duration_multiplier(owner, skill_id)


static func get_skill_next_requirement_text(owner, skill_id: String) -> String:
	return PLAYER_BLESSING_SKILL_STATE.get_skill_next_requirement_text(owner, skill_id)


static func get_skill_graph_text(owner, role_id_filter: String = "") -> String:
	return PLAYER_BLESSING_SKILL_STATE.get_skill_graph_text(owner, role_id_filter)


static func get_basic_attack_range_multiplier(owner, skill_id: String) -> float:
	return PLAYER_BLESSING_SKILL_STATE.get_basic_attack_range_multiplier(owner, skill_id)


static func get_basic_attack_projectile_speed_multiplier(owner, skill_id: String) -> float:
	return PLAYER_BLESSING_SKILL_STATE.get_basic_attack_projectile_speed_multiplier(owner, skill_id)
