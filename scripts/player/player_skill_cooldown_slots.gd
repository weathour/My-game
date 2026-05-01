extends RefCounted

const BUILD_SYSTEM := preload("res://scripts/build/build_system.gd")

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

static func build_slots(role_id: String, attack_remaining: float, attack_interval: float, extra_slots: Array, owner = null) -> Array:
	var slots: Array = [
		{
			"name": "\u666e\u653b",
			"remaining": attack_remaining,
			"duration": max(attack_interval, 0.01),
			"color": get_role_color(role_id),
			"description": _get_basic_attack_description(owner, role_id, attack_interval)
		}
	]
	slots.append_array(extra_slots)
	return slots

static func _get_basic_attack_description(owner, role_id: String, attack_interval: float) -> String:
	var role_name := "当前角色"
	match role_id:
		"swordsman":
			role_name = "剑士"
		"gunner":
			role_name = "枪手"
		"mage":
			role_name = "术师"
	var lines: Array[String] = [
		"%s普攻冷却。攻击间隔 %.2f 秒；冷却结束后按当前攻击模式自动或朝鼠标方向出手。" % [role_name, max(attack_interval, 0.01)]
	]
	var enhancement_text := _make_card_effect_lines(owner, role_id, [
		"battle_omni_pierce",
		"battle_omni_fan",
		"battle_omni_ring",
		"battle_blood_drink",
		"battle_blood_shield"
	])
	if enhancement_text != "":
		lines.append("")
		lines.append("已获得的普攻 / 被动强化：")
		lines.append(enhancement_text)
	return "\n".join(lines)


static func _make_card_effect_lines(owner, role_id: String, card_ids: Array) -> String:
	if owner == null or not is_instance_valid(owner) or not owner.has_method("_get_card_level"):
		return ""
	var lines: Array[String] = []
	for card_id_value in card_ids:
		var card_id := str(card_id_value)
		var level: int = max(0, int(owner._get_card_level(card_id)))
		if level <= 0:
			continue
		var config: Dictionary = BUILD_SYSTEM.get_core_card_config(card_id, role_id)
		lines.append("【%s Lv.%d】%s" % [
			str(config.get("card_title", config.get("title", card_id))),
			level,
			str(config.get("card_type_label", ""))
		])
		for line in _get_role_effect_lines(card_id, role_id):
			lines.append("  - " + line)
	return "\n".join(lines)


static func _get_role_effect_lines(card_id: String, role_id: String) -> Array[String]:
	var result: Array[String] = []
	for effect in BUILD_SYSTEM.get_role_effect_payload(card_id):
		if effect is Dictionary and str(effect.get("role_id", "")) == role_id:
			for line in effect.get("lines", []):
				result.append(str(line))
			break
	return result
