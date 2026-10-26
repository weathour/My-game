extends CanvasLayer

const UI := preload("res://scripts/ui/theme/survivors_ui_theme.gd")
const PLAN := preload("res://scripts/game/combat_wave_plan.gd")
var flow
var root: Control
var status: Label
var skip_button: Button
var shop_button: Button
var shop: PanelContainer
var card: Button
var shop_open: bool = false

func _ready() -> void:
	layer = 9
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	column.position = Vector2(-305, 125)
	column.custom_minimum_size = Vector2(285, 0)
	column.add_theme_constant_override("separation", 8)
	root.add_child(column)
	status = Label.new()
	status.add_theme_font_override("font", UI.get_reading_font())
	status.add_theme_font_size_override("font_size", 18)
	status.add_theme_color_override("font_color", UI.COLOR_TEXT_GOLD)
	column.add_child(status)
	shop_button = _button("靠近阮狗 · 领取急救")
	shop_button.pressed.connect(func() -> void:
		shop_open = not shop_open
		refresh()
	)
	column.add_child(shop_button)
	skip_button = _button("跳过整备，进入下一波")
	skip_button.pressed.connect(flow.skip_preparation)
	column.add_child(skip_button)
	shop = PanelContainer.new()
	shop.add_theme_stylebox_override("panel", UI.panel_style())
	shop.custom_minimum_size = Vector2(350, 0)
	shop.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	shop.position = Vector2(-375, 300)
	root.add_child(shop)
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 12)
	shop.add_child(contents)
	var title := Label.new()
	title.text = "阮狗 · 整备补给"
	title.add_theme_font_override("font", UI.get_reading_font())
	title.add_theme_color_override("font_color", UI.COLOR_TEXT_GOLD)
	contents.add_child(title)
	card = _button("急救\n恢复所有人物已经损失血量的50％\n免费领取 · 每次整备限一张")
	card.custom_minimum_size = Vector2(350, 125)
	card.pressed.connect(flow.claim_first_aid)
	contents.add_child(card)
	var close := _button("收起")
	close.pressed.connect(close_shop)
	contents.add_child(close)
	refresh()

func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 40
	button.add_theme_font_override("font", UI.get_reading_font())
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_stylebox_override("normal", UI.panel_style(UI.COLOR_BG, UI.COLOR_BORDER_GOLD, 1, 5, 12))
	return button

func refresh() -> void:
	if status == null:
		return
	if flow.main.game_over or flow.phase == "complete":
		hide_all()
		return
	root.show()
	status.visible = true
	var phase_label: String = {"combat": "战斗", "clearing": "清理战场", "collecting": "回收经验", "settling": "选择奖励", "preparation": "整备"}.get(flow.phase, "选择奖励")
	if flow.phase == "combat" and PLAN.duration(flow.wave) == 0:
		phase_label = "击败 Boss 后结算"
	status.text = "第 %d / 20 波 · %s\n%s" % [flow.wave, PLAN.title(flow.wave), phase_label]
	var preparing: bool = flow.phase == "preparation"
	skip_button.visible = preparing
	shop_button.visible = preparing
	var near: bool = preparing and is_instance_valid(flow.merchant) and flow.main.player.global_position.distance_to(flow.merchant.global_position) <= 120
	shop_button.disabled = not near or flow.claimed or flow.merchant_health <= 0
	shop_button.text = "阮狗已阵亡" if flow.merchant_health <= 0 else (
		"本轮急救已领取" if flow.claimed else "阮狗 · 领取急救" if near else "靠近阮狗 · 领取急救")
	if not preparing or not near or flow.merchant_health <= 0:
		shop_open = false
	shop.visible = shop_open
	card.disabled = flow.claimed
	if flow.claimed:
		card.text = "急救 · 已领取\n本次整备无法重复领取"
	else:
		card.text = "急救\n恢复所有人物已经损失血量的50％\n免费领取 · 每次整备限一张"

func close_shop() -> void:
	shop_open = false
	if shop != null:
		shop.hide()

func hide_all() -> void:
	if root != null:
		root.hide()
