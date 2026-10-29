extends Control
## Read-only illustrated catalog. It never receives a campaign or save object.
signal closed
const CATALOG := preload("res://scripts/content/enemy_catalog.gd")
const STAGES := preload("res://scripts/content/stage_catalog.gd")
const ART := preload("res://scripts/ui/chronicle/battle_art.gd")
const MANIFEST := preload("res://scripts/ui/chronicle/enemy_visual_manifest.gd")
const RUNTIME := preload("res://scripts/battle/enemy_runtime.gd")
const T := preload("res://scripts/ui/chronicle/chronicle_theme.gd")
const BACKDROP := "res://assets/ui/chronicle/codex/ink-backdrop.png"
const CATEGORY_ORDER := ["ordinary", "elite", "boss", "other"]
const CATEGORY_LABELS := {"ordinary":"普通", "elite":"精英", "boss":"首领", "other":"异物"}
const CLIP_LABELS := {"idle":"待机", "move":"移动", "attack":"攻击", "special":"特殊动作", "hit":"受击", "slam":"重击", "command":"号令"}
const GOLD := Color("bdab7b")
const WORDS := Color("e4dfd1")
const MUTED := Color("aaa69b")
var stage_id := ""
var selected_id := ""
var stage_only := false
var selected_category := "ordinary"
var selected_clip := "idle"
var mode_key := "portrait"
var combat_open := false
var animation_paused := false
var entries: Array = []
var detail: VBoxContainer
var roster: VBoxContainer
var index_scroll: ScrollContainer
var preview: Node2D
var clock := 0.0
var portrait: TextureRect
var preview_clips: Array = []
var preview_bounds_cache: Dictionary = {}
var artwork_stage: Control
var animation_stage: Control
var category_row: HBoxContainer
var scope_row: HBoxContainer
var mode_row: HBoxContainer
var animation_controls: HBoxContainer
var content_row: HBoxContainer
var index_column: VBoxContainer
var text_scroll: ScrollContainer
var outer_margin: MarginContainer
var clip_choice: OptionButton
var pause_button: Button
var _closing := false
var _index_generation := 0

static func all_ids() -> Array:
	return CATALOG.ordinary_ids() + ["L00"] + CATALOG.elite_ids() + CATALOG.boss_ids() + CATALOG.derivative_ids()

static func stage_ids(id: String) -> Array:
	var config: Dictionary = STAGES.STAGES.get(id, {})
	var ids: Array = []
	for wave in config.get("waves", []):
		for key in wave.get("cycle", []):
			if not ids.has(key): ids.append(key)
	for key in config.get("field_elites", []):
		if not ids.has(key): ids.append(key)
	var boss := str(config.get("boss_definition", ""))
	if not boss.is_empty() and not ids.has(boss): ids.append(boss)
	return ids

static func category_for(value: Dictionary) -> String:
	if value.get("rank", "") in ["object", "proxy"] or value.get("params", {}).get("role", "") == "derivative": return "other"
	if value.get("rank", "") == "boss": return "boss"
	if value.get("rank", "") == "field_elite": return "elite"
	return "ordinary"

