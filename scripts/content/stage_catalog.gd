extends RefCounted
## Authored whole-chapter encounters. Initial tuning, not a balance certification.
## Boss HP is absolute. enemy_hp scales ordinary/field elites; damage scales once.
const ENEMIES := preload("res://scripts/content/enemy_catalog.gd")
const ROUTE_ORDER := ["B01", "B02", "B04", "B05", "B03", "B06", "B07", "B08", "B09", "B10", "B11", "B12", "B13", "B14", "B15", "B16", "B17", "B18"]
const STAGES := {
	"B01": {
		"boss_time": 65.0,
		"boss_kills": 28,
		"bonus_time": 105.0,
		"spawn_interval": 1.4,
		"enemy_cap": 28,
		"boss_hp": 550.0,
		"boss_name": "荒道鬼校·空面碑甲",
		"seed": 1701,
		"map": "grass",
		"enemy_hp": 1,
		"enemy_damage": 1.0,
		"boss_definition": "B01",
		"field_elites": [
			"L00",
			"L00"
		],
		"action_budget": {
			"major": 1,
			"melee": 2
		},
		"derivative_cap": 6,
		"boss_derivative_cap": 4,
		"role_caps": {
			"support": 1,
			"heavy": 2,
			"ranged": 4
		},
		"waves": [
			{
				"at": 0.0,
				"count": 1,
				"cycle": [
					"E01"
				]
			},
			{
				"at": 28.0,
				"interval": 1.35,
				"count": 2,
				"cycle": [
					"E01",
					"E01",
					"E01"
				]
			}
		]
	},
	"B02": {
		"boss_time": 80.0,
		"boss_kills": 38,
		"bonus_time": 120.0,
		"spawn_interval": 1.3,
		"enemy_cap": 29,
		"boss_hp": 900.0,
		"boss_name": "守街尸将·檐面巡将",
		"seed": 1702,
		"map": "stone",
		"enemy_hp": 1.05,
		"enemy_damage": 1.047,
		"boss_definition": "B02",
		"field_elites": [
			"L01",
			"L01"
		],
		"action_budget": {
			"major": 1,
			"melee": 2
		},
		"derivative_cap": 6,
		"boss_derivative_cap": 4,
		"role_caps": {
			"support": 1,
			"heavy": 2,
			"ranged": 4
		},
		"waves": [
			{
				"at": 0.0,
				"count": 1,
				"cycle": [
					"E01",
					"E01",
					"E02"
				]
			},
			{
				"at": 28.0,
				"interval": 1.35,
				"count": 2,
				"cycle": [
					"E01",
					"E02",
					"E01",
					"E01"
				]
			}
		]
	},
	"B04": {
		"boss_time": 85.0,
		"boss_kills": 44,
		"bonus_time": 130.0,
		"spawn_interval": 1.3,
		"enemy_cap": 30,
		"boss_hp": 1250.0,
		"boss_name": "押粮鬼尉·轭骨牛督",
		"seed": 1704,
		"map": "grass",
		"enemy_hp": 1.2,
		"enemy_damage": 1.094,
		"boss_definition": "B04",
		"field_elites": [
			"L01",
			"L05"
		],
		"action_budget": {
			"major": 2,
			"melee": 2
		},
		"derivative_cap": 6,
		"boss_derivative_cap": 4,
		"role_caps": {
			"support": 1,
			"heavy": 2,
			"ranged": 4
		},
		"waves": [
			{
				"at": 0.0,
				"count": 1,
				"cycle": [
					"E01",
					"E03",
					"E01"
				]
			},
			{
				"at": 28.0,
				"interval": 1.35,
				"count": 2,
				"cycle": [
					"E04",
					"E01",
					"E03",
					"E02"
				]
			}
		]
	},
	"B05": {
		"boss_time": 90.0,
		"boss_kills": 36,
		"bonus_time": 140.0,
		"spawn_interval": 1.3,
		"enemy_cap": 31,
		"boss_hp": 1150.0,
		"boss_name": "冥灯术士·悬灯道人",
		"seed": 1705,
		"map": "stone",
		"enemy_hp": 1.2,
		"enemy_damage": 1.141,
		"boss_definition": "B05",
		"field_elites": [
			"L05",
			"L01"
		],
		"action_budget": {
			"major": 2,
			"melee": 2
		},
		"derivative_cap": 6,
		"boss_derivative_cap": 4,
		"role_caps": {
			"support": 1,
			"heavy": 2,
			"ranged": 4
		},
		"waves": [
			{
				"at": 0.0,
				"count": 1,
				"cycle": [
					"E01",
					"E04",
					"E05"
				]
			},
			{
				"at": 28.0,
				"interval": 1.35,
				"count": 2,
				"cycle": [
					"E05",
					"E01",
					"E06",
					"E04"
				]
			}
		]
	},
	"B03": {
		"boss_time": 100.0,
		"boss_kills": 54,
		"bonus_time": 150.0,
		"spawn_interval": 1.3,
		"enemy_cap": 32,
		"boss_hp": 1750.0,
		"boss_name": "盘寨鬼魁·三面裂旗魁",
		"seed": 1703,
		"map": "grass",
		"enemy_hp": 1.35,
		"enemy_damage": 1.188,
		"boss_definition": "B03",
		"field_elites": [
			"L05",
			"L01"
		],
		"action_budget": {
			"major": 2,
			"melee": 2
		},
		"derivative_cap": 6,
		"boss_derivative_cap": 4,
		"role_caps": {
			"support": 1,
			"heavy": 2,
			"ranged": 4
		},
		"waves": [
			{
				"at": 0.0,
				"count": 1,
				"cycle": [
					"E01",
					"E03",
					"E04",
					"E02"
				]
			},
			{
				"at": 28.0,
				"interval": 1.35,
				"count": 2,
				"cycle": [
					"E06",
					"E01",
					"E03",
					"E04"
				]
			}
		]
	},
	"B06": {
		"boss_time": 105.0,
		"boss_kills": 48,
		"bonus_time": 160.0,
		"spawn_interval": 1.3,
		"enemy_cap": 33,
		"boss_hp": 2150.0,
		"boss_name": "荒祠镇将·祠脊石兽",
		"seed": 1706,
		"map": "stone",
		"enemy_hp": 1.5,
		"enemy_damage": 1.235,
		"boss_definition": "B06",
		"field_elites": [
			"L01",
			"L05"
		],
		"action_budget": {
			"major": 2,
			"melee": 2
		},
		"derivative_cap": 6,
		"boss_derivative_cap": 4,
		"role_caps": {
			"support": 1,
			"heavy": 2,
			"ranged": 4
		},
		"waves": [
			{
				"at": 0.0,
				"count": 1,
				"cycle": [
					"E04",
					"E02",
					"E03"
				]
			},
			{
				"at": 28.0,
				"interval": 1.35,
				"count": 2,
				"cycle": [
					"E05",
					"E01",
					"E06",
					"E04"
				]
			}
		]
	},
	"B07": {
		"boss_time": 95.0,
		"boss_kills": 45,
		"bonus_time": 175.0,
		"spawn_interval": 1.35,
		"enemy_cap": 34,
		"boss_hp": 2400.0,
		"boss_name": "官署号令者·悬印司令",
		"seed": 1707,
		"map": "stone",
		"enemy_hp": 1.55,
		"enemy_damage": 1.282,
		"boss_definition": "B07",
		"field_elites": [
			"L03",
			"L06"
		],
		"action_budget": {
			"major": 2,
			"melee": 2
		},
		"derivative_cap": 6,
		"boss_derivative_cap": 4,
		"role_caps": {
			"support": 1,
			"heavy": 2,
			"ranged": 4
		},
		"waves": [
			{
				"at": 0.0,
				"count": 1,
				"cycle": [
					"E01",
					"E07",
					"E04",
					"E02"
				]
			},
			{
				"at": 34.0,
				"interval": 1.35,
				"count": 2,
				"cycle": [
					"E09",
					"E01",
					"E03",
					"E07"
				]
			}
		]
	},
	"B08": {
		"boss_time": 100.0,
		"boss_kills": 48,
		"bonus_time": 180.0,
		"spawn_interval": 1.35,
		"enemy_cap": 35,
		"boss_hp": 2700.0,
		"boss_name": "水门冲将·闸齿鳄首",
		"seed": 1708,
		"map": "grass",
		"enemy_hp": 1.65,
		"enemy_damage": 1.329,
		"boss_definition": "B08",
		"field_elites": [
			"L06",
			"L03"
		],
		"action_budget": {
			"major": 2,
			"melee": 2
		},
		"derivative_cap": 6,
		"boss_derivative_cap": 4,
		"role_caps": {
			"support": 1,
			"heavy": 2,
			"ranged": 4
		},
		"waves": [
			{
				"at": 0.0,
				"count": 1,
				"cycle": [
					"E03",
					"E04",
					"E02"
				]
			},
			{
				"at": 34.0,
				"interval": 1.35,
				"count": 2,
				"cycle": [
					"E10",
					"E01",
					"E07",
					"E03"
				]
			}
		]
	},
	"B09": {
		"boss_time": 100.0,
		"boss_kills": 48,
		"bonus_time": 180.0,
		"spawn_interval": 1.35,
		"enemy_cap": 36,
		"boss_hp": 2850.0,
		"boss_name": "军械库将·炉腹铁鬼",
		"seed": 1709,
		"map": "stone",
		"enemy_hp": 1.65,
		"enemy_damage": 1.376,
		"boss_definition": "B09",
		"field_elites": [
			"L03",
			"L06"
		],
		"action_budget": {
			"major": 2,
			"melee": 2
		},
		"derivative_cap": 6,
		"boss_derivative_cap": 4,
		"role_caps": {
			"support": 1,
			"heavy": 2,
			"ranged": 4
		},
		"waves": [
			{
				"at": 0.0,
				"count": 1,
				"cycle": [
					"E09",
					"E01",
					"E04"
				]
			},
			{
				"at": 34.0,
				"interval": 1.35,
				"count": 2,
				"cycle": [
					"E10",
					"E02",
					"E07",
					"E01"
				]
			}
		]
	},
	"B10": {
		"boss_time": 110.0,
		"boss_kills": 54,
		"bonus_time": 195.0,
		"spawn_interval": 1.35,
		"enemy_cap": 37,
		"boss_hp": 3200.0,
		"boss_name": "封库双禁卫·左锁",
		"seed": 1710,
		"map": "stone",
		"enemy_hp": 1.75,
		"enemy_damage": 1.424,
		"boss_definition": "B10",
		"field_elites": [
			"L06",
			"L03"
		],
		"action_budget": {
			"major": 2,
			"melee": 2
		},
		"derivative_cap": 6,
		"boss_derivative_cap": 4,
		"role_caps": {
			"support": 1,
			"heavy": 2,
			"ranged": 4
		},
		"waves": [
			{
				"at": 0.0,
				"count": 1,
				"cycle": [
					"E09",
					"E04",
					"E02"
				]
			},
			{
				"at": 34.0,
				"interval": 1.35,
				"count": 2,
				"cycle": [
					"E10",
					"E01",
					"E07",
					"E03"
				]
			}
		]
	},
	"B11": {
		"boss_time": 100.0,
		"boss_kills": 48,
		"bonus_time": 185.0,
		"spawn_interval": 1.35,
		"enemy_cap": 38,
		"boss_hp": 3150.0,
		"boss_name": "巡城灯师·伞眼灯灵",
		"seed": 1711,
		"map": "stone",
		"enemy_hp": 1.8,
		"enemy_damage": 1.471,
		"boss_definition": "B11",
		"field_elites": [
			"L02",
			"L03"
		],
		"action_budget": {
			"major": 2,
			"melee": 2
		},
		"derivative_cap": 6,
		"boss_derivative_cap": 4,
		"role_caps": {
			"support": 1,
			"heavy": 2,
			"ranged": 4
		},
		"waves": [
			{
				"at": 0.0,
				"count": 1,
				"cycle": [
					"E01",
					"E08",
					"E05",
					"E04"
				]
			},
			{
				"at": 34.0,
				"interval": 1.35,
				"count": 2,
				"cycle": [
					"E10",
					"E02",
					"E08",
					"E01"
				]
			}
		]
	},
	"B12": {
		"boss_time": 110.0,
		"boss_kills": 54,
		"bonus_time": 200.0,
		"spawn_interval": 1.35,
		"enemy_cap": 39,
		"boss_hp": 3600.0,
		"boss_name": "瘟灯阵主·多手幡灯大巫",
		"seed": 1712,
		"map": "stone",
		"enemy_hp": 1.9,
		"enemy_damage": 1.518,
		"boss_definition": "B12",
		"field_elites": [
			"L02",
			"L05"
		],
		"action_budget": {
			"major": 2,
			"melee": 2
		},
		"derivative_cap": 6,
		"boss_derivative_cap": 4,
		"role_caps": {
			"support": 1,
			"heavy": 2,
			"ranged": 4
		},
		"waves": [
			{
				"at": 0.0,
				"count": 1,
				"cycle": [
					"E01",
					"E11",
					"E05"
				]
			},
			{
				"at": 34.0,
				"interval": 1.35,
				"count": 2,
				"cycle": [
					"E08",
					"E04",
					"E06",
					"E11"
				]
			}
		]
	},
	"B13": {
		"boss_time": 105.0,
		"boss_kills": 52,
		"bonus_time": 195.0,
		"spawn_interval": 1.35,
		"enemy_cap": 40,
		"boss_hp": 3650.0,
		"boss_name": "城垣冲将·石鸱裂垛",
		"seed": 1713,
		"map": "stone",
		"enemy_hp": 2,
		"enemy_damage": 1.565,
		"boss_definition": "B13",
		"field_elites": [
			"L04",
			"L06"
		],
		"action_budget": {
			"major": 2,
			"melee": 2
		},
		"derivative_cap": 6,
		"boss_derivative_cap": 4,
		"role_caps": {
			"support": 1,
			"heavy": 2,
			"ranged": 4
		},
		"waves": [
			{
				"at": 0.0,
				"count": 1,
				"cycle": [
					"E03",
					"E04",
					"E07",
					"E02"
				]
			},
			{
				"at": 34.0,
				"interval": 1.35,
				"count": 2,
				"cycle": [
					"E09",
					"E05",
					"E01",
					"E10"
				]
			}
		]
	},
	"B14": {
		"boss_time": 105.0,
		"boss_kills": 52,
		"bonus_time": 195.0,
		"spawn_interval": 1.35,
		"enemy_cap": 41,
		"boss_hp": 3650.0,
		"boss_name": "渡口号令者·引舟鬼帅",
		"seed": 1714,
		"map": "grass",
		"enemy_hp": 2,
		"enemy_damage": 1.612,
		"boss_definition": "B14",
		"field_elites": [
			"L04",
			"L02"
		],
		"action_budget": {
			"major": 2,
			"melee": 2
		},
		"derivative_cap": 6,
		"boss_derivative_cap": 4,
		"role_caps": {
			"support": 1,
			"heavy": 2,
			"ranged": 4
		},
		"waves": [
			{
				"at": 0.0,
				"count": 1,
				"cycle": [
					"E01",
					"E12",
					"E07",
					"E02"
				]
			},
			{
				"at": 34.0,
				"interval": 1.35,
				"count": 2,
				"cycle": [
					"E10",
					"E05",
					"E04",
					"E01"
				]
			}
		]
	},
	"B15": {
		"boss_time": 110.0,
		"boss_kills": 56,
		"bonus_time": 205.0,
		"spawn_interval": 1.35,
		"enemy_cap": 42,
		"boss_hp": 4300.0,
		"boss_name": "曹休·鬼猎兽相",
		"seed": 1715,
		"map": "stone",
		"enemy_hp": 2.15,
		"enemy_damage": 1.659,
		"boss_definition": "B15",
		"field_elites": [
			"L04",
			"L01"
		],
		"action_budget": {
			"major": 2,
			"melee": 2
		},
		"derivative_cap": 6,
		"boss_derivative_cap": 4,
		"role_caps": {
			"support": 1,
			"heavy": 2,
			"ranged": 4
		},
		"waves": [
			{
				"at": 0.0,
				"count": 1,
				"cycle": [
					"E12",
					"E02",
					"E07",
					"E01"
				]
			},
			{
				"at": 34.0,
				"interval": 1.35,
				"count": 2,
				"cycle": [
					"E09",
					"E05",
					"E03",
					"E04"
				]
			}
		]
	},
	"B16": {
		"boss_time": 115.0,
		"boss_kills": 60,
		"bonus_time": 215.0,
		"spawn_interval": 1.35,
		"enemy_cap": 42,
		"boss_hp": 4800.0,
		"boss_name": "曹纯·虎豹甲骑巨相",
		"seed": 1716,
		"map": "stone",
		"enemy_hp": 2.25,
		"enemy_damage": 1.706,
		"boss_definition": "B16",
		"field_elites": [
			"L06",
			"L04"
		],
		"action_budget": {
			"major": 2,
			"melee": 2
		},
		"derivative_cap": 6,
		"boss_derivative_cap": 4,
		"role_caps": {
			"support": 1,
			"heavy": 2,
			"ranged": 4
		},
		"waves": [
			{
				"at": 0.0,
				"count": 1,
				"cycle": [
					"E11",
					"E04",
					"E02",
					"E01"
				]
			},
			{
				"at": 34.0,
				"interval": 1.35,
				"count": 2,
				"cycle": [
					"E12",
					"E08",
					"E03",
					"E05"
				]
			}
		]
	},
	"B17": {
		"boss_time": 115.0,
		"boss_kills": 60,
		"bonus_time": 215.0,
		"spawn_interval": 1.35,
		"enemy_cap": 42,
		"boss_hp": 6200.0,
		"boss_name": "张辽·夜叉裂阵将相",
		"seed": 1717,
		"map": "stone",
		"enemy_hp": 2.35,
		"enemy_damage": 1.753,
		"boss_definition": "B17",
		"field_elites": [
			"L03",
			"L05"
		],
		"action_budget": {
			"major": 2,
			"melee": 2
		},
		"derivative_cap": 6,
		"boss_derivative_cap": 4,
		"role_caps": {
			"support": 1,
			"heavy": 2,
			"ranged": 4
		},
		"waves": [
			{
				"at": 0.0,
				"count": 1,
				"cycle": [
					"E09",
					"E07",
					"E04",
					"E02"
				]
			},
			{
				"at": 34.0,
				"interval": 1.35,
				"count": 2,
				"cycle": [
					"E12",
					"E05",
					"E11",
					"E01"
				]
			}
		]
	},
	"B18": {
		"boss_time": 120.0,
		"boss_kills": 64,
		"bonus_time": 220.0,
		"spawn_interval": 1.35,
		"enemy_cap": 42,
		"boss_hp": 7600.0,
		"boss_name": "吕布·四臂鬼神相",
		"seed": 1718,
		"map": "stone",
		"enemy_hp": 2.5,
		"enemy_damage": 1.8,
		"boss_definition": "B18",
		"field_elites": [
			"L06",
			"L02"
		],
		"action_budget": {
			"major": 2,
			"melee": 2
		},
		"derivative_cap": 6,
		"boss_derivative_cap": 4,
		"role_caps": {
			"support": 1,
			"heavy": 2,
			"ranged": 4
		},
		"waves": [
			{
				"at": 0.0,
				"count": 1,
				"cycle": [
					"E12",
					"E04",
					"E07",
					"E02"
				]
			},
			{
				"at": 34.0,
				"interval": 1.35,
				"count": 2,
				"cycle": [
					"E11",
					"E05",
					"E08",
					"E03"
				]
			}
		]
	}
}

