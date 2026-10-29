extends RefCounted
## Display-only adapter for attempt-scoped state; no inventory, timer or cost rules here.
static func build(battle: RefCounted, id: String, definitions: Dictionary) -> Dictionary:
	var state: Dictionary = battle.mechanic_status(id)
	if state.is_empty(): return {"text":"", "compact":"", "active":false}
	var core: String = str(state.get("core", ""))
	var dead: bool = bool(state.get("dead", false))
	var value: float = float(state.get("value", 0))
	var remaining: float = float(state.get("remaining", 0))
	var main := ""
	var extra: Array[String] = []
	match core:
		"echo":
			main = "回响 %d/%d · %ss" % [value, state.max, number(remaining)] if float(state.max) > 0 else "回响 无记录"
		"ammo": main = "箭 %d/%d · 补箭%ss" % [value, state.max, number(remaining)]
		"refund": main = "待返 %sMP" % number(value) + (" · %ss" % number(remaining) if value > 0 and remaining > 0 else "")
		"relay":
			var previous: String = str(state.get("detail", ""))
			main = "接力 待首次施法" if previous.is_empty() else "接力 需换人" if previous == id else "接力 可接"
		"mark": main = "追击 %d/%d" % [value, state.max]
		"guard":
			if remaining > 0: main = "守势 %d次 · %ss" % [value, number(remaining)]
		"temper":
			if remaining > 0: main = "淬刃 %ss" % number(remaining)
	if dead and not main.is_empty():
		if core == "refund":
			if value <= 0: main = ""
		else: main += " · 停用"
	if not dead:
		for window in state.get("windows", []):
			if str(window.key) == core: continue
			if window.key == "guard": extra.append("守势 %d次 · %ss" % [window.get("charges", 0), number(window.remaining)])
			elif window.key == "temper": extra.append("淬刃 %ss" % number(window.remaining))
		if float(state.get("shield", 0)) > 0: extra.append("盾 %s" % number(state.shield))
	var compact: String = main
	if not extra.is_empty(): compact += ("\n" if not compact.is_empty() else "") + "\n".join(extra)
	var text: String = main
	if core == "relay" and not str(state.get("detail", "")).is_empty():
		var previous: String = str(state.detail)
		text += " · 上次" + str(definitions.get(previous, {}).get("name", previous))
	if not extra.is_empty(): text += (" · " if not text.is_empty() else "") + " · ".join(extra)
	return {"text":text, "compact":compact, "active":not dead and (value > 0 or remaining > 0 or not extra.is_empty()), "state":state}

static func number(value: float) -> String:
	return String.num(value, 1).trim_suffix(".0")
