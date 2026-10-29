extends Control
signal presentation_events(events: Array)
## Scene/animation adapter. No Player, enemy AI, collision bodies, or save dependencies.
const CAMERA := preload("res://scripts/ui/chronicle/boss_camera.gd")
const BOSS_FEEDBACK := preload("res://scripts/ui/chronicle/boss_feedback.gd")
const SETTINGS := preload("res://scripts/game_settings.gd")
const ENEMY_EFFECTS := preload("res://scripts/ui/chronicle/enemy_battle_effects.gd")
const THREATS := preload("res://scripts/ui/chronicle/enemy_threat_view.gd")
const ART := preload("res://scripts/ui/chronicle/battle_art.gd")
const SPACE := preload("res://scripts/battle/battle_space.gd")
const DIRECTOR := preload("res://scripts/battle/stage_director.gd")
const JIA_EFFECTS := preload("res://scripts/ui/chronicle/jia_effects.gd")
const AUTHORED_EFFECTS := preload("res://scripts/ui/chronicle/authored_battle_effects.gd")
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
var authored_effects: RefCounted
var last_seen_cast := 0
var killed_views: Dictionary = {}
var death_views: Array[Dictionary] = []
var released_threats: Array[Dictionary] = []
var opaque_bounds: Dictionary = {}
var enemy_effects: RefCounted
var camera: RefCounted = CAMERA.new()
var boss_feedback: Node
var safe_top := 82.0
var safe_bottom := 150.0
var presentation_finished := false
var camera_body_envelopes: Dictionary = {}
var edge_ground: AtlasTexture
var edge_ground_step := Vector2.ONE

class Foreground:
	extends Node2D
	var canvas: Control
	func _draw() -> void:
		canvas.draw_foreground(self)


