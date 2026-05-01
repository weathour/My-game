extends Control

signal difficulty_selected(difficulty_id: String)
signal closed

const SURVIVORS_MODAL := preload("res://scripts/ui/core/survivors_modal.gd")
const SURVIVORS_SLOT_CARD := preload("res://scripts/ui/components/survivors_slot_card_factory.gd")

const TEXT_CHOOSE_DIFFICULTY := "\u9009\u62e9\u96be\u5ea6"
const TEXT_CLOSE := "\u5173\u95ed"
const TEXT_DIFFICULTY_EASY := "\u7b80\u5355"
const TEXT_DIFFICULTY_NORMAL := "\u666e\u901a"
const TEXT_DIFFICULTY_HARD := "\u56f0\u96be"
const TEXT_DIFFICULTY_HELL := "\u5730\u72f1"
const TEXT_NOT_OPEN := "\u672a\u5f00\u653e"

var modal: Control
var card_grid: GridContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_overlay()
	visible = false

func open() -> void:
	visible = true
	if modal != null and modal.has_method("apply_layout"):
		modal.apply_layout()

func close_overlay() -> void:
	visible = false
	closed.emit()

func _build_overlay() -> void:
	modal = SURVIVORS_MODAL.new()
	modal.configure(Vector2(860.0, 400.0), 0.68, 0.56, Vector2(320.0, 240.0))
	modal.set_title(TEXT_CHOOSE_DIFFICULTY)
	modal.set_hint("选择本次无尽模式的初始难度。")
	add_child(modal)

	card_grid = GridContainer.new()
	card_grid.columns = 2
	card_grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_grid.add_theme_constant_override("h_separation", 12)
	card_grid.add_theme_constant_override("v_separation", 12)
	modal.set_body(card_grid)

	card_grid.add_child(_build_difficulty_card(TEXT_DIFFICULTY_EASY, "easy", false))
	card_grid.add_child(_build_difficulty_card(TEXT_DIFFICULTY_NORMAL, "normal", true))
	card_grid.add_child(_build_difficulty_card(TEXT_DIFFICULTY_HARD, "hard", false))
	card_grid.add_child(_build_difficulty_card(TEXT_DIFFICULTY_HELL, "hell", false))

	modal.clear_footer()
	modal.add_footer_button(TEXT_CLOSE, Callable(self, "close_overlay"), "normal")

func _build_difficulty_card(title_text: String, difficulty_id: String, available: bool) -> Control:
	return SURVIVORS_SLOT_CARD.build_card(
		title_text,
		"标准幸存者割草体验。" if available else TEXT_NOT_OPEN,
		"\u9009\u62e9" if available else TEXT_NOT_OPEN,
		Callable(self, "_emit_difficulty").bind(difficulty_id),
		132.0,
		available,
		not available
	)

func _emit_difficulty(difficulty_id: String) -> void:
	difficulty_selected.emit(difficulty_id)
