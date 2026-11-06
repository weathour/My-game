extends RefCounted
## Pure presentation; combat simulation owns damage, targeting and collision.
## Transients survive the simulation's short effect descriptor; only battle time ages them.
const SKILL := preload("res://scripts/ui/chronicle/skill_presentation.gd")
const SETTINGS := preload("res://scripts/shared/settings.gd")
const PROFILES := preload("res://scripts/ui/chronicle/skill_presentation_profiles.gd")
var skill := SKILL.new()
const SCENES := {
	"boom":preload("res://effects/wizard/boom/boom.tscn"),
	"field":preload("res://effects/wizard/field/field.tscn"),
	"gather":preload("res://effects/wizard/wave/gathering/gatering.tscn"),
	"slash":preload("res://effects/sword/slash3/slasheffect3.tscn"),
	"fan":preload("res://effects/sword/fan/fan.tscn"),
}
const MEDICINE_TRAIL := Color("82d8b0")
const MEDICINE_CORE := Color("dfffe1")
const MEDICINE_CROSS := Color("368e74")
const STAR_COLOR := Color("ffd385")
const SUPPORT_COLOR := Color("a4d8ff")
const MAGIC_COLOR := Color("dfb7ff")
const ICE := preload("res://assets/enemies/skullmage/ice_shard.png")
# Exact unions of the current imported clip-frame alpha bounds. The dedicated
# cache smoke compares these against every source frame, so art edits fail fast.
const CLIP_BOUNDS := {"boom":Rect2i(101,33,57,92),"field":Rect2i(430,622,233,280),"gather":Rect2i(298,399,102,165),"slash":Rect2i(99,30,28,154),"fan":Rect2i(438,396,233,135),"wave":Rect2i(204,224,221,492)}
static var _clips_cache: Dictionary = {}
var clips: Dictionary = {}
var transients: Array[Dictionary] = []
var seen: Dictionary = {}
var clock := 0.0

func _init() -> void:
	if not _clips_cache.is_empty():
		clips=_clips_cache
		return
	for key in SCENES:
		# Read the PackedScene data, not an instance: authored transforms and
		# timers are deliberately not inherited by the current combat runtime.
		var state: SceneState = SCENES[key].get_state()
		for node in state.get_node_count():
			for property in state.get_node_property_count(node):
				if state.get_node_property_name(node, property) == &"sprite_frames":
					var frames: SpriteFrames = state.get_node_property_value(node, property)
					var animation := frames.get_animation_names()[0]
					var textures: Array[Texture2D] = []
					var lengths: Array[float] = []
					for frame in frames.get_frame_count(animation):
						textures.append(frames.get_frame_texture(animation, frame))
						lengths.append(frames.get_frame_duration(animation, frame) / frames.get_animation_speed(animation))
					_store_clip(key, textures, lengths)
	# The wave clip uses its six retained source frames directly.
	var wave: Array[Texture2D] = []
	var durations: Array[float] = []
	for i in range(11, 17):
		wave.append(load("res://effects/wizard/wave/%d.png" % i))
		durations.append(1.0 / 14.0)
	_store_clip("wave", wave, durations)
	for clip: Dictionary in clips.values():
		clip.textures.make_read_only();clip.durations.make_read_only();clip.make_read_only()
	clips.make_read_only()
	_clips_cache=clips

func _store_clip(key: String, textures: Array[Texture2D], durations: Array[float]) -> void:
	var bounds: Rect2i = CLIP_BOUNDS[key]
	var total := 0.0
	for duration: float in durations: total+=duration
	var cropped: Array[Texture2D] = []
	for texture in textures:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(bounds)
		cropped.append(atlas)
	clips[key] = {"textures":cropped, "durations":durations, "duration":total, "bounds":bounds}

static func style(effect: Dictionary) -> String:
	var profile:=PROFILES.render_profile(str(effect.get("source","")),str(effect.get("ability","")),int(effect.get("ability_kind",-1)))
	return str(profile._direct_style if bool(effect.get("direct",true)) else profile._support_style)

func sync(battle: RefCounted) -> void:
	skill.sync(battle)
	clock = battle.director.elapsed
	if not battle.outcome.is_empty():
		transients.clear()
		seen.clear()
		return
	for effect in battle.effects: _remember(effect)
	for i in range(transients.size() - 1, -1, -1):
		if clock - transients[i].started >= transients[i].duration: transients.remove_at(i)
	# Bound deduplication memory independently of frame refresh frequency.
	for key in seen.keys():
		if clock - seen[key] > 3.0: seen.erase(key)

