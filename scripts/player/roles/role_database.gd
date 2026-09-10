extends RefCounted

const ROLE_IDS := ["swordsman", "gunner", "mage", "mechanic"]

const DEFAULT_TEAM_IDS := ["swordsman", "gunner", "mage"]

const ROLE_DATA := [
	{
		"id": "swordsman",
		"name": "\u5251\u58EB",
		"color": Color(1.0, 0.66, 0.35, 1.0),
		"speed_scale": 1.0,
		"move_speed": 140.0,
		"base_health": 150.0,
		"base_dodge": 0.03,
		"base_damage_reduction_value": 20.0,
		"attack_interval": 1.0,
		"damage": 20.0,
		"range": 82.0,
		"background_interval": 2.6,
		"trait_key": "swordsman_trait",
		"trait_option_id": "level_trait_swordsman",
		"trait_name": "\u5251\u58EB\u7279\u6027",
		"trait_effect_type": "swordsman_training",
		"trait_damage_role_id": "swordsman"
	},
	{
		"id": "gunner",
		"name": "\u67AA\u624B",
		"color": Color(1.0, 0.35, 0.32, 1.0),
		"speed_scale": 1.0,
		"move_speed": 150.0,
		"base_health": 120.0,
		"base_dodge": 0.15,
		"base_damage_reduction_value": -40.0,
		"attack_interval": 0.39,
		"damage": 15.0,
		"range": 425.0,
		"background_interval": 2.0,
		"trait_key": "gunner_trait",
		"trait_option_id": "level_trait_gunner",
		"trait_name": "\u67AA\u624B\u7279\u6027",
		"trait_effect_type": "gunner_training",
		"trait_damage_role_id": "gunner"
	},
	{
		"id": "mage",
		"name": "\u6CD5\u5E08",
		"color": Color(0.44, 0.86, 1.0, 1.0),
		"speed_scale": 1.0,
		"move_speed": 130.0,
		"base_health": 120.0,
		"base_dodge": 0.03,
		"base_damage_reduction_value": 0.0,
		"attack_interval": 2.5,
		"damage": 25.0,
		"range": 300.0,
		"background_interval": 3.0,
		"trait_key": "mage_trait",
		"trait_option_id": "level_trait_mage",
		"trait_name": "\u6CD5\u5E08\u7279\u6027",
		"trait_effect_type": "mage_training",
		"trait_damage_role_id": "mage"
	},
	{
		"id": "mechanic",
		"name": "机械师",
		"color": Color(0.95, 0.68, 0.25, 1.0),
		"speed_scale": 1.0,
		"move_speed": 130.0,
		"base_health": 120.0,
		"base_dodge": 0.03,
		"base_damage_reduction_value": 0.0,
		"attack_interval": 0.5,
		"damage": 18.0,
		"range": 300.0,
		"background_interval": 2.4,
		"trait_key": "mechanic_trait",
		"trait_option_id": "level_trait_mechanic",
		"trait_name": "机械师特性",
		"trait_effect_type": "mechanic_training",
		"trait_damage_role_id": "mechanic"
	}
]

const ROLE_UPGRADE_TEMPLATE := {
	"level": 0,
	"interval_bonus": 0.0,
	"range_bonus": 0.0,
	"skill_bonus": 0.0
}

const ROLE_SPECIAL_STATE_TEMPLATES := {
	"swordsman": {
		"crescent_level": 0,
		"thrust_level": 0,
		"counter_level": 0,
		"pursuit_level": 0,
		"blood_level": 0,
		"stance_level": 0
	},
	"gunner": {
		"scatter_level": 0,
		"focus_level": 0,
		"support_level": 0,
		"barrage_level": 0,
		"reload_level": 0,
		"lock_level": 0
	},
	"mage": {
		"echo_level": 0,
		"frost_level": 0,
		"support_level": 0,
		"storm_level": 0,
		"flow_level": 0,
		"gravity_level": 0
	},
	"mechanic": {
		"drone_level": 0,
		"mine_level": 0,
		"emp_level": 0,
		"turret_level": 0,
		"missile_level": 0,
		"overdrive_level": 0
	}
}

