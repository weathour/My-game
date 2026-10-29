extends Control
## Legacy bottom-bar composition, adapted to independent resources and two keys.
const PORTRAIT := preload("res://scripts/ui/hud/widgets/switch_portrait_display.gd")
const ICON := preload("res://scripts/ui/hud/widgets/skill_cooldown_icon.gd")
const ART := preload("res://scripts/ui/chronicle/battle_art.gd")
const C := preload("res://scripts/content/combat_catalog.gd")
const T := preload("res://scripts/ui/chronicle/chronicle_theme.gd")
const MECHANIC := preload("res://scripts/ui/chronicle/battle_mechanic_status.gd")
const WIDTH := 780.0
const HEIGHT := 168.0
const STATUS_BOTTOM_PADDING := 12.0
var active_layout := -1
var layout_tween: Tween
var battle: RefCounted
var definitions: Dictionary
var band: Control
var members: Array = []
var skills: Array = []
var actor_name: Label
var health: ProgressBar
var mana: ProgressBar
var health_text: Label
var mana_text: Label
var experience: ProgressBar
var mechanic_text: Label
var mechanic_extra := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	band = Control.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.size = Vector2(WIDTH, HEIGHT)
	add_child(band)
	var plate := Panel.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.position = Vector2(244, 28)
	plate.size = Vector2(536, 132)
	plate.add_theme_stylebox_override("panel", T.box(Color("15231cdd"), Color("8d774e"), 0))
	band.add_child(plate)
	T.FONT.apply_campaign_frame(plate, "panel")
	for i in 3:
		var root := Control.new()
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.add_child(root)
		var portrait := PORTRAIT.new()
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(portrait)
		var label := T.label("", 13, T.LIGHT)
		label.size.x = 112
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_shadow_color", Color.BLACK)
		label.add_theme_constant_override("shadow_offset_y", 1)
		root.add_child(label)
		var mechanic := T.label("", 11, T.GOLD)
		mechanic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mechanic.size.x = 136
		mechanic.add_theme_color_override("font_shadow_color", Color.BLACK)
		mechanic.add_theme_constant_override("shadow_offset_y", 1)
		root.add_child(mechanic)
		var hp := _bar(root, Vector2.ZERO, Vector2(54, 4), Color("bc725e"))
		var mp := _bar(root, Vector2.ZERO, Vector2(54, 3), Color("7aadc1"))
		members.append({"root":root, "portrait":portrait, "label":label, "mechanic":mechanic, "hp":hp, "mp":mp})
	actor_name = _label("", Vector2(260, 35), 18)
	health = _bar(band, Vector2(260, 66), Vector2(210, 16), Color("a85643"))
	mana = _bar(band, Vector2(260, 91), Vector2(210, 14), Color("527b89"))
	health_text = _label("", health.position, 13, health.size.x)
	mana_text = _label("", mana.position - Vector2(0, 1), 13, mana.size.x)
	mechanic_text = _label("", Vector2(260, 113), 12)
	mechanic_text.name = "active_mechanic_status"
	experience = _bar(band, Vector2(260, 138), Vector2(500, 4), Color("b6a16a"))
	for i in 2:
		var origin := Vector2(489 + i * 142, 57)
		var icon := ICON.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.position = origin
		icon.size = Vector2(46, 46)
		band.add_child(icon)
		var key := _label("J" if i == 0 else "K", origin + Vector2(0, 8), 23, 46)
		var title := _label("", origin + Vector2(53, 0), 15)
		var state := _label("", origin + Vector2(53, 26), 13)
		skills.append({"icon":icon, "key":key, "title":title, "state":state})
	resized.connect(_layout)
	_layout()
	refresh()

func _layout() -> void:
	if band == null: return
	var factor := minf(1.0, maxf(.1, (size.x - 24) / WIDTH))
	band.scale = Vector2.ONE * factor
	band.position = Vector2((size.x - WIDTH * factor) * .5, 4)
	custom_minimum_size.y = (HEIGHT + mechanic_extra) * factor

func _place_members() -> void:
	if active_layout == battle.active: return
	var animate := active_layout >= 0
	active_layout = battle.active
	if layout_tween != null and layout_tween.is_valid(): layout_tween.kill()
	if animate:
		layout_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for i in battle.members.size():
		var entry: Dictionary = members[i]
		var active: bool = i == battle.active
		var right: bool = battle.members.size() == 2 or posmod(i - battle.active, battle.members.size()) == 1
		var center := Vector2(118, 45) if active else Vector2(188 if right else 48, 100)
		var side := 180.0 if active else 135.0
		var at := center - Vector2.ONE * side * .5
		entry.root.z_index = 1 if active else 0
		entry.label.position = Vector2(side * .5 - 56, side * .67 + 9)
		entry.hp.position = Vector2(side * .5 - 27, side * .67 + 29)
		entry.mp.position = entry.hp.position + Vector2(0, 7)
		entry.mechanic.position = Vector2(side * .5 - 68, side * .67 + 45)
		if animate:
			layout_tween.tween_property(entry.root, "position", at, .18)
			layout_tween.tween_property(entry.portrait, "size", Vector2.ONE * side, .18)
		else:
			entry.root.position = at
			entry.portrait.size = Vector2.ONE * side

