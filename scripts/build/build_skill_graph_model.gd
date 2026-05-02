extends RefCounted

const FIRST_BATCH_DB := preload("res://scripts/build/build_first_batch_database.gd")

const LAYER_DEFINITIONS := [
	{"id": 0, "team_level_min": 0, "title": "起步", "subtitle": "Lv.1-5"},
	{"id": 1, "team_level_min": 6, "title": "第一次质变", "subtitle": "Lv.6"},
	{"id": 2, "team_level_min": 12, "title": "循环成形", "subtitle": "Lv.12"},
	{"id": 3, "team_level_min": 18, "title": "跨线成型", "subtitle": "Lv.18"},
	{"id": 4, "team_level_min": 25, "title": "主线毕业", "subtitle": "Lv.25+"}
]

const LANE_DEFINITIONS := [
	{"id": "swordsman", "title": "剑士", "package_id": FIRST_BATCH_DB.PACKAGE_SWORDSMAN},
	{"id": "gunner", "title": "枪手", "package_id": FIRST_BATCH_DB.PACKAGE_GUNNER},
	{"id": "mage", "title": "术师", "package_id": FIRST_BATCH_DB.PACKAGE_MAGE},
	{"id": "resonance", "title": "队伍共鸣", "package_id": ""},
	{"id": "generic", "title": "通用/补强", "package_id": ""}
]

const ROLE_LABELS := {
	"swordsman": "剑士",
	"gunner": "枪手",
	"mage": "术师"
}

const CARD_TYPE_LABELS := {
	"hero": "英雄卡",
	"capstone": "成型卡",
	"resonance_pair": "双人共鸣",
	"resonance_tri": "三人共鸣",
	"generic": "通用卡",
	"mastery": "毕业节点"
}

const AXIS_LABELS := {
	"entry": "入场",
	"exit": "离场",
	"core_output": "普攻/核心输出",
	"ultimate": "大招",
	"capstone": "成型",
	"independent_passive": "独立冷却被动",
	"resonance": "联动",
	"generic": "通用"
}

const POSITION_LABELS := {
	"damage": "输出",
	"control": "控制",
	"survival": "生存",
	"support": "支援",
	"summon": "召唤/造物",
	"resource": "资源",
	"mobility": "机动"
}

const EDGE_TYPE_LABELS := {
	"progression": "同能力包演进",
	"investment": "投入门槛",
	"edge_unlock": "英雄接力解锁",
	"state_logic": "状态生产/消费",
	"bridge_edge": "桥接路线",
	"relay_edge": "接力路线",
	"mirror_edge": "镜像召唤/支援",
	"mastery": "毕业承接"
}


static func build_graph() -> Dictionary:
	var cards_by_id: Dictionary = {}
	var nodes: Array = []
	var node_ids: Dictionary = {}
	for raw_card in FIRST_BATCH_DB.get_offer_card_definitions():
		if raw_card is not Dictionary:
			continue
		var card: Dictionary = raw_card as Dictionary
		var node: Dictionary = _make_node(card)
		if str(node.get("id", "")) == "":
			continue
		nodes.append(node)
		node_ids[str(node.get("id", ""))] = true
		cards_by_id[str(node.get("id", ""))] = card.duplicate(true)
	for raw_mastery in FIRST_BATCH_DB.get_mastery_nodes():
		if raw_mastery is not Dictionary:
			continue
		var mastery: Dictionary = raw_mastery as Dictionary
		var mastery_node: Dictionary = _make_node(mastery)
		if str(mastery_node.get("id", "")) == "":
			continue
		nodes.append(mastery_node)
		node_ids[str(mastery_node.get("id", ""))] = true
		cards_by_id[str(mastery_node.get("id", ""))] = mastery.duplicate(true)
	_sort_nodes(nodes)

	var edges: Array = []
	_append_progression_edges(edges, nodes, cards_by_id, node_ids)
	_append_explicit_edges(edges, cards_by_id, node_ids)
	_append_requirement_edges(edges, nodes, cards_by_id, node_ids)
	_append_state_logic_edges(edges, nodes, cards_by_id, node_ids)
	edges = _dedupe_edges(edges)
	_sort_edges(edges)

	return {
		"nodes": nodes,
		"edges": edges,
		"layers": LAYER_DEFINITIONS.duplicate(true),
		"lanes": LANE_DEFINITIONS.duplicate(true),
		"edge_type_labels": EDGE_TYPE_LABELS.duplicate(true)
	}


