extends RefCounted

const ENEMY_ARCHETYPE_DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")


static func restore_profile_resources(enemy) -> void:
	if enemy == null:
		return
	var profile := ENEMY_ARCHETYPE_DATABASE.get_profile_for_restore(str(enemy.enemy_kind), str(enemy.archetype_id))
	enemy.profile_visual_scene = profile.get("visual_scene", null) as PackedScene
	enemy.body_collision_radius = float(profile.get("body_collision_radius", enemy.body_collision_radius))
	if profile.has("color"):
		enemy.display_color = profile.get("color", enemy.display_color)
	enemy.body_collision_reference_scale = max(0.001, max(abs(enemy.scale.x), abs(enemy.scale.y)))
