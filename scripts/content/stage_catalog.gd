extends RefCounted
## Encounter content only; the director owns time, spawning and victory gates.
const STAGES := {
	"B01":{"boss_time":65.0, "boss_kills":28, "bonus_time":105.0, "spawn_interval":1.4, "enemy_cap":42, "boss_hp":550.0, "boss_name":"荒道鬼校", "seed":1701, "map":"grass"},
	"B02":{"boss_time":80.0, "boss_kills":38, "bonus_time":120.0, "spawn_interval":1.1, "enemy_cap":54, "boss_hp":900.0, "boss_name":"守街尸将", "seed":1702, "map":"stone"},
	"B04":{
		"boss_time":85.0, "boss_kills":44, "bonus_time":130.0, "spawn_interval":1.25, "enemy_cap":52,
		"boss_hp":1250.0, "boss_name":"押粮鬼尉", "seed":1704, "map":"grass", "tint":"e6dac0",
		"enemy_hp":1.35, "enemy_damage":1.1, "boss_cycle":["charge", "nova"],
		"waves":[{"at":0.0,"cycle":["melee","melee","charger","melee"]},
			{"at":28.0,"interval":1.05,"count":2,"cycle":["melee","charger","melee","ranged"]}]
	},
	"B05":{
		"boss_time":90.0, "boss_kills":36, "bonus_time":140.0, "spawn_interval":1.3, "enemy_cap":48,
		"boss_hp":1150.0, "boss_name":"冥灯术士", "seed":1705, "map":"stone", "tint":"a8b8cc",
		"enemy_hp":1.25, "enemy_damage":1.1, "boss_cycle":["fan", "fan", "nova"], "boss_visual":"mage",
		"waves":[{"at":0.0,"cycle":["melee","ranged","ranged","guard"]},
			{"at":32.0,"interval":1.4,"count":2,"cycle":["ranged","melee","guard","ranged"]}]
	},
	"B03":{
		"boss_time":100.0, "boss_kills":54, "bonus_time":150.0, "spawn_interval":1.2, "enemy_cap":60,
		"boss_hp":1750.0, "boss_name":"盘寨鬼魁", "seed":1703, "map":"grass", "tint":"d5bca6",
		"enemy_hp":1.65, "enemy_damage":1.2, "boss_cycle":["charge", "nova", "fan"],
		"waves":[{"at":0.0,"cycle":["melee","charger","melee","ranged"]},
			{"at":25.0,"interval":1.35,"count":2,"cycle":["guard","melee","charger","ranged"]},
			{"at":58.0,"interval":1.15,"count":2,"cycle":["charger","melee","ranged","guard"]}]
	},
	"B06":{
		"boss_time":105.0, "boss_kills":48, "bonus_time":160.0, "spawn_interval":1.35, "enemy_cap":56,
		"boss_hp":2150.0, "boss_name":"荒祠镇将", "seed":1706, "map":"stone", "tint":"b3c1bb",
		"enemy_hp":1.8, "enemy_damage":1.3, "boss_cycle":["fan", "charge", "nova"],
		"waves":[{"at":0.0,"cycle":["guard","ranged","charger","ranged"]},
			{"at":30.0,"interval":1.45,"count":2,"cycle":["charger","ranged","guard","ranged"]}]
	}
}

static func stage(id: String) -> Dictionary:
	return STAGES.get(id, {}).duplicate(true)
