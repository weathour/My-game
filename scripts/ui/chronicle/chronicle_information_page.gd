extends RefCounted
const T := preload("res://scripts/ui/chronicle/chronicle_theme.gd")
const TEXT := preload("res://scripts/ui/chronicle/chronicle_menu_text.gd")

static func build(shell: Control, parent: VBoxContainer, kind: String) -> void:
	var scroll_content: VBoxContainer = shell.PAGES.scroll_column(parent, kind + "_scroll")
	var row := T.row(scroll_content)
	T.space(row)
	var reading := T.column(row)
	reading.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reading.custom_minimum_size.x = minf(880, maxf(260, shell.size.x - 80))
	reading.add_theme_constant_override("separation", 12)
	T.space(row)
	var content := TEXT.section(kind)
	reading.add_child(T.paragraph(TEXT.resolve(str(content.get("intro", ""))), T.LIGHT, 16 if shell.size.y < 650 else 17))
	for section in content.get("sections", []):
		reading.add_child(T.label(str(section.heading), 20 if shell.size.y < 650 else 22, T.GOLD, true))
		reading.add_child(T.paragraph(TEXT.resolve(str(section.body)), T.INK, 16 if shell.size.y < 650 else 17))
	for index in content.get("licenses", []).size():
		var item: Dictionary = content.licenses[index]
		var fold := T.column(reading)
		fold.add_theme_constant_override("separation", 8)
		var words := T.paragraph(str(item.body), T.MUTED, 15 if shell.size.y < 650 else 16)
		words.name = "about_license_body_" + str(index)
		words.visible = false
		var toggle: Button = shell.action(fold, "▸ " + str(item.name), func(): pass, "about_license_" + str(index))
		toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
		toggle.toggle_mode = true
		toggle.toggled.connect(func(expanded: bool):
			words.visible = expanded
			toggle.text = ("▾ " if expanded else "▸ ") + str(item.name))
		fold.add_child(words)
