extends RefCounted
const T := preload("res://scripts/ui/chronicle/chronicle_theme.gd")

static func build(shell: Control, parent: Node) -> void:
	var panel := T.panel(parent, false, 10, false)
	panel.name = "party_summary"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var column := T.column(panel)
	column.add_theme_constant_override("separation", 5)
	column.add_child(T.label("队伍增益", 17, T.GOLD, true))
	var content: VBoxContainer = shell.PAGES.scroll_column(column, "party_summary_scroll")
	var scroll := content.get_parent() as ScrollContainer
	scroll.focus_mode = Control.FOCUS_ALL
	scroll.get_v_scroll_bar().focus_mode = Control.FOCUS_ALL
	content.add_theme_constant_override("separation", 5)
	if not shell.session.has_method("party_summary"):
		content.add_child(T.paragraph("界面演练，不计算实战加成。", T.MUTED, 13))
		return
	var model: Dictionary = shell.session.party_summary()
	var attributes := content
	var effects := content
	if shell.size.x >= 1200:
		var columns := T.row(content)
		columns.add_theme_constant_override("separation", 20)
		attributes = T.column(columns)
		effects = T.column(columns)
		attributes.add_theme_constant_override("separation", 5)
		effects.add_theme_constant_override("separation", 5)
	var table := GridContainer.new()
	table.name = "party_attributes"
	table.columns = 3
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table.add_theme_constant_override("h_separation", 12)
	table.add_theme_constant_override("v_separation", 3)
	attributes.add_child(table)
	for text in ["全队加成", "合计", "来源"]: table.add_child(T.label(text, 12, T.MUTED))
	for stat in model.attributes:
		table.add_child(T.label(stat.title, 13))
		var value := T.label(stat.text, 13, T.GOLD)
		value.name = "party_bonus_" + stat.key
		table.add_child(value)
		var source := T.paragraph("、".join(stat.sources), T.MUTED, 12)
		source.custom_minimum_size.x = 100
		table.add_child(source)
	if model.attributes.is_empty(): attributes.add_child(T.label("尚无额外属性加成", 13, T.MUTED))
	else: attributes.add_child(T.paragraph("持有加成含候补与阵亡人物；补给加成为按资源上限额外回复的比例。", T.MUTED, 12))
	effects.add_child(T.label("后台支援", 14, T.GOLD))
	if model.supports.is_empty(): effects.add_child(T.label("暂无支援", 13, T.MUTED))
	for support in model.supports:
		var words := T.paragraph(support.title + "　" + support.text, T.LIGHT if support.active else T.MUTED, 13)
		words.name = "party_support_" + support.id
		effects.add_child(words)
	if not model.supports.is_empty(): effects.add_child(T.paragraph("配置为辅助且位于后台时生效；前台登场或阵亡时停止。", T.MUTED, 12))
	effects.add_child(T.label("行装效果", 14, T.GOLD))
	for item in model.equipment:
		var words := T.paragraph(item.name + "　" + item.effect + "。" + item.detail, T.LIGHT, 13)
		words.name = "party_equipment_" + item.slot
		effects.add_child(words)
