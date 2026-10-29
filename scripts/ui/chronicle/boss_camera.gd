extends RefCounted
## View-only framing. The simulation's geometry supplies both danger and escape tests.
const SPACE := preload("res://scripts/battle/battle_space.gd")
const GEOMETRY := preload("res://scripts/battle/enemy_geometry.gd")
const THREATS := preload("res://scripts/ui/chronicle/enemy_threat_view.gd")
const MIN_ZOOM := .60
const MAX_ZOOM := 1.0
var center := Vector2.ZERO
var zoom := 1.0
var scale := 1.0
var origin := Vector2.ZERO
var base_origin := Vector2.ZERO
var bounds := Rect2()
var safe_screen := Rect2()
var requested_bounds := Rect2()
var focus_bounds := Rect2()
var safe_route := PackedVector2Array()
var escape_valid := false
var escape_needed := false
var initialized := false
var clock := 0.0
var trauma := 0.0
var shake := Vector2.ZERO
var mode := "follow"
var terminal_point := Vector2.ZERO
var terminal_remaining := 0.0
var comfort_zoom := 1.0
var comfort_boss_id := -1
var hud_obstacles: Array[Rect2] = []
var visual_bounds: Dictionary = {}
var framed_dimensions := Vector2.ZERO
var framed_safe_screen := Rect2()
var framed_hud_obstacles: Array[Rect2] = []

func reset() -> void:
	initialized = false
	zoom = MAX_ZOOM
	trauma = 0.0
	shake = Vector2.ZERO
	safe_route.clear()
	escape_valid = false
	escape_needed = false
	mode = "follow"
	terminal_remaining = 0.0
	comfort_zoom = 1.0
	comfort_boss_id = -1
	framed_dimensions = Vector2.ZERO
	framed_safe_screen = Rect2()
	framed_hud_obstacles.clear()

func consume(events: Array) -> void:
	for event in events:
		match str(event.get("kind", "")):
			"boss_impact": trauma = minf(.72, trauma + .42)
			"boss_phase": trauma = maxf(trauma, .48)
			"boss_defeated":
				trauma = maxf(trauma, .68)
				terminal_point = event.get("position", Vector2.ZERO)
				terminal_remaining = .48

