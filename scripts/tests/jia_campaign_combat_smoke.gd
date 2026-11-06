extends SceneTree
## Exercise the production battle adapter, clips and HUD. Optional native capture
## observes full playing clips at three viewport sizes, including their recovery.
const VIEW := preload("res://scripts/ui/chronicle/battle_view.gd")
const C := preload("res://scripts/content/combat_catalog.gd")
const ART := preload("res://scripts/ui/chronicle/battle_art.gd")
const BOUNDS := preload("res://scripts/ui/chronicle/battle_sprite_bounds.gd")
const HURTBOX := preload("res://scripts/battle/player_hurtbox.gd")
const SPACE := preload("res://scripts/battle/battle_space.gd")
const SETTINGS := preload("res://scripts/shared/settings.gd")
const CLIPS := {"idle":4,"run":8,"attack":4,"sweep":4,"break":4}
var checks := 0
var failures := 0
var viewport: SubViewport
var native_container: SubViewportContainer
var view: Control
var capture_dir := ""
var animation_evidence: Array = []

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_dir = arg.trim_prefix("--capture=")
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	call_deferred("run")

func expect(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)

func frames(count: int = 3) -> void:
	for index in count: await process_frame

func request_for(node: String) -> Dictionary:
	var stage := C.stage(node)
	stage.boss_time = 100000.0
	stage.boss_kills = 100000
	return {"attempt_id":"jia-campaign-art-"+node,"members":["JIA","F11"],"characters":{"JIA":C.record("JIA",3),"F11":C.record("F11")},"equipment":{"weapon":"plain_blade","armor":"cloth_armor","accessory":"ember_seal"},"stage":stage,"seed":1713,"node":{"id":node,"name":"亲征边界验证"}}

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "isolated settings and battle storage")
	if failures: quit(1); return
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if not capture_dir.is_empty() and DisplayServer.get_name() != "headless":
		native_container = SubViewportContainer.new()
		native_container.size = Vector2(1280,720)
		root.add_child(native_container)
		native_container.add_child(viewport)
	else: root.add_child(viewport)
	var definitions := {}
	for person in JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chronicle/characters.json")): definitions[person.id] = person
	view = VIEW.new()
	view.setup(request_for("B13"),definitions)
	viewport.add_child(view)
	view.set_physics_process(false)
	await frames()
	var battle: RefCounted = view.battle
	battle.director.spawn_remaining = 100000
	battle.position = SPACE.CENTER
	view.canvas.refresh(false)
	var actor: Node2D = view.canvas.actor_visual
	expect(actor.scene_file_path.contains("/jia-campaign/"), "actual first Cao battle selects campaign actor")
	expect(ART.actor("JIA").resource_path.contains("/jia/jia.tscn"), "default API preserves common actor")
	expect(ART.portrait("JIA","campaign").resource_path.contains("/jia-campaign/"), "campaign HUD portrait is a separate scene")
	expect(actor.scale.is_equal_approx(Vector2.ONE*.9) and actor.position == Vector2.ZERO, "80px body remains 72world units, independent of 256px canvas")
	expect(actor.sprite.position == Vector2(0,-108), "256px sprite retains measured 128/236 foot anchor")
	expect(BOUNDS.readbacks == 0, "first campaign mount performs no alpha pixel readback")
	expect(HURTBOX.RADIUS == 4.0 and HURTBOX.center(Vector2.ZERO) == Vector2(0,-36), "unchanged controlled collision core and radius")
	var before_stats: Dictionary = battle.current().stats.duplicate(true)
	var before_actor: Dictionary = battle.current().snapshot()
	check_all_clips(actor)
	await check_hud_portraits()
	expect(battle.current().stats == before_stats and battle.current().snapshot() == before_actor, "clip and fit inspection changes no numeric battle state")
	# Failed attempts cannot animate an action. Real BattleSession emits the
	# successful event; the controller must begin at contact exactly once.
	actor._finish_attack()
	battle.enemies.clear()
	battle.current().cooldowns.clear()
	battle.tick(0,Vector2.ZERO)
	view.canvas.refresh(false)
	expect(not actor.attacking, "no target produces no fake basic cast")
	var enemy: RefCounted = battle.director.spawn("E01",battle.position+Vector2(-80,0))
	enemy.hp = 100000
	enemy.max_hp = 100000
	battle.enemies.append(enemy)
	battle.current().cooldowns.clear()
	battle.tick(0,Vector2.ZERO)
	view.canvas.refresh(false)
	expect(actor.attacking and actor.sprite.animation == &"dao-attack" and actor.sprite.flip_h, "real dao hit attacks toward left target")
	expect(actor.sprite.frame == 1 and enemy.hp < 100000, "contact pose begins at immediate damage")
	var presentations: int = actor.presentation_snapshot().successful_presentations
	view.canvas.refresh(true)
	expect(actor.presentation_snapshot().successful_presentations == presentations and actor.sprite.frame == 1, "repeated refresh does not restart contact")
	battle.set_paused(true)
	view.canvas.refresh(false)
	var paused_frame: int = actor.sprite.frame
	var paused_progress: float = actor.sprite.frame_progress
	var paused_clock: float = battle.director.elapsed
	await create_timer(.16).timeout
	view.canvas.advance_presentation(.16)
	view.canvas.refresh(false)
	expect(actor.sprite.frame == paused_frame and is_equal_approx(actor.sprite.frame_progress,paused_progress) and battle.director.elapsed == paused_clock, "pause freezes natural animation and battle clock")
	battle.set_paused(false)
	view.canvas.refresh(true)
	var old_position: Vector2 = battle.position
	battle.tick(.01,Vector2.UP)
	view.canvas.refresh(true)
	expect(battle.position.y < old_position.y and actor.attacking, "attack does not lock movement")
	await create_timer(.4).timeout
	expect(not actor.attacking and actor.sprite.animation == &"dao-run", "natural contact recovery returns to locomotion")
	for weapon in ["plain_blade","long_spear"]:
		battle.equipment.weapon = weapon
		view.canvas.refresh(false)
		var prefix := "spear" if weapon == "long_spear" else "dao"
		for slot in 2:
			actor._finish_attack()
			battle.current().mp = battle.current().stats.mp
			battle.current().cooldowns["JIA_basic"] = 100.0
			battle.current().cooldowns["jia_sweep" if slot == 0 else "jia_break"] = 100.0
			battle.request_skill(slot)
			battle.tick(0,Vector2.ZERO)
			view.canvas.refresh(false)
			expect(not actor.attacking, prefix+" cooldown rejection has no animation "+str(slot))
			battle.current().mp = 0
			battle.current().cooldowns["jia_sweep" if slot == 0 else "jia_break"] = 0.0
			battle.current().cooldowns["JIA_basic"] = 100.0
			battle.request_skill(slot)
			battle.tick(0,Vector2.ZERO)
			view.canvas.refresh(false)
			expect(not actor.attacking, prefix+" mana failure has no animation "+str(slot))
			battle.current().mp = battle.current().stats.mp
			battle.current().cooldowns.clear()
			battle.request_skill(slot)
			battle.tick(0,Vector2.ZERO)
			view.canvas.refresh(false)
			var expected := prefix + ("-sweep" if slot == 0 else "-break")
			expect(actor.attacking and actor.manual_attack and str(actor.sprite.animation) == expected and actor.sprite.frame == 1, "manual-specific contact wins over same-tick basic "+expected)
			var active_identity: String = actor.presentation_snapshot().last_presentation_id
			actor.present_cast({"presentation_id":"rejected-basic-"+expected,"manual":false,"ability":"JIA_basic","direction":Vector2.RIGHT})
			expect(actor.presentation_snapshot().last_presentation_id == active_identity and str(actor.sprite.animation) == expected, "basic cannot interrupt manual recovery "+expected)
			var frame: int = actor.sprite.frame
			var snapshot: Dictionary = actor.presentation_snapshot()
			actor.present_cast({"presentation_id":active_identity,"manual":true,"ability":"jia_sweep" if slot == 0 else "jia_break","direction":Vector2.RIGHT})
			expect(actor.presentation_snapshot() == snapshot and actor.sprite.frame == frame, "same cast is not replayed "+expected)
			await create_timer(.4).timeout
			expect(not actor.attacking, "natural manual recovery finishes "+expected)
	# Successful cast directions flip the whole two-handed weapon, never the
	# simulation anchor or collision center; inspect both weapon families.
	for equipment in ["plain_blade","long_spear"]:
		actor.set_weapon(equipment)
		for direction in [Vector2.RIGHT,Vector2.LEFT]:
			actor._finish_attack()
			actor.present_cast({"presentation_id":"direction-"+equipment+str(direction.x),"ability":"JIA_basic","direction":direction})
			expect(actor.sprite.flip_h == (direction.x<0) and actor.position == Vector2.ZERO, "two-handed held weapon follows actual cast facing "+equipment+str(direction.x))
	actor._finish_attack()
	battle.effects.clear()
	battle.current().cooldowns.clear()
	battle.current().mp = battle.current().stats.mp
	battle.request_skill(0)
	battle.tick(0,Vector2.ZERO)
	view.canvas.refresh(false)
	var old_actor: WeakRef = weakref(actor)
	battle.request_switch(1)
	battle.tick(0,Vector2.ZERO)
	view.canvas.refresh(false)
	expect(view.canvas.actor_kind == "F11" and not view.canvas.actor_visual.scene_file_path.contains("/jia-campaign/"), "switch mounts companion rather than leaking campaign costume")
	battle.switch_cooldown = 0
	battle.request_switch(1)
	battle.tick(0,Vector2.ZERO)
	view.canvas.refresh(false)
	actor = view.canvas.actor_visual
	expect(view.canvas.actor_kind == "JIA" and actor.scene_file_path.contains("/jia-campaign/") and not actor.attacking, "return mounts fresh campaign controller without stale cast replay")
	await frames()
	expect(old_actor.get_ref() == null, "retired controller is released despite retained PNG assets")
	if not capture_dir.is_empty() and DisplayServer.get_name() != "headless":
		await native_animations(actor)
	battle._finish("failed")
	view.canvas.advance_presentation(.01)
	view.canvas.refresh(false)
	expect(battle.effects.is_empty() and view.canvas.authored_effects.transients.is_empty() and view.canvas.authored_effects.skill.transients.is_empty(), "terminal failure clears authored effects")
	var final_actor: WeakRef = weakref(actor)
	view.queue_free()
	viewport.queue_free()
	if native_container != null: native_container.queue_free()
	await frames()
	await create_timer(.3).timeout
	expect(final_actor.get_ref() == null, "view cleanup releases active controller")
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir)
		var file := FileAccess.open(capture_dir.path_join("animation-evidence.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(animation_evidence,"  "))
	print("JIA_CAMPAIGN_COMBAT_SMOKE ","PASS" if failures == 0 else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)

func check_all_clips(actor: Node2D) -> void:
	var reads := BOUNDS.readbacks
	var sprites: SpriteFrames = actor.sprite.sprite_frames
	expect(sprites.get_animation_names().size() == 10, "exactly ten authored dao/spear clips")
	for weapon in ["dao","spear"]:
		for clip in CLIPS:
			var name := StringName(weapon+"-"+clip)
			expect(sprites.has_animation(name) and sprites.get_frame_count(name) == CLIPS[clip], "complete clip frames "+str(name))
			expect(sprites.get_animation_loop(name) == (clip in ["idle","run"]), "only locomotion loops "+str(name))
			for index in CLIPS[clip]:
				var texture := sprites.get_frame_texture(name,index) as AtlasTexture
				expect(texture != null and texture.region == Rect2(256*index,0,256,256), "256-cell atlas order "+str(name)+str(index))
				if texture == null: continue
				var actual := texture.get_image().get_used_rect()
				expect(actual.has_area() and BOUNDS.used_rect(texture) == actual, "imported alpha agrees with precomputed boundary "+str(name)+str(index))
	expect(BOUNDS.readbacks == reads, "all campaign cells use metadata without runtime GPU readback")
	ART.fit_actor(actor,"JIA",false)
	expect(actor.scale.is_equal_approx(Vector2.ONE*.9), "fit uses authored body height rather than transparent canvas")

func check_hud_portraits() -> void:
	for layout in [SETTINGS.HUD_LAYOUT_SIMPLE,SETTINGS.HUD_LAYOUT_TEAM_BAND]:
		view.hud.set_layout(layout)
		view.refresh()
		await frames()
		var presentation: Control = view.hud.presentation
		var entries: Array = presentation.get("members") if presentation.get("members") != null else presentation.get("rows")
		var portrait: Control = entries[0].portrait
		expect(portrait.head_node != null and portrait.head_node.scene_file_path.contains("/jia-campaign/"), "actual Jia portrait uses campaign scene in HUD "+layout)
		var companion: Control = entries[1].portrait
		expect(companion.head_node != null and not companion.head_node.scene_file_path.contains("/jia-campaign/"), "HUD companion portrait remains unchanged "+layout)
	view.hud.set_layout(SETTINGS.HUD_LAYOUT_SIMPLE)
	view.refresh()
	await frames()

func native_animations(actor: Node2D) -> void:
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var battle: RefCounted = view.battle
	battle.enemies.clear()
	battle.effects.clear()
	battle.equipment.weapon = "plain_blade"
	battle.facing = Vector2.RIGHT
	# The combat assertions above deliberately leave real cast lifetimes alive.
	# This art-only sequence has no simulation ticks to age them out, so clear
	# those completed checks' presentation fixtures before reviewing each pose.
	view.canvas._clear_transients()
	battle.position = SPACE.CENTER
	for dimensions in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
		DisplayServer.window_set_size(dimensions)
		native_container.size = Vector2(dimensions)
		viewport.size = dimensions
		await frames(5)
		view._layout_hud()
		view.canvas.refresh(false)
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(capture_dir.path_join("overview-%d.png"%dimensions.x))
		for weapon in ["dao","spear"]:
			actor.set_weapon("long_spear" if weapon == "spear" else "plain_blade")
			for clip in CLIPS:
				actor._finish_attack()
				actor.action.finish(actor.sprite)
				actor.sprite.flip_h = false
				var name := StringName(weapon+"-"+clip)
				actor.sprite.play(name)
				actor.sprite.set_frame_and_progress(0,0)
				var seen := {}
				var duration: float = float(CLIPS[clip])/actor.sprite.sprite_frames.get_animation_speed(name)
				var deadline := Time.get_ticks_msec()+int((duration+.15)*1000)
				while Time.get_ticks_msec()<deadline:
					if actor.sprite.animation == name and not seen.has(actor.sprite.frame):
						var index: int = actor.sprite.frame
						seen[index] = true
						await RenderingServer.frame_post_draw
						var image := viewport.get_texture().get_image()
						var state: Dictionary = view.canvas.camera_state()
						var world: Rect2 = view.canvas._body_rect(actor,battle.position)
						var projected := Rect2(state.base_origin+world.position*state.scale,world.size*state.scale)
						expect(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(projected), "full plume/cloak/weapon alpha remains within native viewport "+str(name)+str(index))
						var foot: Vector2 = view.canvas.origin+battle.position*view.canvas.world_scale
						var factor: float = actor.scale.x*view.canvas.world_scale
						var crop := Rect2i(Rect2(foot+Vector2(-144,-252)*factor,Vector2(288,288)*factor)).intersection(Rect2i(Vector2i.ZERO,dimensions))
						image.get_region(crop).save_png(capture_dir.path_join("%d-%s-%02d.png"%[dimensions.x,name,index]))
					await process_frame
				var expected_frames: Array = []
				for index in CLIPS[clip]: expected_frames.append(index)
				expect(seen.keys() == expected_frames, "complete naturally playing native animation in authored order "+str(dimensions)+str(name))
				animation_evidence.append({"viewport":str(dimensions),"clip":str(name),"frames_seen":seen.keys(),"duration":duration})
