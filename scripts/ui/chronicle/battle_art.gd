extends RefCounted
## Presentation-only asset mapping. Changing a costume never changes combat rules.
const ENEMY_MANIFEST := preload("res://scripts/ui/chronicle/enemy_visual_manifest.gd")
const ENEMY_ACTOR := preload("res://scripts/ui/chronicle/enemy_actor.gd")
const ENEMY_PLACEHOLDER := preload("res://scripts/ui/chronicle/enemy_placeholder.gd")
const BATTLE_SPACE := preload("res://scripts/battle/battle_space.gd")
const SWORD := preload("res://assets/players/sword/sword.tscn")
const JIA := preload("res://assets/players/jia/jia.tscn")
const JIA_APPEARANCE := preload("res://scripts/ui/chronicle/jia_appearance.gd")
const JIA_CAMPAIGN := preload("res://assets/players/jia-campaign/jia-campaign.tscn")
const JIA_CAMPAIGN_HEAD := preload("res://assets/players/jia-campaign/jia-campaign-head.tscn")
const JIA_HEAD := preload("res://assets/players/jia/jia-head.tscn")
const ROSTER := {
	"M07": preload("res://assets/players/chronicle-cast/M07/M07.tscn"),
	"M08": preload("res://assets/players/chronicle-cast/M08/M08.tscn"),
	"F01": preload("res://assets/players/chronicle-cast/F01/F01.tscn"),
	"F11": preload("res://assets/players/chronicle-cast/F11/F11.tscn"),
	"N01": preload("res://assets/players/chronicle-cast/N01/N01.tscn"),
	"N02": preload("res://assets/players/chronicle-cast/N02/N02.tscn"),
	"N03": preload("res://assets/players/chronicle-cast/N03/N03.tscn"),
	"N04": preload("res://assets/players/chronicle-cast/N04/N04.tscn"),
	"N05": preload("res://assets/players/chronicle-cast/N05/N05.tscn"),
	"N06": preload("res://assets/players/chronicle-cast/N06/N06.tscn"),
	"N07": preload("res://assets/players/chronicle-cast/N07/N07.tscn"),
	"N08": preload("res://assets/players/chronicle-cast/N08/N08.tscn"),
	"N09": preload("res://assets/players/chronicle-cast/N09/N09.tscn"),
	"N10": preload("res://assets/players/chronicle-cast/N10/N10.tscn"),
	"N11": preload("res://assets/players/chronicle-cast/N11/N11.tscn"),
	"N12": preload("res://assets/players/chronicle-cast/N12/N12.tscn"),
	"N13": preload("res://assets/players/chronicle-cast/N13/N13.tscn"),
	"N14": preload("res://assets/players/chronicle-cast/N14/N14.tscn"),
	"N15": preload("res://assets/players/chronicle-cast/N15/N15.tscn"),
	"N16": preload("res://assets/players/chronicle-cast/N16/N16.tscn"),
	"N17": preload("res://assets/players/chronicle-cast/N17/N17.tscn"),
	"N18": preload("res://assets/players/chronicle-cast/N18/N18.tscn"),
}

