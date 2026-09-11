extends SceneTree

const TOOLTIP_TEXT_DECORATOR := preload("res://scripts/ui/components/tooltip_text_decorator.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(
		TOOLTIP_TEXT_DECORATOR.highlight_numbers("造成 600% 范围伤害").contains("[color=#FFB84D]600%[/color]"),
		"percent values should be highlighted with the number color"
	)
	_expect(
		TOOLTIP_TEXT_DECORATOR.highlight_numbers("冷却 14.5 秒").contains("[color=#FFB84D]14.5[/color] 秒"),
		"decimal numbers should be highlighted without swallowing the space before 秒"
	)
	_expect(
		TOOLTIP_TEXT_DECORATOR.highlight_numbers("每秒损失当前生命的 1%").contains("[color=#FFB84D]1%[/color]"),
		"single-digit percents should be highlighted"
	)
	_expect(
		TOOLTIP_TEXT_DECORATOR.highlight_numbers("无数字描述").find("[color") < 0,
		"text without numbers should gain no color tags"
	)
	_expect(
		TOOLTIP_TEXT_DECORATOR.highlight_numbers("已有[括号]文本").contains("[lb]括号]"),
		"square brackets in source text should be escaped before decoration"
	)
	_expect(
		TOOLTIP_TEXT_DECORATOR.highlight_numbers("") == "",
		"empty text should stay empty"
	)
	_expect(
		TOOLTIP_TEXT_DECORATOR.highlight_numbers("伤害 +15%", "#00FF00").contains("[color=#00FF00]+15%[/color]"),
		"a custom color should be honored"
	)

	if failures.is_empty():
		print("TOOLTIP_TEXT_DECORATOR_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