func update(battle: RefCounted, dimensions: Vector2, delta: float, reduced_motion: bool, top: float = 82.0, bottom: float = 150.0) -> void:
	if dimensions.x <= 1 or dimensions.y <= 1: return
	var base_scale := minf(dimensions.x / 1280.0, dimensions.y / 720.0)
	var next_safe_screen := Rect2(Vector2(32 * base_scale, top), Vector2(dimensions.x - 64 * base_scale, maxf(160 * base_scale, dimensions.y - top - bottom)))
	var layout_changed := dimensions != framed_dimensions or next_safe_screen != framed_safe_screen or hud_obstacles != framed_hud_obstacles
	if battle.paused and initialized and not layout_changed: return
	var paused_reframe: bool = battle.paused
	# A paused resize is a projection update, never a presentation-time tick.
	var step_delta := 0.0 if paused_reframe else maxf(0, delta)
	clock += step_delta
	terminal_remaining = maxf(0, terminal_remaining - step_delta)
	trauma = maxf(0, trauma - step_delta * 2.6)
	# Preserve the approved 32.4px body floor (72 world px * .45 screen scale).
	# Larger windows may widen further without making the controlled body smaller.
	var minimum_zoom := minf(MIN_ZOOM, .45 / base_scale)
	safe_screen = next_safe_screen
	var player: Vector2 = battle.position
	var primary := Rect2(player + Vector2(-52, -108), Vector2(104, 146))
	var boss: RefCounted
	for enemy in battle.enemies:
		if enemy.rank == "boss" and not enemy.dead and enemy.targetable and enemy.hp_owner_id == enemy.id:
			if boss == null or enemy.position.distance_squared_to(player) < boss.position.distance_squared_to(player): boss = enemy
	var relevant: Array[Dictionary] = []
	var active: Array[Dictionary] = []
	for hazard in battle.hazards:
		if float(hazard.get("damage", 1)) <= 0: continue
		if str(hazard.get("phase", "")) != "tell": active.append(hazard)
	for descriptor in battle.telegraphs:
		if float(descriptor.get("damage", 1)) <= 0: continue
		if GEOMETRY.contains(descriptor, player, 100): relevant.append(descriptor)
	for hazard in active:
		if GEOMETRY.contains(hazard, player, 100): relevant.append(hazard)
	safe_route.clear()
	escape_valid = false
	escape_needed = false
	if not relevant.is_empty():
		var speed: float = float(battle.current().stats.move) * (1 - battle.enemy_slow) * (1.25 if battle.current().haste > 0 else 1.0)
		var route := _escape(player, relevant, active, speed, boss.position if boss != null else player - Vector2(0, 100))
		escape_valid = route.valid
		escape_needed = route.needed
		if escape_valid:
			safe_route.append(player)
			safe_route.append(route.point)
			primary = primary.merge(Rect2(route.point - Vector2.ONE * 24, Vector2.ONE * 48))
	requested_bounds = primary
	if terminal_remaining > 0: requested_bounds = requested_bounds.merge(Rect2(terminal_point - Vector2(70, 120), Vector2(140, 160)))
	mode = "follow" if boss == null else "duel"
	if boss != null:
		var body: Rect2 = visual_bounds.get(boss.id, Rect2(boss.position + Vector2(-boss.radius - 24, -boss.body_height), Vector2((boss.radius + 24) * 2, boss.body_height + boss.radius))).grow(12)
		requested_bounds = requested_bounds.merge(body)
	for descriptor in relevant:
		for point in THREATS.outline(descriptor): requested_bounds = requested_bounds.expand(SPACE.clamp_point(point, Vector2.ZERO))
	if terminal_remaining > 0: mode = "victory"
	if not relevant.is_empty(): mode = "warning"
	# A full arena attack may exceed the readable zoom floor. Keep the controlled
	# body and reachable escape first, then fit as much attack/boss context as possible.
	focus_bounds = requested_bounds
	var capacity := safe_screen.size / (base_scale * minimum_zoom)
	if focus_bounds.size.x > capacity.x or focus_bounds.size.y > capacity.y:
		var limited_center := primary.get_center()
		if boss != null: limited_center = limited_center.lerp(boss.position, .22)
		focus_bounds = Rect2(limited_center - capacity * .5, capacity)
		var required := primary
		if boss != null:
			var with_body := primary.merge(Rect2(visual_bounds.get(boss.id, Rect2(boss.position + Vector2(-boss.radius - 20, -boss.body_height), Vector2((boss.radius + 20) * 2, boss.body_height + boss.radius)))))
			var with_boss := primary.expand(boss.position + Vector2(0, -30)).expand(boss.position + Vector2(0, 16))
			if with_body.size.x <= capacity.x and with_body.size.y <= capacity.y: required = with_body
			elif with_boss.size.x <= capacity.x and with_boss.size.y <= capacity.y: required = with_boss
			elif primary.expand(boss.position).size.x <= capacity.x and primary.expand(boss.position).size.y <= capacity.y: required = primary.expand(boss.position)
		focus_bounds = _contain(focus_bounds, required)
	var wanted_zoom := clampf(minf(safe_screen.size.x / maxf(1, focus_bounds.size.x), safe_screen.size.y / maxf(1, focus_bounds.size.y)) / base_scale, minimum_zoom, MAX_ZOOM)
	if boss != null and bool(boss.current_action.get("major", false)) and boss.windup > 0:
		wanted_zoom = minf(wanted_zoom, .91)
		mode = "warning"
	# Hard visibility is distinct from the pleasant follow target. A charge may
	# move faster than smoothing, and a world-edge clamp may hide a tall helmet.
	var hard_bounds := primary
	if boss != null:
		var real_body: Rect2 = visual_bounds.get(boss.id, Rect2(boss.position + Vector2(-boss.radius, -boss.body_height), Vector2(boss.radius * 2, boss.body_height)))
		var whole := primary.merge(real_body)
		var fit := minf(safe_screen.size.x / maxf(1, whole.size.x), safe_screen.size.y / maxf(1, whole.size.y)) / base_scale
		if fit >= minimum_zoom:
			hard_bounds = whole
			wanted_zoom = minf(wanted_zoom, fit)
		else:
			var anchor_bounds := primary.expand(boss.position)
			var anchor_fit := minf(safe_screen.size.x / maxf(1, anchor_bounds.size.x), safe_screen.size.y / maxf(1, anchor_bounds.size.y)) / base_scale
			if anchor_fit >= minimum_zoom: hard_bounds = anchor_bounds; wanted_zoom = minf(wanted_zoom, anchor_fit)
	# Comfort mode adapts to this window and body/attack footprint, then only widens
	# when necessary during the same duel. It never pulses back after each release.
	if reduced_motion and boss != null:
		if paused_reframe and layout_changed: comfort_boss_id = -1
		if comfort_boss_id != boss.id: comfort_boss_id = boss.id; comfort_zoom = wanted_zoom
		comfort_zoom = minf(comfort_zoom, wanted_zoom)
		wanted_zoom = comfort_zoom
	elif boss == null or not reduced_motion:
		comfort_boss_id = -1
		comfort_zoom = 1.0
	if not initialized or paused_reframe:
		center = focus_bounds.get_center() if boss != null or terminal_remaining > 0 else player + Vector2(0, -20)
		zoom = wanted_zoom
		initialized = true
	else:
		var weight := 1 - exp(-step_delta * (9.0 if wanted_zoom < zoom else 2.8))
		zoom = lerpf(zoom, wanted_zoom, weight)
		var wanted_center := focus_bounds.get_center() if boss != null or terminal_remaining > 0 or not relevant.is_empty() else player + Vector2(0, -20)
		center = center.lerp(wanted_center, 1 - exp(-step_delta * 6.0))
	var hard_fit := minf(safe_screen.size.x / maxf(1, hard_bounds.size.x), safe_screen.size.y / maxf(1, hard_bounds.size.y)) / base_scale
	zoom = minf(zoom, maxf(minimum_zoom, hard_fit))
	scale = base_scale * maxf(minimum_zoom, floorf(zoom * 128.0 + .00001) / 128.0)
	# Guarantee the controlled body/escape and fitting boss silhouette stay clear of HUD even while smoothing.
	var projected := safe_screen.get_center() - center * scale
	projected.x = clampf(projected.x, safe_screen.position.x - hard_bounds.position.x * scale, safe_screen.end.x - hard_bounds.end.x * scale) if hard_bounds.size.x * scale <= safe_screen.size.x else projected.x
	projected.y = clampf(projected.y, safe_screen.position.y - hard_bounds.position.y * scale, safe_screen.end.y - hard_bounds.end.y * scale) if hard_bounds.size.y * scale <= safe_screen.size.y else projected.y
	base_origin = projected.clamp(dimensions - SPACE.SIZE * scale, Vector2.ZERO)
	# Near the physical boundary, allow only the gutter needed to expose the
	# controlled body. A map clamp must not push the actor underneath the HUD.
	base_origin.x = clampf(base_origin.x, safe_screen.position.x - hard_bounds.position.x * scale, safe_screen.end.x - hard_bounds.end.x * scale) if hard_bounds.size.x * scale <= safe_screen.size.x else base_origin.x
	base_origin.y = clampf(base_origin.y, safe_screen.position.y - hard_bounds.position.y * scale, safe_screen.end.y - hard_bounds.end.y * scale) if hard_bounds.size.y * scale <= safe_screen.size.y else base_origin.y
	# The bottom HUD is not a full-width rectangle. Its actual plate and portrait
	# silhouettes reserve their own space without wasting the whole lower band.
	for obstacle in hud_obstacles:
		var body := Rect2(base_origin + (player + Vector2(-20, -82)) * scale, Vector2(40, 106) * scale)
		if body.intersects(obstacle):
			var candidates: Array[Vector2] = [base_origin - Vector2(0, body.end.y - obstacle.position.y + 6), base_origin - Vector2(body.end.x - obstacle.position.x + 6, 0), base_origin + Vector2(obstacle.end.x - body.position.x + 6, 0)]
			var resolved := false
			for candidate in candidates:
				if safe_screen.encloses(Rect2(candidate + hard_bounds.position * scale, hard_bounds.size * scale)):
					base_origin = candidate; resolved = true; break
			if not resolved: base_origin = candidates[0]
	# Keep the continuous integrator separate from pixel snapping. Feeding rounded
	# pixels back into smoothing strands the camera several world units off target.
	center = (safe_screen.get_center() - base_origin) / scale
	base_origin = base_origin.round()
	bounds = Rect2(-base_origin / scale, dimensions / scale)
	if not paused_reframe:
		shake = Vector2.ZERO if reduced_motion else Vector2(sin(clock * 87) + sin(clock * 43 + 1.2) * .4, sin(clock * 71 + 2.1)) * trauma * trauma * 5 * base_scale
	origin = base_origin + shake.round()
	framed_dimensions = dimensions
	framed_safe_screen = safe_screen
	framed_hud_obstacles = hud_obstacles.duplicate()