func _ready() -> void:
	name = "EnemyCodex"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("111210")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := TextureRect.new()
	if ResourceLoader.exists(BACKDROP): backdrop.texture = load(BACKDROP)
	elif FileAccess.file_exists(BACKDROP): backdrop.texture = ImageTexture.create_from_image(Image.load_from_file(BACKDROP))
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer_margin = MarginContainer.new()
	add_child(outer_margin)
	outer_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var page := T.column(outer_margin)
	page.add_theme_constant_override("separation", 14)
	var header := T.row(page)
	header.add_child(T.label("敌情图鉴", 25, WORDS, true))
	T.space(header)
	scope_row = T.row(header)
	scope_row.size_flags_horizontal = Control.SIZE_SHRINK_END
	header.add_child(_quiet("返回", _close, false, "codex_return"))
	page.add_child(_rule())
	content_row = T.row(page)
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	index_column = T.column(content_row)
	index_column.size_flags_horizontal = Control.SIZE_FILL
	index_column.add_theme_constant_override("separation", 12)
	category_row = T.row(index_column)
	category_row.add_theme_constant_override("separation", 0)
	var list_scroll := ScrollContainer.new()
	index_scroll = list_scroll
	list_scroll.name = "enemy_codex_index_scroll"
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.follow_focus = true
	index_column.add_child(list_scroll)
	roster = T.column(list_scroll)
	roster.add_theme_constant_override("separation", 3)
	text_scroll = ScrollContainer.new()
	text_scroll.name = "enemy_codex_detail_scroll"
	text_scroll.size_flags_horizontal = Control.SIZE_FILL
	text_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	text_scroll.follow_focus = true
	content_row.add_child(text_scroll)
	detail = T.column(text_scroll)
	detail.add_theme_constant_override("separation", 14)
	var art_column := T.column(content_row)
	art_column.add_theme_constant_override("separation", 10)
	artwork_stage = Control.new()
	artwork_stage.name = "enemy_artwork_stage"
	artwork_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	artwork_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	artwork_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_column.add_child(artwork_stage)
	portrait = TextureRect.new()
	portrait.name = "enemy_standing_portrait"
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	artwork_stage.add_child(portrait)
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	animation_stage = Control.new()
	animation_stage.name = "enemy_animation_preview"
	animation_stage.clip_contents = true
	animation_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	artwork_stage.add_child(animation_stage)
	animation_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	animation_stage.resized.connect(_fit_active_preview)
	var art_footer := T.row(art_column)
	mode_row = T.row(art_footer)
	mode_row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	T.space(art_footer)
	animation_controls = T.row(art_footer)
	animation_controls.size_flags_horizontal = Control.SIZE_SHRINK_END
	clip_choice = OptionButton.new()
	clip_choice.name = "enemy_preview_clip"
	clip_choice.custom_minimum_size = Vector2(112, 36)
	clip_choice.item_selected.connect(_select_clip)
	for state in ["normal", "hover", "pressed"]:
		var surface := T.box(Color("292820", .82) if state != "normal" else Color("151814", .84), Color("8d8063", .55), 10)
		surface.set_border_width_all(1)
		clip_choice.add_theme_stylebox_override(state, surface)
	clip_choice.add_theme_color_override("font_color", WORDS)
	clip_choice.add_theme_color_override("font_hover_color", GOLD)
	animation_controls.add_child(clip_choice)
	pause_button = _quiet("暂停", func():
		animation_paused = not animation_paused
		pause_button.text = "继续" if animation_paused else "暂停", false, "enemy_preview_pause")
	animation_controls.add_child(pause_button)
	resized.connect(_layout)
	stage_only = not stage_ids(stage_id).is_empty()
	var initial := stage_ids(stage_id) if stage_only else all_ids()
	if selected_id.is_empty() or selected_id not in initial: selected_id = str(initial[0])
	_layout()
	show_entry(selected_id)
	_focus_selection()

func _quiet(value: String, callback: Callable, selected: bool = false, node_name: String = "") -> Button:
	var button := T.quiet_button(value, callback, selected)
	if not node_name.is_empty(): button.name = node_name
	button.custom_minimum_size.y = 34
	button.add_theme_font_size_override("font_size", 16)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var fill := Color("353128", .5) if selected else Color("302f29", .38) if state in ["hover", "pressed"] else Color.TRANSPARENT
		var style := T.box(fill, Color.TRANSPARENT, 7)
		style.set_border_width_all(0)
		style.content_margin_top = 5
		style.content_margin_bottom = 5
		if selected: style.border_color = GOLD; style.border_width_bottom = 1
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", GOLD if selected else WORDS)
	button.add_theme_color_override("font_disabled_color", Color("696a62"))
	return button