func _ready() -> void:
	edge_ground = AtlasTexture.new()
	edge_ground.atlas = ART.map_texture(stage_id)
	edge_ground.region = Rect2(0,432,64,64)
	edge_ground_step = edge_ground.region.size * SPACE.SIZE / edge_ground.atlas.get_size()
	boss_feedback = BOSS_FEEDBACK.new()
	add_child(boss_feedback)
	enemy_effects = ENEMY_EFFECTS.new()
	jia_effects = JIA_EFFECTS.new()
	authored_effects = AUTHORED_EFFECTS.new()
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
	if battle.outcome == "failed": _clear_transients()
	elif not battle.outcome.is_empty(): released_threats.clear()
	_update_transients()
	moving = is_moving
	authored_effects.sync(battle)
	enemy_effects.sync(battle)
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
	actor_visual.modulate = Color("ffb1a1") if battle.current().hurt_lock > .15 and not SETTINGS.comfort_enabled("reduced_flash") else ART.tint(id)
	var live: Dictionary = {}
	var newly_bound_boss := false
	for enemy in battle.enemies:
		live[enemy.id] = true
		if enemy_views.has(enemy.id) and str(enemy_views[enemy.id].node.get_meta("visual_id", "")) != str(enemy.visual_id):
			# Forms retain their simulation identity; only the presentation node changes.
			var previous: Node2D = enemy_views[enemy.id].anchor
			var previous_body: Node2D = enemy_views[enemy.id].node
			if previous_body.has_method("play_death"):
				previous_body.play_death()
				death_views.append({"node":previous, "body":previous_body, "start":battle.director.elapsed, "presentation_start":boss_feedback.clock})
			else:
				actors.remove_child(previous)
				previous.queue_free()
			enemy_views.erase(enemy.id)
		if not enemy_views.has(enemy.id):
			if enemy.rank == "boss": newly_bound_boss = true
			var visual: Node2D = ART.create_enemy(enemy, stage_id)
			# Pixel-sheet hit bursts normally attach to SceneTree.current_scene.
			# Here feedback stays under this arena and follows its pause/scale.
			if visual.get("hit_sheet") != null: visual.set("hit_sheet", null)
			var anchor := Node2D.new()
			actors.add_child(anchor)
			anchor.add_child(visual)
			ART.fit_enemy_instance(visual, enemy, stage_id)
			enemy_views[enemy.id] = {"node":visual, "anchor":anchor, "position":enemy.position, "hp":enemy.hp, "winding":false}

		var entry: Dictionary = enemy_views[enemy.id]
		var node: Node2D = entry.node
		var direction: Vector2 = enemy.position - entry.position
		entry.anchor.position = enemy.position
		# Preserve the authored hit animation until its own lock expires.
		if float(node.get("hit_lock_remaining") if node.get("hit_lock_remaining") != null else 0.0) <= 0:
			if node.has_method("set_moving"): node.set_moving(direction.length_squared() > .001, direction if direction.length_squared() > .001 else enemy.aim)
		if enemy.hp < entry.hp and node.has_method("play_hit") and not SETTINGS.comfort_enabled("reduced_flash"): node.play_hit()
		if node.has_method("present"):
			var presenter: RefCounted = enemy
			if not enemy.targetable and enemy.parent_id > 0:
				for source in battle.enemies:
					if source.id == enemy.parent_id: presenter = source; break
			node.present(presenter, battle.director.elapsed, battle.paused)
		elif enemy.windup > 0 and not entry.winding and node.has_method("play_cast"): node.play_cast()
		node.modulate = Color("acd8e9") if enemy.slow_time > 0 else ART.enemy_tint(enemy.kind, stage_id)
		# Retain ground-based sorting, but reveal the controlled body behind tall enemies.
		var player_body := Rect2(battle.position + Vector2(-18, -72), Vector2(36, 72))
		var obscures_player: bool = enemy.position.y > battle.position.y and _body_rect(node, enemy.position).intersects(player_body)
		node.modulate.a = .42 if obscures_player else .78 if not enemy.targetable else 1.0
		entry["obscures_player"] = obscures_player
		entry.position = enemy.position
		entry.hp = enemy.hp
		entry.winding = enemy.windup > 0
	for key in enemy_views.keys():
		if not live.has(key):
			var node: Node2D = enemy_views[key].anchor
			if killed_views.has(key) and battle.outcome != "failed":
				var body: Node2D = enemy_views[key].node
				if body.has_method("play_death"): body.play_death()
				death_views.append({"node":node, "body":body, "start":battle.director.elapsed, "presentation_start":boss_feedback.clock})
			else:
				actors.remove_child(node)
				node.queue_free()
			enemy_views.erase(key)
	# Use this frame's actual pose, including the first frame of a new clip/form.
	# Animation contact frames must not outrun the visibility constraint by one tick.
	_sync_camera_body_bounds()
	if newly_bound_boss: camera.initialized = false
	camera.update(battle, size, 0, SETTINGS.comfort_enabled("reduced_motion"), safe_top, safe_bottom)
	world_scale = camera.scale
	origin = camera.origin
	actors.position = origin
	actors.scale = Vector2.ONE * world_scale
	# A crouched running frame is shorter than the 72px standing reference.
	# Keep that actual silhouette readable at the farthest camera scale too;
	# this affects presentation only, never the ground marker or hit geometry.
	var controlled_body := _body_rect(actor_visual, battle.position)
	if controlled_body.size.y > 0 and controlled_body.size.y * world_scale < 32.4:
		actor_visual.scale *= 32.4 / (controlled_body.size.y * world_scale)
	killed_views.clear()
	queue_redraw()
	foreground.queue_redraw()

func _body_rect(node: Node2D, point: Vector2) -> Rect2:
	var sprite = node.get("sprite")
	if not (sprite is AnimatedSprite2D or sprite is Sprite2D): return Rect2(point, Vector2.ZERO)
	var texture: Texture2D
	var region := Rect2i()
	if sprite is AnimatedSprite2D:
		texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	elif sprite.texture != null:
		texture = sprite.texture
		var cell: Vector2i = Vector2i(texture.get_size()) / Vector2i(sprite.hframes, sprite.vframes)
		region = Rect2i(Vector2i(sprite.frame % sprite.hframes, sprite.frame / sprite.hframes) * cell, cell)
	if texture == null: return Rect2(point, Vector2.ZERO)
	var key := str(texture.get_instance_id()) + ":" + str(region)
	if not opaque_bounds.has(key):
		var pixels := texture.get_image()
		if region.has_area(): pixels = pixels.get_region(region)
		opaque_bounds[key] = pixels.get_used_rect()
	var dimensions: Vector2 = Vector2(region.size) if region.has_area() else texture.get_size()
	var bounds := Rect2(opaque_bounds[key])
	bounds.position += sprite.offset - dimensions * .5
	if sprite.flip_h: bounds.position.x = -bounds.end.x
	return Transform2D(0, point) * node.transform * sprite.transform * bounds

