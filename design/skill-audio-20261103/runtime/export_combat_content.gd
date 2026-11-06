extends SceneTree

const KITS := preload("res://scripts/content/roster_kit_data.gd")
const ENEMIES := preload("res://scripts/content/enemy_catalog.gd")
const FORMS := preload("res://scripts/content/boss_forms.gd")

func _initialize() -> void:
	var enemies := {}
	var attacks: Array = []
	for id in ENEMIES.DEFINITIONS:
		var source: Dictionary = ENEMIES.DEFINITIONS[id]
		var item: Dictionary = source.duplicate(true)
		var forms: Array = FORMS.forms(id)
		if not forms.is_empty():
			item["forms"] = forms
			for index in forms.size():
				for attack in forms[index].attacks:
					attacks.append({"enemy_id":id,"form_index":index,"enemy_name":source.name,"form_name":forms[index].get("name",""),"attack":attack})
		else:
			for attack in source.get("attacks",[]):
				attacks.append({"enemy_id":id,"form_index":0,"enemy_name":source.name,"form_name":"","attack":attack})
		enemies[id] = item
	var result := {"kits":KITS.DATA,"enemies":enemies,"attacks":attacks}
	var output := "res://design/skill-audio-20261103/runtime/combat-content-baseline.json"
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file == null:
		push_error("Unable to write combat audio baseline")
		quit(1)
		return
	file.store_string(JSON.stringify(result,"\t") + "\n")
	file.close()
	print("COMBAT_CONTENT_BASELINE_OK kits=%d enemy_definitions=%d attacks=%d" % [KITS.DATA.size(),enemies.size(),attacks.size()])
	quit()