func _remember(effect: Dictionary) -> void:
	var resolved:=style(effect)
	if resolved.is_empty(): return
	var key := SKILL.effect_key(effect)
	if seen.has(key): return
	seen[key] = float(effect.get("visual_time",clock))
	var entry := effect.duplicate(false)
	if entry.has("effect_kind"): entry.kind=entry.effect_kind
	if entry.has("beneficiaries"): entry.beneficiaries=entry.beneficiaries.duplicate()
	entry._style=resolved
	entry.started = float(effect.get("visual_time",clock))
	entry.duration = .72 if resolved in ["heal","ward","frost","sweep"] else .42
	transients.append(entry)
	while transients.size()>64: transients.pop_front()

func frame_index(key: String, age: float, loop: bool = false) -> int:
	var clip: Dictionary = clips[key]
	var cursor := fposmod(age, clip.duration) if loop else maxf(0.0, age)
	for i in clip.durations.size():
		cursor -= clip.durations[i]
		if cursor < 0: return i
	return clip.textures.size() - 1

func _texture(painter: Node2D, key: String, age: float, point: Vector2, dimensions: Vector2, angle: float, tint: Color, origin: Vector2, scale: float) -> void:
	painter.draw_set_transform(origin + point * scale, angle, Vector2.ONE * scale)
	painter.draw_texture_rect(clips[key].textures[frame_index(key, age)], Rect2(-dimensions * .5, dimensions), false, tint)

func draw_projectile(painter: Node2D, projectile: Dictionary, origin: Vector2, scale: float) -> bool:
	if projectile.hostile: return false
	var profile:=PROFILES.render_profile(str(projectile.context.source),str(projectile.context.ability),int(projectile.context.get("ability_kind",-1)))
	var kind: String=profile._direct_style if bool(projectile.context.get("direct",true)) else profile._support_style
	if kind.is_empty(): return skill.draw_projectile(painter,projectile,origin,scale,true,profile)
	skill.draw_projectile(painter,projectile,origin,scale,false,profile)
	var point: Vector2 = projectile.position + Vector2(0, -32)
	var angle: float = projectile.velocity.angle()
	if kind == "ice":
		painter.draw_set_transform(origin + point * scale, angle + PI * .5, Vector2.ONE * scale)
		painter.draw_texture_rect(ICE, Rect2(-10, -19, 20, 38), false, Color.WHITE)
	elif kind == "medicine":
		painter.draw_set_transform(origin + point * scale, angle, Vector2.ONE * scale)
		painter.draw_line(Vector2(-22,0), Vector2.ZERO, MEDICINE_TRAIL, 3, true)
		painter.draw_circle(Vector2.ZERO, 7, MEDICINE_CORE)
		painter.draw_line(Vector2(-4,0), Vector2(4,0), MEDICINE_CROSS, 2)
		painter.draw_line(Vector2(0,-4), Vector2(0,4), MEDICINE_CROSS, 2)
	else:
		var star := kind == "star"
		var tint := STAR_COLOR if star else SUPPORT_COLOR if kind == "support_magic" else MAGIC_COLOR
		_texture(painter, "wave", fposmod(clock, clips.wave.duration), point, Vector2(14 if star else 9, 68 if star else 38), angle - PI * .5, tint, origin, scale)
		painter.draw_set_transform(origin + point * scale, angle, Vector2.ONE * scale)
		painter.draw_circle(Vector2.ZERO, 6 if star else 4, tint)
	return true

func consume(events: Array, battle: RefCounted) -> void:
	skill.consume(events,battle)
	clock=battle.director.elapsed
	for fact: Dictionary in events:
		if str(fact.get("kind","")) != "ability_release": continue
		_remember(fact)

func clear() -> void:
	transients.clear();seen.clear();skill.clear()

func draw(painter: Node2D, battle: RefCounted, origin: Vector2, scale: float, font: Font = null) -> void:
	var visible:=SKILL.world_view(painter,origin,scale)
	for effect in transients:
		if not SKILL.effect_visible(effect,visible): continue
		if str(effect._style) in ["heal", "ward"] and effect.get("beneficiary", "") != battle.current().id and battle.current().id not in effect.get("beneficiaries", []): continue
		_draw_event(painter, effect, origin, scale)
	# The ward remains on its actual beneficiary, including after switching back.
	if battle.current().shield > 0 and battle.current().id == "F03":
		_draw_shield(painter, battle.position, .65 + .1 * sin(clock * 3), origin, scale)
	skill.draw(painter,battle,origin,scale,font,SETTINGS.comfort_enabled("reduced_motion"),SETTINGS.comfort_enabled("reduced_flash"),visible)

func _draw_shield(painter: Node2D, point: Vector2, alpha: float, origin: Vector2, scale: float) -> void:
	painter.draw_set_transform(origin + (point + Vector2(0,-35)) * scale, 0, Vector2.ONE * scale)
	var shape := PackedVector2Array([Vector2(-25,-28),Vector2(25,-28),Vector2(29,5),Vector2(0,34),Vector2(-29,5),Vector2(-25,-28)])
	painter.draw_colored_polygon(shape, Color(.32,.85,.74,alpha * .12))
	painter.draw_polyline(shape, Color(.64,1,.84,alpha), 3, true)