static func get_graph_summary(graph: Dictionary) -> String:
	return "%d 个节点 / %d 条关系" % [
		(graph.get("nodes", []) as Array).size(),
		(graph.get("edges", []) as Array).size()
	]


static func _make_node(card: Dictionary) -> Dictionary:
	var card_id: String = str(card.get("id", ""))
	var card_type: String = str(card.get("card_type", ""))
	var team_level_min: int = int(card.get("team_level_min", 0))
	var owner_role: String = str(card.get("owner_role", ""))
	var package_id: String = str(card.get("package_id", ""))
	var lane_id: String = _lane_for_card(card)
	var layer_id: int = _layer_for_team_level(team_level_min)
	var title: String = str(card.get("title", card_id))
	var max_level: int = int(card.get("max_level", 1))
	return {
		"id": card_id,
		"title": title,
		"name": title,
		"summary": str(card.get("summary", _fallback_summary(card))),
		"description": _make_description(card),
		"detail_description": _make_description(card),
		"card_type": card_type,
		"card_type_label": str(CARD_TYPE_LABELS.get(card_type, card_type)),
		"owner_role": owner_role,
		"owner_role_label": str(ROLE_LABELS.get(owner_role, "队伍" if owner_role == "" else owner_role)),
		"package_id": package_id,
		"team_level_min": team_level_min,
		"max_level": max_level,
		"layer": layer_id,
		"lane": lane_id,
		"slot_label": "技能图谱",
		"requires_text": _format_requirements(card),
		"logic_text": _format_logic(card)
	}


static func _make_description(card: Dictionary) -> String:
	var lines: Array[String] = []
	var card_id: String = str(card.get("id", ""))
	var title: String = str(card.get("title", card_id))
	var card_type: String = str(card.get("card_type", ""))
	var owner_role: String = str(card.get("owner_role", ""))
	lines.append("%s｜%s" % [title, str(CARD_TYPE_LABELS.get(card_type, card_type))])
	if owner_role != "":
		lines.append("归属：%s" % str(ROLE_LABELS.get(owner_role, owner_role)))
	else:
		lines.append("归属：队伍")
	lines.append("层级：队伍 Lv.%d+" % int(card.get("team_level_min", 0)))
	var max_level: int = int(card.get("max_level", 1))
	if max_level > 1:
		lines.append("卡内等级：最高 Lv.%d" % max_level)
	var axes: Array[String] = _labels_from_array(card.get("upgrade_axes", []), AXIS_LABELS)
	if not axes.is_empty():
		lines.append("强化面：%s" % "、".join(axes))
	var positions: Array[String] = _labels_from_weight_map(card.get("position_weights", card.get("function_weights", {})), POSITION_LABELS)
	if not positions.is_empty():
		lines.append("定位倾向：%s" % "、".join(positions))
	var requirement_text: String = _format_requirements(card)
	if requirement_text != "":
		lines.append("解锁逻辑：%s" % requirement_text)
	var logic_text: String = _format_logic(card)
	if logic_text != "":
		lines.append("关系逻辑：%s" % logic_text)
	if bool(card.get("has_independent_cooldown", false)):
		lines.append("独立冷却：%.1f 秒｜%s" % [float(card.get("cooldown_seconds", 0.0)), str(card.get("independent_passive_summary", "自动触发"))])
	var summary: String = str(card.get("summary", ""))
	if summary != "":
		lines.append("效果：%s" % summary)
	return "\n".join(lines)


static func _fallback_summary(card: Dictionary) -> String:
	var card_type: String = str(card.get("card_type", ""))
	if card_type == FIRST_BATCH_DB.CARD_TYPE_MASTERY:
		return "主线毕业后降低同线重复权重，并提高桥接/共鸣路线权重。"
	return "Build 节点。"


static func _format_requirements(card: Dictionary) -> String:
	var parts: Array[String] = []
	var team_level_min: int = int(card.get("team_level_min", 0))
	if team_level_min > 0:
		parts.append("队伍 Lv.%d" % team_level_min)
	var investment_requirements: Dictionary = _as_dictionary(card.get("investment_requirements", {}))
	var trigger_requirements: Dictionary = _as_dictionary(card.get("trigger_requirements", {}))
	parts.append_array(_format_requirement_map(investment_requirements))
	parts.append_array(_format_requirement_map(trigger_requirements))
	var requires_any: Array = _as_array(card.get("requires_any", []))
	if not requires_any.is_empty():
		var any_parts: Array[String] = []
		for raw_requirement in requires_any:
			if raw_requirement is Dictionary:
				any_parts.append("{%s}" % "、".join(_format_requirement_map(raw_requirement as Dictionary)))
		if not any_parts.is_empty():
			parts.append("满足其一：%s" % " 或 ".join(any_parts))
	return "；".join(parts)


