extends Control
## Reuses the shipped HUD widgets; reads the new session without importing Player.
const ROW := preload("res://scripts/ui/hud/widgets/team_role_status_row.gd")
const PORTRAIT := preload("res://scripts/ui/hud/widgets/switch_portrait_display.gd")
const ICON := preload("res://scripts/ui/hud/widgets/skill_cooldown_icon.gd")
const ART := preload("res://scripts/ui/chronicle/battle_art.gd")
const C := preload("res://scripts/content/combat_catalog.gd")
const T := preload("res://scripts/ui/chronicle/chronicle_theme.gd")
var battle: RefCounted
var definitions: Dictionary
var band: Control
var rows: Array = []
var experience: ProgressBar
var experience_label: Label
var switch_label: Label
const WIDTH := 1008.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	band = Control.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)
	for i in 3:
		var row := ROW.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.add_child(row)
		var portrait := PORTRAIT.new()
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(portrait)
		var empty := T.label("辅助空位", 15, Color("c2b79d"))
		band.add_child(empty)
		var slots: Array = []
		for j in 4:
			var icon := ICON.new()
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(icon)
			var glyph := T.label("", 15, Color("fff0c9"))
			icon.add_child(glyph)
			glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			var text := T.label("", 13, Color("e9dec3"))
			row.add_child(text)
			slots.append({"icon":icon, "glyph":glyph, "label":text})
		rows.append({"row":row, "portrait":portrait, "slots":slots, "empty":empty})
	experience = T.bar(band, 0, 100, Color("b6a16a"))
	experience.position = Vector2(0, 134)
	experience.size = Vector2(700, 8)
	experience_label = T.label("", 12, Color("dfd8c1"))
	experience_label.position = Vector2(8, 144)
	band.add_child(experience_label)
	switch_label = T.label("", 13, Color("d9ccae"))
	switch_label.position = Vector2(715, 132)
	band.add_child(switch_label)
	resized.connect(_layout)
	_layout()
	refresh()

func _layout() -> void:
	if band == null: return
	var factor := minf(1.0, maxf(0.1, (size.x - 24) / WIDTH))
	band.scale = Vector2.ONE * factor
	band.position = Vector2((size.x - WIDTH * factor) * 0.5, 3)
	custom_minimum_size.y = 170 * factor

func refresh() -> void:
	if band == null: return
	# Stable party slots: no duplicate portrait when only one or two members exist.
	for i in 3:
		var entry: Dictionary = rows[i]
		var row: Control = entry.row
		var present: bool = i < battle.members.size()
		row.visible = present
		entry.empty.visible = not present
		var active: bool = present and i == battle.active
		# Active row grows, while each character retains its position in the roster.
		var y := 0.0
		for preceding in i: y += 56.0 if preceding == battle.active else 39.0
		row.position = Vector2(8 if active else 0, y)
		row.size = Vector2(WIDTH - (8 if active else 0), 52 if active else 35)
		entry.empty.position = Vector2(24, y + 8)
		if not present: continue
		var id: String = battle.members[i]
		var actor: RefCounted = battle.characters[id]
		var state := "阵亡 · 等待泉水" if actor.dead else "前台" if active else "后台支援"
		if not active and not actor.dead and C.definition(id).support == null: state = "后台待命"
		row.set_status({"role_id":id, "role_name":definitions[id].name, "current_health":actor.hp, "max_health":actor.stats.hp,
			"current_mana":actor.mp, "max_mana":actor.stats.mp}, "当前" if active else _switch_key(i), "%s · Lv.%d" % [state, actor.level], active)
		row.modulate = Color("a29b98") if actor.dead else Color.WHITE
		var portrait: Control = entry.portrait
		portrait.size = Vector2.ONE * (78 if active else 61)
		portrait.position = Vector2(117 if active else 96.5, row.size.y * .5) - portrait.size * .5
		portrait.set_role_scene(id, ART.portrait(id))
		portrait.modulate = ART.tint(id)
		# Existing portrait supports an energy ring; new rules explicitly leave it empty.
		portrait.set_state(battle.switch_cooldown / .5, 0.0, active)
		var definition := C.definition(id)
		var routine: Array = definition.get("automatic", [])
		var skills: Array = [C.basic(id, battle.equipment), routine[0] if active and not routine.is_empty() else definition.get("support") if not active else null]
		var manuals: Array = definition.manual
		for j in 2: skills.append(manuals[j] if j < manuals.size() else null)
		for j in 4: _skill(entry.slots[j], skills[j], actor, active, j, row.size.y)
	var actor: RefCounted = battle.current()
	experience.max_value = C.xp_required(actor.level)
	experience.value = actor.xp
	experience_label.text = "%s 经验 %.1f / %d" % [definitions[actor.id].name, actor.xp, experience.max_value]
	switch_label.text = "切换冷却 %.1fs" % battle.switch_cooldown if battle.switch_cooldown > 0 else "Q / E 切换 · J / K 关键技能"

func _switch_key(index: int) -> String:
	if battle.characters[battle.members[index]].dead: return "阵亡"
	var alive: Array = []
	for i in battle.members.size():
		if not battle.characters[battle.members[i]].dead: alive.append(i)
	if alive.size() == 2: return "Q / E"
	return "E" if posmod(index - battle.active, battle.members.size()) == 1 else "Q"

func _skill(slot: Dictionary, skill: Resource, actor: RefCounted, active: bool, index: int, height: float) -> void:
	var icon: Control = slot.icon
	var side := 36.0 if active else 28.0
	icon.size = Vector2.ONE * side
	icon.position = Vector2([530, 635, 746, 873][index], (height - side) * .5)
	var label: Label = slot.label
	label.position = icon.position + Vector2(side + 4, 0)
	label.add_theme_font_size_override("font_size", 12 if active else 11)
	label.add_theme_constant_override("line_spacing", -2)
	if skill == null:
		icon.visible = false
		label.text = ""
		return
	icon.visible = true
	var unlocked: bool = actor.level >= skill.unlock_level and not actor.dead
	var remaining: float = actor.cooldowns.get(skill.id, 0.0)
	var manual := index >= 2
	var enough: bool = actor.mp >= skill.mana_cost
	var color := Color("514938") if manual else Color("294a45")
	icon.set_state(unlocked, color, remaining / (1.0 / actor.stats.speed if index == 0 else maxf(.01, skill.cooldown)))
	icon.set_auto_mode(not manual and unlocked and (active or index == 1))
	icon.process_mode = Node.PROCESS_MODE_DISABLED if battle.paused else Node.PROCESS_MODE_INHERIT
	slot.glyph.text = ("J" if index == 2 else "K") if manual and active else "备" if manual else "援" if index == 1 and not active else "自"
	slot.glyph.modulate = Color.WHITE if unlocked and enough else Color("a49d93")
	var detail := "Lv.%d" % skill.unlock_level if not unlocked else "%.1fs" % remaining if remaining > 0 else "%d魔法" % skill.mana_cost if manual else "自动"
	if manual and unlocked and not enough: detail = "魔法不足"
	if not active and index == 0: detail = "前台普攻"
	if actor.dead: detail = "阵亡"
	label.text = "%s\n%s" % [skill.title, detail]
