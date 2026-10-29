extends SceneTree
## Nine approved masters through real card, character and dialogue presentation controls.
const SHELL := preload("res://scenes/chronicle/chronicle_shell.tscn")
const STORY := preload("res://scripts/ui/chronicle/chronicle_story_view.gd")
const ART := preload("res://scripts/ui/chronicle/chronicle_portraits.gd")
const CARD := preload("res://scripts/ui/chronicle/chronicle_card.gd")
const PROFILE := preload("res://scripts/content/character_profiles.gd")
const T := preload("res://scripts/ui/chronicle/chronicle_theme.gd")
const SETTINGS := preload("res://scripts/game_settings.gd")
const MANIFEST := "res://design/baimen-women-20261028/manifest.json"
# Independently inspected source head bounds, including hair/bun and chin.
const HEADS := {
	"F02":Rect2(398,44,255,205), "F03":Rect2(400,8,210,235),
	"F04":Rect2(435,40,200,220), "F05":Rect2(398,8,205,225),
	"F06":Rect2(397,8,190,238), "F07":Rect2(344,5,270,250),
	"F08":Rect2(406,10,215,240), "F09":Rect2(390,12,240,235),
	"F10":Rect2(395,7,215,230)
}
var checks := 0
var failures := 0
var capture_dir := ""
var focus_id := ""
var viewport: SubViewport
var shell: Control
var metrics: Array = []
var source_entries: Array = []

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_dir = arg.trim_prefix("--capture=")
		if arg.begins_with("--focus="): focus_id = arg.trim_prefix("--focus=")
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)

func frames(count: int = 8) -> void:
	for i in count: await process_frame

func capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	if not focus_id.is_empty() and not name.contains(focus_id) and not name.begins_with("cards-"): return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	viewport.get_texture().get_image().save_png(capture_dir.path_join(name + ".png"))

func contains(control: Control, dimensions: Vector2i) -> bool:
	return Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(control.get_global_rect())

func fitted_rect(art: TextureRect) -> Rect2:
	var texture_size: Vector2 = art.texture.get_size()
	var factor := minf(art.size.x / texture_size.x, art.size.y / texture_size.y)
	return Rect2(art.global_position + (art.size - texture_size * factor) * .5, texture_size * factor)

func check_card(card: Button, id: String, dimensions: Vector2i) -> void:
	expect(contains(card, dimensions), "card control fits " + id + str(dimensions))
	var atlas := card.portrait as AtlasTexture
	expect(atlas != null and atlas.atlas == ART.standing(id), "card uses its own independent master " + id)
	if atlas == null: return
	var footer := 46.0 if card.compact else 61.0
	var area := Vector2(card.size.x - 10, card.size.y - footer - 5)
	var source: Rect2 = card.portrait_source_rect(area)
	var absolute := Rect2(atlas.region.position + source.position, source.size)
	expect(absolute.encloses(HEADS[id]), "actual cover region retains head/bun/chin " + id + str(dimensions))
	metrics.append({"surface":"card", "id":id, "viewport":str(dimensions), "source_rect":str(absolute), "control":str(card.get_global_rect())})

func cards_page(dimensions: Vector2i) -> void:
	var page := PanelContainer.new()
	page.theme = T.make_theme()
	page.add_theme_stylebox_override("panel", T.box(T.DARK, T.BORDER, 18))
	viewport.add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := T.column(page)
	column.add_child(T.label("白门楼人物 · 卡片构图", 24, T.GOLD, true))
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(center)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	center.add_child(grid)
	var card_size := Vector2(164,198) if dimensions.x == 960 else Vector2(210,255) if dimensions.x == 1280 else Vector2(285,350)
	for entry in source_entries:
		var id: String = entry.id
		var card := CARD.new()
		card.name = "art_card_" + id
		card.custom_minimum_size = card_size
		card.configure(id, shell.session.characters[id].name, PROFILE.find(id).title, "", false, shell.session.characters[id].rarity)
		grid.add_child(card)
	await frames()
	for entry in source_entries: check_card(grid.find_child("art_card_" + entry.id, false, false), entry.id, dimensions)
	await capture("cards-" + str(dimensions.x))
	page.queue_free()
	await frames()