static func _format_requirement_map(requirements: Dictionary) -> Array[String]:
	var parts: Array[String] = []
	var role_investment: Dictionary = _as_dictionary(requirements.get("role_investment", {}))
	for role_id_value in role_investment.keys():
		var role_id: String = str(role_id_value)
		parts.append("%s投入 %.1f" % [str(ROLE_LABELS.get(role_id, role_id)), float(role_investment.get(role_id_value, 0.0))])
	var package_depth: Dictionary = _as_dictionary(requirements.get("package_depth", {}))
	for package_id_value in package_depth.keys():
		parts.append("能力包深度 %.1f" % float(package_depth.get(package_id_value, 0.0)))
	var edge_level: Dictionary = _as_dictionary(requirements.get("edge_level", {}))
	for edge_key_value in edge_level.keys():
		parts.append("接力 %s %.1f" % [_format_edge_key(str(edge_key_value)), float(edge_level.get(edge_key_value, 0.0))])
	var tag_points: Dictionary = _as_dictionary(requirements.get("tag_points", {}))
	for tag_value in tag_points.keys():
		parts.append("状态/门派 %s %.1f" % [str(tag_value), float(tag_points.get(tag_value, 0.0))])
	if requirements.has("edge_total_min"):
		parts.append("总接力 %.1f" % float(requirements.get("edge_total_min", 0.0)))
	return parts


static func _format_logic(card: Dictionary) -> String:
	var parts: Array[String] = []
	var produces: Array[String] = _weight_keys(card.get("produce_weights", {}))
	if not produces.is_empty():
		parts.append("产出 %s" % "、".join(produces))
	var consumes: Array[String] = _weight_keys(card.get("consume_weights", {}))
	if not consumes.is_empty():
		parts.append("消费 %s" % "、".join(consumes))
	var edge_gain: Dictionary = _as_dictionary(card.get("edge_gain", {}))
	if not edge_gain.is_empty():
		var edge_parts: Array[String] = []
		for edge_key_value in edge_gain.keys():
			edge_parts.append("%s +%.1f" % [_format_edge_key(str(edge_key_value)), float(edge_gain.get(edge_key_value, 0.0))])
		parts.append("接力 %s" % "、".join(edge_parts))
	var package_edges: Array = _as_array(card.get("package_edges", []))
	if not package_edges.is_empty():
		var bridge_parts: Array[String] = []
		for raw_edge in package_edges:
			if raw_edge is Dictionary:
				var edge: Dictionary = raw_edge as Dictionary
				bridge_parts.append("%s -> %s" % [str(edge.get("type", "bridge")), str(edge.get("to", ""))])
		if not bridge_parts.is_empty():
			parts.append("显式桥接 %s" % "、".join(bridge_parts))
	return "；".join(parts)


static func _append_progression_edges(edges: Array, nodes: Array, cards_by_id: Dictionary, node_ids: Dictionary) -> void:
	var group_map: Dictionary = {}
	for raw_node in nodes:
		if raw_node is not Dictionary:
			continue
		var node: Dictionary = raw_node as Dictionary
		var lane_id: String = str(node.get("lane", ""))
		var package_id: String = str(node.get("package_id", ""))
		var graph_group: String = package_id if package_id != "" else lane_id
		if graph_group == "":
			continue
		var layer_id: int = int(node.get("layer", 0))
		var key: String = "%s|%d" % [graph_group, layer_id]
		if not group_map.has(key):
			group_map[key] = []
		(group_map[key] as Array).append(str(node.get("id", "")))
	var groups: Array[String] = []
	for raw_lane in LANE_DEFINITIONS:
		var lane: Dictionary = raw_lane as Dictionary
		var package_id: String = str(lane.get("package_id", ""))
		groups.append(package_id if package_id != "" else str(lane.get("id", "")))
	for graph_group in groups:
		for layer_index in range(LAYER_DEFINITIONS.size() - 1):
			var from_key: String = "%s|%d" % [graph_group, layer_index]
			if not group_map.has(from_key):
				continue
			var next_layer: int = _next_non_empty_layer(group_map, graph_group, layer_index + 1)
			if next_layer < 0:
				continue
			var to_key: String = "%s|%d" % [graph_group, next_layer]
			for from_id_value in group_map.get(from_key, []):
				for to_id_value in group_map.get(to_key, []):
					var from_id: String = str(from_id_value)
					var to_id: String = str(to_id_value)
					if from_id == to_id or not node_ids.has(from_id) or not node_ids.has(to_id):
						continue
					var edge_type: String = "mastery" if _is_mastery_node(cards_by_id.get(to_id, {})) else "progression"
					edges.append(_make_edge(from_id, to_id, edge_type, str(EDGE_TYPE_LABELS.get(edge_type, edge_type))))


