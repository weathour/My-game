extends SceneTree

const FirstBatchRuntime := preload("res://scripts/build/build_first_batch_runtime.gd")
const FirstBatchModel := preload("res://scripts/build/build_first_batch_model.gd")
const FirstBatchMilestoneFlow := preload("res://scripts/player/player_first_batch_milestone_flow.gd")
const DeveloperOptionProvider := preload("res://scripts/developer/developer_option_provider.gd")
const BuildSystem := preload("res://scripts/build/build_system.gd")
const PlayerRewardApplier := preload("res://scripts/player/player_reward_applier.gd")
const SwordsmanBladeShadowAbility := preload("res://scripts/abilities/swordsman_blade_shadow_ability.gd")
const GunnerSpotterDroneAbility := preload("res://scripts/abilities/gunner_spotter_drone_ability.gd")
const MageGuardianPuppetAbility := preload("res://scripts/abilities/mage_guardian_puppet_ability.gd")

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_check_runtime_offer_format()
	_check_runtime_state_reconstruction()
	_check_runtime_refresh_format()
	_check_stage_6_milestone_unlock_surface()
	_check_developer_provider_uses_first_batch_cards()
	_check_boss_build_role_rewards()
	_check_dedicated_ability_cooldown_slots()
	if failures.is_empty():
		print("BUILD_FIRST_BATCH_RUNTIME_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check_runtime_offer_format() -> void:
	var state := FirstBatchRuntime.make_state_from_card_levels(1, {})
	var raw_offer := FirstBatchModel.build_upgrade_offer(state)
	var options := FirstBatchRuntime.format_options_for_state(raw_offer.get("options", []), state, raw_offer.get("context", {}))
	if options.size() != 3:
		failures.append("runtime should format three offer slots, got %d" % options.size())
	var slots := {}
	for option in options:
		var data: Dictionary = option
		slots[str(data.get("slot", ""))] = true
		if not bool(data.get("first_batch_card", false)):
			failures.append("runtime option should carry first_batch_card marker: %s" % str(data))
		if str(data.get("detail_description", "")) == "":
			failures.append("runtime option should include detail text: %s" % str(data))
	if not slots.has("body") or not slots.has("combat") or not slots.has("skill"):
		failures.append("runtime should map continue/link/pivot to body/combat/skill, got %s" % str(slots))

func _check_runtime_state_reconstruction() -> void:
	var state := FirstBatchRuntime.make_state_from_card_levels(6, {
		"swd_break_step": 1,
		"swd_blood_echo": 1
	})
	var role_investment: Dictionary = state.get("role_investment", {})
	if float(role_investment.get("swordsman", 0.0)) < 2.0:
		failures.append("runtime state should reconstruct swordsman investment, got %s" % str(role_investment))
	var options := FirstBatchModel.build_upgrade_options(state)
	var has_sword_engine := false
	for option in options:
		var id := str((option as Dictionary).get("id", ""))
		if id == "swd_tide_pull" or id == "swd_overheal_guard":
			has_sword_engine = true
	if not has_sword_engine:
		failures.append("reconstructed state should unlock swordsman level-6 engine offers, got %s" % str(options))

func _check_runtime_refresh_format() -> void:
	var state := FirstBatchRuntime.make_state_from_card_levels(12, {
		"swd_break_step": 1,
		"swd_blood_echo": 1,
		"swd_tide_pull": 1,
		"gun_entry_barrage": 1
	})
	var offer := FirstBatchModel.build_upgrade_offer(state)
	var refreshed := FirstBatchModel.refresh_upgrade_offer(state, offer)
	var context: Dictionary = refreshed.get("context", {})
	if int(context.get("refresh_remaining", -1)) != 0:
		failures.append("model refresh should consume one chance before runtime formatting, got %s" % str(context))
	var formatted := FirstBatchRuntime.format_options_for_state(refreshed.get("options", []), state, context)
	if formatted.is_empty():
		failures.append("runtime should keep refreshed options or fallback")
	for option in formatted:
		var data: Dictionary = option
		if not ["body", "combat", "skill"].has(str(data.get("slot", ""))):
			failures.append("refreshed runtime slot should stay UI-compatible: %s" % str(data))

func _check_stage_6_milestone_unlock_surface() -> void:
	var owner := MilestoneOwnerStub.new()
	owner.first_batch_milestone_state = FirstBatchMilestoneFlow.build_milestone_state_data()
	owner.level = 5
	FirstBatchMilestoneFlow.check_level_milestones(owner)
	if FirstBatchMilestoneFlow.is_threshold_unlocked(owner, 6):
		failures.append("level 5 should not unlock stage 6 milestone")
	owner.level = 6
	FirstBatchMilestoneFlow.check_level_milestones(owner)
	if not FirstBatchMilestoneFlow.is_threshold_unlocked(owner, 6):
		failures.append("level 6 should unlock first-batch combat milestone")
	if owner.team_bonus_calls.size() != 1 or owner.banner_count <= 0 or owner.effect_count <= 0:
		failures.append("level 6 milestone should apply stats and visible feedback")
	for role_id in ["swordsman", "gunner", "mage"]:
		var slots := FirstBatchMilestoneFlow.get_milestone_skill_slots(owner, role_id)
		if slots.is_empty():
			failures.append("level 6 milestone should expose cooldown slot for %s" % role_id)
		elif str((slots[0] as Dictionary).get("slot_label", "")) != "Build质变":
			failures.append("level 6 cooldown slot should be labeled Build质变: %s" % str(slots[0]))
	FirstBatchMilestoneFlow.apply_attack_milestones(owner, "swordsman", 1, false)
	var cooldowns: Dictionary = (owner.first_batch_milestone_state.get("cooldowns", {}) as Dictionary)
	if float(cooldowns.get("swd_stage6_break_pull", 0.0)) <= 0.0:
		failures.append("swordsman stage 6 attack should start independent cooldown")
	if owner.damage_calls <= 0 or owner.active_mana_added <= 0.0:
		failures.append("swordsman stage 6 attack should have gameplay impact")
	FirstBatchMilestoneFlow.update_cooldowns(owner, 1.0)
	var cooldown_after_tick: float = float((owner.first_batch_milestone_state.get("cooldowns", {}) as Dictionary).get("swd_stage6_break_pull", 0.0))
	if cooldown_after_tick >= float(cooldowns.get("swd_stage6_break_pull", 0.0)):
		failures.append("milestone cooldown should tick down")

func _check_developer_provider_uses_first_batch_cards() -> void:
	var options := DeveloperOptionProvider.get_first_batch_build_options({
		"swd_break_step": 1,
		"swd_blood_echo": 1
	}, 6)
	var has_old_dangzhen := false
	var has_enabled_stage_6_sword := false
	for raw_option in options:
		if raw_option is not Dictionary:
			continue
		var option: Dictionary = raw_option
		var id := str(option.get("id", ""))
		if id == "battle_dangzhen_qichao":
			has_old_dangzhen = true
		if id == "swd_tide_pull" and bool(option.get("enabled", false)):
			has_enabled_stage_6_sword = true
	if has_old_dangzhen:
		failures.append("developer first-batch provider should not list old dangzhen card ids")
	if not has_enabled_stage_6_sword:
		failures.append("developer first-batch provider should enable stage-6 cards when gates are met")


func _check_boss_build_role_rewards() -> void:
	var options := BuildSystem.get_boss_build_reward_options({"swd_blade_shadow": 2}, {}, "gunner")
	if options.size() != 3:
		failures.append("boss build should always offer exactly three role options, got %d" % options.size())
	var ids: Array[String] = []
	for option in options:
		var data: Dictionary = option
		ids.append(str(data.get("id", "")))
		if str(data.get("slot", "")) != "card":
			failures.append("boss build options should be card-slot selectable: %s" % str(data))
	if ids.size() >= 1 and ids[0] != "boss_build_gunner_spotter_drone":
		failures.append("active role should be ordered first in boss build reward, got %s" % str(ids))
	for required_id in ["boss_build_swordsman_blade_shadow", "boss_build_gunner_spotter_drone", "boss_build_mage_guardian_puppet"]:
		if not ids.has(required_id):
			failures.append("boss build missing role option %s: %s" % [required_id, str(ids)])
	var owner := BossRewardOwnerStub.new()
	PlayerRewardApplier.apply_small_boss_reward(owner, "boss_build_swordsman_blade_shadow")
	if int(owner.card_pick_levels.get("swd_blade_shadow", 0)) != 1:
		failures.append("boss swordsman reward should grant sword exclusive card level")
	if owner.special_calls.is_empty() or owner.effect_count <= 0:
		failures.append("boss role reward should apply specials and visible feedback")

func _check_dedicated_ability_cooldown_slots() -> void:
	var sword_owner := AbilityOwnerStub.new("swordsman", "swd_blade_shadow")
	var sword_ability := SwordsmanBladeShadowAbility.new()
	if not sword_ability.can_trigger(sword_owner, "swordsman"):
		failures.append("swordsman blade shadow should trigger with exclusive card")
	if str(sword_ability.get_cooldown_slot(sword_owner).get("name", "")) != "剑影留形":
		failures.append("sword exclusive cooldown slot should expose its own name")
	var gun_owner := AbilityOwnerStub.new("gunner", "gun_spotter_drone")
	var gun_ability := GunnerSpotterDroneAbility.new()
	if not gun_ability.can_trigger(gun_owner, "gunner"):
		failures.append("gunner spotter drone should trigger with exclusive card")
	if str(gun_ability.get_cooldown_slot(gun_owner).get("name", "")) != "侦察无人机":
		failures.append("gunner exclusive cooldown slot should expose its own name")
	var mage_owner := AbilityOwnerStub.new("mage", "mag_guardian_puppet")
	var mage_ability := MageGuardianPuppetAbility.new()
	if not mage_ability.can_trigger(mage_owner, "mage"):
		failures.append("mage guardian puppet should trigger with exclusive card")
	if str(mage_ability.get_cooldown_slot(mage_owner).get("name", "")) != "守护傀儡":
		failures.append("mage exclusive cooldown slot should expose its own name")

class SignalStub:
	func emit(_summary = null) -> void:
		pass

class MilestoneOwnerStub:
	var level := 1
	var first_batch_milestone_state: Dictionary = {}
	var role_switch_cooldown_bonus := 0.0
	var energy_gain_multiplier := 1.0
	var background_interval_multiplier := 1.0
	var ultimate_cost_multiplier := 1.0
	var global_position := Vector2.ZERO
	var facing_direction := Vector2.RIGHT
	var card_pick_levels: Dictionary = {}
	var stats_changed := SignalStub.new()
	var team_bonus_calls: Array = []
	var special_keys: Array = []
	var banner_count := 0
	var effect_count := 0
	var damage_calls := 0
	var active_mana_added := 0.0

	func _apply_team_role_bonus(damage_bonus: float, interval_bonus: float, range_bonus: float, skill_bonus: float) -> void:
		team_bonus_calls.append([damage_bonus, interval_bonus, range_bonus, skill_bonus])

	func _increase_team_specials(entries: Array) -> void:
		special_keys.append_array(entries)

	func _update_fire_timer() -> void:
		pass

	func get_stat_summary() -> Dictionary:
		return {}

	func _show_switch_banner(_prefix: String, _title: String, _color: Color) -> void:
		banner_count += 1

	func _spawn_ring_effect(_center: Vector2, _radius: float, _color: Color, _width: float, _duration: float) -> void:
		effect_count += 1

	func _spawn_burst_effect(_center: Vector2, _radius: float, _color: Color, _duration: float) -> void:
		effect_count += 1

	func _queue_camera_shake(_strength: float, _duration: float) -> void:
		effect_count += 1

	func _get_active_role() -> Dictionary:
		return {"id": "swordsman"}

	func _get_card_level(card_id: String) -> int:
		return int(card_pick_levels.get(card_id, 0))

	func _get_role_damage(_role_id: String) -> float:
		return 20.0

	func _spawn_crescent_wave_effect(_center: Vector2, _direction: Vector2, _radius: float, _color: Color, _duration: float, _speed: float, _width: float) -> void:
		effect_count += 1

	func _pull_enemies_toward(_center: Vector2, _radius: float, _force: float) -> void:
		effect_count += 1

	func _damage_enemies_in_radius(_center: Vector2, _radius: float, _damage: float, _vulnerability: float = 0.0, _slow_multiplier: float = 1.0, _slow_duration: float = 0.0, _source_role_id: String = "") -> int:
		damage_calls += 1
		return 2

	func _add_active_role_mana(amount: float, _emit_signal: bool = true) -> void:
		active_mana_added += amount

class BossRewardOwnerStub:
	var global_position := Vector2.ZERO
	var card_pick_levels: Dictionary = {}
	var special_reward_levels: Dictionary = {}
	var role_upgrade_levels: Dictionary = {"swordsman": {}, "gunner": {}, "mage": {}}
	var role_special_states: Dictionary = {"swordsman": {}, "gunner": {}, "mage": {}}
	var background_interval_multiplier := 1.0
	var damage_taken_multiplier := 1.0
	var current_health := 50.0
	var max_health := 100.0
	var health_changed := SignalStub.new()
	var special_calls: Array = []
	var effect_count := 0
	var mana_added := 0.0

	func _get_active_role() -> Dictionary:
		return {"id": "gunner"}

	func _increase_role_special(role_id: String, key: String, amount: int = 1) -> void:
		special_calls.append([role_id, key, amount])
		var data: Dictionary = role_special_states.get(role_id, {})
		data[key] = int(data.get(key, 0)) + amount
		role_special_states[role_id] = data

	func _add_active_role_mana(amount: float, _emit_signal: bool = true) -> void:
		mana_added += amount

	func _spawn_combat_tag(_position: Vector2, _text: String, _color: Color) -> void:
		effect_count += 1

	func _spawn_ring_effect(_center: Vector2, _radius: float, _color: Color, _width: float, _duration: float) -> void:
		effect_count += 1

	func _spawn_burst_effect(_center: Vector2, _radius: float, _color: Color, _duration: float) -> void:
		effect_count += 1


class AbilityOwnerStub:
	var is_dead := false
	var level_up_active := false
	var facing_direction := Vector2.RIGHT
	var card_pick_levels: Dictionary = {}

	func _init(_role_id: String, card_id: String) -> void:
		card_pick_levels[card_id] = 1

	func _get_card_level(card_id: String) -> int:
		return int(card_pick_levels.get(card_id, 0))

	func _get_equipment_cooldown_multiplier() -> float:
		return 1.0

	func _get_equipment_skill_range_multiplier() -> float:
		return 1.0
