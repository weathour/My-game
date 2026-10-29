extends RefCounted
## Raster decoration only. Threat geometry, damage and lifetimes remain simulation-owned.
const ROOT := "res://assets/enemies/baimen/fx/"
const JIA := preload("res://scripts/ui/chronicle/jia_effects.gd")
const GEOMETRY_VIEW := preload("res://scripts/ui/chronicle/enemy_threat_view.gd")
const EFFECT_IDS := ["bone_bolt", "lantern_pulse", "pot_miasma", "coffin_smoke", "lightning", "command_seal", "heal_seal", "charge_dust"]
var clips: Dictionary = {}
var transients: Array[Dictionary] = []
var seen: Dictionary = {}
var jia: RefCounted

func _init() -> void:
	jia = JIA.new()
	for id in EFFECT_IDS:
		var metadata_path: String = ROOT + str(id) + "/manifest.json"
		if not FileAccess.file_exists(metadata_path): continue
		var data = JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
		if not data is Dictionary: continue
		var path: String = ROOT + str(id) + "/effect.png"
		if not ResourceLoader.exists(path): continue
		var sheet: Texture2D = load(path)
		var size_data: Array = data.get("frame_size", [128,128])
		var textures: Array[Texture2D] = []
		for index in int(data.get("frames", 4)):
			var frame := AtlasTexture.new()
			frame.atlas = sheet
			frame.region = Rect2(index * float(size_data[0]), 0, float(size_data[0]), float(size_data[1]))
			textures.append(frame)
		clips[id] = {"textures":textures, "fps":float(data.get("fps", 10)), "anchor":data.get("anchor_px", [size_data[0] * .5, size_data[1] * .5]), "frame_size":Vector2(size_data[0],size_data[1])}

func consume(events: Array, battle: RefCounted) -> void:
	if not battle.outcome.is_empty(): clear(); return
	for event in events:
		if event.kind == "enemy_remove":
			var source_id := int(event.id)
			for i in range(transients.size() - 1, -1, -1):
				if int(transients[i].get("source_id", 0)) == source_id: transients.remove_at(i)
		if event.kind == "boss_phase":
			var boss_id := int(event.id)
			for enemy in battle.enemies:
				if enemy.id == boss_id: _add("coffin_smoke", {"origin":enemy.position, "radius":enemy.radius * 1.8}, battle.director.elapsed, .5, boss_id)
		if event.kind not in ["enemy_release", "enemy_hazard_release"] or not event.has("geometry"): continue
		var key := "%s:%d:%d" % [str(event.kind), int(event.id), int(event.action_serial)]
		if seen.has(key): continue
		seen[key] = true
		var g: Dictionary = event.geometry.duplicate(true)
		var action := str(g.get("action_id", "swipe"))
		var style := str({"shot":"lantern_pulse", "fan":"lantern_pulse", "charge":"charge_dust", "pot":"pot_miasma", "heal":"heal_seal", "command":"command_seal", "summon":"coffin_smoke", "anchor":"lantern_pulse", "pulse":"lantern_pulse", "collaboration":"command_seal", "marker":"lightning", "hook":"thrust", "slam":"sweep", "swipe":"slash"}.get(action, "slash"))
		if event.kind == "enemy_hazard_release" and str(g.get("shape", "")) == "marker": style = "lightning"
		if action in ["shot", "fan"] and event.kind != "enemy_hazard_release": g["radius"] = 25.0; g["shape"] = "disc"
		_add(style, g, battle.director.elapsed, .38, int(event.id))
		if action in ["heal", "command"]:
			for enemy in battle.enemies:
				if enemy.id in g.get("beneficiaries", []): _add(style, {"origin":enemy.position, "radius":enemy.radius + 15}, battle.director.elapsed, .5, int(event.id))

func _add(style: String, geometry: Dictionary, clock: float, duration: float, source_id: int) -> void:
	transients.append({"style":style, "geometry":geometry, "start":clock, "duration":duration, "source_id":source_id})

func clear() -> void:
	transients.clear()
	seen.clear()

func sync(battle: RefCounted) -> void:
	if not battle.outcome.is_empty(): clear(); return
	for index in range(transients.size() - 1, -1, -1):
		if battle.director.elapsed - transients[index].start >= transients[index].duration: transients.remove_at(index)