func _rule() -> HSeparator:
	var line := HSeparator.new()
	var style := StyleBoxLine.new()
	style.color = Color(GOLD, .28)
	style.thickness = 1
	line.add_theme_stylebox_override("separator", style)
	return line

func _clear(parent: Node) -> void:
	for child in parent.get_children(): parent.remove_child(child); child.queue_free()

func _scope_ids() -> Array:
	return stage_ids(stage_id) if stage_only else all_ids()

func _build_roster() -> void:
	_index_generation += 1
	_clear(scope_row)
	for scope in [true, false]:
		var stage_scope: bool = scope
		var button := _quiet("本关" if stage_scope else "全部", func(): set_scope(stage_scope), stage_only == stage_scope, "codex_scope_stage" if stage_scope else "codex_scope_all")
		button.disabled = stage_scope and stage_ids(stage_id).is_empty()
		scope_row.add_child(button)
	_clear(category_row)
	var scope_ids := _scope_ids()
	for raw in CATEGORY_ORDER:
		var key := str(raw)
		var available := false
		for id in scope_ids:
			if category_for(CATALOG.definition(str(id))) == key: available = true; break
		var button := _quiet(CATEGORY_LABELS[key], func(): select_category(key), selected_category == key, "codex_category_" + key)
		button.disabled = not available
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 14)
		category_row.add_child(button)
	_clear(roster)
	entries = []
	for id in scope_ids:
		if category_for(CATALOG.definition(str(id))) == selected_category: entries.append(id)
	for raw in entries:
		var id := str(raw)
		var definition := CATALOG.definition(id)
		var button := _quiet(str(definition.name), func(): show_entry(id), selected_id == id, "enemy_codex_" + id)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.tooltip_text = str(definition.name)
		roster.add_child(button)

func set_scope(value: bool) -> void:
	stage_only = value and not stage_ids(stage_id).is_empty()
	var ids := _scope_ids()
	if selected_id not in ids:
		selected_id = str(ids[0])
	show_entry(selected_id)

func select_category(key: String) -> void:
	if key not in CATEGORY_ORDER: return
	for id in _scope_ids():
		if category_for(CATALOG.definition(str(id))) == key:
			show_entry(str(id))
			return

func show_entry(id: String) -> void:
	var focused_name := _focused_name()
	var value := CATALOG.definition(id)
	if value.is_empty(): return
	selected_id = id
	if stage_only and id not in stage_ids(stage_id): stage_only = false
	selected_category = category_for(value)
	if roster == null: return
	_build_roster()
	_clear(detail)
	var category := T.label(_rank_label(value), 14, GOLD)
	category.name = "enemy_entry_category"
	detail.add_child(category)
	var title := T.paragraph(str(value.name).replace("·", "\n"), WORDS, 29 if size.x >= 1100 else 25)
	title.name = "enemy_entry_title"
	title.add_theme_font_override("font", T.FONT.get_heading_font())
	detail.add_child(title)
	detail.add_child(_rule())
	var description := T.paragraph(str(value.description), Color("c7c3b8"), 16 if size.x >= 1100 else 15)
	description.name = "enemy_entry_description"
	description.add_theme_constant_override("line_spacing", 7)
	detail.add_child(description)
	detail.add_child(_quiet("战斗情报  " + ("▴" if combat_open else "▾"), func(): combat_open = not combat_open; show_entry(selected_id), combat_open, "enemy_combat_toggle"))
	if combat_open:
		var combat := T.column(detail)
		combat.name = "enemy_combat_details"
		combat.add_theme_constant_override("separation", 10)
		if value.rank != "proxy":
			combat.add_child(T.label("生命  %d" % int(value.hp), 15, WORDS))
			if float(value.damage) > 0: combat.add_child(T.label("攻击  %d" % int(value.damage), 15, WORDS))
			if float(value.speed) > 0: combat.add_child(T.label("移速  %d" % int(value.speed), 15, WORDS))
		combat.add_child(_rule())
		for line in value.counterplay: combat.add_child(T.paragraph(str(line), MUTED, 15))
	portrait.texture = ART.enemy_portrait(str(value.visual_id))
	_clear(animation_stage)
	preview = null
	_update_clip_options(str(value.visual_id))
	if mode_key == "moves": _create_preview(value)
	_update_modes()
	_sync_focus()
	_restore_focus.call_deferred(focused_name)
	_reveal_selected.call_deferred()

