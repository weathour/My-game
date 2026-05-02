extends RefCounted

# Handoff note:
# Character panel visibility and pause rules live here. main.gd remains the
# input entry point, while this flow owns whether the panel may open/close and
# how it affects pause state.

static func toggle_character_panel(main: Node) -> void:
	if main.character_panel == null:
		return
	if main.character_panel.visible:
		hide_character_panel(main)
		return
	if not can_show_character_panel(main):
		return
	show_character_panel(main)

static func can_show_character_panel(main: Node) -> bool:
	if main.character_panel == null or main.player == null:
		return false
	if main.get_tree().paused:
		return false
	if main.level_up_ui != null and main.level_up_ui.visible:
		return false
	if main.pause_menu != null and main.pause_menu.visible:
		return false
	if main.hud != null and main.hud.get("build_graph_panel") != null and bool(main.hud.get("build_graph_panel").get("visible")):
		return false
	return true

static func show_character_panel(main: Node) -> void:
	if not can_show_character_panel(main):
		return
	main.get_tree().paused = true
	main.character_panel.show_for_player(main.player)

static func hide_character_panel(main: Node) -> void:
	if main.character_panel == null:
		return
	main.character_panel.hide_panel()
	main.get_tree().paused = false
