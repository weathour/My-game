extends RefCounted

const PERFORMANCE_COUNTERS := preload("res://scripts/game/performance_counters.gd")
const ENEMY_BULLET := preload("res://scripts/enemy_bullet.gd")
const BOSS_RENDERER := preload("res://scripts/enemies/boss_projectile_renderer.gd")
const FRAME_CONTEXT := preload("res://scripts/enemies/enemy_projectile_frame_context.gd")
const PERFORMANCE_RECORDER := preload("res://scripts/game/performance_recorder.gd")

const BATCH_FRAME_META_KEY := "__enemy_projectile_batch_simulation_frame"


static func update_enemy_projectiles(scene: Node, delta: float, render_boss_projectiles: bool = true) -> void:
	if scene == null or delta <= 0.0:
		return
	var current_frame: int = Engine.get_physics_frames()
	if int(scene.get_meta(BATCH_FRAME_META_KEY, -1)) == current_frame:
		return
	scene.set_meta(BATCH_FRAME_META_KEY, current_frame)

	var renderer: Node2D = BOSS_RENDERER.get_or_create(scene) if render_boss_projectiles else null
	var context := FRAME_CONTEXT.new()
	var profile := bool(scene.get_meta(&"_profile_boss_projectiles", false))
	var started := Time.get_ticks_usec() if profile else 0
	if profile:
		PERFORMANCE_RECORDER.begin_scope("enemy_projectile_simulation_ms")
	var updated_count := 0
	for raw_projectile in _get_runtime_enemy_projectiles(scene):
		if not is_instance_valid(raw_projectile):
			continue
		# The built-in projectile has a known interface. Avoid reflecting its
		# property list and using call()/set() thousands of times per frame.
		if raw_projectile is ENEMY_BULLET:
			var bullet := raw_projectile as ENEMY_BULLET
			if bullet.pooled or bullet.is_queued_for_deletion():
				continue
			if not bullet.batch_simulation_enabled:
				bullet.batch_simulation_enabled = true
				bullet.set_physics_process(false)
			if renderer != null and bullet.boss_render_owner == null and bullet.visual_style.begins_with("boss_danmaku_"):
				renderer.add_projectile(bullet)
			bullet.batch_physics_process(delta, context)
			updated_count += 1
			continue
		if raw_projectile == null or not is_instance_valid(raw_projectile) or raw_projectile is not Node:
			continue
		var projectile_node := raw_projectile as Node
		if not projectile_node.has_method("can_use_batch_simulation") or not projectile_node.has_method("batch_physics_process"):
			continue
		if not bool(projectile_node.call("can_use_batch_simulation")):
			_restore_projectile_physics(projectile_node)
			continue

		if "batch_simulation_enabled" in projectile_node:
			projectile_node.set("batch_simulation_enabled", true)
		if projectile_node.is_physics_processing():
			projectile_node.set_physics_process(false)
		projectile_node.call("batch_physics_process", delta)
		updated_count += 1

	var render_started := Time.get_ticks_usec() if profile else 0
	if profile:
		PERFORMANCE_RECORDER.end_scope("enemy_projectile_simulation_ms")
		PERFORMANCE_RECORDER.begin_scope("enemy_projectile_renderer_sync_ms")
	if renderer != null:
		renderer.sync()
	if profile:
		PERFORMANCE_RECORDER.end_scope("enemy_projectile_renderer_sync_ms")
		scene.set_meta(&"_boss_simulation_usec", render_started - started)
		scene.set_meta(&"_boss_render_upload_usec", Time.get_ticks_usec() - render_started)
	if updated_count > 0:
		PERFORMANCE_COUNTERS.add("batched_enemy_projectiles", updated_count)


static func _get_runtime_enemy_projectiles(scene: Node) -> Array:
	if scene.has_method("get_runtime_enemy_projectiles"):
		return scene.call("get_runtime_enemy_projectiles")
	return scene.get_tree().get_nodes_in_group("enemy_projectiles") if scene.is_inside_tree() else []


static func _restore_projectile_physics(projectile_node: Node) -> void:
	if "batch_simulation_enabled" in projectile_node:
		projectile_node.set("batch_simulation_enabled", false)
	var pooled := false
	if "pooled" in projectile_node:
		pooled = bool(projectile_node.get("pooled"))
	if projectile_node.is_inside_tree() and not pooled and not projectile_node.is_physics_processing():
		projectile_node.set_physics_process(true)
