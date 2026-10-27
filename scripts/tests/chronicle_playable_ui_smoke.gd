extends SceneTree
const SHELL := preload("res://scenes/chronicle/chronicle_shell.tscn")
const TARGET := preload("res://scripts/battle/targeting.gd")
const DIRECTOR := preload("res://scripts/battle/stage_director.gd")
const SETTINGS := preload("res://scripts/game_settings.gd")
var shell: Control
var failures := 0
var capture_dir := ""
var viewport: SubViewport

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_dir = arg.trim_prefix("--capture=")
	call_deferred("run")

func expect(condition: bool, message: String) -> void:
	if not condition: failures += 1; push_error(message)

func frames(count: int = 4) -> void:
	for i in count: await process_frame

func capture(name: String) -> void:
	await frames(4)
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	viewport.get_texture().get_image().save_png(capture_dir.path_join(name + ".png"))
	expect(Vector2i(viewport.get_texture().get_size()) == viewport.size, "capture matches requested viewport")
	print("CAPTURE ", name, " ", viewport.get_texture().get_size())

func resize_view(dimensions: Vector2i) -> void:
	viewport.size = dimensions
	await frames(10)

func click(id: String) -> void:
	var button := shell.find_child(id, true, false) as Button
	expect(button != null and button.is_visible_in_tree() and not button.disabled, "usable " + id)
	if button != null and not button.disabled: button.pressed.emit()
	await frames()