func refresh() -> void:
	if band == null: return
	_place_members()
	var alive: Array = []
	for i in battle.members.size():
		if not battle.characters[battle.members[i]].dead: alive.append(i)
	var extra := 0.0
	for i in 3:
		var entry: Dictionary = members[i]
		entry.root.visible = i < battle.members.size()
		if i >= battle.members.size(): continue
		var id: String = battle.members[i]
		var actor: RefCounted = battle.characters[id]
		var active: bool = i == battle.active
		entry.portrait.set_role_scene(id, ART.portrait(id))
		entry.portrait.modulate = Color("777777") if actor.dead else ART.tint(id)
		entry.portrait.set_state(battle.switch_cooldown / .5, 0.0, active)
		var key := "Q/E" if alive.size() == 2 else "E" if posmod(i - battle.active, battle.members.size()) == 1 else "Q"
		entry.label.text = "阵亡" if actor.dead else "当前" if active else key + " · " + definitions[id].name
		# Keep the protagonist's identity and health visible off-field.
		if i == 0: entry.label.text = "主 · " + entry.label.text
		entry.hp.max_value = actor.stats.hp
		entry.hp.value = actor.hp
		entry.mp.max_value = actor.stats.mp
		entry.mp.value = 0 if actor.dead else actor.mp
		var model: Dictionary = MECHANIC.build(battle, id, definitions)
		entry.mechanic.name = "member_mechanic_" + id
		entry.mechanic.text = model.compact
		# Label's font metrics include the real height of every explicit line.
		entry.mechanic.size = Vector2(136, entry.mechanic.get_minimum_size().y)
		entry.mechanic.visible = not active and not str(model.compact).is_empty()
		entry.mechanic.add_theme_color_override("font_color", T.GOLD if model.active else T.MUTED)
		if entry.mechanic.visible:
			var target_y: float = 100.0 - 135.0 * .5 + entry.mechanic.position.y
			var content_bottom: float = band.position.y + target_y + entry.mechanic.get_minimum_size().y
			extra = maxf(extra, content_bottom + STATUS_BOTTOM_PADDING - HEIGHT)
	if not is_equal_approx(extra, mechanic_extra):
		mechanic_extra = extra
		_layout()
	var actor: RefCounted = battle.current()
	actor_name.text = "%s  Lv.%d" % [definitions[actor.id].name, actor.level]
	var active_status: Dictionary = MECHANIC.build(battle, actor.id, definitions)
	mechanic_text.text = active_status.text
	mechanic_text.visible = not str(active_status.text).is_empty()
	mechanic_text.add_theme_color_override("font_color", T.GOLD if active_status.active else T.MUTED)
	health.max_value = actor.stats.hp
	health.value = actor.hp
	mana.max_value = actor.stats.mp
	mana.value = actor.mp
	health_text.text = "%d / %d" % [ceili(actor.hp), actor.stats.hp]
	mana_text.text = "%d / %d" % [floori(actor.mp), actor.stats.mp]
	experience.max_value = C.xp_required(actor.level)
	experience.value = actor.xp
	var manual: Array = C.definition(actor.id).manual
	for i in 2:
		var entry: Dictionary = skills[i]
		var present := i < manual.size()
		for control in entry.values(): control.visible = present
		if not present: continue
		var skill: Resource = manual[i]
		var unlocked: bool = actor.level >= skill.unlock_level and not actor.dead
		var remaining: float = actor.cooldowns.get(skill.id, 0.0)
		var cost: float = battle.manual_cost(skill, actor.id)
		var enough: bool = actor.mp >= cost
		entry.icon.set_state(unlocked, Color("514938"), remaining / maxf(.01, skill.cooldown))
		entry.title.text = skill.title
		entry.key.modulate = Color.WHITE if unlocked and enough else Color("aaa69c")
		entry.state.text = "Lv.%d" % skill.unlock_level if not unlocked else "%ds" % ceili(remaining) if remaining > 0 else "缺魔" if not enough else "%s魔法" % MECHANIC.number(cost)

func _bar(parent: Control, origin: Vector2, dimensions: Vector2, color: Color) -> ProgressBar:
	var bar := T.bar(parent, 0, 100, color)
	bar.custom_minimum_size = dimensions
	bar.position = origin
	bar.size = dimensions
	return bar

func _label(value: String, origin: Vector2, font_size: int, width: float = 0) -> Label:
	var label := T.label(value, font_size, T.LIGHT)
	label.position = origin
	if width > 0:
		label.size.x = width
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	band.add_child(label)
	return label
