extends Control
## Scene/animation adapter. No Player, enemy AI, collision bodies, or save dependencies.
const ART := preload("res://scripts/ui/chronicle/battle_art.gd")
const SPACE := preload("res://scripts/battle/battle_space.gd")
const DIRECTOR := preload("res://scripts/battle/stage_director.gd")
const JIA_EFFECTS := preload("res://scripts/ui/chronicle/jia_effects.gd")
var battle: RefCounted
var stage_id := "B01"
var actor_anchor: Node2D
var actor_visual: Node2D
var actor_kind := ""
var world_scale := 1.0
var origin := Vector2.ZERO
var moving := false
var actor_moving := false
var actors: Node2D
var enemy_views: Dictionary = {}
var effect_frames: Dictionary = {}
var foreground: Foreground
var jia_effects: RefCounted
var last_seen_cast := 0

class Foreground:
	extends Node2D
	var canvas: Control
	func _draw() -> void:
		canvas.draw_foreground(self)


func _ready() -> void:
	jia_effects = JIA_EFFECTS.new()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	actors = Node2D.new()
	actors.y_sort_enabled = true
	add_child(actors)
	foreground = Foreground.new()
	foreground.canvas = self
	foreground.z_index = 2
	add_child(foreground)
	for pair in [["slash", ART.SLASH], ["ring", ART.NOVA], ["cast", ART.FIELD]]:
		# These scenes contain presentation only. Keep their authored SpriteFrames,
		# rendering against the battle clock so pause and cleanup are exact.
		var template: Node = pair[1].instantiate()
		var sprite := template.find_children("*", "AnimatedSprite2D", true, false)[0] as AnimatedSprite2D
		effect_frames[pair[0]] = {"frames":sprite.sprite_frames, "animation":sprite.animation}
		template.free()

func refresh(is_moving: bool) -> void:
	if actors == null: return
	moving = is_moving
	world_scale = minf(size.x / 1280.0, size.y / 720.0)
	# Stable reference view over a larger world; UI overlays do not change zoom.
	var wanted: Vector2 = size * Vector2(.5, .48) - battle.position * world_scale
	origin = wanted.clamp(size - SPACE.SIZE * world_scale, Vector2.ZERO)
	actors.position = origin
	actors.scale = Vector2.ONE * world_scale
	actors.process_mode = Node.PROCESS_MODE_DISABLED if battle.paused else Node.PROCESS_MODE_INHERIT
	var id: String = battle.current().id
	if id != actor_kind:
		if is_instance_valid(actor_anchor): actors.remove_child(actor_anchor); actor_anchor.queue_free()
		actor_visual = ART.actor(id).instantiate()
		actor_anchor = Node2D.new()
		actors.add_child(actor_anchor)
		actor_anchor.add_child(actor_visual)
		actor_kind = id
		actor_moving = false
	actor_anchor.position = battle.position
	if not battle.paused:
		actor_moving = moving
		if actor_visual.has_method("set_weapon"): actor_visual.set_weapon(battle.equipment.get("weapon", ""))
		actor_visual.set_moving(actor_moving, battle.facing)
		_present_casts()
	ART.fit_actor(actor_visual, id, actor_moving)
	actor_visual.modulate = Color("ffb1a1") if battle.current().hurt_lock > .15 else ART.tint(id)
	var live: Dictionary = {}
	for enemy in battle.enemies:
		live[enemy.id] = true
		if not enemy_views.has(enemy.id):
			var visual: Node2D = ART.enemy(enemy.kind, stage_id).instantiate()
			# Pixel-sheet hit bursts normally attach to SceneTree.current_scene.
			# Here feedback stays under this arena and follows its pause/scale.
			if visual.get("hit_sheet") != null: visual.set("hit_sheet", null)
			var anchor := Node2D.new()
			actors.add_child(anchor)
			anchor.add_child(visual)
			ART.fit_enemy(visual, enemy.kind, stage_id)
			enemy_views[enemy.id] = {"node":visual, "anchor":anchor, "position":enemy.position, "hp":enemy.hp, "winding":false}

		var entry: Dictionary = enemy_views[enemy.id]
		var node: Node2D = entry.node
		var direction: Vector2 = enemy.position - entry.position
		entry.anchor.position = enemy.position
		# Preserve the authored hit animation until its own lock expires.
		if float(node.get("hit_lock_remaining") if node.get("hit_lock_remaining") != null else 0.0) <= 0:
			node.set_moving(direction.length_squared() > .001, direction if direction.length_squared() > .001 else enemy.aim)
		if enemy.hp < entry.hp and node.has_method("play_hit"): node.play_hit()
		if enemy.windup > 0 and not entry.winding and node.has_method("play_cast"): node.play_cast()
		node.modulate = Color("acd8e9") if enemy.slow_time > 0 else ART.enemy_tint(enemy.kind, stage_id)
		entry.position = enemy.position
		entry.hp = enemy.hp
		entry.winding = enemy.windup > 0
	for key in enemy_views.keys():
		if not live.has(key):
			var node: Node2D = enemy_views[key].anchor
			actors.remove_child(node)
			node.queue_free()
			enemy_views.erase(key)
	queue_redraw()
	foreground.queue_redraw()