func texture(style: String, age: float, loop: bool = false) -> Texture2D:
	if style in ["slash", "sweep", "thrust"]:
		var frames: Array = jia.frames[style]
		return frames[mini(3, int(maxf(0, age) * 12))]
	if not clips.has(style): return null
	var clip: Dictionary = clips[style]
	var index := int(maxf(0, age) * clip.fps)
	return clip.textures[index % clip.textures.size() if loop else mini(index, clip.textures.size() - 1)]

func draw_projectile(painter: Node2D, projectile: Dictionary, elapsed: float, screen_origin: Vector2, world_scale: float) -> bool:
	if not projectile.get("hostile", false): return false
	var image := texture("bone_bolt", elapsed, true)
	if image == null: return false
	var direction: Vector2 = projectile.velocity.normalized()
	var size := Vector2(42, 21)
	painter.draw_set_transform(screen_origin + projectile.position * world_scale, direction.angle(), Vector2.ONE * world_scale)
	# The bone tip lies at the simulated projectile position; the soft trail is behind it.
	var anchor_data: Array = clips.bone_bolt.anchor
	var ratio: Vector2 = Vector2(anchor_data[0],anchor_data[1]) / clips.bone_bolt.frame_size
	painter.draw_texture_rect(image, Rect2(-ratio * size, size), false, Color.WHITE)
	return true

func draw(painter: Node2D, battle: RefCounted) -> void:
	for hazard in battle.hazards:
		var style := "pot_miasma" if str(hazard.get("kind", "")) == "pot" else "lightning" if str(hazard.get("shape", "")) == "marker" else "lantern_pulse"
		if str(hazard.get("phase", "")) == "tell": continue
		_draw_geometry(painter, style, hazard, battle.director.elapsed, .70, true)
	for enemy in battle.enemies:
		if enemy.definition_id == "D05" or (enemy.parent_id > 0 and enemy.definition_id == "D01" and enemy.age < .4):
			_draw_geometry(painter, "coffin_smoke", {"origin":enemy.position, "radius":enemy.radius + 20}, enemy.age, .65, true)
		if enemy.state == "active" and enemy.attack == "charge":
			_draw_geometry(painter, "charge_dust", {"origin":enemy.position - enemy.aim * 28, "radius":45, "direction":enemy.aim}, battle.director.elapsed, .6, true)
	for entry in transients:
		_draw_geometry(painter, entry.style, entry.geometry, battle.director.elapsed - entry.start, .8)

func _draw_geometry(painter: Node2D, style: String, g: Dictionary, age: float, alpha: float, loop: bool = false) -> void:
	var image := texture(style, age, loop)
	if image == null: return
	var point: Vector2 = g.get("origin", Vector2.ZERO)
	var radius := float(g.get("radius", 40))
	var direction: Vector2 = g.get("direction", Vector2.RIGHT)
	var dimension := Vector2.ONE * radius * 2
	if style in ["slash", "sweep", "thrust", "pot_miasma", "lantern_pulse"] and g.has("shape"):
		var polygon := GEOMETRY_VIEW.outline(g)
		var bounds := Rect2(polygon[0], Vector2.ZERO)
		for p in polygon: bounds = bounds.expand(p)
		var uv := PackedVector2Array()
		for p in polygon: uv.append((p - bounds.position) / bounds.size.max(Vector2.ONE))
		painter.draw_colored_polygon(polygon, Color(1,1,1,alpha), uv, image)
		return
	if style == "lightning": dimension = Vector2(radius * 1.4, radius * 2.4)
	if style == "charge_dust": dimension = Vector2(radius * 2, radius)
	var anchor_ratio := Vector2(.5, .75)
	if clips.has(style):
		var anchor_data: Array = clips[style].anchor
		anchor_ratio = Vector2(anchor_data[0],anchor_data[1]) / clips[style].frame_size
	var rect := Rect2(point - dimension * anchor_ratio, dimension)
	if style == "charge_dust":
		var quad := PackedVector2Array()
		for corner in [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]: quad.append(point + ((corner - anchor_ratio) * dimension).rotated(direction.angle()))
		painter.draw_colored_polygon(quad, Color(1,1,1,alpha), PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]), image)
	else: painter.draw_texture_rect(image, rect, false, Color(1,1,1,alpha))
