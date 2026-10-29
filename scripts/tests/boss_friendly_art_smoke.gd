extends SceneTree
## Runtime verification of manifest-driven friendly reuse of human-form sheets.
const ART := preload("res://scripts/ui/chronicle/battle_art.gd")
const IDS := {
	"M01": "B18_human", "M02": "B17_human", "M03": "M03_human",
	"M04": "M04_human", "M05": "B16_human", "M06": "B15_human",
}
var checks := 0
var failures := 0
var gallery: SubViewport

func _init() -> void:
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func wait_frames(count: int = 2) -> void:
	for index in count:
		await process_frame

func run() -> void:
	print("BOSS_FRIENDLY_ART_SMOKE_START")
	gallery = SubViewport.new()
	gallery.size = Vector2i(900, 240)
	gallery.transparent_bg = true
	gallery.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(gallery)
	var row := Node2D.new()
	gallery.add_child(row)
	var index := 0
	var pause_actor: Node2D
	var pause_parent: Node
	for id in IDS:
		var human_id: String = IDS[id]
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/enemies/baimen/%s/manifest.json" % human_id))
		expect(manifest.get("status", "") == "final", human_id + " finalized runtime manifest")
		expect(ART.actor(id) != null and ART.portrait(id) != null, id + " friendly actor and portrait routing")
		var actor: Node2D = ART.actor(id).instantiate()
		row.add_child(actor)
		await wait_frames()
		var sprite := actor.get_node("AnimatedSprite2D") as AnimatedSprite2D
		expect(sprite.sprite_frames != null, id + " SpriteFrames loaded")
		expect(sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, id + " nearest-neighbor rendering")
		ART.fit_actor(actor, id, false)
		var expected_scale := 72.0 / float(manifest.get("body_height_px", 224.0))
		expect(is_equal_approx(actor.scale.x, expected_scale) and is_zero_approx(actor.position.y), id + " fits manifest body height to 72 with foot at origin")
		var idle_size: Array = manifest.clips.idle.frame_size
		var anchor: Array = manifest.anchor_px
		expect(is_zero_approx(sprite.position.y + float(anchor[1]) - float(idle_size[1]) * 0.5), id + " sprite foot anchor reaches local origin")
		for clip_name in ["idle", "move", "attack", "special"]:
			var clip: Dictionary = manifest.clips.get(clip_name, {})
			expect(sprite.sprite_frames.has_animation(clip_name), id + " loaded " + clip_name)
			expect(sprite.sprite_frames.get_frame_count(clip_name) == int(clip.get("frames", 0)), id + " frame count " + clip_name)
		var faces_left := bool(manifest.get("faces_left", false))
		expect(sprite.flip_h == false, id + " starts in manifest-authored facing")
		actor.set_moving(true, Vector2.LEFT)
		expect(sprite.flip_h == not faces_left, id + " left facing mirrors relative to manifest default")
		actor.set_moving(true, Vector2.RIGHT)
		expect(sprite.flip_h == faces_left, id + " right facing mirrors relative to manifest default")
		var attack_contact := int(manifest.clips.attack.get("contact_frame", 0))
		actor.play_attack(Vector2.LEFT, false)
		expect(sprite.animation == &"attack" and sprite.frame == attack_contact, id + " attack begins at manifest contact frame")
		expect(sprite.flip_h == not faces_left, id + " attack faces left relative to manifest default")
		var special_contact := int(manifest.clips.special.get("contact_frame", 0))
		actor.play_attack(Vector2.RIGHT, true)
		expect(sprite.animation == &"special" and sprite.frame == special_contact and actor.manual_attack, id + " manual event begins at special contact frame")
		expect(sprite.flip_h == faces_left, id + " manual attack faces right relative to manifest default")
		actor.play_attack(Vector2.LEFT, false)
		expect(sprite.animation == &"special" and actor.manual_attack, id + " manual action has priority over normal cast")
		var head: Node2D = ART.portrait(id).instantiate()
		head.position = Vector2(90 + index * 142, 110)
		head.scale = Vector2.ONE * 0.42
		row.add_child(head)
		await wait_frames()
		var portrait_sprite := head.get_node("Sprite2D") as Sprite2D
		var portrait_spec: Dictionary = manifest.get("portrait", {})
		var portrait_path := "res://assets/enemies/baimen/%s/%s" % [human_id, portrait_spec.get("file", "portrait.png")]
		var portrait := load(portrait_path) as Texture2D
		var expected_region: Array = manifest.get("head_rect_px", [])
		expect(portrait_sprite.texture is AtlasTexture and portrait_sprite.texture.atlas == portrait, id + " portrait uses source atlas")
		expect(expected_region.size() == 4 and portrait_sprite.texture.region == Rect2(expected_region[0], expected_region[1], expected_region[2], expected_region[3]), id + " portrait crop follows reviewed head_rect_px")
		if id == "M01":
			pause_parent = Node.new()
			root.add_child(pause_parent)
			pause_actor = ART.actor(id).instantiate()
			pause_parent.add_child(pause_actor)
			pause_actor.set_moving(true, Vector2.RIGHT)
		index += 1
		print("BOSS_FRIENDLY_ART_ID_DONE ", id)
	print("BOSS_FRIENDLY_ART_RENDER")
	var screenshot_path := "unavailable"
	if DisplayServer.get_name() != "headless":
		await wait_frames(2)
		var screenshot := gallery.get_texture().get_image()
		if screenshot != null and not screenshot.is_empty():
			screenshot_path = "/tmp/boss-friendly-head-crops.png"
			screenshot.save_png(screenshot_path)
	if pause_actor != null:
		var pause_sprite := pause_actor.get_node("AnimatedSprite2D") as AnimatedSprite2D
		await create_timer(0.18).timeout
		pause_parent.process_mode = Node.PROCESS_MODE_DISABLED
		await create_timer(0.2).timeout
		var paused_frame := pause_sprite.frame
		var paused_progress := pause_sprite.frame_progress
		await create_timer(0.2).timeout
		expect(pause_sprite.frame == paused_frame and is_equal_approx(pause_sprite.frame_progress, paused_progress), "inherited disabled ancestor pauses AnimatedSprite2D")
		pause_parent.process_mode = Node.PROCESS_MODE_INHERIT
		await create_timer(0.2).timeout
		expect(pause_sprite.frame != paused_frame or not is_equal_approx(pause_sprite.frame_progress, paused_progress), "inherited process resumes AnimatedSprite2D")
	print("BOSS_FRIENDLY_ART_SMOKE ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures, " portrait_capture=", screenshot_path)
	quit(0 if failures == 0 else 1)