func _sync_camera_body_bounds() -> void:
	camera.visual_bounds.clear()
	for enemy in battle.enemies:
		if enemy.rank != "boss" or not enemy_views.has(enemy.id): continue
		var node: Node2D = enemy_views[enemy.id].node
		if str(node.get_meta("visual_id", "")) != str(enemy.visual_id): continue
		var rect := _body_rect(node, enemy.position)
		if not rect.has_area(): continue
		var key := str(enemy.id) + ":" + str(enemy.visual_id) + ":" + str(node.scale)
		var relative := Rect2(rect.position - enemy.position, rect.size)
		# A direction change or idle frame must not make the camera breathe. Keep
		# the observed pose envelope for this form, including its mirrored weapon.
		relative = relative.merge(Rect2(Vector2(-relative.end.x, relative.position.y), relative.size))
		camera_body_envelopes[key] = Rect2(camera_body_envelopes.get(key, relative)).merge(relative)
		var envelope: Rect2 = camera_body_envelopes[key]
		camera.visual_bounds[enemy.id] = Rect2(enemy.position + envelope.position, envelope.size)

func advance_presentation(delta: float) -> void:
	if boss_feedback == null or battle == null: return
	boss_feedback.advance(delta, battle.paused, battle.outcome)
	if not battle.outcome.is_empty() and (battle.outcome == "failed" or boss_feedback.victory_remaining <= 0):
		if not presentation_finished:
			camera.reset()
			boss_feedback.clear()
			_clear_transients()
			presentation_finished = true
	_sync_camera_body_bounds()
	camera.update(battle, size, delta, SETTINGS.comfort_enabled("reduced_motion"), safe_top, safe_bottom)

func victory_presentation_pending() -> bool:
	return boss_feedback != null and boss_feedback.victory_remaining > 0

func camera_state() -> Dictionary:
	return camera.snapshot()

func _exit_tree() -> void:
	camera.reset()
	camera_body_envelopes.clear()
	if boss_feedback != null: boss_feedback.clear()
	_clear_transients()

func consume_events(events: Array) -> void:
	# Optional read-only telemetry before BattleView clears the simulation batch.
	if not presentation_events.get_connections().is_empty(): presentation_events.emit(events.duplicate(true))
	if battle.outcome != "failed":
		camera.consume(events)
		if boss_feedback != null: boss_feedback.consume(events)
	elif boss_feedback != null:
		boss_feedback.clear()
	enemy_effects.consume(events, battle)
	for event in events:
		if event.kind == "kill": killed_views[int(event.id)] = true
		if event.kind == "enemy_release" and event.has("geometry"):
			var geometry: Dictionary = event.geometry.duplicate(true)
			if enemy_views.has(int(event.id)):
				var actor: Node2D = enemy_views[int(event.id)].node
				if actor.has_method("play_release"): actor.play_release(geometry, battle.director.elapsed)
			if str(geometry.get("action_id", "")) == "collaboration":
				for child in battle.enemies:
					if child.parent_id == int(event.id) and not child.targetable and enemy_views.has(child.id):
						var apparition: Node2D = enemy_views[child.id].node
						if apparition.has_method("play_release"): apparition.play_release(geometry, battle.director.elapsed)
			geometry["view_until"] = battle.director.elapsed + .18
			released_threats.append(geometry)

func _update_transients() -> void:
	for index in range(death_views.size() - 1, -1, -1):
		var entry: Dictionary = death_views[index]
		var elapsed: float = boss_feedback.clock - float(entry.get("presentation_start", boss_feedback.clock)) if battle.outcome == "victory" else battle.director.elapsed - entry.start
		if entry.has("body") and entry.body.has_method("present_death"): entry.body.present_death(elapsed)
		entry.node.modulate.a = clampf(1 - elapsed / .3, 0, 1)
		if elapsed >= .3:
			entry.node.queue_free()
			death_views.remove_at(index)
	for index in range(released_threats.size() - 1, -1, -1):
		if battle.director.elapsed >= released_threats[index].view_until: released_threats.remove_at(index)

func _clear_transients() -> void:
	for entry in death_views: entry.node.queue_free()
	death_views.clear()
	released_threats.clear()
	killed_views.clear()

func _present_casts() -> void:
	var selected: Dictionary = {}
	for effect in battle.effects:
		if effect.kind == "impact": continue
		if int(effect.get("cast", 0)) <= last_seen_cast: continue
		if effect.get("source", "") != actor_kind or not effect.get("direct", false): continue
		if selected.is_empty() or effect.color == "manual": selected = effect
	last_seen_cast = battle.cast_serial
	if not selected.is_empty():
		if actor_visual.has_method("present_cast"):
			actor_visual.present_cast(selected)
		elif actor_visual.has_method("play_attack"):
			actor_visual.play_attack(selected.direction, selected.color == "manual")