func story_page(id: String, dimensions: Vector2i) -> void:
	var reader := STORY.new()
	# Read-only presentation fixture, authored quote; it claims no encounter or unlock.
	reader.setup({"id":"art-preview-" + id, "title":shell.session.characters[id].name, "location":"人物立绘展示", "background":"res://assets/story/chronicle/market.png", "lines":[{"id":"portrait", "speaker":id, "text":PROFILE.find(id).quote, "actors":[{"id":"JIA","slot":"left"},{"id":id,"slot":"right"}]}]})
	viewport.add_child(reader)
	await frames()
	reader.reveal_current()
	var actor := reader.find_child("StoryActor_" + id, true, false) as TextureRect
	var dialogue := reader.find_child("StoryDialogue", true, false) as Control
	var name_panel: Control = reader._name_panel
	var atlas := actor.texture as AtlasTexture
	expect(atlas != null and atlas.atlas == ART.standing(id), "dialogue uses selected independent master " + id)
	expect(actor.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED and contains(actor, dimensions), "dialogue never stretches or leaves stage " + id)
	var fit := fitted_rect(actor)
	var factor: float = fit.size.x / actor.texture.get_width()
	var head: Rect2 = HEADS[id]
	var head_on_screen := Rect2(fit.position + (head.position - atlas.region.position) * factor, head.size * factor)
	expect(head_on_screen.end.y < name_panel.global_position.y and head_on_screen.end.y < dialogue.global_position.y, "speaker head stays above text/nameplate " + id + str(dimensions))
	expect(head_on_screen.size.y >= 70 if dimensions.x >= 1280 else head_on_screen.size.y >= 50, "dialogue head remains readable " + id + str(dimensions))
	for target in ["StoryDialogue", "StorySpeaker", "event_continue", "story_back"]:
		expect(contains(reader.find_child(target, true, false), dimensions), "story text/control fits " + target)
	metrics.append({"surface":"story", "id":id, "viewport":str(dimensions), "head_on_screen":str(head_on_screen), "source_rect":str(atlas.region)})
	await capture("story-" + id + "-" + str(dimensions.x))
	reader.queue_free()
	await frames()

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "isolated test state")
	if failures: quit(1); return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	source_entries = manifest.characters
	expect(source_entries.size() == 9, "nine approved master identities")
	for entry in source_entries:
		var id: String = entry.id
		var source := "res://design/baimen-women-20261028/" + str(entry.path)
		var runtime := ART.STANDING_ROOT + id + "-standing.png"
		expect(FileAccess.get_sha256(source) == entry.sha256 and FileAccess.get_sha256(runtime) == entry.sha256, "runtime RGBA bytes match approved version " + id)
		var image := Image.new()
		image.load_png_from_buffer(FileAccess.get_file_as_bytes(runtime))
		expect(image.get_format() == Image.FORMAT_RGBA8 and image.get_size() == Vector2i(1024,1536), "RGBA full master retained " + id)
		expect(image.get_pixel(0,0).a < .02 and image.get_pixel(1023,1535).a < .02, "master contains genuine transparent exterior " + id)
		expect(ART.standing(id).resource_path == runtime, "standing resolves full standalone PNG " + id)
	var original_motion := SETTINGS.comfort_enabled("reduced_motion")
	SETTINGS.save_comfort("reduced_motion", true)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	shell = SHELL.instantiate()
	shell.session.directory = "user://baimen-women-ui-" + str(Time.get_ticks_usec())
	viewport.add_child(shell)
	await frames()
	var before: Dictionary = shell.session.data.duplicate(true)
	for dimensions in [Vector2i(960,540), Vector2i(1280,720), Vector2i(1920,1080)]:
		viewport.size = dimensions
		await frames()
		for entry in source_entries:
			var id: String = entry.id
			shell.selected_character = id
			shell.inspect_character(id, "profile")
			await frames()
			var art := shell.character_sheet.find_child("CharacterStanding", true, false) as TextureRect
			expect(art.texture == ART.standing(id) and not art.texture is AtlasTexture, "detail retains full body and feet " + id)
			expect(art.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED and contains(art, dimensions), "detail fits without deformation " + id)
			expect(not fitted_rect(art).intersects((shell.character_sheet.find_child("character_detail_panel", true, false) as Control).get_global_rect()), "full body does not cover detail text " + id)
			await capture("detail-" + id + "-" + str(dimensions.x))
			shell.roster_filter = "all"
			shell.search_text = shell.session.characters[id].name
			shell.open_page("roster")
			await frames()
			var card := shell.find_child("character_" + id, true, false) as Button
			check_card(card, id, dimensions)
			expect(card.size.x < dimensions.x * .3, "single search result stays a card rather than wide banner " + id)
			shell.hide()
			await story_page(id, dimensions)
			shell.show()
		shell.hide()
		await cards_page(dimensions)
		shell.show()
	expect(shell.session.data == before, "art browsing never changes campaign/resources/unlocks")
	shell.queue_free()
	viewport.queue_free()
	await frames()
	SETTINGS.save_comfort("reduced_motion", original_motion)
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir)
		var file := FileAccess.open(capture_dir.path_join("ui-framing-metrics.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(metrics, "  "))
	print("BAIMEN_WOMEN_PORTRAITS_SMOKE ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
