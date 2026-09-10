extends RefCounted

static func get_role_name(role_id: String) -> String:
	match role_id:
		"swordsman":
			return "\u5251\u58EB"
		"gunner":
			return "\u67AA\u624B"
		"mage":
			return "\u672F\u5E08"
		"mechanic":
			return "\u673A\u68B0\u5E08"
		_:
			return "\u89D2\u8272"

static func get_role_theme_color(roles: Array, role_id: String) -> Color:
	for role_data in roles:
		if str(role_data.get("id", "")) == role_id:
			return role_data.get("color", Color(1.0, 1.0, 1.0, 1.0))
	return Color(1.0, 1.0, 1.0, 1.0)

static func get_role_detail_summary(role_id: String, _special_data: Dictionary) -> String:
	match role_id:
		"swordsman":
			return "\u795D\u798F\u9A71\u52A8"
		"gunner":
			return "\u5708\u5916\u5904\u51B3"
		"mage":
			return "\u795D\u798F\u9A71\u52A8"
		"mechanic":
			return "\u90E8\u7F72\u706B\u529B"
		_:
			return ""

static func get_role_route_summary(role_id: String, _special_data: Dictionary) -> String:
	match role_id:
		"swordsman":
			return "\u795D\u798F\u6210\u957F"
		"gunner":
			return "\u65E0\u4F24\u6EDA\u96EA\u7403"
		"mage":
			return "\u795D\u798F\u6210\u957F"
		"mechanic":
			return "\u96F6\u4EF6\u6210\u957F"
		_:
			return ""

static func get_role_core_summary(role_id: String) -> String:
	match role_id:
		"swordsman":
			return "\u56FA\u6709 \u8D34\u8EAB\u7834\u950B"
		"gunner":
			return "\u56FA\u6709 \u730E\u6740\u77AC\u6740"
		"mage":
			return "\u56FA\u6709 \u5E7F\u57DF\u56DE\u54CD"
		"mechanic":
			return "\u56FA\u6709 \u6218\u573A\u6539\u88C5"
		_:
			return ""
