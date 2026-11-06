extends Control
signal skill_hovered(anchor: Control)
signal skill_unhovered(anchor: Control)
signal layout_changed
const JIA_APPEARANCE := preload("res://scripts/ui/chronicle/jia_appearance.gd")
## Both presentations observe the same battle; changing layout never changes it.
const SETTINGS := preload("res://scripts/shared/settings.gd")
const SIMPLE := preload("res://scripts/ui/chronicle/battle_hud_simple.gd")
const TEAM := preload("res://scripts/ui/chronicle/battle_hud_team.gd")
var jia_appearance := JIA_APPEARANCE.COMMON
var battle: RefCounted
var definitions: Dictionary
var presentation: Control
var layout_key := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_layout(SETTINGS.load_hud_layout())

func set_layout(value: String) -> void:
	var next := SETTINGS.normalize_hud_layout(value)
	if next == layout_key and is_instance_valid(presentation): return
	layout_key = next
	if is_instance_valid(presentation):
		remove_child(presentation)
		presentation.queue_free()
	presentation = TEAM.new() if next == SETTINGS.HUD_LAYOUT_TEAM_BAND else SIMPLE.new()
	presentation.battle = battle
	presentation.definitions = definitions
	presentation.jia_appearance = jia_appearance
	presentation.skill_hovered.connect(func(anchor: Control): skill_hovered.emit(anchor))
	presentation.skill_unhovered.connect(func(anchor: Control): skill_unhovered.emit(anchor))
	add_child(presentation)
	presentation.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	presentation.minimum_size_changed.connect(_sync_height)
	_sync_height()
	layout_changed.emit()

func _sync_height() -> void:
	custom_minimum_size.y = presentation.custom_minimum_size.y

func refresh() -> void:
	if is_instance_valid(presentation): presentation.refresh()
