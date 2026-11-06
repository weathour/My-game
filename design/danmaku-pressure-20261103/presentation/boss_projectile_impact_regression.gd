extends SceneTree
## Real authored Boss action descriptors through the actual feedback event API.
const CATALOG := preload("res://scripts/content/enemy_catalog.gd")
const ENEMY := preload("res://scripts/battle/enemy_runtime.gd")
const GEOMETRY := preload("res://scripts/battle/enemy_geometry.gd")
const THREATS := preload("res://scripts/ui/chronicle/enemy_threat_view.gd")
const FEEDBACK := preload("res://scripts/ui/chronicle/boss_feedback.gd")
const CAMERA := preload("res://scripts/ui/chronicle/boss_camera.gd")
const BACKGROUND := Color("151b18")
var checks := 0
var failures := 0
var capture_dir := ""

class ImpactPainter:
	extends Node2D
	var feedback: Node
	func _draw() -> void:
		draw_rect(Rect2(0,0,480,320), Color("151b18"))
		feedback.draw(self, Vector2.ZERO, 1.0, false, false)

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_dir = arg.trim_prefix("--capture=")
	call_deferred("run")

func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func authored_action(enemy: RefCounted, kinds: Array) -> Dictionary:
	for form in enemy.forms:
		for action in form.attacks:
			if str(action.get("action", "")) in kinds: return action
	for action in enemy.actions:
		if str(action.get("action", "")) in kinds: return action
	return {}

func render_check(viewport: SubViewport, painter: Node2D, label: String, expected_empty: bool) -> void:
	painter.queue_redraw()
	for i in 3: await process_frame
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var colored := 0
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x,y)
			if absf(pixel.r-BACKGROUND.r)+absf(pixel.g-BACKGROUND.g)+absf(pixel.b-BACKGROUND.b) > .04: colored += 1
	expect(colored == 0 if expected_empty else colored > 20, label + " actual render has no false fan outline" if expected_empty else label + " actual area outline remains visible")
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir)
		image.save_png(capture_dir.path_join(label+".png"))

func run() -> void:
	var enemy := ENEMY.new(1,CATALOG.definition("B15"),Vector2(30,160))
	var fan := authored_action(enemy,["fan"])
	expect(not fan.is_empty(), "current authored B15 has a fan action")
	if fan.is_empty(): quit(1); return
	var g := GEOMETRY.descriptor(enemy,fan,Vector2(330,160))
	expect(bool(g.get("projectile_only", false)), "actual fan descriptor is projectile_only")
	var before := g.duplicate(true)
	var feedback := FEEDBACK.new()
	root.add_child(feedback)
	var camera := CAMERA.new()
	var event := {"kind":"boss_impact","position":enemy.position,"geometry":g}
	feedback.consume([event])
	camera.consume([event])
	expect(feedback.marks.is_empty() and THREATS.impact_outline(g).is_empty(), "actual fan impact creates no full-sector mark")
	expect(camera.trauma == 0, "ordinary Boss firing creates no heavy shake")
	expect(g == before, "feedback never edits actual collision descriptor")
	for policy in ["none","aim","area"]:
		var configured: Dictionary = g.duplicate(true)
		configured.warning_policy = policy
		feedback.consume([{"kind":"boss_impact","position":enemy.position,"geometry":configured}])
		expect(feedback.marks.is_empty() and THREATS.impact_outline(configured).is_empty(), "projectile_only remains non-area for policy " + policy)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(480,320)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var painter := ImpactPainter.new()
	painter.feedback = feedback
	viewport.add_child(painter)
	await render_check(viewport,painter,"boss-fan-no-false-area",true)
	var charge := authored_action(enemy,["charge","slam","swipe"])
	expect(not charge.is_empty(), "current Boss has a true area action")
	if not charge.is_empty():
		var area := GEOMETRY.descriptor(enemy,charge,Vector2(330,160))
		var area_event := {"kind":"boss_impact","position":enemy.position,"geometry":area}
		feedback.consume([area_event])
		camera.consume([area_event])
		expect(feedback.marks.size() == 1 and not THREATS.impact_outline(area).is_empty(), "true area impact retains its exact outline")
		expect(camera.trauma > 0, "true heavy area impact retains bounded shake")
		await render_check(viewport,painter,"boss-area-impact-retained",false)
	viewport.queue_free()
	feedback.queue_free()
	await process_frame
	print("BOSS_PROJECTILE_IMPACT_REGRESSION ","PASS" if failures == 0 else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)