func set_mode(value: String) -> void:
	var focused_name := _focused_name()
	if value not in ["portrait", "moves"]: return
	mode_key = value
	if mode_key == "moves" and preview == null: _create_preview(CATALOG.definition(selected_id))
	_update_modes()
	_sync_focus()
	_restore_focus.call_deferred(focused_name)

func _update_modes() -> void:
	_clear(mode_row)
	for raw in ["portrait", "moves"]:
		var key := str(raw)
		mode_row.add_child(_quiet("立绘" if key == "portrait" else "招式", func(): set_mode(key), mode_key == key, "codex_mode_" + key))
	portrait.visible = mode_key == "portrait"
	animation_stage.visible = mode_key == "moves"
	animation_controls.visible = mode_key == "moves"

func _update_clip_options(visual_id: String) -> void:
	clip_choice.clear()
	preview_clips = MANIFEST.REQUIRED_CLIPS.duplicate()
	for key in MANIFEST.resolved(visual_id).get("clips", {}):
		if not preview_clips.has(key): preview_clips.append(key)
	for key in preview_clips: clip_choice.add_item(str(CLIP_LABELS.get(key, "招式")))
	if selected_clip not in preview_clips: selected_clip = "idle"
	clip_choice.select(preview_clips.find(selected_clip))

func _select_clip(index: int) -> void:
	if index < 0 or index >= preview_clips.size(): return
	selected_clip = str(preview_clips[index])
	clip_choice.select(index)
	if animation_paused and is_instance_valid(preview) and preview.has_method("preview"):
		preview.preview(selected_clip, clock)

func _create_preview(value: Dictionary) -> void:
	var runtime: RefCounted = RUNTIME.new(0, "melee", Vector2.ZERO)
	runtime.configure(value)
	preview = ART.create_enemy(runtime, stage_id if not stage_id.is_empty() else "B02")
	animation_stage.add_child(preview)
	_fit_active_preview()

func _rank_label(value: Dictionary) -> String:
	if value.rank == "proxy": return "协同演出" if not bool(value.params.get("targetable", true)) else "共血形体"
	return str({"ordinary":"普通", "heavy":"重型", "field_elite":"精英", "boss":"首领", "object":"可破坏物"}.get(value.rank, "异物"))

func _preview_bounds(visual_id: String) -> Rect2:
	if preview_bounds_cache.has(visual_id): return preview_bounds_cache[visual_id]
	var metadata := MANIFEST.resolved(visual_id)
	var anchor_data: Array = metadata.get("anchor_px", [0,0])
	var anchor := Vector2(anchor_data[0],anchor_data[1])
	var bounds := Rect2()
	var found := false
	for clip in metadata.get("clips", {}).values():
		var texture := MANIFEST.texture(visual_id, str(clip.get("file", "")))
		if texture == null: continue
		var image := texture.get_image()
		var frame_size_data: Array = clip.get("frame_size", [1,1])
		var frame_size := Vector2i(frame_size_data[0],frame_size_data[1])
		for index in int(clip.get("frames", 1)):
			var used := Rect2(image.get_region(Rect2i(Vector2i(index * frame_size.x,0),frame_size)).get_used_rect())
			if not used.has_area(): continue
			used.position -= anchor
			bounds = bounds.merge(used) if found else used
			found = true
	preview_bounds_cache[visual_id] = bounds
	return bounds

