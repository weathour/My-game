extends RefCounted

static func serialize_color_for_save(color_value: Variant) -> Array:
	var color := normalize_role_color(color_value, Color.WHITE)
	return [color.r, color.g, color.b, color.a]

static func normalize_role_color(color_value: Variant, fallback: Color) -> Color:
	if color_value is Color:
		return color_value
	if color_value is Array:
		var color_array: Array = color_value
		if color_array.size() >= 4:
			return Color(
				float(color_array[0]),
				float(color_array[1]),
				float(color_array[2]),
				float(color_array[3])
			)
		if color_array.size() >= 3:
			return Color(
				float(color_array[0]),
				float(color_array[1]),
				float(color_array[2]),
				1.0
			)
	if color_value is String:
		var color_text := str(color_value).strip_edges()
		if color_text.begins_with("(") and color_text.ends_with(")"):
			color_text = color_text.substr(1, color_text.length() - 2)
		var parts := color_text.split(",", false)
		if parts.size() >= 4:
			return Color(
				float(parts[0].strip_edges()),
				float(parts[1].strip_edges()),
				float(parts[2].strip_edges()),
				float(parts[3].strip_edges())
			)
		if parts.size() >= 3:
			return Color(
				float(parts[0].strip_edges()),
				float(parts[1].strip_edges()),
				float(parts[2].strip_edges()),
				1.0
			)
	return fallback

static func serialize_roles_for_save(roles: Array) -> Array:
	var saved_roles: Array = []
	for role_variant in roles:
		if not (role_variant is Dictionary):
			continue
		var role_data: Dictionary = (role_variant as Dictionary).duplicate(true)
		role_data["color"] = serialize_color_for_save(role_data.get("color", Color.WHITE))
		saved_roles.append(role_data)
	return saved_roles

static func normalize_loaded_roles(saved_roles: Variant, base_roles: Array, pad_roles: Array = []) -> Array:
	var base_role_map: Dictionary = {}
	for base_role_variant in base_roles:
		if base_role_variant is Dictionary:
			var base_role: Dictionary = base_role_variant
			base_role_map[str(base_role.get("id", ""))] = base_role

	var normalized_roles: Array = []
	if saved_roles is Array:
		for saved_role_variant in saved_roles:
			if not (saved_role_variant is Dictionary):
				continue
			var saved_role: Dictionary = (saved_role_variant as Dictionary).duplicate(true)
			var role_id := str(saved_role.get("id", ""))
			var merged_role: Dictionary = {}
			var fallback_color: Color = Color.WHITE
			if base_role_map.has(role_id):
				var base_role_data: Dictionary = (base_role_map[role_id] as Dictionary)
				merged_role = base_role_data.duplicate(true)
				fallback_color = base_role_data.get("color", Color.WHITE)
			merged_role.merge(saved_role, true)
			if base_role_map.has(role_id):
				var current_role: Dictionary = base_role_map[role_id]
				merged_role["base_health"] = current_role.get("base_health", merged_role.get("base_health"))
				merged_role["base_damage_reduction_value"] = current_role.get("base_damage_reduction_value", merged_role.get("base_damage_reduction_value"))
			merged_role["color"] = normalize_role_color(
				merged_role.get("color", Color.WHITE),
				fallback_color
			)
			normalized_roles.append(merged_role)

	var ordered_ids: Array = []
	for role_variant in normalized_roles:
		if role_variant is Dictionary:
			var role_id := str((role_variant as Dictionary).get("id", ""))
			if role_id != "":
				ordered_ids.append(role_id)
	var pad_source: Array = pad_roles if not pad_roles.is_empty() else base_roles
	for fallback_role_variant in pad_source:
		if normalized_roles.size() >= pad_source.size():
			break
		var fallback_role: Dictionary = fallback_role_variant
		var fallback_id := str(fallback_role.get("id", ""))
		if ordered_ids.has(fallback_id):
			continue
		normalized_roles.append(fallback_role.duplicate(true))

	return normalized_roles