static func _append_explicit_edges(edges: Array, cards_by_id: Dictionary, node_ids: Dictionary) -> void:
	for card_id_value in cards_by_id.keys():
		var card_id: String = str(card_id_value)
		var card: Dictionary = _as_dictionary(cards_by_id.get(card_id, {}))
		var package_edges: Array = _as_array(card.get("package_edges", []))
		for raw_edge in package_edges:
			if raw_edge is not Dictionary:
				continue
			var edge: Dictionary = raw_edge as Dictionary
			var target_id: String = str(edge.get("to", ""))
			if target_id == "" or not node_ids.has(target_id):
				continue
			var edge_type: String = str(edge.get("type", "bridge_edge"))
			var label: String = str(EDGE_TYPE_LABELS.get(edge_type, edge_type))
			var cost: float = float(edge.get("cost", 0.0))
			if cost > 0.0:
				label = "%s %.1f" % [label, cost]
			edges.append(_make_edge(card_id, target_id, edge_type, label))


static func _append_requirement_edges(edges: Array, nodes: Array, cards_by_id: Dictionary, node_ids: Dictionary) -> void:
	for raw_target_node in nodes:
		if raw_target_node is not Dictionary:
			continue
		var target_node: Dictionary = raw_target_node as Dictionary
		var target_id: String = str(target_node.get("id", ""))
		var target_card: Dictionary = _as_dictionary(cards_by_id.get(target_id, {}))
		var requirement: Dictionary = _merged_requirements(target_card)
		var role_requirements: Dictionary = _as_dictionary(requirement.get("role_investment", {}))
		var package_requirements: Dictionary = _as_dictionary(requirement.get("package_depth", {}))
		var edge_requirements: Dictionary = _required_edge_keys(target_card)
		if role_requirements.is_empty() and package_requirements.is_empty() and edge_requirements.is_empty():
			continue
		for raw_source_node in nodes:
			if raw_source_node is not Dictionary:
				continue
			var source_node: Dictionary = raw_source_node as Dictionary
			var source_id: String = str(source_node.get("id", ""))
			if source_id == target_id:
				continue
			var source_layer: int = int(source_node.get("layer", 0))
			var target_layer: int = int(target_node.get("layer", 0))
			if source_layer >= target_layer:
				continue
			if source_layer < max(0, target_layer - 1):
				continue
			var source_card: Dictionary = _as_dictionary(cards_by_id.get(source_id, {}))
			var source_role_gain: Dictionary = _as_dictionary(source_card.get("trait_gain", {}))
			var source_package_gain: Dictionary = _as_dictionary(source_card.get("package_gain", {}))
			if _maps_share_positive_key(source_role_gain, role_requirements) or _maps_share_positive_key(source_package_gain, package_requirements):
				edges.append(_make_edge(source_id, target_id, "investment", "投入门槛"))
			var source_edge_gain: Dictionary = _as_dictionary(source_card.get("edge_gain", {}))
			if _maps_share_positive_key(source_edge_gain, edge_requirements):
				edges.append(_make_edge(source_id, target_id, "edge_unlock", "接力解锁"))


static func _append_state_logic_edges(edges: Array, nodes: Array, cards_by_id: Dictionary, _node_ids: Dictionary) -> void:
	for raw_source_node in nodes:
		if raw_source_node is not Dictionary:
			continue
		var source_node: Dictionary = raw_source_node as Dictionary
		var source_id: String = str(source_node.get("id", ""))
		var source_card: Dictionary = _as_dictionary(cards_by_id.get(source_id, {}))
		var produces: Dictionary = _as_dictionary(source_card.get("produce_weights", {}))
		if produces.is_empty():
			continue
		for raw_target_node in nodes:
			if raw_target_node is not Dictionary:
				continue
			var target_node: Dictionary = raw_target_node as Dictionary
			var target_id: String = str(target_node.get("id", ""))
			if target_id == source_id:
				continue
			var source_layer: int = int(source_node.get("layer", 0))
			var target_layer: int = int(target_node.get("layer", 0))
			if target_layer <= source_layer:
				continue
			if target_layer > source_layer + 1:
				continue
			var target_card: Dictionary = _as_dictionary(cards_by_id.get(target_id, {}))
			var consumes: Dictionary = _as_dictionary(target_card.get("consume_weights", {}))
			var required_tags: Dictionary = _required_tag_keys(target_card)
			if _maps_share_positive_key(produces, consumes) or _maps_share_positive_key(produces, required_tags):
				edges.append(_make_edge(source_id, target_id, "state_logic", "状态逻辑"))