func _draw_authored_effect(painter: Node2D, effect: Dictionary) -> void:
	# New enemy releases use their actual descriptor, rather than a misleading generic full disc.
	if effect.get("hostile", false) and not str(effect.get("visual_id", "")).is_empty(): return
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
	_draw_edge_ground()
	draw_texture_rect(ART.map_texture(stage_id), SPACE.BOUNDS, false, ART.map_tint(stage_id))
	var font := get_theme_font("font")
	var names := ["补给", "修习", "选卡精英", "装备精英"]
	for i in (4 if battle.director.config.get("fields_enabled", true) else 0):
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
		# Foot marks expose the actual hurt radius independently of tall combat art.
		if enemy.targetable:
			draw_arc(point, enemy.radius, 0, TAU, 32, Color("ad8b68", .50), 1, true)
		if enemy.rank in ["heavy", "field_elite", "boss"]:
			draw_circle(point, 3, Color("e7ca9b"))
		if enemy.id == battle.target_id: draw_arc(point, enemy.radius + 4, 0.3, 2.8, 16, Color("e3dcac"), 1.5, true)
	draw_set_transform(origin, 0, Vector2.ONE * world_scale)
	draw_arc(battle.position, 20, 0, TAU, 32, Color("e0cf9a"), 2, true)
	if battle.current().shield > 0: draw_arc(battle.position, 27, 0, TAU, 32, Color("a8c8d0"), 2, true)

func _draw_edge_ground() -> void:
	if edge_ground == null or not camera.bounds.has_area(): return
	# Decorative extension only. The arena remains SPACE.BOUNDS; no extra movement,
	# fields, collision or map coordinates are introduced by this ground patch.
	var visible: Rect2 = camera.bounds
	var first := Vector2i(floor(visible.position.x / edge_ground_step.x), floor(visible.position.y / edge_ground_step.y))
	var last := Vector2i(ceil(visible.end.x / edge_ground_step.x), ceil(visible.end.y / edge_ground_step.y))
	for y in range(first.y, last.y):
		for x in range(first.x, last.x):
			var rect := Rect2(Vector2(x,y) * edge_ground_step, edge_ground_step)
			if SPACE.BOUNDS.encloses(rect): continue
			# Alternating mirror tiles share the exact source edge with neighbours,
			# avoiding a repeated square seam in the decorative extension.
			var flip := Vector2(-1 if posmod(x,2) else 1, -1 if posmod(y,2) else 1)
			var corner := rect.position + Vector2(rect.size.x if flip.x < 0 else 0, rect.size.y if flip.y < 0 else 0)
			draw_set_transform(origin + corner * world_scale, 0, flip * world_scale)
			draw_texture_rect(edge_ground, Rect2(Vector2.ZERO,rect.size), false, ART.map_tint(stage_id) * Color(.84,.84,.84))
	draw_set_transform(origin, 0, Vector2.ONE * world_scale)