func _present_casts() -> void:
	var selected: Dictionary = {}
	for effect in battle.effects:
		if int(effect.get("cast", 0)) <= last_seen_cast: continue
		if effect.get("source", "") != actor_kind or not effect.get("direct", false): continue
		if selected.is_empty() or effect.color == "manual": selected = effect
	last_seen_cast = battle.cast_serial
	if not selected.is_empty() and actor_visual.has_method("play_attack"):
		actor_visual.play_attack(selected.direction, selected.color == "manual")

func _draw_authored_effect(painter: Node2D, effect: Dictionary) -> void:
	var color := Color("da7753") if effect.get("hostile", false) else Color("92cbe0") if effect.get("color") == "support" else Color.WHITE
	painter.draw_set_transform(origin, 0, Vector2.ONE * world_scale)
	if effect.kind == "line":
		painter.draw_line(effect.origin, effect.end, color, 12, true)
		return
	if not effect_frames.has(effect.kind): return
	var data: Dictionary = effect_frames[effect.kind]
	var frames: SpriteFrames = data.frames
	var count := frames.get_frame_count(data.animation)
	var frame := mini(count - 1, int(clampf(1.0 - effect.life / .22, 0.0, 1.0) * count))
	var texture := frames.get_frame_texture(data.animation, frame)
	if effect.get("source", "") == "JIA" and effect.kind in ["ring", "slash"]:
		texture = jia_effects.texture(effect)
	var radius: float = effect.radius
	var dimension := Vector2.ONE * radius * 2
	var angle := 0.0
	var point: Vector2 = effect.origin
	if effect.kind == "slash":
		angle = effect.direction.angle()
		point += effect.direction * radius * .5
		dimension = Vector2(radius, 32 if effect.narrow else radius * 1.4)
	color.a = minf(1.0, effect.life * 8)
	painter.draw_set_transform(origin + point * world_scale, angle, Vector2.ONE * world_scale)
	painter.draw_texture_rect(texture, Rect2(-dimension * .5, dimension), false, color)

