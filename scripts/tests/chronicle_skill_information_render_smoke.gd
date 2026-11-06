extends SceneTree
## Actual pointer/keyboard paths. No mouse-enter or pressed signal is emitted by this test.
const VIEW := preload("res://scripts/ui/chronicle/battle_view.gd")
const C := preload("res://scripts/content/combat_catalog.gd")
const INFO := preload("res://scripts/content/skill_information.gd")
const DATA := preload("res://scripts/tests/chronicle_skill_information_smoke.gd")
const SETTINGS := preload("res://scripts/shared/settings.gd")
const SHELL := preload("res://scenes/chronicle/chronicle_shell.tscn")
var checks := 0
var failures := 0
var viewport: SubViewport
var container: SubViewportContainer
var view: Control
var shell: Control
var definitions := {}
var capture_dir := ""
var quick := false
var pointer := Vector2.ZERO

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):capture_dir=arg.trim_prefix("--capture=")
		if arg=="--quick":quick=true
	if DisplayServer.get_name()!="headless":DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	call_deferred("run")

func expect(value: bool,label: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(label)

func frames(count: int = 3) -> void:
	for index in count:await process_frame

func press(code: int,target: Viewport = null) -> void:
	var surface: Viewport = viewport if target==null else target
	var event := InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true
	surface.push_input(event);await frames(2)
	event=event.duplicate();event.pressed=false;surface.push_input(event);await frames(2)

func move_mouse(point: Vector2) -> void:
	var event := InputEventMouseMotion.new();event.position=point;event.global_position=point;event.relative=point-pointer;pointer=point
	viewport.push_input(event)

func capture(label: String) -> void:
	if capture_dir.is_empty():return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	viewport.get_texture().get_image().save_png(capture_dir.path_join(label+".png"))

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"),"isolated settings and saves")
	if failures:quit(1);return
	var motion := SETTINGS.comfort_enabled("reduced_motion");var layout := SETTINGS.load_hud_layout()
	SETTINGS.save_comfort("reduced_motion",true)
	viewport=SubViewport.new();viewport.size=Vector2i(1280,720);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.gui_embed_subwindows=true
	# This is an independently addressed GUI viewport. A live container would
	# also forward the physical desktop pointer over the injected test pointer.
	root.add_child(viewport)
	for person in JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chronicle/characters.json")):definitions[person.id]=person
	for dimensions in ([Vector2i(960,540)] if quick else [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]):
		viewport.size=dimensions
		if container!=null:container.size=Vector2(dimensions);DisplayServer.window_set_size(dimensions)
		for selected_layout in ([SETTINGS.HUD_LAYOUT_SIMPLE] if quick else [SETTINGS.HUD_LAYOUT_SIMPLE,SETTINGS.HUD_LAYOUT_TEAM_BAND]):
			await mount_battle()
			view.hud.set_layout(selected_layout);view.refresh();await frames(8)
			await check_hover(selected_layout,dimensions)
			await check_keyboard(selected_layout,dimensions)
			view.queue_free();await frames(4);view=null
	if not quick:await check_character_and_reward()
	if is_instance_valid(shell):shell.queue_free()
	await frames();viewport.queue_free()
	if container!=null:container.queue_free()
	await frames();await create_timer(.3).timeout
	SETTINGS.save_comfort("reduced_motion",motion);SETTINGS.save_hud_layout(layout)
	print("CHRONICLE_SKILL_INFORMATION_RENDER_SMOKE ","PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)

func mount_battle() -> void:
	var ids: Array = ["JIA","F11","N07"];var records := {}
	for id in ids:records[id]=C.record(id,10)
	var stage := C.stage("B02");stage.boss_time=100000.0;stage.boss_kills=100000
	view=VIEW.new();view.setup({"attempt_id":"skill-info-input","members":ids,"characters":records,"equipment":{"weapon":"plain_blade","armor":"cloth_armor","accessory":"ember_seal"},"stage":stage,"seed":61106,"node":{"id":"B02","name":"技能查阅输入验证"}},definitions)
	viewport.add_child(view);view.set_physics_process(false);await frames()
	var foe: RefCounted = view.battle.director.spawn("E01",view.battle.position+Vector2(80,0));foe.hp=100000;foe.max_hp=100000;view.battle.enemies.append(foe);view.battle.spatial.rebuild(view.battle.enemies)
	view.canvas.refresh(false);view.refresh();move_mouse(Vector2(8,8));await frames()

func hit(layout: String,id: String,slot: int) -> Control:
	var name := "manual_skill_hit_%d"%slot if layout==SETTINGS.HUD_LAYOUT_SIMPLE else "manual_skill_hit_%d_%d"%[view.battle.members.find(id),slot]
	return view.hud.find_child(name,true,false) as Control

func hover(control: Control) -> void:
	expect(control!=null and control.is_visible_in_tree(),"real visible skill pointer target")
	if control==null:return
	move_mouse(control.get_global_rect().get_center());await frames(1)
	if view.skill_tooltip.anchor!=control:
		var hovered: Control = viewport.gui_get_hovered_control()
		print("HOVER_ROUTE ",{"requested":str(control.get_path()),"rect":control.get_global_rect(),"hovered":str(hovered.get_path()) if hovered!=null else "null","pointer":viewport.get_mouse_position()})
	expect(view.skill_tooltip.anchor==control,"actual pointer motion enters the intended hit Control")
	if view.skill_tooltip.elapsed<.25:expect(not view.skill_tooltip.panel.visible,"hover waits for its delay")
	var first_frames_fit := true
	var delay := create_timer(.34)
	while delay.time_left>0:
		await RenderingServer.frame_post_draw
		if view.skill_tooltip.panel.visible:
			var painted_rect: Rect2 = view.skill_tooltip.panel.get_global_rect()
			if not Rect2(Vector2.ZERO,Vector2(viewport.size)).encloses(painted_rect):
				if first_frames_fit:print("TOOLTIP_FIRST_PAINT ",{"rect":painted_rect,"viewport":viewport.size,"minimum":view.skill_tooltip.panel.get_combined_minimum_size(),"elapsed":view.skill_tooltip.elapsed,"anchor":control.get_global_rect()})
				first_frames_fit=false
	await frames()
	expect(first_frames_fit,"every visible delayed-hover frame fits its viewport")
	expect(view.skill_tooltip.panel.visible,"delayed hover is actually visible")

func check_hover(layout: String,dimensions: Vector2i) -> void:
	var b: RefCounted = view.battle
	var before := DATA.snapshot(b)
	await hover(hit(layout,"JIA",1))
	var tip: Control = view.skill_tooltip
	expect(tip.current_model.ability_id=="jia_break" and tip.current_model.character_id=="JIA","hover uses exact current J/K ability")
	expect(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(tip.panel.get_global_rect()),"hover panel fits viewport "+layout+str(dimensions))
	expect(tip.summary.get_global_transform().get_scale().is_equal_approx(Vector2.ONE) and tip.panel.size.x>=320,"tooltip avoids scaled HUD typography")
	var panel_id: int = tip.panel.get_instance_id();var label_id: int = tip.summary.get_instance_id();var count := tip.find_children("*","",true,false).size()
	await create_timer(.35).timeout
	expect(tip.panel.get_instance_id()==panel_id and tip.summary.get_instance_id()==label_id and tip.find_children("*","",true,false).size()==count,"10Hz refresh reuses nodes")
	expect(DATA.snapshot(b)==before,"real hover does not pay/cast/aim/tick or write battle records")
	await capture("%d-%s-hover-JIA-K"%[dimensions.x,layout])
	b.active=1;view.refresh();await frames(5);await create_timer(.15).timeout
	if layout==SETTINGS.HUD_LAYOUT_SIMPLE:expect(tip.current_model.character_id=="F11","switch updates same simple HUD anchor")
	else:expect(tip.current_model.character_id=="JIA" and tip.current_model.state=="inactive","team anchor remains bound to its actual member after switch")
	await hover(hit(layout,"F11",0));expect(tip.current_model.ability_id=="emma_frost","F11 hover follows switched/member context")
	var tooltip_rect: Rect2 = tip.panel.get_global_rect()
	if not Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(tooltip_rect):print("TOOLTIP_BOUNDS ",{"layout":layout,"dimensions":dimensions,"rect":tooltip_rect,"minimum":tip.panel.get_combined_minimum_size(),"tooltip_size":tip.size,"anchor":tip.anchor.get_global_rect()})
	expect(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(tooltip_rect),"long echo conditions fit viewport "+layout+str(dimensions))
	await capture("%d-%s-hover-F11-J"%[dimensions.x,layout])
	b.active=2;view.refresh();await frames(5);await hover(hit(layout,"N07",1))
	expect(tip.current_model.state=="missing" and not tip.current_model.present,"unassigned K is visibly missing")
	move_mouse(Vector2(8,8));await frames(3);expect(not tip.panel.visible,"pointer exit closes tooltip")
	b.active=0;view.refresh();await frames(5);await hover(hit(layout,"JIA",0))
	await press(KEY_ESCAPE)
	expect(b.paused and not tip.panel.visible,"Esc pause hides active hover")
	await press(KEY_ESCAPE);expect(not b.paused,"second Esc resumes from ordinary pause")
	move_mouse(Vector2(8,8));await frames()

func select_keyboard(option: OptionButton,index: int) -> void:
	expect(viewport.gui_get_focus_owner()==option,"keyboard has focused intended selector")
	await press(KEY_ENTER)
	var popup := option.get_popup()
	expect(popup.visible,"Enter opens actual OptionButton popup")
	# PopupMenu's supported arrow navigation is relative to its real focused
	# item. Home is not assumed to implement a menu reset on this Godot build.
	var origin := popup.get_focused_item()
	expect(origin>=0,"opened popup has a genuine focused item")
	if origin<0:origin=option.selected
	for step in absi(index-origin):await press(KEY_DOWN if index>origin else KEY_UP)
	await press(KEY_ENTER)
	if option.selected!=index:print("POPUP_ROUTE ",{"selected":option.selected,"wanted":index,"visible":popup.visible,"focused_item":popup.get_focused_item()})
	expect(option.selected==index,"keyboard popup selects actual item")

func check_keyboard(layout: String,dimensions: Vector2i) -> void:
	var b: RefCounted = view.battle
	b.active=0;view.refresh();await frames()
	await press(KEY_ESCAPE);expect(b.paused,"Esc enters pause menu")
	await press(KEY_TAB)
	expect(viewport.gui_get_focus_owner().name=="battle_skill_information","Tab reaches skill information from resume")
	var paused := DATA.snapshot(b)
	await press(KEY_ENTER)
	expect(view.pause_skills_open and b.paused,"Enter opens read-only inspector while paused")
	var inspector: Control = view.overlay
	expect(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(inspector.panel.get_global_rect()),"inspector fits viewport")
	expect(inspector.current_model.ability_id=="jia_sweep","inspector starts on current J")
	await press(KEY_ENTER)
	expect(inspector.member_choice.get_popup().visible,"keyboard opens member popup before cancellation")
	await press(KEY_ESCAPE)
	expect(not inspector.member_choice.get_popup().visible and view.pause_skills_open and b.paused,"popup Esc closes only its menu and preserves paused inspector")
	await select_keyboard(inspector.member_choice,1)
	expect(inspector.current_model.character_id=="F11","keyboard changes character without battle switch")
	await press(KEY_TAB)
	var choice := -1
	for index in inspector.entries.size():
		if inspector.entries[index].slot=="manual_k":choice=index
	expect(choice>=0,"K explanation is selectable")
	await select_keyboard(inspector.ability_choice,choice)
	expect(inspector.current_model.ability_id=="emma_star" and inspector.current_model.state=="inactive","keyboard shows real off-field K state")
	await press(KEY_TAB);await press(KEY_TAB)
	var expand: Button = inspector.find_child("battle_skill_expand",true,false)
	var details: Control = inspector.find_child("battle_skill_details",true,false)
	expect(expand!=null and details!=null and not details.visible,"expanded boundaries begin collapsed")
	if expand!=null and details!=null:
		expect(viewport.gui_get_focus_owner()==expand,"Tab reaches actual detail expander")
		await press(KEY_ENTER);expect(details.visible,"keyboard expands details")
		await press(KEY_TAB);expect(viewport.gui_get_focus_owner()==details,"expanded details join focus loop")
		await press(KEY_END)
	await capture("%d-%s-paused-keyboard-F11-K"%[dimensions.x,layout])
	var before_nodes: Array = inspector.body.get_children().map(func(child: Node):return child.get_instance_id())
	await create_timer(.25).timeout
	expect(inspector.body.get_children().map(func(child: Node):return child.get_instance_id())==before_nodes and DATA.snapshot(b)==paused,"pause inspection preserves clocks/intent/MP/CD/targets/records and node identity")
	await press(KEY_ESCAPE)
	expect(not view.pause_skills_open and b.paused and viewport.gui_get_focus_owner().name=="battle_skill_information","Esc returns to pause with entry focus and remains paused")
	await press(KEY_TAB);expect(viewport.gui_get_focus_owner().name=="battle_audio_settings","keyboard can still reach existing audio settings")
	var settings_before := FileAccess.get_file_as_bytes(SETTINGS.SETTINGS_PATH)
	await press(KEY_ENTER);expect(view.pause_audio_open and b.paused and view.find_child("audio_channels_scroll",true,false)!=null,"existing audio page still opens from pause")
	await press(KEY_ESCAPE)
	expect(not view.pause_audio_open and b.paused and FileAccess.get_file_as_bytes(SETTINGS.SETTINGS_PATH)==settings_before,"audio read-only visit returns without writing settings/resuming")
	await press(KEY_ESCAPE)
	expect(not b.paused and b._skill_intents.is_empty() and b._switch_intent==0,"final Esc resumes without hidden attack or switch intents")

func campaign_snapshot() -> Dictionary:
	var files := {}
	if DirAccess.dir_exists_absolute(shell.session.directory):
		for name in DirAccess.get_files_at(shell.session.directory):files[name]=FileAccess.get_file_as_bytes(shell.session.directory.path_join(name))
	return {"data":shell.session.data.duplicate(true),"rng":shell.session.reward_rng.state,"files":files}

func check_character_and_reward() -> void:
	viewport.size=Vector2i(1280,720)
	if container!=null:container.size=Vector2(1280,720);DisplayServer.window_set_size(Vector2i(1280,720))
	shell=SHELL.instantiate();shell.session.directory="user://skill-information-characters";viewport.add_child(shell);await frames(6)
	shell.open_page("roster");await frames()
	var before := campaign_snapshot()
	for id in C.IDS:
		shell.inspect_character(id,"abilities");await frames(1)
		var sheet: Control = shell.character_sheet
		var overview: Label = sheet.find_child("character_playstyle_summary",true,false)
		expect(overview!=null and overview.text==INFO.character(id).overview,"all38 real sheets use complete same-source overview "+id)
		var manual_k: Control = sheet.find_child("character_ability_manual_1",true,false)
		if C.definition(id).manual.size()==1:expect(manual_k!=null and manual_k.text=="K · 未配备" and sheet.find_child("character_ability_description_manual_1",true,false)==null,"unassigned K has explicit placeholder "+id)
		for key in ["basic","manual_0","manual_1","support","trait"]:
			var details: Control = sheet.find_child("character_ability_details_"+key,true,false)
			if details!=null:expect(not details.visible,"all details begin folded after changing character "+id+key)
		shell.close_character_sheet(false);await frames(1)
	expect(campaign_snapshot()==before,"all character reading preserves campaign/RNG/files")
	# Reward browsing is distinct from selecting or claiming the existing draft.
	var state: RefCounted = shell.session
	state.data.current="B01";state.data.available=["B01"];state.data.pending={"node":"B01","candidates":["N01","N04","N07","N13","N16"],"selected":["N01"],"picks":2,"extra":false}
	shell.reward_focus="N07";shell.open_page("reward");await frames()
	var button: Button = shell.find_child("reward_details",true,false)
	expect(button!=null and shell.find_child("reward_playstyle_summary",true,false)!=null and shell.find_child("reward_support_summary",true,false)!=null,"reward uses overview/support and real details entry")
	button.grab_focus();before=campaign_snapshot();await press(KEY_ENTER)
	expect(is_instance_valid(shell.character_sheet) and shell.character_sheet.character_id=="N07","actual reward keyboard button opens same character sheet")
	await press(KEY_ESCAPE);await frames()
	expect(not is_instance_valid(shell.character_sheet) and viewport.gui_get_focus_owner()==button and campaign_snapshot()==before,"Esc restores reward_details focus with candidates/selected/picks/owned/RNG/files unchanged")
	await capture("reward-details-return")
	# Once reading is complete, exercise the existing intentional reward action.
	var rng_before: int = state.reward_rng.state
	var owned_before: Dictionary = state.data.owned.duplicate(true)
	var card: Button = shell.find_child("reward_card_N07",true,false)
	card.grab_focus();await press(KEY_ENTER);await frames()
	expect(state.data.pending.selected==["N01","N07"],"actual reward card still selects after closing information")
	var claim: Button = shell.find_child("reward_claim",true,false)
	expect(claim!=null and not claim.disabled,"normal claim is enabled at the exact pick count")
	claim.grab_focus();await press(KEY_ENTER);await frames()
	expect(state.data.pending.is_empty() and "B01" in state.data.completed,"actual confirmation still commits reward and advances its node")
	for id in ["N01","N07"]:
		expect(state.data.owned.has(id) and state.data.owned[id].level==int(owned_before.get(id,{}).get("level",0))+1,"only intentional selected reward grants its card "+id)
	expect(state.reward_rng.state==rng_before,"reading and claiming fixed candidates do not redraft RNG")