const ROSTER_HEADS := {
	"M07": preload("res://assets/players/chronicle-cast/M07/M07-head.tscn"),
	"M08": preload("res://assets/players/chronicle-cast/M08/M08-head.tscn"),
	"F01": preload("res://assets/players/chronicle-cast/F01/F01-head.tscn"),
	"F11": preload("res://assets/players/chronicle-cast/F11/F11-head.tscn"),
	"N01": preload("res://assets/players/chronicle-cast/N01/N01-head.tscn"),
	"N02": preload("res://assets/players/chronicle-cast/N02/N02-head.tscn"),
	"N03": preload("res://assets/players/chronicle-cast/N03/N03-head.tscn"),
	"N04": preload("res://assets/players/chronicle-cast/N04/N04-head.tscn"),
	"N05": preload("res://assets/players/chronicle-cast/N05/N05-head.tscn"),
	"N06": preload("res://assets/players/chronicle-cast/N06/N06-head.tscn"),
	"N07": preload("res://assets/players/chronicle-cast/N07/N07-head.tscn"),
	"N08": preload("res://assets/players/chronicle-cast/N08/N08-head.tscn"),
	"N09": preload("res://assets/players/chronicle-cast/N09/N09-head.tscn"),
	"N10": preload("res://assets/players/chronicle-cast/N10/N10-head.tscn"),
	"N11": preload("res://assets/players/chronicle-cast/N11/N11-head.tscn"),
	"N12": preload("res://assets/players/chronicle-cast/N12/N12-head.tscn"),
	"N13": preload("res://assets/players/chronicle-cast/N13/N13-head.tscn"),
	"N14": preload("res://assets/players/chronicle-cast/N14/N14-head.tscn"),
	"N15": preload("res://assets/players/chronicle-cast/N15/N15-head.tscn"),
	"N16": preload("res://assets/players/chronicle-cast/N16/N16-head.tscn"),
	"N17": preload("res://assets/players/chronicle-cast/N17/N17-head.tscn"),
	"N18": preload("res://assets/players/chronicle-cast/N18/N18-head.tscn"),
}
const WOMEN := {
	"F02": preload("res://assets/players/baimen-women/F02/F02.tscn"),
	"F03": preload("res://assets/players/baimen-women/F03/F03.tscn"),
	"F04": preload("res://assets/players/baimen-women/F04/F04.tscn"),
	"F05": preload("res://assets/players/baimen-women/F05/F05.tscn"),
	"F06": preload("res://assets/players/baimen-women/F06/F06.tscn"),
	"F07": preload("res://assets/players/baimen-women/F07/F07.tscn"),
	"F08": preload("res://assets/players/baimen-women/F08/F08.tscn"),
	"F09": preload("res://assets/players/baimen-women/F09/F09.tscn"),
	"F10": preload("res://assets/players/baimen-women/F10/F10.tscn"),
}
const WOMEN_HEADS := {
	"F02": preload("res://assets/players/baimen-women/F02/F02-head.tscn"),
	"F03": preload("res://assets/players/baimen-women/F03/F03-head.tscn"),
	"F04": preload("res://assets/players/baimen-women/F04/F04-head.tscn"),
	"F05": preload("res://assets/players/baimen-women/F05/F05-head.tscn"),
	"F06": preload("res://assets/players/baimen-women/F06/F06-head.tscn"),
	"F07": preload("res://assets/players/baimen-women/F07/F07-head.tscn"),
	"F08": preload("res://assets/players/baimen-women/F08/F08-head.tscn"),
	"F09": preload("res://assets/players/baimen-women/F09/F09-head.tscn"),
	"F10": preload("res://assets/players/baimen-women/F10/F10-head.tscn"),
}
const FRIENDLY := {
	"M01": preload("res://assets/enemies/baimen/M01/friendly.tscn"),
	"M02": preload("res://assets/enemies/baimen/M02/friendly.tscn"),
	"M03": preload("res://assets/enemies/baimen/M03/friendly.tscn"),
	"M04": preload("res://assets/enemies/baimen/M04/friendly.tscn"),
	"M05": preload("res://assets/enemies/baimen/M05/friendly.tscn"),
	"M06": preload("res://assets/enemies/baimen/M06/friendly.tscn"),
}
const FRIENDLY_HEADS := {
	"M01": preload("res://assets/enemies/baimen/M01/friendly-head.tscn"),
	"M02": preload("res://assets/enemies/baimen/M02/friendly-head.tscn"),
	"M03": preload("res://assets/enemies/baimen/M03/friendly-head.tscn"),
	"M04": preload("res://assets/enemies/baimen/M04/friendly-head.tscn"),
	"M05": preload("res://assets/enemies/baimen/M05/friendly-head.tscn"),
	"M06": preload("res://assets/enemies/baimen/M06/friendly-head.tscn"),
}
const FRIENDLY_HUMAN_IDS := {
	"M01": "B18_human", "M02": "B17_human", "M03": "M03_human",
	"M04": "M04_human", "M05": "B16_human", "M06": "B15_human",
}
const MAGE := preload("res://assets/players/wizard/wizard.tscn")
const GUN := preload("res://assets/players/gun/gun.tscn")
const SWORD_HEAD := preload("res://assets/UI/facility/swordchange.tscn")
const MAGE_HEAD := preload("res://assets/UI/facility/witchchange.tscn")
const GUN_HEAD := preload("res://assets/UI/facility/gunchange.tscn")
const SLASH := preload("res://effects/sword/slash3/slasheffect3.tscn")
const NOVA := preload("res://effects/wizard/boom/boom.tscn")
const FIELD := preload("res://effects/wizard/field/field.tscn")
const BOLTS := [preload("res://effects/gun/bullet/1.png"), preload("res://effects/gun/bullet/2.png"), preload("res://effects/gun/bullet/3.png"), preload("res://effects/gun/bullet/4.png")]
const COLORS := {"JIA":Color.WHITE, "F11":Color.WHITE, "N01":Color("c6cbd4"), "N04":Color("dfc2a5"), "N07":Color("d9c9ad"), "N13":Color("a2d8c0"), "N16":Color("e5cdbc"), "N17":Color("b9c4df")}
const ENVIRONMENT_MANIFEST := "res://assets/data/chronicle/battle_environments.json"
static var _environment_manifest: Dictionary = {}
static var _ground_textures: Dictionary = {}
static var _ground_previews: Dictionary = {}

