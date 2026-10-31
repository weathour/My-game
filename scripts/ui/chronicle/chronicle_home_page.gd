extends RefCounted
## Title actions share a single compact two-column rhythm; artwork keeps its own space.
const NAV := preload("res://scripts/ui/chronicle/chronicle_menu_navigation.gd")
const T := preload("res://scripts/ui/chronicle/chronicle_theme.gd")
const TEXT := preload("res://scripts/ui/chronicle/chronicle_menu_text.gd")

static func build(shell: Control) -> void:
	var compact: bool = shell.size.y < 650
	shell.portrait(shell.body, shell.size.x * .43)
	var row := T.row(shell.page_margin())
	T.space(row)
	var panel := T.panel(row, false, 18 if compact else 26)
	panel.name = "home_menu_panel"
	panel.custom_minimum_size.x = 420 if compact else clampf(shell.size.x * .40, 470, 560)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var column := T.column(panel)
	column.add_theme_constant_override("separation", 7 if compact else 12)
	var header := T.column(column)
	header.add_theme_constant_override("separation", 3 if compact else 5)
	header.add_child(T.label(TEXT.text("home", "eyebrow"), 13 if compact else 15, T.MUTED))
	header.add_child(T.label(TEXT.text("home", "title"), 40 if compact else 52, T.INK, true))
	header.add_child(T.paragraph(TEXT.text("home", "description_compact" if compact else "description"), T.INK, 14 if compact else 17))
	column.add_child(HSeparator.new())
	var focus_rows: Array = []
	var automatic: Dictionary = shell.session.read_slot("auto")
	if not automatic.is_empty():
		var resume: Button = _button(shell, column, "continue", shell.resume, "continue_campaign", true)
		resume.custom_minimum_size.y = 42 if compact else 50
		focus_rows.append([resume])
	var start := T.row(column)
	start.add_theme_constant_override("separation", 10)
	var new_button := _button(shell, start, "new", shell.new_campaign, "new_campaign", automatic.is_empty())
	var load_button: Button = _button(shell, start, "load", func(): shell.open_page("saves"), "home_load")
	load_button.disabled = shell.readable_save_slots().is_empty()
	focus_rows.append([new_button, load_button])
	load_button.tooltip_text = TEXT.text("home", "no_saves") if load_button.disabled else TEXT.text("saves", "description_readonly")
	var extras := T.row(column)
	extras.add_theme_constant_override("separation", 10)
	var music := _button(shell, extras, "music", shell.open_music, "music_room")
	var codex := _button(shell, extras, "codex", shell.open_enemy_codex, "home_codex")
	focus_rows.append([music, codex])
	var system := T.row(column)
	system.add_theme_constant_override("separation", 10)
	var world := _button(shell, system, "world", func(): shell.open_page("world"), "inspect_world")
	var settings := _button(shell, system, "settings", func(): shell.open_page("settings"), "home_settings")
	focus_rows.append([world, settings])
	column.add_child(HSeparator.new())
	var footer := T.row(column)
	footer.add_theme_constant_override("separation", 8)
	var help := _button(shell, footer, "help", func(): shell.open_page("help"), "home_help", false, true)
	var about := _button(shell, footer, "about", func(): shell.open_page("about"), "home_about", false, true)
	var quit := _button(shell, footer, "quit", shell.request_quit, "home_quit", false, true)
	focus_rows.append([help, about, quit])
	NAV.wire(focus_rows)
	if load_button.disabled:
		var empty := T.label(TEXT.text("home", "no_saves"), 12 if compact else 13, T.MUTED)
		empty.name = "home_no_saves"
		column.add_child(empty)

static func _button(shell: Control, parent: Node, key: String, callback: Callable, id: String, primary: bool = false, small: bool = false) -> Button:
	var button: Button = shell.action(parent, TEXT.text("home", key), callback, id, primary)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = (34 if small else 38) if shell.size.y < 650 else (40 if small else 46)
	button.add_theme_font_size_override("font_size", (14 if small else 16) if shell.size.y < 650 else (15 if small else 18))
	return button
