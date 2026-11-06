extends SceneTree
## Independent acceptance for the fixed 72-world-unit standing-body danger core.
const VIEW := preload("res://scripts/ui/chronicle/battle_view.gd")
const BATTLE := preload("res://scripts/battle/battle_session.gd")
const SPACE := preload("res://scripts/battle/battle_space.gd")
const HURTBOX := preload("res://scripts/battle/player_hurtbox.gd")
const GEOMETRY := preload("res://scripts/battle/enemy_geometry.gd")
const ENEMY := preload("res://scripts/battle/enemy_runtime.gd")
const ENEMIES := preload("res://scripts/content/enemy_catalog.gd")
const COMBAT := preload("res://scripts/content/combat_catalog.gd")
const BODY_REFERENCE_HEIGHT := 72.0
const CORE_FROM_FEET := Vector2(0, -36)
const ACTORS := ["JIA", "F02", "F11", "N07", "M01"]
var viewport: SubViewport
var view: Control
var capture_dir := ""
var checks := 0
var failures := 0
var captures: Array[Dictionary] = []

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_dir = arg.trim_prefix("--capture=")
	call_deferred("run")

func expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func frames(count: int = 5) -> void:
	for _i in count: await process_frame

func fixture_request(ids: Array) -> Dictionary:
	var records := {}
	# BattleSession's defeat check always consults JIA even when the visible
	# fixture group does not include her. Keep that invariant valid in group 2.
	for id in ACTORS: records[id] = COMBAT.record(id)
	var definitions := {}
	var people: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chronicle/characters.json"))
	for person in people: definitions[str(person.id)] = person
	return {
		"request": {"attempt_id":"hurtbox-center-smoke", "members":ids.duplicate(), "characters":records,
			"equipment":{"weapon":"plain_blade", "armor":"cloth_armor", "accessory":""},
			"stage":COMBAT.stage("B01"), "seed":59021, "node":{"id":"B01", "name":"红点中心验收"}},
		"definitions":definitions,
	}

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "campaign/settings and runtime writes remain isolated in temporary user data")
	if failures: quit(1); return
	expect(is_equal_approx(HURTBOX.RADIUS, 4.0) and is_equal_approx(BATTLE.hurt_radius(), 4.0), "real collision radius remains four world units")
	verify_shared_geometry()
	verify_projectile_hits()
	verify_movement_attack_and_pickup()
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	for group_index in 2:
		var ids: Array = [ACTORS.slice(0, 3), ACTORS.slice(3, 5)][group_index]
		var fixture := fixture_request(ids)
		view = VIEW.new()
		view.setup(fixture.request, fixture.definitions)
		viewport.add_child(view)
		view.set_physics_process(false)
		await frames(12)
		var battle: RefCounted = view.battle
		battle.director.spawn_remaining = 10000.0
		battle.director.config.boss_time = 100000.0
		battle.director.config.boss_kills = 100000
		for dimensions in [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1920, 1080)]:
			viewport.size = dimensions
			view.size = Vector2(dimensions)
			await frames(3)
			for index in ids.size():
				battle.active = index
				battle.position = SPACE.CENTER
				view.canvas.camera.reset()
				view.canvas.refresh(false)
				view.refresh()
				await frames(4)
				verify_rendered_marker(str(ids[index]), dimensions)
				if dimensions == Vector2i(1280, 720): await capture_actor(str(ids[index]), dimensions)
		if group_index == 0:
			# A real switch and moving pose do not drag the core to the feet.
			battle.active = 0
			battle.position = SPACE.CENTER
			battle.switch_cooldown = 0
			var before_switch: Vector2 = expected_core(battle.position)
			battle.request_switch(1)
			battle.tick(0.0, Vector2.ZERO)
			view.canvas.refresh(false)
			view.refresh()
			await frames(3)
			expect(battle.current().id == "F02", "actual battle switch selects the next controlled character")
			expect(view.canvas.controlled_hurtbox().center == before_switch, "switch preserves core at the 72-unit standing-body center")
			var before_move: Vector2 = battle.position
			var move_rate: float = battle.current().stats.move
			battle.tick(0.2, Vector2.RIGHT)
			view.canvas.refresh(true)
			view.refresh()
			await frames(3)
			expect(is_equal_approx(battle.position.x - before_move.x, move_rate * 0.2), "movement remains measured from the ground anchor")
			expect(view.canvas.controlled_hurtbox().center == expected_core(battle.position), "moving animation does not offset the danger core")
		view.queue_free()
		await frames(3)
	viewport.queue_free()
	await frames(2)
	write_report()
	print("CHRONICLE_PLAYER_HURTBOX_CENTER_SMOKE ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures, " captures=", captures.size())
	quit(1 if failures else 0)

func expected_core(foot: Vector2) -> Vector2:
	# Independent acceptance datum from the approved standing-body specification;
	# intentionally does not read HURTBOX.center or SPACE.ACTOR_BODY_HEIGHT.
	return foot + CORE_FROM_FEET

func verify_shared_geometry() -> void:
	var foot := Vector2(750, 620)
	var core := expected_core(foot)
	expect(is_equal_approx(core.y, foot.y - BODY_REFERENCE_HEIGHT * 0.5), "72-unit reference puts accepted center 36 units above feet")
	expect(HURTBOX.center(foot) == core, "shared collision helper matches the independent standing-body datum")
	var circle := {"shape":"disc", "origin":core, "radius":1.0}
	expect(GEOMETRY.contains_actor(circle, foot), "area shape contains the same accepted danger point")
	expect(not GEOMETRY.contains_actor(circle, foot + CORE_FROM_FEET * -1.0), "old foot point is outside a core-centered area")
	var enemy := ENEMY.new(-510, ENEMIES.definition("E01"), foot + Vector2(0, 190))
	var marker := GEOMETRY.descriptor(enemy, {"id":"center_marker", "action":"marker", "shape":"marker", "radius":2.0, "windup":0.5}, foot)
	expect(marker.origin == core and GEOMETRY.contains_actor(marker, foot), "marker telegraph locks the visible core, not the feet")
	var charge := GEOMETRY.descriptor(enemy, {"id":"center_charge", "action":"charge", "shape":"line", "length":300.0, "half_width":3.0}, foot)
	var intended := (core - enemy.position).normalized()
	expect(charge.origin == enemy.position and Vector2(charge.direction).dot(intended) > 0.999, "charge aim points at the accepted core while retaining its own geometry origin")
	expect(GEOMETRY.contains_actor(charge, foot), "charge collision and ground-anchor adapter agree with the core point")

func isolated_battle(id: String = "JIA") -> RefCounted:
	var fixture := fixture_request([id])
	var battle: RefCounted = BATTLE.new(fixture.request)
	battle.director.config.boss_time = 100000.0
	battle.director.config.boss_kills = 100000
	battle.director.spawn_remaining = 10000
	battle.position = SPACE.CENTER
	battle._actor_previous_position = battle.position
	battle.enemies.clear()
	return battle

func shot_loss(y_offset_from_foot: float) -> float:
	var battle := isolated_battle()
	var actor: RefCounted = battle.current()
	var before: float = actor.hp
	battle.projectiles.append({"position":battle.position + Vector2(-20, y_offset_from_foot),
		"velocity":Vector2(400, 0), "life":1.0, "hostile":true, "damage":20.0,
		"hit_radius":0.0, "source_id":-510, "move_id":"hurtbox_center_test"})
	battle.tick(0.1, Vector2.ZERO)
	return before - float(actor.hp)

func verify_projectile_hits() -> void:
	var core_hit := shot_loss(CORE_FROM_FEET.y)
	var foot_sweep := shot_loss(0.0)
	var outside_radius := shot_loss(CORE_FROM_FEET.y - 4.1)
	expect(core_hit > 0.0, "real hostile projectile sweep across torso center causes damage")
	expect(is_zero_approx(foot_sweep), "projectile sweep across the old foot marker does not damage the player")
	expect(is_zero_approx(outside_radius), "a center sweep beyond the four-unit collision radius stays harmless")

func verify_movement_attack_and_pickup() -> void:
	var battle := isolated_battle()
	var actor: RefCounted = battle.current()
	var old_foot: Vector2 = battle.position
	var move_rate: float = actor.stats.move
	battle.tick(0.2, Vector2.RIGHT)
	expect(is_equal_approx(battle.position.x - old_foot.x, move_rate * 0.2), "simulation movement speed is unchanged by the elevated danger point")
	battle.position = SPACE.CENTER
	var ability: Resource = COMBAT.basic("JIA", battle.equipment)
	var reach: float = battle.mechanics.query_reach(ability, battle.current(), true)
	var target := ENEMY.new(-511, ENEMIES.definition("E01"), battle.position + Vector2(reach + ENEMIES.definition("E01").radius - 1.0, 0))
	battle.enemies = [target]
	var target_distance_from_core: float = expected_core(battle.position).distance_to(target.position)
	var casts: bool = battle._cast(ability, battle.current(), true)
	var cast_event: Dictionary = {}
	for event in battle.events:
		if str(event.get("kind", "")) == "cast": cast_event = event; break
	expect(casts and not cast_event.is_empty(), "basic attack retains its ground-anchor range at the old edge")
	expect(target_distance_from_core > reach + target.radius, "attack edge fixture would be out of range if targeting moved to the hitbox center")
	expect(cast_event.get("origin", Vector2.ZERO) == battle.position, "basic attack origin remains at the ground anchor")
	battle.enemies.clear()
	battle.gems = [{"position":battle.position, "amount":1.0}]
	battle.events.clear()
	battle._update_gems(0.0)
	var picked_up := false
	for event in battle.events:
		if str(event.get("kind", "")) == "xp_pickup": picked_up = true
	expect(battle.gems.is_empty() and picked_up, "pickup still collects at the ground anchor rather than shifting with hurtbox")

func verify_rendered_marker(actor_id: String, dimensions: Vector2i) -> void:
	var canvas: Control = view.canvas
	var hit: Dictionary = canvas.controlled_hurtbox()
	var foot: Vector2 = view.battle.position
	var accepted := expected_core(foot)
	expect(hit.visible and hit.center == accepted and is_equal_approx(float(hit.radius), 4.0), "red canvas marker equals independent core/radius for %s at %s" % [actor_id, dimensions])
	var bounds := opaque_actor_bounds(canvas.actor_visual)
	expect(bounds.has_area() and bounds.has_point(CORE_FROM_FEET), "core lies inside this real idle frame's opaque character body: %s" % actor_id)
	if DisplayServer.get_name() != "headless":
		expect(marker_pixel(canvas, accepted), "rendered red pixel is centered on accepted torso point: %s at %s" % [actor_id, dimensions])

func opaque_actor_bounds(visual: Node2D) -> Rect2:
	var sprite := visual.get("sprite") as Node2D
	if sprite == null: return Rect2()
	var texture: Texture2D
	if sprite is AnimatedSprite2D:
		var animated := sprite as AnimatedSprite2D
		if animated.sprite_frames == null or not animated.sprite_frames.has_animation(animated.animation): return Rect2()
		texture = animated.sprite_frames.get_frame_texture(animated.animation, animated.frame)
	elif sprite is Sprite2D:
		texture = (sprite as Sprite2D).texture
	if texture == null: return Rect2()
	var used := texture.get_image().get_used_rect()
	if used.size == Vector2i.ZERO: return Rect2()
	var local := Rect2(used)
	if sprite is Sprite2D and (sprite as Sprite2D).centered:
		local.position -= texture.get_size() * 0.5
	if sprite is AnimatedSprite2D and (sprite as AnimatedSprite2D).centered:
		local.position -= texture.get_size() * 0.5
	local.position += Vector2(sprite.get("offset"))
	return visual.transform * sprite.transform * local

func marker_pixel(canvas: Control, world_point: Vector2) -> bool:
	var screen_point: Vector2 = canvas.origin + world_point * canvas.world_scale
	var image := viewport.get_texture().get_image()
	var pixel := Vector2i(roundi(screen_point.x), roundi(screen_point.y))
	if pixel.x < 0 or pixel.y < 0 or pixel.x >= image.get_width() or pixel.y >= image.get_height(): return false
	var color := image.get_pixelv(pixel)
	return color.r > 0.8 and color.g < 0.3 and color.b < 0.45

func capture_actor(actor_id: String, dimensions: Vector2i) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var canvas: Control = view.canvas
	var hit: Dictionary = canvas.controlled_hurtbox()
	var screen_point: Vector2 = canvas.origin + hit.center * canvas.world_scale
	var source := viewport.get_texture().get_image()
	var center := Vector2i(roundi(screen_point.x), roundi(screen_point.y))
	var region := Rect2i(center - Vector2i(64, 64), Vector2i(128, 128))
	region.position.x = clampi(region.position.x, 0, source.get_width() - region.size.x)
	region.position.y = clampi(region.position.y, 0, source.get_height() - region.size.y)
	var crop := source.get_region(region)
	crop.resize(384, 384, Image.INTERPOLATE_NEAREST)
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var filename := "%s-%d.png" % [actor_id, dimensions.x]
	var saved := crop.save_png(capture_dir.path_join(filename)) == OK
	expect(saved, "enlarged torso screenshot saved: " + filename)
	var report_relative_path := capture_dir.get_file().path_join(filename)
	captures.append({"actor_id":actor_id, "viewport":[dimensions.x,dimensions.y], "world_scale":canvas.world_scale,
		"foot_world":[view.battle.position.x,view.battle.position.y], "core_world":[hit.center.x,hit.center.y],
		"expected_core_from_feet":[0,-36], "radius_world":hit.radius, "screenshot":report_relative_path})

func write_report() -> void:
	if capture_dir.is_empty(): return
	var report_path := capture_dir.get_base_dir().path_join("hurtbox-center-results.json")
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write hurtbox center verification report")
		return
	file.store_string(JSON.stringify({"schema_version":1,"reference":{"standing_body_height_world":BODY_REFERENCE_HEIGHT,"core_offset_from_feet":[0,-36],"radius":4},
		"checks":checks,"failures":failures,"captures":captures}, "  "))
	file.close()