# Measured opaque animation bounds after the scene's own authored transforms.
# Vector2 = height, bottom/ground coordinate. Never normalize by transparent frame size.
const BODY_SWORD_IDLE := Vector2(93.0, 46.4752)
const BODY_SWORD_RUN := Vector2(94.24, 48.05)
const BODY_MAGE_IDLE := Vector2(50.05, 26.6)
const BODY_MAGE_RUN := Vector2(52.65, 27.95)
const BODY_GUN_IDLE := Vector2(81.84, 40.238)
const BODY_GUN_RUN := Vector2(81.84, 41.602)
const ACTOR_HEIGHT := BATTLE_SPACE.ACTOR_BODY_HEIGHT

static func fit_actor(visual: Node2D, id: String, moving: bool) -> void:
	if ROSTER.has(id):
		_fit_body(visual, visual.body_profile(), ACTOR_HEIGHT)
		return
	if FRIENDLY.has(id):
		# The controller already loaded this exact manifest when mounting the actor.
		# Fitting is called every frame, so it must not read/parse the file again.
		var metadata: Dictionary = visual.manifest
		var body_height := float(metadata.get("body_height_px", 224.0))
		_fit_body(visual, Vector2(body_height, 0.0), ACTOR_HEIGHT)
		return
	if id == "JIA":
		_fit_body(visual, visual.body_profile(), ACTOR_HEIGHT)
		return
	if WOMEN.has(id):
		# Authored standing body is 80px, feet at the scene origin. Preserve
		# the natural crouch/run height instead of stretching every pose.
		_fit_body(visual, Vector2(80, 0), ACTOR_HEIGHT)
		return
	var profile := BODY_SWORD_RUN if moving else BODY_SWORD_IDLE
	if actor(id) == MAGE: profile = BODY_MAGE_RUN if moving else BODY_MAGE_IDLE
	elif actor(id) == GUN: profile = BODY_GUN_RUN if moving else BODY_GUN_IDLE
	_fit_body(visual, profile, ACTOR_HEIGHT)

static func _fit_body(visual: Node2D, profile: Vector2, height: float) -> void:
	var factor := height / profile.x
	visual.scale = Vector2.ONE * factor
	visual.position = Vector2(0, -profile.y * factor)
	var shadow := visual.get_node_or_null("Shadow") as Node2D
	if shadow != null: shadow.position.y = profile.y

static func actor(id: String, appearance: String = JIA_APPEARANCE.COMMON) -> PackedScene:
	if ROSTER.has(id): return ROSTER[id]
	if id == "JIA": return JIA_CAMPAIGN if appearance == JIA_APPEARANCE.CAMPAIGN else JIA
	if FRIENDLY.has(id): return FRIENDLY[id]
	if WOMEN.has(id): return WOMEN[id]
	if id in ["F11", "N13", "N16", "N14", "N18"]: return MAGE
	if id == "N07": return GUN
	return SWORD