func key(code: int, pressed: bool = true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	viewport.push_input(event)
	for i in 3: await physics_frame
	if pressed:
		event = event.duplicate()
		event.pressed = false
		Input.parse_input_event(event)
		viewport.push_input(event)
		await frames(2)

func run() -> void:
	var original_layout := SETTINGS.load_hud_layout()
	SETTINGS.save_hud_layout(SETTINGS.HUD_LAYOUT_LEGACY)
	# An actual rendered viewport avoids host window-manager/DPI resize races.
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	shell = SHELL.instantiate()
	shell.session.directory = "user://chronicle_playable_ui_tests/" + str(Time.get_ticks_usec())
	viewport.add_child(shell)
	await frames(10)
	await resize_view(Vector2i(1280,720))
	await capture("01-title")
	await click("new_campaign")
	await click("modal_confirm")
	# Fixed test seed; production new campaigns receive a fresh reward stream.
	shell.session.data.reward_seed = 781103
	await click("route_forward")
	await click("event_continue")
	await click("route_forward")
	await click("prep_start")
	expect(shell.page == "battle", "real combat opened")
	var view: Control = shell.battle_view
	expect(view.canvas.actor_visual.scene_file_path == "res://assets/players/jia/jia.tscn", "Jia uses his dedicated combat animation")
	expect(view.hud.layout_key == SETTINGS.HUD_LAYOUT_LEGACY, "simple HUD preference is loaded")
	expect(view.hud.presentation.members[0].root.visible and not view.hud.presentation.members[1].root.visible and not view.hud.presentation.members[2].root.visible, "solo HUD has no duplicated party members or empty-slot labels")
	var before: Vector2 = view.battle.position
	await key(KEY_W)
	expect(view.battle.position.y < before.y, "keyboard movement")
	await key(KEY_ESCAPE)
	expect(view.battle.paused, "keyboard pause")
	var time: float = view.battle.director.elapsed
	var sprite: AnimatedSprite2D = view.canvas.actor_visual.sprite
	var animation_frame := sprite.frame
	var animation_progress := sprite.frame_progress
	await frames(12)
	expect(view.battle.director.elapsed == time, "paused game clock frozen")
	expect(sprite.frame == animation_frame and is_equal_approx(sprite.frame_progress, animation_progress), "character animation freezes with battle pause")
	await capture("02-pause")
	await key(KEY_ESCAPE)
	await play_stage(3, "03-first-battle")
	expect(shell.page == "route" and shell.session.data.current == "S02", "real victory returns to Emma event")
	expect("long_spear" in shell.session.data.inventory, "equipment elite yielded weapon")
	await click("route_forward")
	await click("event_continue")
	expect(shell.page == "reward" and shell.session.data.owned.has("F11"), "story recruitment and rewards connected")
	await capture("04-first-reward")
	await click("reward_card_N16")
	await click("reward_card_N13")
	await click("reward_claim")
	await click("nav_roster")
	await click("character_F11")
	await click("assign_0")
	await click("character_N16")
	await click("assign_1")
	await capture("05-roster")
	await click("nav_equipment")
	await click("equip_slot_weapon")
	await click("equip_long_spear")
	expect(shell.session.data.equipped.weapon == "long_spear", "between-stage equipment change")
	await click("nav_route")
	await click("route_forward")
	await capture("06-preparation")
	await click("prep_start")
	view = shell.battle_view
	await key(KEY_E)
	expect(view.battle.current().id == "F11", "keyboard switches to Emma")
	expect(view.canvas.actor_visual.scene_file_path == "res://assets/players/wizard/wizard.tscn", "Emma reuses the existing mage scene")
	expect(view.hud.presentation.actor_name.text.begins_with("艾玛") and view.hud.presentation.skills[0].key.text == "J", "simple HUD follows controlled member")
	expect(view.hud.presentation.members[0].label.text.begins_with("主") and view.hud.presentation.members[0].hp.value > 0, "protagonist health remains visible off-field")
	var mana: float = view.battle.current().mp
	await key(KEY_J)
	expect(view.battle.current().mp < mana - 20, "manual ability consumes Emma mana")
	await capture("07-emma")
	await resize_view(Vector2i(960,540))
	expect(Rect2(Vector2.ZERO, view.canvas.size).has_point(view.canvas.origin + view.battle.position * view.canvas.world_scale), "following camera keeps actor in compact viewport")
	var simple: Control = view.hud.presentation
	expect(simple.band.position.x >= 0 and simple.band.position.x + simple.WIDTH * simple.band.scale.x <= view.hud.size.x, "simple bar fits compact viewport")
	await capture("08-compact")
	await key(KEY_ESCAPE)
	var layout_choice := view.find_child("battle_hud_layout", true, false) as OptionButton
	expect(layout_choice != null, "layout can be changed while paused")
	var hp_before: float = view.battle.current().hp
	var mp_before: float = view.battle.current().mp
	var cooldowns_before: Dictionary = view.battle.current().cooldowns.duplicate()
	view.battle.current().mp = 0
	view.battle.current().cooldowns.clear()
	view.hud.refresh()
	expect(view.hud.presentation.skills[0].state.text == "缺魔", "mana shortage differs from cooldown")
	view.battle.current().mp = mp_before
	view.battle.current().cooldowns = cooldowns_before.duplicate()
	var reserve: RefCounted = view.battle.characters[view.battle.members[2]]
	reserve.dead = true
	view.hud.refresh()
	expect(view.hud.presentation.members[2].label.text == "阵亡", "fallen auxiliary has explicit unavailable state")
	reserve.dead = false
	view.hud.refresh()
	layout_choice.select(1)
	layout_choice.item_selected.emit(1)
	await frames()
	expect(view.hud.layout_key == SETTINGS.HUD_LAYOUT_TEAM_BAND and SETTINGS.load_hud_layout() == SETTINGS.HUD_LAYOUT_TEAM_BAND, "team layout selected and persisted")
	expect(view.battle.current().hp == hp_before and view.battle.current().mp == mp_before and view.battle.current().cooldowns == cooldowns_before, "layout changes preserve resources and cooldowns")
	await key(KEY_ESCAPE)
	await capture("08-team-compact")
	var team: Control = view.hud.presentation
	expect(team.band.position.x >= 0 and team.band.position.x + team.WIDTH * team.band.scale.x <= view.hud.size.x, "team band fits compact viewport")
	expect(team.rows[1].row.active and team.rows[1].slots[2].glyph.text == "J", "team HUD follows controlled member")
	await key(KEY_ESCAPE)
	layout_choice = view.find_child("battle_hud_layout", true, false) as OptionButton
	layout_choice.select(0)
	layout_choice.item_selected.emit(0)
	await key(KEY_ESCAPE)
	await resize_view(Vector2i(1920,1080))
	await capture("09-large")
	await resize_view(Vector2i(1280,720))
	view.battle.switch_cooldown = 0
	await key(KEY_Q)
	expect(view.battle.current().id == "JIA", "return to protagonist")
	await play_stage(2, "10-second-battle")
	expect(shell.page == "reward" and shell.session.data.pending.picks == 3, "extra elite yields actual five choose three")
	await capture("11-extra-reward")
	var candidates: Array = shell.session.data.pending.candidates.duplicate()
	for i in 3: await click("reward_card_" + candidates[i])
	await click("reward_claim")
	await click("route_forward")
	await click("event_continue")
	await capture("12-next-content")
	var forward := shell.find_child("route_forward", true, false) as Button
	expect(not forward.disabled and shell.session.battle_available("B04"), "second segment is reachable after the market")
	shell.open_page("settings")
	await frames()
	var saved_choice := shell.find_child("hud_layout", true, false) as OptionButton
	expect(saved_choice != null and saved_choice.item_count == 2 and saved_choice.selected == 0, "settings page exposes both layouts and reads saved preference")
	print("CHRONICLE_PLAYABLE_UI_SMOKE ", "PASS" if failures == 0 else "FAIL", " failures=", failures)
	shell.queue_free()
	await frames()
	viewport.queue_free()
	await frames()
	SETTINGS.save_hud_layout(original_layout)
	quit(0 if failures == 0 else 1)

func play_stage(field: int, screenshot: String) -> void:
	var view: Control = shell.battle_view
	view.set_physics_process(false)
	var b: RefCounted = view.battle
	var captured := false
	var captured_wave := false
	for frame in 18000:
		if not b.outcome.is_empty(): break
		var target := TARGET.nearest(b.enemies, b.position, 2000)
		var movement := Vector2.ZERO
		if b.director.field == -1: movement = (DIRECTOR.FIELD_POSITIONS[field] - b.position).normalized()
		elif target != null:
			if b.position.distance_to(target.position) > 75: movement = (target.position - b.position).normalized()
			if target.kind == "boss" and target.windup > 0: movement = target.aim.orthogonal()
		elif not b.gems.is_empty(): movement = (b.gems[0].position - b.position).normalized()
		if frame % 15 == 0: b.request_skill(0); b.request_skill(1)
		b.tick(1.0 / 60.0, movement)
		if frame >= 480 and not captured_wave:
			view.canvas.refresh(true)
			view.refresh()
			expect(view.canvas.enemy_views.size() == b.enemies.size(), "one presentation instance per live enemy")
			await capture(screenshot + "-wave")
			captured_wave = true
		if b.director.boss_spawned and not captured:
			view.canvas.refresh(true)
			view.refresh()
			await capture(screenshot)
			captured = true
	expect(b.outcome == "victory", "actual win " + screenshot)
	view._physics_process(0)
	await frames()