func _contain(rect: Rect2, required: Rect2) -> Rect2:
	var result := rect
	if required.position.x < result.position.x: result.position.x = required.position.x
	if required.end.x > result.end.x: result.position.x = required.end.x - result.size.x
	if required.position.y < result.position.y: result.position.y = required.position.y
	if required.end.y > result.end.y: result.position.y = required.end.y - result.size.y
	return result

func _escape(player: Vector2, dangers: Array[Dictionary], active: Array[Dictionary], move_speed: float, frame_hint: Vector2) -> Dictionary:
	var threatened := false
	var available := INF
	for danger in dangers:
		if GEOMETRY.contains(danger, player, 18):
			threatened = true
			if str(danger.get("phase", "tell")) == "tell": available = minf(available, maxf(0, float(danger.get("remaining", .9))))
			else: available = minf(available, .9)
	if not threatened: return {"valid":false, "point":player, "needed":false}
	var reach := minf(650, maxf(0, move_speed * available))
	var best := Vector2.ZERO
	var distance := INF
	for ring in range(1, 7):
		for sample in 24:
			var point := player + Vector2.from_angle(TAU * sample / 24) * reach * ring / 6.0
			if not Rect2(SPACE.PLAYER_MARGIN, SPACE.SIZE - SPACE.PLAYER_MARGIN * 2).has_point(point): continue
			var safe := true
			for danger in dangers:
				if GEOMETRY.contains(danger, point, 20): safe = false; break
			if not safe: continue
			for hazard in active:
				for step in range(1, 7):
					if GEOMETRY.contains(hazard, player.lerp(point, step / 6.0), 18): safe = false; break
				if not safe: break
			# The tiny tie-break chooses an equally short safe endpoint that shares
			# space with the boss, avoiding unnecessary downward camera pressure.
			var score := player.distance_squared_to(point) + point.distance_squared_to(frame_hint) * .0001
			if safe and score < distance:
				best = point
				distance = score
	return {"valid":distance < INF, "point":best, "needed":true}

func snapshot() -> Dictionary:
	return {"mode":mode, "center":center, "zoom":zoom, "scale":scale, "origin":origin, "base_origin":base_origin, "bounds":bounds, "safe_screen":safe_screen, "focus_bounds":focus_bounds, "requested_bounds":requested_bounds, "safe_route":safe_route.duplicate(), "escape_valid":escape_valid, "escape_needed":escape_needed, "trauma":trauma, "shake":shake}
