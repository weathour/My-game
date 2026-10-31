extends RefCounted
## Pure presentation. Never instantiates legacy bullets, collision, Player or ability code.
## Transients survive the simulation's short effect descriptor; only battle time ages them.
const SCENES := {
	"boom":preload("res://effects/wizard/boom/boom.tscn"),
	"field":preload("res://effects/wizard/field/field.tscn"),
	"gather":preload("res://effects/wizard/wave/gathering/gatering.tscn"),
	"slash":preload("res://effects/sword/slash3/slasheffect3.tscn"),
	"fan":preload("res://effects/sword/fan/fan.tscn"),
}
const ICE := preload("res://assets/enemies/skullmage/ice_shard.png")
var clips: Dictionary = {}
var transients: Array[Dictionary] = []
var seen: Dictionary = {}
var clock := 0.0

func _init() -> void:
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
	# wave.tscn contains legacy bullet business logic. Load ONLY its PNGs.
	var wave: Array[Texture2D] = []
	var durations: Array[float] = []
	for i in range(11, 17):
		wave.append(load("res://effects/wizard/wave/%d.png" % i))
		durations.append(1.0 / 14.0)
	_store_clip("wave", wave, durations)

func _store_clip(key: String, textures: Array[Texture2D], durations: Array[float]) -> void:
	var bounds := Rect2i()
	var total := 0.0
	for i in textures.size():
		var used := textures[i].get_image().get_used_rect()
		bounds = used if i == 0 else bounds.merge(used)
		total += durations[i]
	var cropped: Array[Texture2D] = []
	for texture in textures:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(bounds)
		cropped.append(atlas)
	clips[key] = {"textures":cropped, "durations":durations, "duration":total, "bounds":bounds}

static func style(effect: Dictionary) -> String:
	var source: String = effect.get("source", "")
	var ability: String = effect.get("ability", "")
	if source == "F11":
		if ability == "emma_frost": return "frost"
		if ability == "emma_ice": return "ice"
		if ability == "emma_star": return "star"
		return "support_magic" if not effect.get("direct", true) else "magic"
	if source == "F03":
		if ability in ["physician_heal", "physician_support"]: return "heal"
		if ability == "physician_ward": return "ward"
		return "medicine"
	if source == "F07":
		if ability == "bandit_sweep": return "sweep"
		if ability == "bandit_thrust": return "thrust"
		return "sword"
	return ""

func sync(battle: RefCounted) -> void:
	clock = battle.director.elapsed
	if not battle.outcome.is_empty():
		transients.clear()
		seen.clear()
		return
	for effect in battle.effects:
		if style(effect).is_empty(): continue
		var key := "%d:%s" % [int(effect.get("cast", 0)), effect.kind]
		if seen.has(key): continue
		seen[key] = float(effect.get("visual_time", clock))
		var entry: Dictionary = effect.duplicate(true)
		entry["started"] = float(effect.get("visual_time", clock))
		entry["duration"] = .72 if style(effect) in ["heal", "ward", "frost", "sweep"] else .42
		transients.append(entry)
	for i in range(transients.size() - 1, -1, -1):
		if clock - transients[i].started >= transients[i].duration: transients.remove_at(i)
	# Bound deduplication memory independently of frame refresh frequency.
	for key in seen.keys():
		if clock - seen[key] > 3.0: seen.erase(key)

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
	var kind := style(projectile.context)
	if kind.is_empty(): return false
	var point: Vector2 = projectile.position + Vector2(0, -32)
	var angle: float = projectile.velocity.angle()
	if kind == "ice":
		painter.draw_set_transform(origin + point * scale, angle + PI * .5, Vector2.ONE * scale)
		painter.draw_texture_rect(ICE, Rect2(-10, -19, 20, 38), false, Color.WHITE)
	elif kind == "medicine":
		painter.draw_set_transform(origin + point * scale, angle, Vector2.ONE * scale)
		painter.draw_line(Vector2(-22,0), Vector2.ZERO, Color("82d8b0"), 3, true)
		painter.draw_circle(Vector2.ZERO, 7, Color("dfffe1"))
		painter.draw_line(Vector2(-4,0), Vector2(4,0), Color("368e74"), 2)
		painter.draw_line(Vector2(0,-4), Vector2(0,4), Color("368e74"), 2)
	else:
		var star := kind == "star"
		var tint := Color("ffd385") if star else Color("a4d8ff") if kind == "support_magic" else Color("dfb7ff")
		_texture(painter, "wave", fposmod(clock, clips.wave.duration), point, Vector2(14 if star else 9, 68 if star else 38), angle - PI * .5, tint, origin, scale)
		painter.draw_set_transform(origin + point * scale, angle, Vector2.ONE * scale)
		painter.draw_circle(Vector2.ZERO, 6 if star else 4, tint)
	return true

func draw(painter: Node2D, battle: RefCounted, origin: Vector2, scale: float) -> void:
	for effect in transients:
		if style(effect) in ["heal", "ward"] and effect.get("beneficiary", "") != battle.current().id and battle.current().id not in effect.get("beneficiaries", []): continue
		_draw_event(painter, effect, origin, scale)
	# The ward remains on its actual beneficiary, including after switching back.
	if battle.current().shield > 0 and battle.current().id == "F03":
		_draw_shield(painter, battle.position, .65 + .1 * sin(clock * 3), origin, scale)

func _draw_shield(painter: Node2D, point: Vector2, alpha: float, origin: Vector2, scale: float) -> void:
	painter.draw_set_transform(origin + (point + Vector2(0,-35)) * scale, 0, Vector2.ONE * scale)
	var shape := PackedVector2Array([Vector2(-25,-28),Vector2(25,-28),Vector2(29,5),Vector2(0,34),Vector2(-29,5),Vector2(-25,-28)])
	painter.draw_colored_polygon(shape, Color(.32,.85,.74,alpha * .12))
	painter.draw_polyline(shape, Color(.64,1,.84,alpha), 3, true)

func _draw_event(painter: Node2D, effect: Dictionary, origin: Vector2, scale: float) -> void:
	var kind := style(effect)
	var age: float = maxf(0.0, clock - effect.started)
	var progress: float = clampf(age / effect.duration, 0, 1)
	var alpha := minf(1.0, (1.0 - progress) * 3)
	var point: Vector2 = effect.origin
	var tint := Color(1,1,1,alpha)
	if effect.kind == "impact":
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
