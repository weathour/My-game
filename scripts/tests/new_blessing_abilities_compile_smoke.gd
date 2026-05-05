extends SceneTree

const PlayerScript := preload("res://scripts/player.gd")
const MageMetaFieldAbility := preload("res://scripts/abilities/mage_meta_field_ability.gd")
const SwordsmanCrescentWaveAbility := preload("res://scripts/abilities/swordsman_crescent_wave_ability.gd")
const GunnerShrapnelFieldAbility := preload("res://scripts/abilities/gunner_shrapnel_field_ability.gd")


func _init() -> void:
	var scripts: Array = [
		PlayerScript,
		MageMetaFieldAbility,
		SwordsmanCrescentWaveAbility,
		GunnerShrapnelFieldAbility
	]
	if scripts.size() != 4:
		push_error("new blessing ability compile smoke failed to preload scripts")
		quit(1)
		return
	print("NEW_BLESSING_ABILITIES_COMPILE_SMOKE_OK")
	quit(0)
