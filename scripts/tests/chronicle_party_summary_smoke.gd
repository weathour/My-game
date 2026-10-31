extends SceneTree
const SERVICE := preload("res://scripts/campaign/campaign_service.gd")
const C := preload("res://scripts/content/combat_catalog.gd")
const BATTLE := preload("res://scripts/battle/battle_session.gd")
const SHELL := preload("res://scenes/chronicle/chronicle_shell.tscn")
const RARITY := preload("res://scripts/ui/chronicle/card_rarity.gd")
var failures := 0
var checks := 0
var viewport: SubViewport
var shell: Control
var capture_dir := ""

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_dir = arg.trim_prefix("--capture=")
	call_deferred("run")

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures += 1; push_error(message)

func frames(count: int = 8) -> void:
	for i in count: await process_frame

func capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	viewport.get_texture().get_image().save_png(capture_dir.path_join(name + ".png"))

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "test saves isolated")
	if failures: quit(1); return
	var state := SERVICE.new()
	state.directory = "user://party-summary-" + str(Time.get_ticks_usec())
	var summary: Dictionary = state.party_summary()
	expect(summary.attributes.is_empty() and summary.supports.is_empty(), "solo empty slots invent no passive/support")
	expect(summary.equipment.size() == 3, "all three default equipment effects visible")
	for id in state.characters:
		expect(RARITY.TIERS.has(state.characters[id].rarity), "explicit valid rarity " + id)
		if id.begins_with("N"): expect(state.characters[id].rarity == "common", "ordinary troops blue " + id)
	expect(state.characters.M03.kind == state.characters.M01.kind and state.characters.M03.rarity != state.characters.M01.rarity, "rarity independent of important-character flag")
	# Keep the original twelve-person numeric fixture stable as the content library grows.
	for id in ["JIA", "F11", "N01", "N04", "N07", "N13", "N16", "N17", "F03", "N18", "F07", "N14"]:
		state.data.owned[id] = C.record(id, 2)
	state.data.owned.N01.level = 5
	state.data.owned.N13.dead = true
	state.data.owned.N13.hp = 0
	state.data.party = ["F11", "N16"]
	state.data.inventory.append_array(["iron_armor", "long_spear", "frost_jade"])
	state.data.equipped.armor = "iron_armor"
	var before: Dictionary = state.data.duplicate(true)
	summary = state.party_summary()
	expect(state.data == before, "summary projection never mutates campaign")
	expect(is_equal_approx(summary.totals.attack, 4.0), "unselected reserve levels contribute to attack")
	expect(is_equal_approx(summary.totals.regen, 1.04), "fallen reserve retains owned mana regeneration")
	expect(is_equal_approx(summary.totals.armor, 4.24), "iron armor included exactly once with physician passive")
	expect(is_equal_approx(summary.totals.supply_mp, 0.14), "all supply bonuses included")
	expect(summary.supports.size() == 2 and summary.supports[0].id == "F11" and summary.supports[1].id == "N16", "only configured auxiliaries provide support")
	for key in ["attack", "armor", "speed", "regen"]:
		var effective := C.attributes("JIA", 2, C.owned_bonuses(state.data.owned), state.data.equipped)
		var base := C.attributes("JIA", 2)
		expect(is_equal_approx(effective[key] - base[key], summary.totals[key]), "table matches battle attribute: " + key)
	var battle := BATTLE.new({"attempt_id":"summary-test", "members":state.roster(), "characters":state.data.owned, "equipment":state.data.equipped, "stage":C.stage("B01"), "seed":91})
	battle.current().hp = 5
	battle.tick(0.001, Vector2.ZERO)
	var actual_heal: float = battle.current().hp - 5
	var healing_number := RegEx.new()
	healing_number.compile("恢复([0-9.]+)生命")
	var displayed_heal := healing_number.search(summary.supports[1].text)
	expect(actual_heal > 0 and displayed_heal != null and is_equal_approx(float(displayed_heal.get_string(1)), actual_heal), "displayed heal agrees with actual support cast")
	state.data.owned.N16.dead = true
	state.data.owned.N16.hp = 0
	summary = state.party_summary()
	expect(not summary.supports[1].active and summary.supports[1].text.contains("支援停止"), "fallen configured support is inactive")
	expect(is_equal_approx(summary.totals.supply_hp, .05), "fallen helper retains owned passive")
	state.data.owned.N16 = C.record("N16", 2)
	expect(state.assign("N17", 1), "normal assignment succeeds")
	summary = state.party_summary()
	expect(summary.supports[1].id == "N17", "changing auxiliary updates actual support")
	expect(state.equip("cloth_armor"), "armor change succeeds")
	expect(is_equal_approx(state.party_summary().totals.armor, .24), "removing armor removes only equipment armor")
	expect(state.equip("long_spear") and state.equip("frost_jade"), "weapon and enchant changes succeed")
	summary = state.party_summary()
	expect(summary.equipment[0].id == "long_spear" and summary.equipment[2].id == "frost_jade", "equipment table reflects all current slots")
	state.data.owned.F11.level += 1
	expect(is_equal_approx(state.party_summary().totals.regen, 1.19), "duplicate or XP level reflected immediately")
	viewport = SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.size = Vector2i(1280,720)
	root.add_child(viewport)
	shell = SHELL.instantiate()
	shell.session = state
	viewport.add_child(shell)
	await frames()
	state.data.current = "B02"
	state.data.available = ["B02"]
	shell.selected_character = "F11"
	for dimensions in [Vector2i(960,540), Vector2i(1280,720), Vector2i(1920,1080)]:
		viewport.size = dimensions
		await frames()
		for page in ["roster", "preparation"]:
			shell.open_page(page)
			await frames()
			(shell.find_child("party_summary_scroll", true, false) as ScrollContainer).scroll_vertical = 0
			await frames()
			var previous: Control
			for i in 3:
				var member := shell.find_child("prep_member_%d" % i, true, false) as Control
				expect(Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(member.get_global_rect()), "member fits " + str(dimensions))
				if previous != null: expect(member.global_position.x - previous.get_global_rect().end.x <= 16, "party slots stay clustered")
				previous = member
			var panel := shell.find_child("party_summary", true, false) as Control
			expect(panel.global_position.x > previous.get_global_rect().end.x, "summary occupies freed space on right")
			expect(Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(panel.get_global_rect()), "summary fits viewport")
			var scroll := shell.find_child("party_summary_scroll", true, false) as ScrollContainer
			expect(scroll.size.y >= 90, "summary has usable scroll area")
			expect(shell.find_child("party_bonus_regen", true, false) != null, "actual modifiers rendered")
			expect(shell.find_child("party_support_N17", true, false) != null, "actual auxiliary rendered")
			await capture(page + "-" + str(dimensions.x))
			scroll.scroll_vertical = 10000
			await frames()
			var gear := shell.find_child("party_equipment_accessory", true, false) as Control
			expect(gear.get_global_rect().end.y <= scroll.get_global_rect().end.y + 1, "last equipment effect reachable by scrolling")
			if page == "roster": await capture("effects-" + str(dimensions.x))
		state.data.pending = {"node":"B02", "candidates":["N01","F11","M01","N17","M03"], "picks":2, "selected":[], "extra":false}
		shell.open_page("reward")
		await frames()
		await capture("rarities-" + str(dimensions.x))
		expect(shell.find_child("reward_card_N01", true, false).rarity == "common", "reward blue common")
		expect(shell.find_child("reward_card_F11", true, false).rarity == "rare", "reward purple rare")
		expect(shell.find_child("reward_card_M01", true, false).rarity == "legendary", "reward gold legendary")
		state.data.pending = {}
	shell.queue_free()
	await frames()
	viewport.queue_free()
	await frames()
	print("CHRONICLE_PARTY_SUMMARY_SMOKE ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