func draw_foreground(painter: Node2D) -> void:
	if battle == null: return
	painter.draw_set_transform(origin, 0, Vector2.ONE * world_scale)
	enemy_effects.draw(painter, battle)
	boss_feedback.draw(painter, origin, world_scale, SETTINGS.comfort_enabled("reduced_motion"), SETTINGS.comfort_enabled("reduced_flash"))
	# The controlled ground marker remains above bodies without changing world y sorting.
	painter.draw_arc(battle.position, 20, 0, TAU, 32, Color("f1ebbd"), 2, true)
	painter.draw_line(battle.position + Vector2(-5, 0), battle.position + Vector2(5, 0), Color("f1ebbd"), 2, true)
	painter.draw_line(battle.position + Vector2(0, -5), battle.position + Vector2(0, 5), Color("f1ebbd"), 2, true)
	# Persistent threats render over every body, so even the final Boss cannot conceal them.
	for descriptor in battle.hazards:
		if str(descriptor.get("phase", "active")) != "tell": THREATS.draw(painter, descriptor, true)
	for descriptor in battle.telegraphs: THREATS.draw(painter, descriptor)
	for descriptor in released_threats: THREATS.draw(painter, descriptor, true)
	for enemy in battle.enemies:
		_draw_enemy_state(painter, enemy)
		if not enemy.targetable: continue
		if enemy.hp >= enemy.max_hp and enemy.rank not in ["boss", "field_elite"] and enemy.kind not in ["boss", "card_elite", "equipment_elite"]: continue
		var owner: RefCounted = enemy.damage_owner()
		var pos: Vector2 = enemy.position + Vector2(-22, enemy.radius + 10)
		painter.draw_rect(Rect2(pos, Vector2(44, 4)), Color("30352d"))
		painter.draw_rect(Rect2(pos, Vector2(44 * owner.hp / maxf(1, owner.max_hp), 4)), Color("bc7563"))
	for p in battle.projectiles:
		if enemy_effects.draw_projectile(painter, p, battle.director.elapsed, origin, world_scale): continue
		if authored_effects.draw_projectile(painter, p, origin, world_scale): continue
		var color := Color("ed957d") if p.hostile else Color("a9ddff") if not p.context.direct else Color.WHITE
		var texture: Texture2D = ART.BOLTS[int(battle.director.elapsed * 14) % ART.BOLTS.size()]
		painter.draw_set_transform(origin + p.position * world_scale, p.velocity.angle(), Vector2.ONE * world_scale)
		painter.draw_texture_rect(texture, Rect2(-16, -8, 32, 16), false, color)
	for effect in battle.effects:
		if not AUTHORED_EFFECTS.style(effect).is_empty(): continue
		_draw_authored_effect(painter, effect)
	authored_effects.draw(painter, battle, origin, world_scale)
	_draw_minimap(painter)

func _draw_enemy_state(painter: Node2D, enemy: RefCounted) -> void:
	var point: Vector2 = enemy.position
	if enemy.behavior_id == "E04":
		var guarding: bool = enemy.guard_active and enemy.state != "recovery"
		var angle: float = enemy.aim.angle()
		painter.draw_arc(point, enemy.radius + 7, angle - PI * .45, angle + PI * .45, 20, Color("b4dae2") if guarding else Color("7a796b", .45), 4 if guarding else 1, true)
	if enemy.command_remaining > 0:
		var flag := point + Vector2(0, -enemy.body_height - 8)
		painter.draw_line(flag, flag + Vector2(0, -11), Color("f5cb71"), 2, true)
		painter.draw_colored_polygon(PackedVector2Array([flag + Vector2(0,-11), flag + Vector2(9,-8), flag + Vector2(0,-5)]), Color("f5cb71"))
	if enemy.protection_remaining > 0:
		for child in battle.enemies:
			if child.parent_id == enemy.id and child.definition_id == "D01" and not child.dead and child.position.distance_to(point) <= 220:
				painter.draw_line(point, child.position, Color("9bc9cb", .8), 2, true)
				painter.draw_arc(point, enemy.radius + 5, 0, TAU, 32, Color("9bc9cb"), 2, true)

func _draw_minimap(painter: Node2D) -> void:
	painter.draw_set_transform(Vector2.ZERO)
	# Same overview convention as the existing battle HUD: framed bounds,
	# hostile dots and a bright controlled actor, now with four optional fields.
	var rect := Rect2(size.x - 178, 82, 168, 94.5)
	painter.draw_rect(rect.grow(4), Color("101a15e0"))
	painter.draw_texture_rect(ART.map_texture(stage_id), rect, false, Color("758278") * ART.map_tint(stage_id))
	painter.draw_rect(rect, Color("b28b4b"), false, 1)
	var ratio := rect.size / SPACE.SIZE
	var viewport_rect := Rect2(rect.position + camera.bounds.position * ratio, camera.bounds.size * ratio)
	viewport_rect = viewport_rect.intersection(rect)
	painter.draw_rect(viewport_rect, Color("e8e4d0"), false, 1)
	for i in (4 if battle.director.config.get("fields_enabled", true) else 0):
		if battle.director.field != -1 and battle.director.field != i: continue
		var point: Vector2 = rect.position + DIRECTOR.FIELD_POSITIONS[i] * ratio
		painter.draw_circle(point, 3, Color("e4d5a0"))
		painter.draw_string(get_theme_font("font"), point + Vector2(5 if i % 2 == 0 else -16, 4), ["补", "习", "卡", "装"][i], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("fff0c8"))
	for enemy in battle.enemies:
		painter.draw_circle(rect.position + enemy.position * ratio, 3 if enemy.kind == "boss" else 1.5, Color("f39b81") if enemy.kind == "boss" else Color("d76651"))
	painter.draw_circle(rect.position + battle.position * ratio, 3, Color("d4f4ff"))
