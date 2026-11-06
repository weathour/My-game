extends RefCounted
## Read-only cosmetic vocabulary. Gameplay data, targeting and timing stay in CombatCatalog.
const PATH := "res://assets/data/chronicle/skill_presentation_profiles.json"
static var _data: Dictionary = {}
static var _basics: Dictionary = {}
static var _render_cache: Dictionary = {}
static var _render_count := 0
const MAX_RENDER_PROFILES := 512

static func _load_data() -> void:
	if not _data.is_empty(): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		_data = parsed
		for entry: Dictionary in _data.get("ability_profiles",{}).values():
			if str(entry.get("slot","")) == "basic": _basics[str(entry.source)] = entry.duplicate(true)

static func all_profiles() -> Dictionary:
	_load_data()
	return _data.get("ability_profiles", {}).duplicate(true)

static func profile(source: String, ability: String, kind_override: int = -1) -> Dictionary:
	_load_data()
	var row: Dictionary = _data.get("ability_profiles", {}).get(ability, {}).duplicate(true)
	if not row.is_empty() and str(row.get("source","")) != source: row={}
	if row.is_empty() and _basics.has(source):
		row=_basics[source].duplicate(true)
		row.ability=ability
		if ability == "curse_dot": row.material="curse";row.motion="contact"
		if ability == "guard_counter": row.motion="guard"
	if row.is_empty():
		# Runtime aliases are actual secondary outcomes, never additional roster skills.
		row = {"source":source,"ability":ability,"weapon":"talisman","material":"curse" if ability == "curse_dot" else "steel","motion":"contact","palette":"c8b6d7" if ability == "curse_dot" else "c6dce7","accent":"8f73a9","signature":0,"strength":.4,"release_duration":.28,"contact_duration":.16,"title":""}
	if ability == "JIA_basic" and kind_override == 1:
		row.merge(_data.get("equipment_variants", {}).get("JIA_basic:long_spear", {}), true)
	return row

# Internal render views are shared and immutable; the public editing/query API
# above still returns detached copies, including aliases and equipment variants.
static func render_profile(source: String, ability: String, kind_override: int = -1) -> Dictionary:
	kind_override=1 if ability=="JIA_basic" and kind_override==1 else -1
	if _render_cache.has(source) and _render_cache[source].has(ability) and _render_cache[source][ability].has(kind_override):
		return _render_cache[source][ability][kind_override]
	var row := profile(source,ability,kind_override)
	row._palette_color = Color(str(row.palette))
	row._accent_color = Color(str(row.accent))
	var direct_style := ""
	var support_style := ""
	if source == "F11":
		direct_style = {"emma_frost":"frost","emma_ice":"ice","emma_star":"star"}.get(ability,"magic")
		support_style = direct_style if ability in ["emma_frost","emma_ice","emma_star"] else "support_magic"
	elif source == "F03":
		direct_style = "heal" if ability in ["physician_heal","physician_support"] else "ward" if ability == "physician_ward" else "medicine"
		support_style = direct_style
	elif source == "F07":
		direct_style = {"bandit_sweep":"sweep","bandit_thrust":"thrust"}.get(ability,"sword")
		support_style = direct_style
	row._direct_style = direct_style
	row._support_style = support_style
	var count := 3+int(row.signature)%5
	var outline: Array[Vector2] = []
	var angles: Array[float] = []
	for i in count+1:
		var angle: float = TAU*i/count
		angles.append(angle)
		outline.append(Vector2.from_angle(angle))
	var marks: Array[Vector2] = []
	var mark_angles: Array[float] = []
	for i in int(row.signature)%3+1:
		mark_angles.append(i*.8)
		marks.append(Vector2.from_angle(i*.8))
	outline.make_read_only();angles.make_read_only();marks.make_read_only();mark_angles.make_read_only()
	row._glyph_outline=outline;row._glyph_angles=angles;row._glyph_marks=marks;row._glyph_mark_angles=mark_angles
	var primary: Array[Vector2]=[]
	var secondary: Array[Vector2]=[]
	for i in 5: primary.append(Vector2.from_angle(i*TAU/5+float(row.signature)*.21))
	for i in 3: secondary.append(Vector2.from_angle(i*TAU/3+float(row.signature)*.21))
	primary.make_read_only();secondary.make_read_only()
	row._contact_primary=primary;row._contact_secondary=secondary
	row.make_read_only()
	if _render_count<MAX_RENDER_PROFILES:
		if not _render_cache.has(source): _render_cache[source]={}
		if not _render_cache[source].has(ability): _render_cache[source][ability]={}
		_render_cache[source][ability][kind_override]=row
		_render_count+=1
	return row