static func get_role_data() -> Array:
	var result: Array = []
	for role_data in ROLE_DATA:
		result.append((role_data as Dictionary).duplicate(true))
	return result

static func get_role_ids() -> Array:
	return ROLE_IDS.duplicate()


static func get_team_role_data(team_ids: Array = []) -> Array:
	var ordered_ids: Array = []
	for role_variant in team_ids:
		var role_id := str(role_variant)
		if role_id != "" and not ordered_ids.has(role_id):
			ordered_ids.append(role_id)
	if ordered_ids.is_empty():
		ordered_ids = DEFAULT_TEAM_IDS.duplicate()
	var result: Array = []
	for role_id in ordered_ids:
		var role_data := get_role_data_by_id(role_id)
		if not role_data.is_empty():
			result.append(role_data)
	return result


static func get_role_data_by_id(role_id: String) -> Dictionary:
	for role_data in ROLE_DATA:
		if str((role_data as Dictionary).get("id", "")) == role_id:
			return (role_data as Dictionary).duplicate(true)
	return {}


static func get_role_trait_definitions(role_order: Array = []) -> Array:
	var ordered_roles: Array = []
	if role_order.is_empty():
		ordered_roles = get_role_data()
	else:
		var seen := {}
		for role_variant in role_order:
			var role_data: Dictionary = {}
			if role_variant is Dictionary:
				role_data = (role_variant as Dictionary).duplicate(true)
			else:
				role_data = get_role_data_by_id(str(role_variant))
			var role_id := str(role_data.get("id", ""))
			if role_id == "" or seen.has(role_id):
				continue
			if not role_data.has("trait_key"):
				var base_role := get_role_data_by_id(role_id)
				if not base_role.is_empty():
					base_role.merge(role_data, true)
					role_data = base_role
			ordered_roles.append(role_data)
			seen[role_id] = true
	var result: Array = []
	for role_data in ordered_roles:
		var role_id := str((role_data as Dictionary).get("id", ""))
		var trait_key := str((role_data as Dictionary).get("trait_key", ""))
		if role_id == "" or trait_key == "":
			continue
		result.append({
			"role_id": role_id,
			"role_name": str((role_data as Dictionary).get("name", role_id)),
			"trait_key": trait_key,
			"trait_name": str((role_data as Dictionary).get("trait_name", "%s\u7279\u6027" % str((role_data as Dictionary).get("name", role_id)))),
			"trait_option_id": str((role_data as Dictionary).get("trait_option_id", "level_trait_%s" % trait_key)),
			"trait_effect_type": str((role_data as Dictionary).get("trait_effect_type", "generic")),
			"trait_damage_role_id": str((role_data as Dictionary).get("trait_damage_role_id", role_id))
		})
	return result


static func get_role_trait_key(role_id: String) -> String:
	return str(get_role_data_by_id(role_id).get("trait_key", ""))


static func get_role_trait_name(role_id: String) -> String:
	var role_data := get_role_data_by_id(role_id)
	return str(role_data.get("trait_name", "%s\u7279\u6027" % str(role_data.get("name", role_id))))

static func get_role_upgrade_data() -> Dictionary:
	var result := {}
	for role_id in ROLE_IDS:
		result[role_id] = ROLE_UPGRADE_TEMPLATE.duplicate(true)
	return result

static func get_role_special_state_data() -> Dictionary:
	var result := {}
	for role_id in ROLE_IDS:
		result[role_id] = (ROLE_SPECIAL_STATE_TEMPLATES.get(role_id, {}) as Dictionary).duplicate(true)
	return result

static func get_role_timing_state_data(default_value: Variant) -> Dictionary:
	var result := {}
	for role_id in ROLE_IDS:
		result[role_id] = default_value
	return result
