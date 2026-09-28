extends SceneTree

const DEVELOPER_ACTIONS := preload("res://scripts/developer/developer_actions.gd")
const DEVELOPER_OPTION_PROVIDER := preload("res://scripts/developer/developer_option_provider.gd")
const HUD := preload("res://scripts/hud.gd")
const RUAN_STONE_SYSTEM := preload("res://scripts/player/ruan_stone_system.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := MainStub.new()
	root.add_child(main)
	var player := PlayerStub.new()
	main.player = player
	main.add_child(player)

	var options := DEVELOPER_OPTION_PROVIDER.get_ruan_stone_options(player)
	var expected_option_count := 2 + RUAN_STONE_SYSTEM.STONE_IDS.size() * 3
	assert(options.size() == expected_option_count)
	assert(str(options[0].get("title", "")).contains("当前 0"))
	assert(DEVELOPER_ACTIONS.apply_ruan_stone_action(main, "bones:add:100"))
	assert(player.get_developer_bone_count() == 100)
	assert(DEVELOPER_ACTIONS.apply_ruan_stone_action(main, "level:set:thunder:10"))
	assert(player.get_ruan_stone_level("thunder") == 10)
	assert(DEVELOPER_ACTIONS.apply_ruan_stone_action(main, "level:add:thunder:1"))
	assert(player.get_ruan_stone_level("thunder") == 11)
	assert(DEVELOPER_ACTIONS.apply_ruan_stone_action(main, "equip:thunder"))
	assert(player.get_equipped_ruan_stone() == "thunder")
	assert(main.refresh_count == 4)
	assert(main.save_count == 0)
	assert(not DEVELOPER_ACTIONS.apply_ruan_stone_action(main, "equip:frost"))

	var hud := HUD.new()
	root.add_child(hud)
	await process_frame
	var developer_root := Control.new()
	hud.add_child(developer_root)
	hud._build_developer_panel(developer_root)
	var panel: PanelContainer = hud.get("developer_panel")
	hud.set_developer_ruan_stone_options(DEVELOPER_OPTION_PROVIDER.get_ruan_stone_options(player))
	assert((panel.get("ruan_stone_list") as VBoxContainer).get_child_count() == expected_option_count)
	hud.developer_ruan_stone_action_requested.connect(func(action_id: String): hud.set_meta("emitted_action", action_id))
	panel._on_ruan_stone_button_pressed("ruan_stone:equip:thunder")
	assert(str(hud.get_meta("emitted_action", "")) == "equip:thunder")

	var unsupported_main := MainStub.new()
	unsupported_main.player = Node.new()
	unsupported_main.add_child(unsupported_main.player)
	root.add_child(unsupported_main)
	assert(not DEVELOPER_ACTIONS.apply_ruan_stone_action(unsupported_main, "bones:add:100"))
	assert(unsupported_main.refresh_count == 0)

	print("DEVELOPER_RUAN_STONE_SMOKE_OK")
	quit(0)


class MainStub:
	extends Node

	var player: Node
	var refresh_count := 0
	var save_count := 0

	func _refresh_hud() -> void:
		refresh_count += 1

	func _save_run_state() -> void:
		save_count += 1


class PlayerStub:
	extends Node

	var bones := 0
	var levels := {"thunder": 0, "frost": 0, "poison": 0, "flame": 0, "fury": 0}
	var equipped := ""

	func get_developer_bone_count() -> int:
		return bones

	func set_developer_bone_count(value: int) -> void:
		bones = max(0, value)

	func get_ruan_stone_level(stone_id: String) -> int:
		return int(levels.get(stone_id, 0))

	func set_developer_ruan_stone_level(stone_id: String, level: int) -> void:
		if levels.has(stone_id):
			levels[stone_id] = max(0, level)

	func get_equipped_ruan_stone() -> String:
		return equipped

	func equip_developer_ruan_stone(stone_id: String) -> bool:
		if get_ruan_stone_level(stone_id) <= 0:
			return false
		equipped = stone_id
		return true
