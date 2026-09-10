extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const HUD_SCENE := preload("res://scenes/hud.tscn")
const PLAYER_BLESSING_SKILL_STATE := preload("res://scripts/player/player_blessing_skill_state.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene

	var player = PLAYER_SCENE.instantiate()
	scene.add_child(player)
	await process_frame
	player.configure_story_loadout(["swordsman", "gunner", "mechanic"])
	player.active_role_index = 2
	player._update_active_role_state()
	for skill_id in ["tulip_turret", "mine", "emp_burst", "drone", "missile_volley"]:
		PLAYER_BLESSING_SKILL_STATE.force_unlock_skill(player, skill_id, 1)

	var hud = HUD_SCENE.instantiate()
	scene.add_child(hud)
	await process_frame
	await process_frame

	var bar = hud.get("combat_skill_bar")
	if bar == null:
		failures.append("hud.combat_skill_bar missing")
		_report()
		return

	# Simulate one live update like game_hud_flow.update_frame_hud does.
	hud.update_stats(player.get_stat_summary())
	await process_frame

	var order: Array = bar.get("switch_role_order")
	if order != ["swordsman", "gunner", "mechanic"]:
		failures.append("switch_role_order after update should follow team, got %s" % str(order))

	var portraits: Dictionary = bar.get("switch_cd_portraits")
	for role_id in ["swordsman", "gunner", "mechanic"]:
		if not portraits.has(role_id):
			failures.append("switch portrait missing for %s (layout %s)" % [role_id, str(bar.get("hud_layout"))])

	var rows: Array = bar.get("team_role_rows")
	if str(bar.get("hud_layout")) != "team_band":
		print("legacy layout: no team rows by design")
	elif rows.size() != 3:
		failures.append("team_role_rows should be 3, got %d" % rows.size())
	else:
		# active = mechanic (index 2) => rows should be [gunner, mechanic, swordsman]
		var expected := ["gunner", "mechanic", "swordsman"]
		for i in range(3):
			var data: Dictionary = rows[i].get("data", {})
			var rid := str(data.get("role_id", ""))
			if rid != expected[i]:
				failures.append("row %d should be %s, got %s" % [i, expected[i], rid])
		var active_row: Dictionary = rows[1]
		var slots: Array = active_row.get("slots", [])
		var slot_names: Array = []
		for slot_nodes in slots:
			slot_names.append(str((slot_nodes as Dictionary).get("skill_id", "")))
		print("active row slots: %s" % str(slot_names))
		var active_data: Dictionary = active_row.get("data", {})
		var cooldown_slots: Array = active_data.get("cooldown_slots", [])
		var names: Array = []
		for s in cooldown_slots:
			names.append(str((s as Dictionary).get("name", "")))
		print("active role cooldown slot names: %s" % str(names))

	# Report what the bar shows at init BEFORE any update (fresh bar).
	var hud2 = HUD_SCENE.instantiate()
	scene.add_child(hud2)
	await process_frame
	var bar2 = hud2.get("combat_skill_bar")
	var rows2: Array = bar2.get("team_role_rows")
	var init_ids: Array = []
	for r in rows2:
		init_ids.append(str((r as Dictionary).get("data", {}).get("role_id", "")))
	print("fresh bar rows before update: %s (layout=%s)" % [str(init_ids), str(bar2.get("hud_layout"))])
	var order2: Array = bar2.get("switch_role_order")
	print("fresh bar switch_role_order: %s" % str(order2))

	_report()


func _report() -> void:
	if failures.is_empty():
		print("HUD_INIT_PROBE_OK")
		quit(0)
	else:
		for f in failures:
			push_error(f)
		quit(1)
