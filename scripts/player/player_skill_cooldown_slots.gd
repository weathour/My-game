extends RefCounted


static func get_role_color(role_id: String) -> Color:
	match role_id:
		"swordsman":
			return Color(1.0, 0.72, 0.24, 1.0)
		"gunner":
			return Color(0.34, 0.82, 1.0, 1.0)
		"mage":
			return Color(0.78, 0.46, 1.0, 1.0)
		_:
			return Color(1.0, 0.74, 0.34, 1.0)


static func build_slots(role_id: String, attack_remaining: float, attack_interval: float, extra_slots: Array, _owner = null) -> Array:
	var slots: Array = [
		{
			"name": "普攻",
			"remaining": attack_remaining,
			"duration": max(attack_interval, 0.01),
			"color": get_role_color(role_id),
			"description": _get_basic_attack_description(role_id, attack_interval)
		}
	]
	slots.append_array(extra_slots)
	return slots


static func _get_basic_attack_description(role_id: String, attack_interval: float) -> String:
	var role_name := "当前角色"
	match role_id:
		"swordsman":
			role_name = "剑士"
		"gunner":
			role_name = "枪手"
		"mage":
			role_name = "术师"
	return "%s普攻冷却。攻击间隔 %.2f 秒；冷却结束后按当前攻击模式出手。" % [role_name, max(attack_interval, 0.01)]