static func portrait(id: String, appearance: String = JIA_APPEARANCE.COMMON) -> PackedScene:
	if ROSTER_HEADS.has(id): return ROSTER_HEADS[id]
	if id == "JIA": return JIA_CAMPAIGN_HEAD if appearance == JIA_APPEARANCE.CAMPAIGN else JIA_HEAD
	if FRIENDLY_HEADS.has(id): return FRIENDLY_HEADS[id]
	if WOMEN_HEADS.has(id): return WOMEN_HEADS[id]
	if id in ["F11", "N13", "N16", "N14", "N18"]: return MAGE_HEAD
	if id == "N07": return GUN_HEAD
	return SWORD_HEAD

static func tint(id: String) -> Color:
	if ROSTER.has(id): return Color.WHITE
	if id == "N14": return Color("b7b0dc")
	if id == "N18": return Color("d6ca9f")
	return COLORS.get(id, Color.WHITE)

static func create_enemy(value: RefCounted, stage: String) -> Node2D:
	var identity := str(value.visual_id)
	var metadata := ENEMY_MANIFEST.resolved(identity)
	var visual: Node2D
	if not metadata.get("clips", {}).is_empty():
		visual = ENEMY_ACTOR.new()
		visual.setup(identity)
	else:
		# Missing current art remains visible without loading an obsolete enemy runtime.
		visual = ENEMY_PLACEHOLDER.new()
		visual.set_meta("missing_enemy_art", true)
	visual.set_meta("visual_id", identity)
	fit_enemy_instance(visual, value, stage)
	return visual

static func fit_enemy_instance(visual: Node2D, value: RefCounted, _stage: String) -> void:
	var profile := Vector2(64, 0)
	if visual.has_method("body_profile"): profile = visual.body_profile()
	_fit_body(visual, profile, value.body_height)

static func enemy_portrait(visual_id: String) -> Texture2D:
	return ENEMY_MANIFEST.texture(visual_id, "portrait.png")

static func map_texture(stage: String) -> Texture2D:
	var profile := environment(stage)
	var path := str(profile.get("texture", ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		if not _ground_textures.has(path): _ground_textures[path] = load(path)
		if _ground_textures[path] is Texture2D: return _ground_textures[path]
	return null

static func map_preview_texture(stage: String) -> Texture2D:
	var texture := map_texture(stage)
	if texture == null: return null
	var path := texture.resource_path
	if not _ground_previews.has(path):
		# Minimap uses the same center-cropped area as the ground's uniform cover.
		var source := texture.get_size()
		var factor := maxf(BATTLE_SPACE.SIZE.x / source.x, BATTLE_SPACE.SIZE.y / source.y)
		var cropped := BATTLE_SPACE.SIZE / factor
		var preview := AtlasTexture.new()
		preview.atlas = texture
		preview.region = Rect2((source - cropped) * .5, cropped)
		_ground_previews[path] = preview
	return _ground_previews[path]

static func map_tint(stage: String) -> Color:
	if has_environment_texture(stage): return Color(str(environment(stage).get("tint", "ffffff")))
	return Color.WHITE

static func environment_manifest() -> Dictionary:
	if _environment_manifest.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(ENVIRONMENT_MANIFEST))
		if parsed is Dictionary: _environment_manifest = parsed
	return _environment_manifest

static func environment(stage: String) -> Dictionary:
	var manifest := environment_manifest()
	var overlay: Dictionary = manifest.get("stages", {}).get(stage, {})
	var profile: Dictionary = manifest.get("environments", {}).get(str(overlay.get("environment", "")), {}).duplicate()
	profile.merge(overlay, true)
	return profile

static func has_environment_texture(stage: String) -> bool:
	var path := str(environment(stage).get("texture", ""))
	return not path.is_empty() and ResourceLoader.exists(path)
