extends SceneTree
## The actual in-place sheet, real numeric decomposition and read-only browsing.
const SHELL := preload("res://scenes/chronicle/chronicle_shell.tscn")
const C := preload("res://scripts/content/combat_catalog.gd")
const PROFILE := preload("res://scripts/content/character_profiles.gd")
const DETAIL := preload("res://scripts/ui/chronicle/character_detail_projection.gd")
const SETTINGS := preload("res://scripts/game_settings.gd")
var checks := 0
var failures := 0
var viewport: SubViewport
var shell: Control
var capture_dir := "docs/design-reviews/evidence/2026-10-29/party-inspection/character/screens"

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_dir = arg.trim_prefix("--capture=")
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1;push_error(message)

func frames(count: int = 5) -> void:
	for i in count: await process_frame

func press(key: Key) -> void:
	var event := InputEventKey.new();event.keycode = key;event.pressed = true
	viewport.push_input(event);await frames()
	event = InputEventKey.new();event.keycode = key;event.pressed = false
	viewport.push_input(event);await frames(1)

func capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	viewport.get_texture().get_image().save_png(capture_dir.path_join(name + ".png"))

func label(name: String) -> Label:
	return shell.character_sheet.find_child(name,true,false) as Label

func snapshot() -> Dictionary:
	var state: RefCounted = shell.session
	var files := {}
	if DirAccess.dir_exists_absolute(state.directory):
		for file in DirAccess.get_files_at(state.directory): files[file] = FileAccess.get_file_as_bytes(state.directory.path_join(file))
	return {"data":state.data.duplicate(true),"rng":state.reward_rng.state,"files":files}

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"),"isolated storage")
	if failures: quit(1);return
	var motion := SETTINGS.comfort_enabled("reduced_motion")
	SETTINGS.save_comfort("reduced_motion",true)
	viewport = SubViewport.new();viewport.size = Vector2i(1280,720);viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	shell = SHELL.instantiate();shell.session.directory = "user://character-panels-" + str(Time.get_ticks_usec());viewport.add_child(shell);await frames()
	shell.open_page("roster");await frames()
	var state: RefCounted = shell.session
	var before := snapshot()
	for id in state.characters:
		shell.inspect_character(id)
		await frames(1)
		var sheet: Control = shell.character_sheet
		var model: Dictionary = DETAIL.build(state.data,state.characters,id)
		expect(shell.page == "roster" and sheet.character_id == id,"inspection stays in formation context " + id)
		expect(label("CharacterName").text == state.characters[id].name,"stable identity " + id)
		if id == "JIA": expect(label("CharacterTitle").text == "主角","equal rarity and title displayed once")
		expect(label("character_ability_description_basic").text == model.basic.description,"actual basic projection " + id)
		expect(label("character_ability_description_manual_0").text == model.manual[0].description,"actual skill projection " + id)
		if id != "JIA": expect(label("character_preview") != null and not model.experience.available and model.experience.value == null,"unowned preview does not invent experience " + id)
		sheet.select_tab("profile");await frames(1)
		expect(label("CharacterBiography").text == PROFILE.find(id).biography and label("character_acquisition").text == state.characters[id].gate,"actual authored profile and gate " + id)
	expect(snapshot() == before,"all38 previews leave campaign/RNG/files unchanged")
	shell.close_character_sheet()
	state.data.owned.F03 = C.record("F03",5)
	state.data.owned.F03.hp = 100;state.data.owned.F03.mp = 21;state.data.owned.F03.xp = 23.75
	state.data.owned.F11 = C.record("F11",3)
	state.data.owned.N13 = C.record("N13",9999);state.data.owned.N13.dead = true;state.data.owned.N13.hp = 0
	state.data.party = ["F11","F03"]
	state.data.equipped.armor = "iron_armor"
	before = snapshot()
	var expected: Dictionary = DETAIL.build(state.data,state.characters,"F03")
	expect(expected.attribute_rows.size() == 7,"seven structured attribute rows")
	for row in expected.attribute_rows:
		expect(is_equal_approx(row.current,row.base + row.growth + row.owned + row.equipment),"exact decomposition " + row.key)
		expect(is_equal_approx(row.growth,float(C.GROWTH.get(row.key,0)) * 4),"actual cumulative growth " + row.key)
		if row.key == "regen": expect(is_equal_approx(row.owned,float(C.OWNED_CAPS.regen)),"fallen reserve contributes capped actual held bonus")
		if row.key == "armor": expect(row.equipment == 4,"actual shared armor contribution")
	expect(expected.experience.value == 23.75 and expected.experience.required == C.xp_required(5),"actual experience threshold and record")
	for dimensions in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
		viewport.size = dimensions;await frames()
		for fixture in ["preview","alive","dead"]:
			state.data.owned.F03.dead = fixture == "dead";state.data.owned.F03.hp = 0 if fixture == "dead" else 100
			var id := "M01" if fixture == "preview" else "F03"
			shell.inspect_character(id,"abilities");await frames()
			var sheet: Control = shell.character_sheet
			expect(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(sheet.panel.get_global_rect()),"sheet fits " + fixture + str(dimensions))
			expect(sheet.panel.size.x < dimensions.x and sheet.panel.size.y < dimensions.y,"context edges remain visible " + str(dimensions))
			expect(sheet.portrait.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED,"full portrait aspect preserved")
			expect(not sheet.portrait.get_global_rect().intersects(sheet.find_child("character_detail_panel",true,false).get_global_rect()),"art and text remain separated")
			expect(sheet.find_child("assign_0",true,false) == null and sheet.find_child("remove_auxiliary",true,false) == null,"inspection has no formation mutation buttons")
			if fixture != "preview": expect(label("character_support_state").text.contains("阵亡" if fixture == "dead" else "已配置"),"real support availability " + fixture)
			await capture(fixture + "-abilities-" + str(dimensions.x))
			if fixture == "alive" and dimensions.x == 960:
				(sheet.tabs.abilities as Button).grab_focus()
				for step in 3: await press(KEY_TAB)
				expect(viewport.gui_get_focus_owner() == sheet.scroll,"Tab reaches body scroll within modal loop")
				await press(KEY_HOME);expect(sheet.scroll.scroll_vertical == 0,"keyboard Home reaches beginning")
				await press(KEY_PAGEDOWN);expect(sheet.scroll.scroll_vertical > 0,"keyboard PageDown advances long abilities")
				await press(KEY_END)
				var bar: VScrollBar = sheet.scroll.get_v_scroll_bar()
				expect(sheet.scroll.scroll_vertical >= int(bar.max_value - bar.page) - 1,"keyboard End reaches last ability")
				await press(KEY_PAGEUP);expect(sheet.scroll.scroll_vertical < int(bar.max_value - bar.page),"keyboard PageUp returns through abilities")
			sheet.scroll.scroll_vertical = 100000;await frames();var old_scroll: int = sheet.scroll.scroll_vertical
			sheet.select_tab("growth");await frames()
			expect(sheet.find_child("character_attribute_table",true,false) != null and shell.modal == null,"growth is a structured local tab")
			if fixture == "alive":
				expect(label("character_experience").text.contains("23.75"),"real XP displayed")
				expect(label("character_current_resources").text.contains("100 / ") and label("character_stat_hp_title").text == "生命上限","current resource and effective maximum remain distinct")
				for row in expected.attribute_rows:
					var cell := label("character_stat_%s_current" % row.key)
					expect(cell != null and sheet.scroll.get_global_rect().encloses(cell.get_global_rect()),"numeric table row visible " + row.key)
			await capture(fixture + "-growth-" + str(dimensions.x))
			sheet.select_tab("profile");await frames();sheet.scroll.scroll_vertical = 100000;await frames()
			var ending := label("CharacterRelationship")
			expect(ending.get_global_rect().end.y <= sheet.scroll.get_global_rect().end.y + 1,"last authored profile paragraph reachable")
			await capture(fixture + "-profile-" + str(dimensions.x))
			sheet.select_tab("abilities");await frames()
			expect(sheet.scroll.scroll_vertical == old_scroll,"each tab restores its own reading position")
			shell.close_character_sheet();await frames(1)
	state.data.owned.F03.dead = false;state.data.owned.F03.hp = 100
	expect(snapshot() == before,"owned, fallen and unowned inspection never changes records/RNG/files")
	# The sheet API reuses one modal instead of replacing the underlying page.
	shell.inspect_character("F03","growth");await frames();var same: Control = shell.character_sheet
	shell.inspect_character("F07","profile");await frames()
	expect(shell.character_sheet == same and same.character_id == "F07" and same.active_tab == "profile","same inspection layer switches identity/tab")
	shell.close_character_sheet()
	shell.roster_filter = "all"
	shell.search_text = "女医者";shell.open_page("roster");await frames()
	expect(shell.find_child("character_F03",true,false) != null,"original title remains searchable")
	shell.search_text = "钱绮罗";shell.render();await frames()
	expect(shell.find_child("character_F04",true,false) != null,"named character remains searchable")
	shell.queue_free();await frames();viewport.queue_free();await frames();SETTINGS.save_comfort("reduced_motion",motion)
	print("CHRONICLE_CHARACTER_PANELS_SMOKE ","PASS" if failures == 0 else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)
