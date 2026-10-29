extends SceneTree
## Real casts feed both HUD layouts; no fabricated status dictionaries or screen mocks.
const VIEW := preload("res://scripts/ui/chronicle/battle_view.gd")
const C := preload("res://scripts/content/combat_catalog.gd")
const SETTINGS := preload("res://scripts/game_settings.gd")
var checks := 0
var failures := 0
var viewport: SubViewport
var view: Control
var definitions := {}
var capture_dir := ""
var focus_capture := false
var focus_metrics: Array = []

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_dir = arg.trim_prefix("--capture=")
		if arg == "--focus-capture": focus_capture = true
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)

func frames(count: int = 8) -> void:
	for i in count: await process_frame

func capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	viewport.get_texture().get_image().save_png(capture_dir.path_join(name + ".png"))

func fixture(ids: Array, armor: String = "cloth_armor") -> RefCounted:
	if is_instance_valid(view):
		view.queue_free()
		await frames()
	var records := {}
	for id in ids: records[id] = C.record(id, 10)
	var stage: Dictionary = C.stage("B01")
	stage.boss_time = 10000.0
	stage.boss_kills = 10000
	stage.spawn_interval = 10000.0
	view = VIEW.new()
	view.setup({"attempt_id":"mechanic-hud", "members":ids, "characters":records, "equipment":{"weapon":"plain_blade","armor":armor,"accessory":"ember_seal"},"stage":stage,"seed":927,"node":{"id":"B01","name":"人物机制显示检查"}}, definitions)
	viewport.add_child(view)
	view.set_physics_process(false)
	await frames()
	var b: RefCounted = view.battle
	b.director.spawn_remaining = 10000.0
	var enemy: RefCounted = b.director.spawn("melee", b.position + Vector2(90, 0))
	enemy.hp = 100000
	enemy.max_hp = 100000
	enemy.cooldown = 10000
	enemy.speed = 0
	b.enemies.append(enemy)
	for actor in b.characters.values():
		actor.stats.regen = 0
		actor.cooldowns[str(C.basic(actor.id, b.equipment).id)] = 10000
		for skill in C.definition(actor.id).automatic: actor.cooldowns[str(skill.id)] = 10000
		var support: Resource = C.definition(actor.id).support
		if support != null: actor.cooldowns[str(support.id)] = 10000
	return b

func paid(b: RefCounted, id: String, index: int = 0) -> void:
	b.active = b.members.find(id)
	expect(b._cast(C.definition(id).manual[index], b.characters[id], true, true), "real paid cast " + id)
	b._resolve_hits()

func refresh() -> void:
	# Finish portrait placement deterministically; the animation itself is checked elsewhere.
	if view.hud.layout_key == SETTINGS.HUD_LAYOUT_LEGACY: view.hud.presentation.active_layout = -1
	view.canvas.refresh(false)
	view.refresh()
	await frames()

func status(id: String) -> Label:
	if view.hud.layout_key == SETTINGS.HUD_LAYOUT_LEGACY and view.battle.current().id == id:
		return view.hud.presentation.mechanic_text
	return view.hud.presentation.find_child("member_mechanic_" + id, true, false) as Label

func check_layout(dimensions: Vector2i) -> void:
	var bounds := Rect2(Vector2.ZERO, Vector2(dimensions))
	var labels: Array = view.hud.presentation.find_children("member_mechanic_*", "Label", true, false)
	if view.hud.layout_key == SETTINGS.HUD_LAYOUT_LEGACY: labels.append(view.hud.presentation.mechanic_text)
	for words: Label in labels:
		if words.is_visible_in_tree():
			var minimum: Vector2 = words.get_minimum_size()
			var full_rect: Rect2 = words.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, Vector2(maxf(words.size.x, minimum.x), minimum.y))
			expect(words.size.y + .1 >= minimum.y and bounds.encloses(full_rect), "complete font-derived state height fits " + words.name + str(dimensions))
			expect(full_rect.end.y <= dimensions.y - 12, "state retains twelve-pixel bottom margin " + words.name + str(dimensions))
			if words.text.count("\n") > 0:
				var font: Font = words.get_theme_font("font")
				var required: float = font.get_height(words.get_theme_font_size("font_size")) * words.get_line_count() + words.get_theme_constant("line_spacing") * (words.get_line_count() - 1)
				expect(minimum.y + 1 >= required, "multiline rect includes every font line")
	expect(view.canvas.size == Vector2(dimensions), "status HUD leaves battlefield viewport intact")