static func _make_edge(from_id: String, to_id: String, edge_type: String, label: String) -> Dictionary:
	return {
		"from": from_id,
		"to": to_id,
		"type": edge_type,
		"label": label
	}


static func _dedupe_edges(edges: Array) -> Array:
	var result: Array = []
	var seen: Dictionary = {}
	for raw_edge in edges:
		if raw_edge is not Dictionary:
			continue
		var edge: Dictionary = raw_edge as Dictionary
		var key: String = "%s|%s|%s" % [str(edge.get("from", "")), str(edge.get("to", "")), str(edge.get("type", ""))]
		if seen.has(key):
			continue
		seen[key] = true
		result.append(edge)
	return result


static func _sort_nodes(nodes: Array) -> void:
	nodes.sort_custom(func(a, b):
		var node_a: Dictionary = a as Dictionary
		var node_b: Dictionary = b as Dictionary
		if int(node_a.get("layer", 0)) != int(node_b.get("layer", 0)):
			return int(node_a.get("layer", 0)) < int(node_b.get("layer", 0))
		if _lane_index(str(node_a.get("lane", ""))) != _lane_index(str(node_b.get("lane", ""))):
			return _lane_index(str(node_a.get("lane", ""))) < _lane_index(str(node_b.get("lane", "")))
		return str(node_a.get("title", "")) < str(node_b.get("title", ""))
	)


static func _sort_edges(edges: Array) -> void:
	edges.sort_custom(func(a, b):
		var edge_a: Dictionary = a as Dictionary
		var edge_b: Dictionary = b as Dictionary
		var key_a: String = "%s|%s|%s" % [str(edge_a.get("from", "")), str(edge_a.get("to", "")), str(edge_a.get("type", ""))]
		var key_b: String = "%s|%s|%s" % [str(edge_b.get("from", "")), str(edge_b.get("to", "")), str(edge_b.get("type", ""))]
		return key_a < key_b
	)


static func _lane_for_card(card: Dictionary) -> String:
	var card_type: String = str(card.get("card_type", ""))
	if card_type == FIRST_BATCH_DB.CARD_TYPE_GENERIC:
		return "generic"
	if card_type == FIRST_BATCH_DB.CARD_TYPE_RESONANCE_PAIR or card_type == FIRST_BATCH_DB.CARD_TYPE_RESONANCE_TRI:
		return "resonance"
	var owner_role: String = str(card.get("owner_role", ""))
	if owner_role != "":
		return owner_role
	var package_id: String = str(card.get("package_id", ""))
	for raw_lane in LANE_DEFINITIONS:
		var lane: Dictionary = raw_lane as Dictionary
		if str(lane.get("package_id", "")) == package_id and package_id != "":
			return str(lane.get("id", ""))
	return "generic"


static func _layer_for_team_level(team_level_min: int) -> int:
	if team_level_min >= 25:
		return 4
	if team_level_min >= 18:
		return 3
	if team_level_min >= 12:
		return 2
	if team_level_min >= 6:
		return 1
	return 0


static func _next_non_empty_layer(group_map: Dictionary, graph_group: String, start_layer: int) -> int:
	for layer_index in range(start_layer, LAYER_DEFINITIONS.size()):
		var key: String = "%s|%d" % [graph_group, layer_index]
		if group_map.has(key) and not (group_map.get(key, []) as Array).is_empty():
			return layer_index
	return -1


static func _lane_index(lane_id: String) -> int:
	for index in range(LANE_DEFINITIONS.size()):
		var lane: Dictionary = LANE_DEFINITIONS[index] as Dictionary
		if str(lane.get("id", "")) == lane_id:
			return index
	return LANE_DEFINITIONS.size()


