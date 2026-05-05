extends RefCounted

static func get_role_name(role_id: String) -> String:
	match role_id:
		"swordsman":
			return "\u5251\u58EB"
		"gunner":
			return "\u67AA\u624B"
		"mage":
			return "\u672F\u5E08"
		_:
			return "\u89D2\u8272"

static func get_role_theme_color(roles: Array, role_id: String) -> Color:
	for role_data in roles:
		if str(role_data.get("id", "")) == role_id:
			return role_data.get("color", Color(1.0, 1.0, 1.0, 1.0))
	return Color(1.0, 1.0, 1.0, 1.0)

static func get_role_detail_summary(role_id: String, special_data: Dictionary) -> String:
	match role_id:
		"swordsman":
			return "\u56DE\u65CB%d | \u7A7F\u950B%d | \u53CD\u51FB%d | \u8FFD\u65A9%d | \u6218\u7EBF%d | \u5B88\u52BF%d" % [
				int(special_data.get("crescent_level", 0)),
				int(special_data.get("thrust_level", 0)),
				int(special_data.get("counter_level", 0)),
				int(special_data.get("pursuit_level", 0)),
				int(special_data.get("blood_level", 0)),
				int(special_data.get("stance_level", 0))
			]
		"gunner":
			return "\u6563\u5C04%d | \u805A\u7126%d | \u652F\u63F4%d | \u5F39\u5E55%d | \u7EED\u884C%d | \u9501\u5B9A%d" % [
				int(special_data.get("scatter_level", 0)),
				int(special_data.get("focus_level", 0)),
				int(special_data.get("support_level", 0)),
				int(special_data.get("barrage_level", 0)),
				int(special_data.get("reload_level", 0)),
				int(special_data.get("lock_level", 0))
			]
		"mage":
			return "\u56DE\u54CD%d | \u51B0\u7EB9%d | \u652F\u63F4%d | \u98CE\u66B4%d | \u6D41\u8F6C%d | \u584C\u7F29%d" % [
				int(special_data.get("echo_level", 0)),
				int(special_data.get("frost_level", 0)),
				int(special_data.get("support_level", 0)),
				int(special_data.get("storm_level", 0)),
				int(special_data.get("flow_level", 0)),
				int(special_data.get("gravity_level", 0))
			]
		_:
			return ""

static func get_role_route_summary(role_id: String, special_data: Dictionary) -> String:
	match role_id:
		"swordsman":
			var crescent_level := int(special_data.get("crescent_level", 0))
			var thrust_level := int(special_data.get("thrust_level", 0))
			var sustain_score := int(special_data.get("counter_level", 0)) + int(special_data.get("blood_level", 0)) + int(special_data.get("stance_level", 0))
			if crescent_level >= 2 and crescent_level >= thrust_level and crescent_level >= sustain_score:
				return "\u8D34\u8EAB\u7EDE\u6740"
			if thrust_level >= 2 and thrust_level > crescent_level and thrust_level >= sustain_score:
				return "\u8FD1\u8DDD\u5904\u51B3"
			if sustain_score >= 4:
				return "\u5438\u8840\u786C\u6297"
			return "\u8D34\u8138\u524D\u538B"
		"gunner":
			var scatter_level := int(special_data.get("scatter_level", 0))
			var focus_level := int(special_data.get("focus_level", 0))
			var support_score := int(special_data.get("support_level", 0)) + int(special_data.get("reload_level", 0))
			var lock_score := focus_level + int(special_data.get("lock_level", 0))
			if scatter_level >= 2 and scatter_level >= focus_level and scatter_level >= support_score:
				return "\u8FDC\u7A0B\u5C01\u9501"
			if lock_score >= 4 and lock_score >= scatter_level and lock_score >= support_score:
				return "\u5B9A\u70B9\u72D9\u6740"
			if focus_level >= 2 and focus_level > scatter_level and focus_level >= support_score:
				return "\u8FDC\u8DDD\u72D9\u6740"
			if support_score >= 3:
				return "\u8FFD\u730E\u538B\u5236"
			return "\u8FDC\u8DDD\u70B9\u5C04"
		"mage":
			var echo_score := int(special_data.get("echo_level", 0)) + int(special_data.get("storm_level", 0))
			var frost_score := int(special_data.get("frost_level", 0)) + int(special_data.get("support_level", 0))
			var gravity_score := frost_score + int(special_data.get("gravity_level", 0))
			var flow_level := int(special_data.get("flow_level", 0))
			if echo_score >= 3 and echo_score >= frost_score:
				return "\u8FDE\u7206\u5171\u9E23"
			if gravity_score >= 4 and gravity_score >= echo_score:
				return "\u584C\u7F29\u63A7\u573A"
			if frost_score >= 3 and frost_score > echo_score:
				return "\u51B0\u57DF\u63A7\u573A"
			if flow_level >= 2:
				return "\u6CD5\u6F6E\u5FAA\u73AF"
			return "\u5747\u8861\u79D8\u6CD5"
		_:
			return ""

static func get_role_core_summary(role_id: String) -> String:
	match role_id:
		"swordsman":
			return "\u56FA\u6709 \u8D34\u8EAB\u7834\u950B"
		"gunner":
			return "\u56FA\u6709 \u8FDC\u8DDD\u8FFD\u730E"
		"mage":
			return "\u56FA\u6709 \u5E7F\u57DF\u56DE\u54CD"
		_:
			return ""