func _draw() -> void:
	if battle == null: return
	draw_rect(Rect2(Vector2.ZERO, size), Color("1d2522"))
	draw_set_transform(origin, 0, Vector2.ONE * world_scale)
	draw_texture_rect(ART.map_texture(stage_id), SPACE.BOUNDS, false, ART.map_tint(stage_id))
	var font := get_theme_font("font")
	var names := ["补给", "修习", "选卡精英", "装备精英"]
	for i in 4:
		var point: Vector2 = DIRECTOR.FIELD_POSITIONS[i]
		var available: bool = battle.director.field == -1
		var chosen: bool = battle.director.field == i
		var color := Color("e4d5a0") if available else Color("9aa87a") if chosen else Color("697568")
		draw_circle(point, 38, Color(color, 0.12))
		draw_arc(point, 38, 0, TAU, 40, color, 2, true)
		draw_string(font, point + Vector2(-48, -48), names[i] if available else "已选" if chosen else "关闭", HORIZONTAL_ALIGNMENT_CENTER, 96, 20, color)
	for gem in battle.gems:
		draw_colored_polygon(PackedVector2Array([gem.position + Vector2(0,-5), gem.position + Vector2(4,0), gem.position + Vector2(0,5), gem.position + Vector2(-4,0)]), Color("a5d4ce"))
	for enemy in battle.enemies:
		var point: Vector2 = enemy.position
		if enemy.windup > 0:
			var warning := Color(0.78,0.28,0.16,0.65)
			if enemy.attack == "charge": draw_line(point, point + enemy.aim * 240, warning, enemy.radius * 1.6, true)
			elif enemy.attack == "nova":
				draw_circle(point, enemy.blast_radius, Color(warning, .12))
				draw_arc(point, enemy.blast_radius, 0, TAU, 48, warning, 3, true)
			elif enemy.attack in ["shot", "fan"]: draw_line(point, point + enemy.aim * 160, warning, 3, true)
			else: draw_arc(point, enemy.radius + 32, 0, TAU, 32, warning, 3, true)
		if enemy.id == battle.target_id: draw_arc(point, enemy.radius + 4, 0.3, 2.8, 16, Color("e3dcac"), 1.5, true)
	draw_set_transform(origin, 0, Vector2.ONE * world_scale)
	draw_arc(battle.position, 20, 0, TAU, 32, Color("e0cf9a"), 2, true)
	if battle.current().shield > 0: draw_arc(battle.position, 27, 0, TAU, 32, Color("a8c8d0"), 2, true)

func draw_foreground(painter: Node2D) -> void:
	if battle == null: return
	painter.draw_set_transform(origin, 0, Vector2.ONE * world_scale)
	for enemy in battle.enemies:
		if enemy.hp >= enemy.max_hp and enemy.kind not in ["boss", "card_elite", "equipment_elite"]: continue
		var pos: Vector2 = enemy.position + Vector2(-22, enemy.radius + 10)
		painter.draw_rect(Rect2(pos, Vector2(44, 4)), Color("30352d"))
		painter.draw_rect(Rect2(pos, Vector2(44 * enemy.hp / enemy.max_hp, 4)), Color("bc7563"))
	for p in battle.projectiles:
		var color := Color("ed957d") if p.hostile else Color("a9ddff") if not p.context.direct else Color.WHITE
		var texture: Texture2D = ART.BOLTS[int(battle.director.elapsed * 14) % ART.BOLTS.size()]
		painter.draw_set_transform(origin + p.position * world_scale, p.velocity.angle(), Vector2.ONE * world_scale)
		painter.draw_texture_rect(texture, Rect2(-16, -8, 32, 16), false, color)
	for effect in battle.effects:
		_draw_authored_effect(painter, effect)
	_draw_minimap(painter)

func _draw_minimap(painter: Node2D) -> void:
	painter.draw_set_transform(Vector2.ZERO)
	# Same overview convention as the existing battle HUD: framed bounds,
	# hostile dots and a bright controlled actor, now with four optional fields.
	var rect := Rect2(size.x - 178, 82, 168, 94.5)
	painter.draw_rect(rect.grow(4), Color("101a15e0"))
	painter.draw_texture_rect(ART.map_texture(stage_id), rect, false, Color("758278") * ART.map_tint(stage_id))
	painter.draw_rect(rect, Color("b28b4b"), false, 1)
	var ratio := rect.size / SPACE.SIZE
	var viewport_rect := Rect2(rect.position - origin / world_scale * ratio, size / world_scale * ratio)
	painter.draw_rect(viewport_rect, Color("e8e4d0"), false, 1)
	for i in 4:
		if battle.director.field != -1 and battle.director.field != i: continue
		var point: Vector2 = rect.position + DIRECTOR.FIELD_POSITIONS[i] * ratio
		painter.draw_circle(point, 3, Color("e4d5a0"))
		painter.draw_string(get_theme_font("font"), point + Vector2(5 if i % 2 == 0 else -16, 4), ["补", "习", "卡", "装"][i], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("fff0c8"))
	for enemy in battle.enemies:
		painter.draw_circle(rect.position + enemy.position * ratio, 3 if enemy.kind == "boss" else 1.5, Color("f39b81") if enemy.kind == "boss" else Color("d76651"))
	painter.draw_circle(rect.position + battle.position * ratio, 3, Color("d4f4ff"))
