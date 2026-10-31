extends "res://scripts/ui/chronicle/chronicle_card.gd"
## Native mouse drag and equivalent keyboard pickup share one campaign transaction.
const BASE_CARD := preload("res://scripts/ui/chronicle/chronicle_card.gd")
const DRAG_KIND := "chronicle_party_member"
const STATE_META := "party_drag_interaction"
var host: Control
var slot_index := -1 # -1 is the character library; -2 is the fixed protagonist slot.
var drop_hover := false

static func interaction(shell: Control) -> Dictionary:
	if not shell.has_meta(STATE_META): shell.set_meta(STATE_META, {"keyboard":{}, "suppress_until":0})
	return shell.get_meta(STATE_META)

static func carried(shell: Control) -> Dictionary:
	return interaction(shell).keyboard

static func suppressing_click(shell: Control) -> bool:
	var state := interaction(shell)
	return not state.keyboard.is_empty() or Time.get_ticks_msec() < int(state.suppress_until)

static func cancel(shell: Control) -> void:
	if not is_instance_valid(shell) or not shell.has_meta(STATE_META): return
	var viewport: Viewport = shell.get_viewport() if shell.is_inside_tree() else null
	if viewport != null and viewport.gui_is_dragging():
		var data: Variant = viewport.gui_get_drag_data()
		if data is Dictionary and data.get("kind") == DRAG_KIND and data.get("session") == shell.session.get_instance_id(): viewport.gui_cancel_drag()
	if shell.has_meta(STATE_META): shell.remove_meta(STATE_META)
	if is_instance_valid(shell.frame):
		for card in shell.frame.find_children("*", "Button", true, false): card.queue_redraw()

static func valid_drop(shell: Control, data: Variant, target: int) -> bool:
	if not is_instance_valid(shell) or not data is Dictionary or not shell.session.has_method("can_reposition_party"): return false
	if data.get("kind") != DRAG_KIND or data.get("session") != shell.session.get_instance_id() or data.get("page") != shell.page: return false
	if not data.get("id") is String or typeof(data.get("source_slot")) != TYPE_INT: return false
	return shell.page in ["roster", "preparation"] and shell.session.can_reposition_party(data.id, target, data.source_slot)

static func apply_drop(shell: Control, data: Variant, target: int) -> bool:
	if not valid_drop(shell, data, target): return false
	var id: String = data.id
	var source: int = data.source_slot
	carried(shell).clear()
	interaction(shell).suppress_until = Time.get_ticks_msec() + 180
	if not shell.session.reposition_party(id, target, source): return false
	shell.selected_character = id
	shell.queue_render()
	return true

func _ready() -> void:
	super._ready()
	mouse_exited.connect(func(): drop_hover = false; queue_redraw())

func _payload() -> Dictionary:
	if not is_instance_valid(host) or character_id.is_empty() or slot_index == -2 or not host.session.has_method("can_reposition_party"): return {}
	var source: int = host.session.data.party.find(character_id)
	if not host.session.can_reposition_party(character_id, 0, source): return {}
	return {"kind":DRAG_KIND, "id":character_id, "source_slot":source, "session":host.session.get_instance_id(), "page":host.page}

func _get_drag_data(_position: Vector2) -> Variant:
	var data := _payload()
	if data.is_empty(): return null
	carried(host).clear()
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var preview := BASE_CARD.new()
	preview.compact = true
	preview.configure(character_id, character_name, subtitle, "拖入辅助位", false, rarity)
	preview.size = Vector2(136, 176)
	preview.position = Vector2(-68, -42)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(preview)
	set_drag_preview(holder)
	get_viewport().gui_set_drag_description(character_name + "，拖入辅助位；拖回人物列表移出编队")
	return data

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	drop_hover = valid_drop(host, data, slot_index)
	queue_redraw()
	return drop_hover

func _drop_data(_position: Vector2, data: Variant) -> void:
	apply_drop(host, data, slot_index)

func _draw() -> void:
	if character_id.is_empty() and slot_index >= 0:
		var bounds := Rect2(Vector2.ZERO, size)
		draw_style_box(T.box(Color("15271f"), T.BORDER, 0), bounds)
		draw_rect(bounds.grow(-5), Color("63704c"), false, 1)
		var center := Vector2(size.x * .5, size.y * .40)
		draw_line(center - Vector2(13, 0), center + Vector2(13, 0), T.GOLD, 2)
		draw_line(center - Vector2(0, 13), center + Vector2(0, 13), T.GOLD, 2)
		draw_string(T.FONT.get_reading_font(), Vector2(6, size.y * .74), "拖入人物", HORIZONTAL_ALIGNMENT_CENTER, size.x - 12, 16, T.MUTED)
	else:
		super._draw()
	if drop_hover:
		draw_rect(Rect2(Vector2.ZERO, size).grow(-2), T.GOLD, false, 4)
	if not carried(host).is_empty() and carried(host).get("id") == character_id:
		draw_rect(Rect2(Vector2.ZERO, size).grow(-7), T.GOLD, false, 2)

func _exit_tree() -> void:
	if is_instance_valid(host) and host.has_meta(STATE_META):
		var state: Dictionary = host.get_meta(STATE_META)
		if not state.keyboard.is_empty():
			state.keyboard.clear()
			state.suppress_until = 0

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		drop_hover = false
		interaction(host).suppress_until = Time.get_ticks_msec() + 180
		queue_redraw()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or event.keycode != KEY_ESCAPE: return
	var viewport := get_viewport()
	if viewport.gui_is_dragging() and valid_drag_identity(viewport.gui_get_drag_data()):
		viewport.gui_cancel_drag()
		viewport.set_input_as_handled()
	elif not carried(host).is_empty() and valid_drag_identity(carried(host)):
		carried(host).clear()
		interaction(host).suppress_until = Time.get_ticks_msec() + 180
		viewport.set_input_as_handled()
		for card in host.frame.find_children("*", "Button", true, false): card.queue_redraw()

func valid_drag_identity(data: Variant) -> bool:
	return is_instance_valid(host) and data is Dictionary and data.get("kind") == DRAG_KIND and data.get("session") == host.session.get_instance_id()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_RIGHT or (event.button_index == MOUSE_BUTTON_LEFT and event.double_click)):
		if not character_id.is_empty():
			interaction(host).suppress_until = Time.get_ticks_msec() + 180
			host.inspect_character(character_id)
			accept_event()
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_SPACE:
		if carried(host).is_empty():
			interaction(host).keyboard = _payload()
			if not carried(host).is_empty(): accept_event(); queue_redraw()
		elif apply_drop(host, carried(host), slot_index): accept_event()
	elif event.keycode == KEY_ENTER and not carried(host).is_empty():
		apply_drop(host, carried(host), slot_index)
		accept_event()