func _draw_event(painter: Node2D, effect: Dictionary, origin: Vector2, scale: float) -> void:
	var kind: String=effect._style if effect.has("_style") else style(effect)
	var age: float = maxf(0.0, clock - effect.started)
	var progress: float = clampf(age / effect.duration, 0, 1)
	var alpha := minf(1.0, (1.0 - progress) * 3)
	var point: Vector2 = effect.origin
	var tint := Color(1,1,1,alpha)
	if effect.kind == "impact":
		point += Vector2(0,32-clampf(float(effect.get("body_height",64))*.45,24,96))
		if kind == "ice":
			painter.draw_set_transform(origin + (point + Vector2(0,-32)) * scale, age * 2, Vector2.ONE * scale)
			for i in 6:
				var direction := Vector2.from_angle(i * TAU / 6)
				painter.draw_line(direction * 4, direction * (14 + progress * 18), Color(.6,.9,1,alpha), 3, true)
		elif kind == "medicine":
			_texture(painter,"field",age,point + Vector2(0,-32),Vector2(32,38),0,Color(.4,1,.7,alpha),origin,scale)
		else:
			_texture(painter,"gather",age,point + Vector2(0,-32),Vector2(66,80) if kind == "star" else Vector2(35,45),0,Color(1,.84,.6,alpha) if kind == "star" else tint,origin,scale)
		return
	match kind:
		"heal":
			_texture(painter,"field",age,point,Vector2(82,32),0,Color(.45,1,.7,alpha),origin,scale)
			painter.draw_set_transform(origin + point * scale,0,Vector2.ONE * scale)
			for i in 5:
				var pos := Vector2((i - 2) * 16, -18 - fposmod(progress * 65 + i * 13, 60))
				painter.draw_line(pos - Vector2(4,0),pos + Vector2(4,0),Color(.65,1,.78,alpha),3)
				painter.draw_line(pos - Vector2(0,4),pos + Vector2(0,4),Color(.65,1,.78,alpha),3)
		"ward":
			_texture(painter,"field",age,point,Vector2(84,32),0,Color(.5,.9,.8,alpha),origin,scale)
			_draw_shield(painter,point,alpha,origin,scale)
		"frost":
			painter.draw_set_transform(origin + point * scale,0,Vector2.ONE * scale)
			var radius: float = effect.radius
			painter.draw_circle(Vector2.ZERO,radius,Color(.3,.7,.95,alpha * .07))
			painter.draw_arc(Vector2.ZERO,radius,0,TAU,64,Color(.6,.9,1,alpha),3,true)
			for i in 12:
				var angle := i * TAU / 12
				var pos := Vector2.from_angle(angle) * radius * .88
				painter.draw_set_transform(origin + (point + pos) * scale,angle + PI * .5,Vector2.ONE * scale)
				painter.draw_texture_rect(ICE,Rect2(-8,-17,16,34),false,Color(1,1,1,alpha))
			_texture(painter,"boom",age,point + Vector2(0,-40),Vector2(55,85),0,Color(.7,.9,1,alpha),origin,scale)
		"sweep":
			# Each half-circle uses the old fan art, normalized to the real radius.
			for side in 2:
				_texture(painter,"fan",age + .125,point + Vector2(0,effect.radius * (-.5 if side == 0 else .5)),Vector2(effect.radius * 2,effect.radius),side * PI,tint,origin,scale)
		"sword", "thrust":
			var direction: Vector2 = effect.direction
			var narrow := kind == "thrust"
			# Local x spans [0, reach], local y uses the same 22-unit
			# thrust half-width as Targeting; broad attacks remain a forward arc.
			if narrow:
				_texture(painter,"slash",age + .0375,point + direction * effect.radius * .5,Vector2(44,effect.radius),direction.angle() + PI * .5,tint,origin,scale)
			else:
				_texture(painter,"fan",age + .125,point + direction * effect.radius * .45,Vector2(effect.radius * 1.9,effect.radius),direction.angle() + PI * .5,tint,origin,scale)
		_:
			# Muzzle gathering is separate from its travelling spell and impact.
			if kind == "support_magic":
				_texture(painter,"field",age,point,Vector2(48,20),0,Color(.55,.8,1,alpha),origin,scale)
			var dimensions := Vector2(44,52) if kind == "star" else Vector2(24,32)
			_texture(painter,"gather",age,point + effect.direction * 25 + Vector2(0,-32),dimensions,0,Color(.6,.85,1,alpha) if kind == "ice" else tint,origin,scale)
