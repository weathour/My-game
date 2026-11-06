extends Control
## One unscaled, read-only hover surface for either battle HUD composition.
const INFO := preload("res://scripts/content/skill_information.gd")
const T := preload("res://scripts/ui/chronicle/chronicle_theme.gd")
const HOVER_DELAY := 0.25
const REFRESH_INTERVAL := 0.1
var battle: RefCounted
var anchor: Control
var panel: PanelContainer
var heading: Label
var category: Label
var summary: Label
var trigger: Label
var conditions: Label
var facts: Label
var state: Label
var hint: Label
var elapsed := 0.0
var refresh_remaining := 0.0
var last_signature := ""
var current_model: Dictionary = {}
var _placement_queued := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = T.panel(self, true, 13, false)
	panel.name = "battle_skill_tooltip_panel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := T.column(panel)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 6)
	heading = _line(column, "battle_skill_tooltip_title", 18, T.LIGHT)
	category = _line(column, "battle_skill_tooltip_category", 12, T.MUTED)
	summary = _line(column, "battle_skill_tooltip_summary", 14, T.LIGHT)
	trigger = _line(column, "battle_skill_tooltip_trigger", 12, T.MUTED)
	conditions = _line(column, "battle_skill_tooltip_conditions", 13, T.LIGHT)
	facts = _line(column, "battle_skill_tooltip_facts", 13, T.GOLD)
	state = _line(column, "battle_skill_tooltip_state", 13, T.GOLD)
	hint = _line(column, "battle_skill_tooltip_hint", 12, T.MUTED)
	hint.text = INFO.ui("hover_hint")
	# Establish the wrap width before the first hover. A narrow initial label
	# width can otherwise leave a stale, very tall container minimum.
	panel.size = Vector2(_panel_width(),0)
	resized.connect(_queue_place)
	panel.minimum_size_changed.connect(_queue_place)
	panel.hide()
	set_process(false)

func _line(parent: Node, node_name: String, font_size: int, color: Color) -> Label:
	var label := T.paragraph("", color, font_size)
	label.name = node_name
	parent.add_child(label)
	return label

func show_for(control: Control) -> void:
	if not is_instance_valid(control) or battle.paused or not battle.outcome.is_empty(): return
	if anchor == control: return
	anchor = control
	elapsed = 0.0
	refresh_remaining = 0.0
	last_signature = ""
	panel.hide()
	set_process(true)

func leave(control: Control) -> void:
	if anchor == control: dismiss()

func dismiss() -> void:
	anchor = null
	current_model = {}
	last_signature = ""
	if is_instance_valid(panel): panel.hide()
	set_process(false)

func _process(delta: float) -> void:
	if not is_instance_valid(anchor) or not anchor.is_visible_in_tree() or battle.paused or not battle.outcome.is_empty():
		dismiss()
		return
	elapsed += delta
	if elapsed < HOVER_DELAY: return
	refresh_remaining -= delta
	if refresh_remaining > 0.0: return
	refresh_remaining = REFRESH_INTERVAL
	var id := str(anchor.get_meta("skill_character_id", ""))
	var slot := int(anchor.get_meta("skill_slot", -1))
	if id.is_empty() or slot not in [0, 1]:
		dismiss()
		return
	current_model = INFO.manual_model(battle, id, slot)
	var signature := JSON.stringify(current_model)
	if signature != last_signature:
		last_signature = signature
		_apply(current_model)
	_queue_place()

func _apply(model: Dictionary) -> void:
	heading.text = "%s · %s %s" % [model.get("character_name", ""), model.get("key", ""), model.get("title", "")]
	category.text = str(model.get("category", ""))
	# J/K already identifies the manual slot. Keep the brief hover surface for
	# effects, requirements and current availability rather than repeating it.
	category.hide()
	summary.text = str(model.get("summary", ""))
	trigger.text = str(model.get("trigger", ""))
	trigger.hide()
	conditions.text = "\n".join(model.get("conditions", []))
	conditions.visible = not conditions.text.is_empty()
	facts.text = " · ".join(model.get("facts", []))
	facts.visible = not facts.text.is_empty()
	state.text = str(model.get("state_text", ""))
	var state_color := T.GOLD if model.get("state", "") == "ready" else T.LIGHT
	if state.get_theme_color("font_color") != state_color: state.add_theme_color_override("font_color", state_color)
	panel.size = Vector2(_panel_width(),0)
	_queue_place()

func _panel_width() -> float:
	return minf(400,maxf(200,size.x - 24))

func _queue_place() -> void:
	if _placement_queued: return
	_placement_queued = true
	_settle_place.call_deferred()

func _settle_place() -> void:
	_placement_queued = false
	if not is_instance_valid(anchor) or elapsed < HOVER_DELAY or last_signature.is_empty(): return
	_place()
	# Container sorting can change the minimum again after assigning the wrap
	# width. Coalesce those changes before the first reveal; live refreshes keep
	# the existing panel visible and do not restart the hover delay.
	if not panel.visible: _reveal.call_deferred()

func _reveal() -> void:
	if _placement_queued or not is_instance_valid(anchor) or elapsed < HOVER_DELAY or last_signature.is_empty(): return
	_place()
	panel.show()

func _place() -> void:
	if not is_instance_valid(panel) or not is_instance_valid(anchor): return
	var width := _panel_width()
	panel.size = Vector2(width, maxf(0, panel.get_combined_minimum_size().y))
	var rect := anchor.get_global_rect()
	var local := rect.position - global_position
	var x := clampf(local.x, 12, maxf(12, size.x - panel.size.x - 12))
	var y := local.y - panel.size.y - 10
	if y < 12: y = local.y + rect.size.y + 10
	y = clampf(y, 12, maxf(12, size.y - panel.size.y - 12))
	panel.position = Vector2(x, y)
