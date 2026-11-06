extends RefCounted
## Collision-based visual measurements; decoration and bloom never count as danger.
const GEOMETRY := preload("res://scripts/battle/enemy_geometry.gd")
const THREATS := preload("res://scripts/ui/chronicle/enemy_threat_view.gd")

static func coverage(battle: RefCounted, camera: Dictionary) -> Dictionary:
	var area_cells := 0
	var bullet_cells := 0
	var swept_cells := 0
	var total := 32 * 20
	var areas: Array = battle.telegraphs.duplicate()
	for hazard in battle.hazards:
		if str(hazard.get("phase", "active")) != "tell": areas.append(hazard)
	for y in 20:
		for x in 32:
			var screen: Vector2 = camera.safe_screen.position + camera.safe_screen.size * Vector2((x + .5) / 32.0, (y + .5) / 20.0)
			var point: Vector2 = (screen - camera.origin) / camera.scale
			var area := false
			for g in areas:
				if THREATS.warning_policy(g) == "area" and float(g.get("damage", 1)) > 0 and GEOMETRY.contains(g, point, 0): area = true; break
			if area: area_cells += 1
			var bullet := false
			var swept := false
			for p in battle.projectiles:
				if not p.get("hostile", false): continue
				var radius := float(p.get("hit_radius", 5))
				if point.distance_to(p.position) <= radius: bullet = true
				if Geometry2D.get_closest_point_to_segment(point, p.position, p.position + p.velocity * minf(.75, p.life)).distance_to(point) <= radius: swept = true
				if bullet and swept: break
			if bullet: bullet_cells += 1
			if swept: swept_cells += 1
	var enemy_feet_visible := 0
	var hostile_cores_visible := 0
	var safe_enemy_feet := 0
	var safe_hostile_cores := 0
	for enemy in battle.enemies:
		if enemy.dead: continue
		if camera.bounds.has_point(enemy.position): enemy_feet_visible += 1
		if camera.safe_screen.has_point(camera.origin + enemy.position * camera.scale): safe_enemy_feet += 1
	for projectile in battle.projectiles:
		if not projectile.get("hostile", false): continue
		if camera.bounds.grow(float(projectile.get("hit_radius", 5))).has_point(projectile.position): hostile_cores_visible += 1
		if camera.safe_screen.grow(float(projectile.get("hit_radius", 5)) * camera.scale).has_point(camera.origin + projectile.position * camera.scale): safe_hostile_cores += 1
	return {"enemy_feet_in_viewport":enemy_feet_visible,"hostile_cores_in_viewport":hostile_cores_visible,"enemy_feet_in_hud_free_view":safe_enemy_feet,"hostile_cores_in_hud_free_view":safe_hostile_cores,"visible_counts_scope":"enemy foot anchors and hostile solid cores; tall silhouettes may intersect screen with feet outside","sample_cells":total,"area_union_fraction":area_cells/float(total),"bullet_instant_fraction":bullet_cells/float(total),"bullet_swept_0_75s_fraction":swept_cells/float(total),"sweep_horizon_seconds":.75}