func layouts(name: String, required: Dictionary) -> void:
	for key in [SETTINGS.HUD_LAYOUT_LEGACY, SETTINGS.HUD_LAYOUT_TEAM_BAND]:
		view.hud.set_layout(key)
		for dimensions in [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1920, 1080)]:
			viewport.size = dimensions
			await frames()
			await refresh()
			check_layout(dimensions)
			for id in required:
				var words: Label = status(id)
				expect(words != null and words.visible and words.text.contains(required[id]), "actual state displayed " + name + "/" + id)
			if focus_capture:
				if name == "offfield-windows" and key == SETTINGS.HUD_LAYOUT_LEGACY and dimensions.x in [960, 1280]:
					var words: Label = status("F02")
					focus_metrics.append({"viewport":str(dimensions), "control_height":words.size.y, "font_minimum_height":words.get_minimum_size().y, "line_count":words.get_line_count(), "global_rect":str(words.get_global_rect()), "bottom_margin":dimensions.y - words.get_global_rect().end.y})
					await capture(name + "-" + key + "-" + str(dimensions.x))
			elif dimensions.x == 1280 or name in ["echo-arrows", "refund-relay", "guard-temper-shield"]:
				await capture(name + "-" + key + "-" + str(dimensions.x))
		var snapshot := {}
		for id in view.battle.members: snapshot[id] = view.battle.mechanic_status(id)
		view.toggle_pause()
		view.battle.tick(100, Vector2.ONE)
		await refresh()
		for id in view.battle.members: expect(snapshot[id] == view.battle.mechanic_status(id), "pause freezes resource projection " + id)
		view.toggle_pause()
		await refresh()

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "isolated storage")
	if failures: quit(1); return
	for person in JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chronicle/characters.json")): definitions[person.id] = person
	var previous_layout := SETTINGS.load_hud_layout()
	SETTINGS.save_hud_layout(SETTINGS.HUD_LAYOUT_LEGACY)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var b: RefCounted = await fixture(["JIA", "F11", "F06"])
	paid(b, "F06")
	paid(b, "F11")
	paid(b, "JIA")
	expect(b.mechanic_status("F11").value == 1 and b.mechanic_status("F06").value < 6, "real record charge and arrow use established")
	await layouts("echo-arrows", {"F11":"回响 1/2", "F06":"箭"})
	b.active = 1
	await layouts("switched-echo", {"F11":"回响 1/2", "F06":"箭"})
	b.active = 0
	b.characters.F06.dead = true
	b.characters.F06.hp = 0
	await layouts("fallen-arrows", {"F06":"停用"})
	b = await fixture(["JIA", "F04", "F10"])
	paid(b, "JIA")
	paid(b, "F10")
	b.active = 0
	b.characters.JIA.cooldowns.clear()
	var price: float = b.manual_cost(C.definition("JIA").manual[0], "JIA")
	b.characters.JIA.mp = price
	expect(price < C.definition("JIA").manual[0].mana_cost, "relay lowers real next cost")
	await layouts("refund-relay", {"F04":"待返", "F10":"接力 需换人"})
	for key in [SETTINGS.HUD_LAYOUT_LEGACY, SETTINGS.HUD_LAYOUT_TEAM_BAND]:
		view.hud.set_layout(key)
		await refresh()
		var words: String = view.hud.presentation.skills[0].state.text if key == SETTINGS.HUD_LAYOUT_LEGACY else view.hud.presentation.rows[0].slots[2].label.text
		expect(words.contains("17.6") and not words.contains("缺") and not words.contains("不足"), "HUD uses actual affordable relay price in " + key)
	b.characters.F04.dead = true
	b.characters.F04.hp = 0
	await layouts("fallen-refund", {"F04":"待返"})
	expect(not status("F04").text.contains("停用"), "issued refund is not falsely disabled with owner death")
	b = await fixture(["JIA", "F02", "F08"], "iron_armor")
	b.active = 1
	b.mechanics.receive_hit(b.characters.F02, 1, b.equipment)
	paid(b, "F02")
	b.characters.F08.cooldowns.erase(str(C.definition("F08").support.id))
	expect(b._cast(C.definition("F08").support, b.characters.F08, false), "real support tempers active guard")
	await layouts("guard-temper-shield", {"F02":"守势"})
	expect(status("F02").text.contains("淬刃") and status("F02").text.contains("盾"), "HUD keeps secondary finite window and own shield")
	b.active = 0
	await layouts("offfield-windows", {"F02":"守势"})
	expect(status("F02").text.contains("淬刃"), "off-field window remains readable after switch")
	b = await fixture(["JIA"])
	await layouts("no-resource", {})
	for key in [SETTINGS.HUD_LAYOUT_LEGACY, SETTINGS.HUD_LAYOUT_TEAM_BAND]:
		view.hud.set_layout(key)
		await refresh()
		expect(not status("JIA").visible, "empty state has no resource text in " + key)
	view.queue_free()
	viewport.queue_free()
	await frames()
	SETTINGS.save_hud_layout(previous_layout)
	if focus_capture and not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir)
		var metrics := FileAccess.open(capture_dir.path_join("offfield-layout-metrics.json"), FileAccess.WRITE)
		metrics.store_string(JSON.stringify(focus_metrics, "  "))
	print("CHRONICLE_MECHANIC_HUD_SMOKE ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
