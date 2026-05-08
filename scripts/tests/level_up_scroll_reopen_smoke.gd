extends SceneTree

const LEVEL_UP_UI_SCENE := preload("res://scenes/level_up_ui.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ui := LEVEL_UP_UI_SCENE.instantiate()
	root.add_child(ui)

	ui.show_menu("技能奖励 1", _make_options("first", 18))
	await process_frame
	await process_frame
	_check_scroll_range(ui, "first skill panel should be scrollable")

	ui.hide_ui()
	ui.show_menu("技能奖励 2", _make_options("second", 18))
	await process_frame
	await process_frame
	_check_scroll_range(ui, "second same-frame skill panel should stay scrollable")

	ui.queue_free()
	await process_frame
	if failures.is_empty():
		print("LEVEL_UP_SCROLL_REOPEN_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _make_options(prefix: String, count: int) -> Array:
	var options: Array = []
	for index in range(count):
		options.append({
			"id": "%s_%d" % [prefix, index],
			"title": "技能选项 %d" % [index + 1],
			"description": "用于验证连续奖励面板滚动条的长列表选项。",
			"preview_description": "滚动验证"
		})
	return options


func _check_scroll_range(ui: Node, failure_message: String) -> void:
	var card_list: Variant = ui.get("card_list")
	if card_list == null:
		failures.append("%s: missing card list" % failure_message)
		return
	var scroll_area: Variant = card_list.get("scroll_area")
	if scroll_area == null:
		failures.append("%s: missing scroll area" % failure_message)
		return
	var scroll_bar: VScrollBar = (scroll_area as ScrollContainer).get_v_scroll_bar()
	if scroll_bar == null or scroll_bar.max_value <= scroll_bar.page:
		failures.append("%s: scrollbar range max %.1f page %.1f" % [failure_message, scroll_bar.max_value if scroll_bar != null else 0.0, scroll_bar.page if scroll_bar != null else 0.0])