func _fit_active_preview() -> void:
	if not is_instance_valid(preview): return
	_fit_preview(animation_stage, preview, _preview_bounds(str(CATALOG.definition(selected_id).visual_id)))

func _fit_preview(stage: Control, actor: Node2D, bounds: Rect2) -> void:
	if not is_instance_valid(actor) or not bounds.has_area(): return
	var available := stage.size.max(Vector2.ONE) - Vector2.ONE * 24
	var factor := minf(available.x / bounds.size.x, available.y / bounds.size.y)
	actor.scale = Vector2.ONE * factor
	actor.position = (stage.size - bounds.size * factor) * .5 - bounds.position * factor

func _layout() -> void:
	if outer_margin == null: return
	var compact := size.x < 1100
	for side in ["left", "right"]: outer_margin.add_theme_constant_override("margin_" + side, 22 if compact else 34)
	for side in ["top", "bottom"]: outer_margin.add_theme_constant_override("margin_" + side, 18 if compact else 25)
	content_row.add_theme_constant_override("separation", 20 if compact else 30)
	index_column.custom_minimum_size.x = 188 if compact else 226
	text_scroll.custom_minimum_size.x = 200 if compact else 244
	_fit_active_preview()

func _sync_focus() -> void:
	var controls: Array[Control] = []
	for node in find_children("*", "BaseButton", true, false):
		if node is Control and node.is_visible_in_tree() and not node.disabled and node.focus_mode != Control.FOCUS_NONE: controls.append(node)
	for index in controls.size():
		var control: Control = controls[index]
		var previous: Control = controls[posmod(index - 1, controls.size())]
		var next: Control = controls[(index + 1) % controls.size()]
		control.focus_previous = control.get_path_to(previous)
		control.focus_next = control.get_path_to(next)
		control.focus_neighbor_left = control.focus_previous
		control.focus_neighbor_top = control.focus_previous
		control.focus_neighbor_right = control.focus_next
		control.focus_neighbor_bottom = control.focus_next

func _focused_name() -> String:
	var focus := get_viewport().gui_get_focus_owner()
	return str(focus.name) if focus != null and is_ancestor_of(focus) else ""

func _restore_focus(preferred: String) -> void:
	if _closing: return
	if preferred.is_empty() or preferred.begins_with("enemy_codex_"):
		_focus_selection()
		return
	var control := find_child(preferred, true, false) as Control
	if control != null and control.is_visible_in_tree(): control.grab_focus()
	else: _focus_selection()

func _reveal_selected() -> void:
	var generation := _index_generation
	if _closing or not is_inside_tree(): return
	# Container minimum sizes and row positions settle after rebuilding the index.
	await get_tree().process_frame
	await get_tree().process_frame
	if _closing or not is_inside_tree() or generation != _index_generation or index_scroll == null: return
	var button := roster.get_node_or_null("enemy_codex_" + selected_id) as Control
	if button != null: index_scroll.ensure_control_visible(button)

func _focus_selection() -> void:
	var button := roster.get_node_or_null("enemy_codex_" + selected_id) as Control
	if button != null: button.grab_focus()

func _close() -> void:
	if _closing: return
	_closing = true
	get_viewport().set_input_as_handled()
	closed.emit()

func _process(delta: float) -> void:
	if mode_key != "moves" or animation_paused: return
	clock += delta
	if is_instance_valid(preview):
		if preview.has_method("preview"): preview.preview(selected_clip, clock)
		elif preview.has_method("set_moving"): preview.set_moving(selected_clip == "move", Vector2.RIGHT)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE: _close(); return
		var focus := get_viewport().gui_get_focus_owner()
		if focus == null or not is_ancestor_of(focus): _focus_selection()

func _unhandled_key_input(_event: InputEvent) -> void:
	# All remaining keyboard input belongs to this modal, never the route beneath it.
	get_viewport().set_input_as_handled()
