extends RefCounted

static func show_error(owner: Node, text: String) -> void:
	preload("res://scripts/ui/ui_audio.gd").play("error")
	var dialog := AcceptDialog.new()
	dialog.title = "存档未完成"
	dialog.dialog_text = text
	dialog.ok_button_text = "返回"
	owner.add_child(dialog)
	dialog.visibility_changed.connect(func():
		if not dialog.visible:
			dialog.queue_free()
	)
	dialog.popup_centered(Vector2i(520, 220))

static func health_text(health: String) -> String:
	match health:
		"recoverable":
			return "主档无法读取，可以恢复上一个有效备份。"
		"corrupt":
			return "主档与备份均无法读取。原文件已保留，请恢复外部备份；不会自动新建覆盖。"
		"incompatible":
			return "此档案需要其他内容版本。原文件已保留，请使用兼容版本打开。"
	return "保存失败，请检查存储空间与文件权限后重试。"