static func stage(id: String) -> Dictionary:
	return STAGES.get(id, {}).duplicate(true)

static func validate() -> Array:
	var errors: Array = []
	if STAGES.size() != 18: errors.append("chapter must author all 18 combat nodes")
	for id in STAGES:
		var value: Dictionary = STAGES[id]
		var boss := ENEMIES.definition(value.boss_definition)
		if boss.is_empty() or boss.rank != "boss": errors.append(id + ": invalid boss")
		if value.boss_hp <= 0 or value.boss_time <= 0 or value.boss_kills <= 0: errors.append(id + ": invalid gate")
		if value.field_elites.size() != 2: errors.append(id + ": two reward slot profiles required")
		for elite_id in value.field_elites:
			if ENEMIES.definition(elite_id).get("rank") != "field_elite": errors.append(id + ": invalid field elite")
		if value.enemy_cap < 28 or value.enemy_cap > 42: errors.append(id + ": ordinary cap outside authored range")
		if value.action_budget.major != (1 if id in ["B01", "B02"] else 2): errors.append(id + ": action budget mismatch")
		for wave in value.waves:
			if wave.cycle.is_empty(): errors.append(id + ": empty wave")
			for enemy_id in wave.cycle:
				if enemy_id not in ENEMIES.ordinary_ids(): errors.append(id + ": invalid ordinary " + enemy_id)
	return errors
