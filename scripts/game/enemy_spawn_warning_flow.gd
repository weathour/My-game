extends RefCounted

const SPAWN_WARNING_VIEW := preload("res://scripts/game/enemy_spawn_warning_view.gd")
const SPAWN_WARNING_BATCH := preload("res://scripts/game/spawn_warning_batch.gd")

const SPAWN_WARNING_RADIUS := 26.0


static func show_enemy_spawn_warning(main: Node, archetype: String, health_multiplier: float, speed_multiplier: float, damage_multiplier: float, spawn_position: Vector2) -> void:
	var batch: Node = get_spawn_warning_batch(main)
	if batch != null:
		batch.add_warning(spawn_position, SPAWN_WARNING_RADIUS, {
			"archetype": archetype,
			"health_multiplier": health_multiplier,
			"speed_multiplier": speed_multiplier,
			"damage_multiplier": damage_multiplier,
			"spawn_position": spawn_position
		})
		return
	var warning := SPAWN_WARNING_VIEW.new()
	warning.global_position = spawn_position
	main.add_child(warning)
	warning.finished.connect(func() -> void:
		spawn_after_warning(main, archetype, health_multiplier, speed_multiplier, damage_multiplier, spawn_position)
	, CONNECT_ONE_SHOT)
	warning.configure(SPAWN_WARNING_RADIUS)


static func get_spawn_warning_batch(main: Node) -> Node:
	if main == null or not is_instance_valid(main):
		return null
	var batch: Node = main.get_node_or_null("SpawnWarningBatch")
	if batch == null:
		batch = SPAWN_WARNING_BATCH.new()
		batch.name = "SpawnWarningBatch"
		main.add_child(batch)
		batch.warning_finished.connect(func(entry: Dictionary) -> void:
			var payload_variant: Variant = entry.get("payload", {})
			if payload_variant is not Dictionary:
				return
			var payload: Dictionary = payload_variant
			spawn_after_warning(
				main,
				str(payload.get("archetype", "chaser")),
				float(payload.get("health_multiplier", 1.0)),
				float(payload.get("speed_multiplier", 1.0)),
				float(payload.get("damage_multiplier", 1.0)),
				payload.get("spawn_position", Vector2.ZERO)
			)
		)
	return batch


static func spawn_after_warning(main: Node, archetype: String, health_multiplier: float, speed_multiplier: float, damage_multiplier: float, spawn_position: Vector2) -> void:
	if main == null or not is_instance_valid(main) or bool(main.get("game_over")):
		return
	if main.get("player") == null:
		return
	if main.has_method("queue_runtime_enemy_spawn"):
		main.queue_runtime_enemy_spawn({
			"kind": "normal",
			"archetype": archetype,
			"health_multiplier": health_multiplier,
			"speed_multiplier": speed_multiplier,
			"damage_multiplier": damage_multiplier,
			"spawn_position": spawn_position
		})
		return
	main.ENEMY_SPAWN_FLOW.spawn_configured_enemy_at(main, "normal", archetype, health_multiplier, speed_multiplier, spawn_position, damage_multiplier)
