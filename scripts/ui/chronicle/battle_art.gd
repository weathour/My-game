extends RefCounted
## Presentation-only asset mapping. Changing a costume never changes combat rules.
const STAGES := preload("res://scripts/content/stage_catalog.gd")
const SWORD := preload("res://assets/players/sword/sword.tscn")
const JIA := preload("res://assets/players/jia/jia.tscn")
const JIA_HEAD := preload("res://assets/players/jia/jia-head.tscn")
const MAGE := preload("res://assets/players/wizard/wizard.tscn")
const GUN := preload("res://assets/players/gun/gun.tscn")
const SWORD_HEAD := preload("res://assets/UI/facility/swordchange.tscn")
const MAGE_HEAD := preload("res://assets/UI/facility/witchchange.tscn")
const GUN_HEAD := preload("res://assets/UI/facility/gunchange.tscn")
const SOLDIER := preload("res://assets/enemies/skullsolider/skullsoilder.tscn")
const ELITE := preload("res://assets/enemies/skullsolider/eliteskull.tscn")
const SKULL_MAGE := preload("res://assets/enemies/skullmage/skull_mage.tscn")
const SLIME := preload("res://assets/enemies/slime/Slime.tscn")
const MAP := preload("res://assets/maps/grassland_3_rgba.png")
const SLASH := preload("res://effects/sword/slash3/slasheffect3.tscn")
const NOVA := preload("res://effects/wizard/boom/boom.tscn")
const FIELD := preload("res://effects/wizard/field/field.tscn")
const BOLTS := [preload("res://effects/gun/bullet/1.png"), preload("res://effects/gun/bullet/2.png"), preload("res://effects/gun/bullet/3.png"), preload("res://effects/gun/bullet/4.png")]
const MAP_STONE := preload("res://assets/maps/grassland_4_20260613_232523_189_godot_package/PixelworkMapStitch/grassland_4_20260613_232523_189/images/overall/source.png")
const COLORS := {"JIA":Color.WHITE, "F11":Color.WHITE, "N01":Color("c6cbd4"), "N04":Color("dfc2a5"), "N07":Color("d9c9ad"), "N13":Color("a2d8c0"), "N16":Color("e5cdbc"), "N17":Color("b9c4df")}

# Measured opaque animation bounds after the scene's own authored transforms.
# Vector2 = height, bottom/ground coordinate. Never normalize by transparent frame size.
const BODY_SWORD_IDLE := Vector2(93.0, 46.4752)
const BODY_SWORD_RUN := Vector2(94.24, 48.05)
const BODY_MAGE_IDLE := Vector2(50.05, 26.6)
const BODY_MAGE_RUN := Vector2(52.65, 27.95)
const BODY_GUN_IDLE := Vector2(81.84, 40.238)
const BODY_GUN_RUN := Vector2(81.84, 41.602)
const BODY_SOLDIER := Vector2(57.288, 8.8176)
const BODY_ELITE := Vector2(81.84, 11.168)
const BODY_SLIME := Vector2(32, 20)
const BODY_SKULL_MAGE := Vector2(130.65, 54.625)
const ACTOR_HEIGHT := 72.0

static func fit_actor(visual: Node2D, id: String, moving: bool) -> void:
	if id == "JIA":
		# Authored standing body is 80px, feet at the scene origin. Preserve
		# the natural crouch/run height instead of stretching every pose.
		_fit_body(visual, Vector2(80, 0), ACTOR_HEIGHT)
		return
	var profile := BODY_SWORD_RUN if moving else BODY_SWORD_IDLE
	if actor(id) == MAGE: profile = BODY_MAGE_RUN if moving else BODY_MAGE_IDLE
	elif actor(id) == GUN: profile = BODY_GUN_RUN if moving else BODY_GUN_IDLE
	_fit_body(visual, profile, ACTOR_HEIGHT)

static func fit_enemy(visual: Node2D, kind: String, stage: String) -> void:
	var profile := BODY_SLIME if stage == "B01" else BODY_SOLDIER
	var height := 32.0 if stage == "B01" else 64.0
	if kind == "ranged": profile = BODY_SKULL_MAGE; height = 68
	elif kind == "card_elite": profile = BODY_SKULL_MAGE; height = 92
	elif kind == "equipment_elite": profile = BODY_ELITE; height = 96
	elif kind == "boss": profile = BODY_SKULL_MAGE if _mage_boss(stage) else BODY_ELITE; height = 112
	elif kind == "charger": profile = BODY_SOLDIER; height = 72
	elif kind == "guard": profile = BODY_SOLDIER; height = 78
	_fit_body(visual, profile, height)

static func _fit_body(visual: Node2D, profile: Vector2, height: float) -> void:
	var factor := height / profile.x
	visual.scale = Vector2.ONE * factor
	visual.position = Vector2(0, -profile.y * factor)
	var shadow := visual.get_node_or_null("Shadow") as Node2D
	if shadow != null: shadow.position.y = profile.y

static func actor(id: String) -> PackedScene:
	if id == "JIA": return JIA
	if id in ["F11", "N13", "N16", "F03", "N14", "N18"]: return MAGE
	if id == "N07": return GUN
	return SWORD

static func portrait(id: String) -> PackedScene:
	if id == "JIA": return JIA_HEAD
	if id in ["F11", "N13", "N16", "F03", "N14", "N18"]: return MAGE_HEAD
	if id == "N07": return GUN_HEAD
	return SWORD_HEAD

static func tint(id: String) -> Color:
	if id == "F03": return Color("e8d1c6")
	if id == "F07": return Color("e6b2a2")
	if id == "N14": return Color("b7b0dc")
	if id == "N18": return Color("d6ca9f")
	return COLORS.get(id, Color.WHITE)

static func enemy(kind: String, stage: String) -> PackedScene:
	match kind:
		"ranged", "card_elite": return SKULL_MAGE
		"boss": return SKULL_MAGE if _mage_boss(stage) else ELITE
		"equipment_elite": return ELITE
		"charger", "guard": return SOLDIER
	return SLIME if stage == "B01" else SOLDIER

static func _mage_boss(stage: String) -> bool:
	return STAGES.STAGES.get(stage, {}).get("boss_visual", "") == "mage"

static func map_texture(stage: String) -> Texture2D:
	return MAP_STONE if STAGES.STAGES.get(stage, {}).get("map", "grass") == "stone" else MAP

static func map_tint(stage: String) -> Color:
	return Color(STAGES.STAGES.get(stage, {}).get("tint", "ffffff"))

static func enemy_tint(kind: String, stage: String) -> Color:
	if kind == "charger": return Color("e2ae87")
	if kind == "guard": return Color("b6c8d5")
	if kind == "boss" and _mage_boss(stage): return Color("c2b5ed")
	return Color.WHITE