static func _merged_requirements(card: Dictionary) -> Dictionary:
	var merged: Dictionary = {}
	_merge_requirement_into(merged, _as_dictionary(card.get("investment_requirements", {})))
	_merge_requirement_into(merged, _as_dictionary(card.get("trigger_requirements", {})))
	return merged


static func _merge_requirement_into(target: Dictionary, source: Dictionary) -> void:
	for key_value in source.keys():
		var key: String = str(key_value)
		if source.get(key_value) is Dictionary:
			if not target.has(key):
				target[key] = {}
			var target_map: Dictionary = target.get(key, {})
			var source_map: Dictionary = source.get(key_value, {})
			for sub_key in source_map.keys():
				target_map[sub_key] = max(float(target_map.get(sub_key, 0.0)), float(source_map.get(sub_key, 0.0)))
			target[key] = target_map
		else:
			target[key] = source.get(key_value)


static func _required_edge_keys(card: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	_add_requirement_map_keys(result, _as_dictionary(card.get("investment_requirements", {})), "edge_level")
	_add_requirement_map_keys(result, _as_dictionary(card.get("trigger_requirements", {})), "edge_level")
	for raw_requirement in _as_array(card.get("requires_any", [])):
		if raw_requirement is Dictionary:
			_add_requirement_map_keys(result, raw_requirement as Dictionary, "edge_level")
	return result


static func _required_tag_keys(card: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	_add_requirement_map_keys(result, _as_dictionary(card.get("investment_requirements", {})), "tag_points")
	_add_requirement_map_keys(result, _as_dictionary(card.get("trigger_requirements", {})), "tag_points")
	for raw_requirement in _as_array(card.get("requires_any", [])):
		if raw_requirement is Dictionary:
			_add_requirement_map_keys(result, raw_requirement as Dictionary, "tag_points")
	return result


static func _add_requirement_map_keys(result: Dictionary, requirement: Dictionary, map_key: String) -> void:
	var values: Dictionary = _as_dictionary(requirement.get(map_key, {}))
	for key_value in values.keys():
		result[key_value] = max(float(result.get(key_value, 0.0)), float(values.get(key_value, 0.0)))


static func _maps_share_positive_key(left: Dictionary, right: Dictionary) -> bool:
	if left.is_empty() or right.is_empty():
		return false
	for key_value in left.keys():
		if float(left.get(key_value, 0.0)) > 0.0 and float(right.get(key_value, 0.0)) > 0.0:
			return true
	return false


static func _is_mastery_node(card_variant: Variant) -> bool:
	if card_variant is not Dictionary:
		return false
	var card: Dictionary = card_variant as Dictionary
	return str(card.get("card_type", "")) == FIRST_BATCH_DB.CARD_TYPE_MASTERY


static func _labels_from_array(values_variant: Variant, label_map: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if values_variant is not Array:
		return result
	for value in values_variant as Array:
		var key: String = str(value)
		result.append(str(label_map.get(key, key)))
	return result


static func _labels_from_weight_map(weights_variant: Variant, label_map: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if weights_variant is not Dictionary:
		return result
	var weights: Dictionary = weights_variant as Dictionary
	var pairs: Array = []
	for key_value in weights.keys():
		pairs.append({"key": str(key_value), "weight": float(weights.get(key_value, 0.0))})
	pairs.sort_custom(func(a, b): return float((a as Dictionary).get("weight", 0.0)) > float((b as Dictionary).get("weight", 0.0)))
	for pair_value in pairs:
		var pair: Dictionary = pair_value as Dictionary
		if float(pair.get("weight", 0.0)) <= 0.0:
			continue
		var key: String = str(pair.get("key", ""))
		result.append(str(label_map.get(key, key)))
		if result.size() >= 3:
			break
	return result


static func _weight_keys(weights_variant: Variant) -> Array[String]:
	var result: Array[String] = []
	if weights_variant is not Dictionary:
		return result
	var weights: Dictionary = weights_variant as Dictionary
	for key_value in weights.keys():
		if float(weights.get(key_value, 0.0)) > 0.0:
			result.append(str(key_value))
	result.sort()
	return result


static func _format_edge_key(edge_key: String) -> String:
	var parts: PackedStringArray = edge_key.split("->")
	if parts.size() != 2:
		return edge_key
	return "%s→%s" % [str(ROLE_LABELS.get(parts[0], parts[0])), str(ROLE_LABELS.get(parts[1], parts[1]))]


static func _as_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


static func _as_array(value: Variant) -> Array:
	if value is Array:
		return (value as Array).duplicate(true)
	return []
