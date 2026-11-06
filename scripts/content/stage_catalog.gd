extends RefCounted
## Authored whole-chapter encounters. Initial tuning, not a balance certification.
## Boss HP is absolute. enemy_hp scales ordinary/field elites; damage scales once.
const ENEMIES := preload("res://scripts/content/enemy_catalog.gd")
const ROUTE_ORDER := ["B01", "B02", "B04", "B05", "B03", "B06", "B07", "B08", "B09", "B10", "B11", "B12", "B13", "B14", "B15", "B16", "B17", "B18"]
const STAGES := {
	"B01": {
		"boss_time": 65.0,
		"boss_kills": 90,
		"bonus_time": 105.0,
		"spawn_interval": 0.78,
		"enemy_cap": 58,
		"boss_hp": 550.0,
		"boss_name": "荒道鬼校·空面碑甲",
		"seed": 1701,
		"enemy_hp": 1,
		"enemy_damage": 1.0,
		"boss_definition": "B01",
		"field_elites": [
			"L00",
			"L00"
		],
		"action_budget": {
			"major": 3,
			"melee": 6
		},
		"derivative_cap": 6,
		"boss_derivative_cap": 4,
		"role_caps": {
			"support": 1,
			"heavy": 2,
			"ranged": 5
		},
		"waves": [
			{
				"at": 0.0,
				"count": 4,
				"cycle": [
					"E01",
					"E01",
					"E01"
				],
				"interval": 0.78,
				"formation": "surround",
				"spawn_radius": 620,
				"formation_spread": 1.7,
				"intercept_lead": 1.0
			},
			{
				"at": 28.0,
				"interval": 0.72,
				"count": 5,
				"cycle": [
					"E01",
					"E01",
					"E01",
					"E01",
					"E01",
					"E01",
					"E01",
					"E01",
					"E01"
				],
				"formation": "flank",
				"spawn_radius": 620,
				"formation_spread": 1.25,
				"intercept_lead": 1.0
			},
			{
				"at": 58.0,
				"interval": 0.66,
				"count": 5,
				"cycle": [
					"E01",
					"E01",
					"E01",
					"E01",
					"E01",
					"E01",
					"E01",
					"E01",
					"E01"
				],
				"formation": "intercept",
				"spawn_radius": 620,
				"formation_spread": 1.7,
				"intercept_lead": 1.0
			}
		],
		"boss_min_time": 28.0
	},
	"B02": {
		"boss_time": 80.0,
		"boss_kills": 122,
		"bonus_time": 120.0,
		"spawn_interval": 0.768,
		"enemy_cap": 60,
		"boss_hp": 900.0,
		"boss_name": "守街尸将·檐面巡将",
		"seed": 1702,
		"enemy_hp": 1.05,
		"enemy_damage": 1.047,
		"boss_definition": "B02",
		"field_elites": [
			"L01",
			"L01"
		],
		"action_budget": {
			"major": 3,
			"melee": 6
		},
		"derivative_cap": 6,
		"boss_derivative_cap": 4,
		"role_caps": {
			"support": 1,
			"heavy": 2,
			"ranged": 5
		},
		"waves": [
			{
				"at": 0.0,
				"count": 4,
				"cycle": [
					"E01",
					"E01",
					"E01",
					"E01",
					"E01",
					"E01",
					"E01",
					"E01",
					"E02"
				],
				"interval": 0.768,
				"formation": "surround",
				"spawn_radius": 620,
				"formation_spread": 1.7,
				"intercept_lead": 1.0
			},
			{
				"at": 28.0,
				"interval": 0.708,
				"count": 5,
				"cycle": [
					"E01",
					"E01",
					"E01",
					"E01",
					"E01",
					"E02",
					"E01",
					"E01",
					"E01",
					"E01",
					"E01",
					"E01"
				],
				"formation": "flank",
				"spawn_radius": 620,
				"formation_spread": 1.25,
				"intercept_lead": 1.0
			},
			{
				"at": 58.0,
				"interval": 0.648,
				"count": 5,
				"cycle": [
					"E01",
					"E01",
					"E01",
					"E01",
					"E01",
					"E02",
					"E01",
					"E01",
					"E01",
					"E01",
					"E01",
					"E01"
				],
				"formation": "intercept",
				"spawn_radius": 620,
				"formation_spread": 1.7,
				"intercept_lead": 1.0
			}
		],
		"boss_min_time": 29.0
	},
	"B04": {
		"boss_time": 85.0,
		"boss_kills": 141,
		"bonus_time": 130.0,
		"spawn_interval": 0.744,
		"enemy_cap": 64,
		"boss_hp": 1250.0,
		"boss_name": "押粮鬼尉·轭骨牛督",
		"seed": 1704,
		"enemy_hp": 1.2,
		"enemy_damage": 1.094,
		"boss_definition": "B04",
		"field_elites": [
			"L01",
			"L05"
		],
		"action_budget": {
			"major": 3,
			"melee": 6
		},
		"derivative_cap": 6,
		"boss_derivative_cap": 4,
		"role_caps": {
			"support": 1,
			"heavy": 2,
			"ranged": 5
		},
		"waves": [
			{
				"at": 0.0,
				"count": 4,
				"cycle": [
					"E01",
					"E01",
					"E01",
					"E01",
					"E01",
					"E03",
					"E01",
					"E01",
					"E01"
				],
				"interval": 0.744,
				"formation": "surround",
				"spawn_radius": 620,
				"formation_spread": 1.7,
				"intercept_lead": 1.0
			},
			{
				"at": 28.0,
				"interval": 0.684,
				"count": 5,
				"cycle": [
					"E01",
					"E01",
					"E04",
					"E01",
					"E01",
					"E01",
					"E01",
					"E01",
					"E03",
					"E01",
					"E01",
					"E02"
				],
				"formation": "flank",
				"spawn_radius": 620,
				"formation_spread": 1.25,
				"intercept_lead": 1.0
			},
			{
				"at": 58.0,
				"interval": 0.624,
				"count": 5,
				"cycle": [
					"E01",
					"E01",
					"E04",
					"E01",
					"E01",
					"E01",
					"E01",
					"E01",
					"E03",
					"E01",
					"E01",
					"E02"
				],
				"formation": "intercept",
				"spawn_radius": 620,
				"formation_spread": 1.7,
				"intercept_lead": 1.0
			}
		],
		"boss_min_time": 31.0
	},
	"B05": {
		"boss_time": 90.0,
		"boss_kills": 115,
		"bonus_time": 140.0,
		"spawn_interval": 0.732,
		"enemy_cap": 66,
		"boss_hp": 1150.0,
		"boss_name": "冥灯术士·悬灯道人",
		"seed": 1705,
		"enemy_hp": 1.2,
		"enemy_damage": 1.141,
		"boss_definition": "B05",
		"field_elites": [
			"L05",
			"L01"
		],
		"action_budget": {
			"major": 3,
			"melee": 6
		},
		"derivative_cap": 6,
		"boss_derivative_cap": 4,
		"role_caps": {
			"support": 1,
			"heavy": 2,
			"ranged": 5
		},
		"waves": [
			{
				"at": 0.0,
				"count": 4,
				"cycle": [
					"E01",
					"E01",
					"E01",
					"E01",
					"E01",
					"E04",
					"E01",
					"E01",
					"E05"
				],
				"interval": 0.732,
				"formation": "surround",
				"spawn_radius": 620,
				"formation_spread": 1.7,
				"intercept_lead": 1.0
			},
			{
				"at": 28.0,
				"interval": 0.672,
				"count": 5,
				"cycle": [
					"E01",
					"E01",
					"E05",
					"E01",
					"E01",
					"E01",
					"E01",
					"E01",
					"E06",
					"E01",
					"E01",
					"E04"
				],
				"formation": "flank",
				"spawn_radius": 620,
				"formation_spread": 1.25,
				"intercept_lead": 1.0
			},
			{
				"at": 58.0,
				"interval": 0.612,
				"count": 5,
				"cycle": [
					"E01",
					"E01",
					"E05",
					"E01",
					"E01",
					"E01",
					"E01",
					"E01",
					"E06",
					"E01",
					"E01",
					"E04"
				],
				"formation": "intercept",
				"spawn_radius": 620,
				"formation_spread": 1.7,
				"intercept_lead": 1.0
			}
		],
		"boss_min_time": 32.0
	},
	"B03": {
		"boss_time": 100.0,
		"boss_kills": 173,
		"bonus_time": 150.0,
		"spawn_interval": 0.756,
		"enemy_cap": 62,
		"boss_hp": 1750.0,
		"boss_name": "盘寨鬼魁·三面裂旗魁",
		"seed": 1703,
		"enemy_hp": 1.35,
		"enemy_damage": 1.188,
		"boss_definition": "B03",
		"field_elites": [
			"L05",
			"L01"
		],
		"action_budget": {
			"major": 3,
			"melee": 6
		},
		"derivative_cap": 6,
		"boss_derivative_cap": 4,
		"role_caps": {
			"support": 1,
			"heavy": 2,
			"ranged": 5
		},
		"waves": [
			{
				"at": 0.0,
				"count": 4,
				"cycle": [
					"E01",
					"E01",
					"E01",
					"E01",
					"E01",
					"E03",
					"E01",
					"E01",
					"E04",
					"E01",
					"E01",
					"E02"
				],
				"interval": 0.756,
				"formation": "surround",
				"spawn_radius": 620,
				"formation_spread": 1.7,
				"intercept_lead": 1.0
			},
			{
				"at": 28.0,
				"interval": 0.696,
				"count": 5,
				"cycle": [
					"E01",
					"E01",
					"E06",
					"E01",
					"E01",
					"E01",
					"E01",
					"E01",
					"E03",
					"E01",
					"E01",
					"E04"
				],
				"formation": "flank",
				"spawn_radius": 620,
				"formation_spread": 1.25,
				"intercept_lead": 1.0
			},
			{
				"at": 58.0,
				"interval": 0.636,
				"count": 5,
				"cycle": [
					"E01",
					"E01",
					"E06",
					"E01",
					"E01",
					"E01",
					"E01",
					"E01",
					"E03",
					"E01",
					"E01",
					"E04"
				],
				"formation": "intercept",
				"spawn_radius": 620,
				"formation_spread": 1.7,
				"intercept_lead": 1.0
			}
		],
		"boss_min_time": 30.0
	},
	"B06": {
		"boss_time": 105.0,
		"boss_kills": 154,
		"bonus_time": 160.0,
		"spawn_interval": 0.72,
		"enemy_cap": 68,
		"boss_hp": 2150.0,
		"boss_name": "荒祠镇将·祠脊石兽",
		"seed": 1706,
		"enemy_hp": 1.5,
		"enemy_damage": 1.235,
		"boss_definition": "B06",
		"field_elites": [
			"L01",
			"L05"
		],
		"action_budget": {
			"major": 3,
			"melee": 6
		},
		"derivative_cap": 6,
		"boss_derivative_cap": 4,
		"role_caps": {
			"support": 1,
			"heavy": 2,
			"ranged": 5
		},
		"waves": [
			{
				"at": 0.0,
				"count": 4,
				"cycle": [
					"E01",
					"E01",
					"E04",
					"E01",
					"E01",
					"E02",
					"E01",
					"E01",
					"E03"
				],
				"interval": 0.72,
				"formation": "surround",
				"spawn_radius": 620,
				"formation_spread": 1.7,
				"intercept_lead": 1.0
			},
			{
				"at": 28.0,
				"interval": 0.66,
				"count": 5,
				"cycle": [
					"E01",
					"E01",
					"E05",
					"E01",
					"E01",
					"E01",
					"E01",
					"E01",
					"E06",
					"E01",
					"E01",
					"E04"
				],
				"formation": "flank",
				"spawn_radius": 620,
				"formation_spread": 1.25,
				"intercept_lead": 1.0
			},
			{
				"at": 58.0,
				"interval": 0.6,
				"count": 5,
				"cycle": [
					"E01",
					"E01",
					"E05",
					"E01",
					"E01",
					"E01",
					"E01",
					"E01",
					"E06",
					"E01",
					"E01",
					"E04"
				],
				"formation": "intercept",
				"spawn_radius": 620,
				"formation_spread": 1.7,
				"intercept_lead": 1.0
			}
		],
		"boss_min_time": 33.0
	},
	"B07": {
		"boss_time": 95.0,
		"boss_kills": 144,
		"bonus_time": 175.0,
		"spawn_interval": 0.708,
		"enemy_cap": 70,
		"boss_hp": 2400.0,
		"boss_name": "官署号令者·悬印司令",
		"seed": 1707,
		"enemy_hp": 1.55,
		"enemy_damage": 1.282,
		"boss_definition": "B07",
		"field_elites": [
			"L03",
			"L06"
		],
		"action_budget": {
			"major": 4,
			"melee": 8
		},
		"derivative_cap": 6,
		"boss_derivative_cap": 4,
		"role_caps": {
			"support": 1,
			"heavy": 3,
			"ranged": 7
		},
		"waves": [
			{
				"at": 0.0,
				"count": 5,
				"cycle": [
					"E01",
					"E01",
					"E01",
					"E01",
					"E01",
					"E07",
					"E01",
					"E01",
					"E04",
					"E01",
					"E01",
					"E02"
				],
				"interval": 0.708,
				"formation": "surround",
				"spawn_radius": 620,
				"formation_spread": 1.7,
				"intercept_lead": 1.0
			},
			{
				"at": 34.0,
				"interval": 0.648,
				"count": 6,
				"cycle": [
					"E01",
					"E01",
					"E09",
					"E01",
					"E01",
					"E01",
					"E01",
					"E01",
					"E03",
					"E01",
					"E01",
					"E07"
				],
				"formation": "flank",
				"spawn_radius": 620,
				"formation_spread": 1.25,
				"intercept_lead": 1.0
			},
			{
				"at": 58.0,
				"interval": 0.588,
				"count": 6,
				"cycle": [
					"E01",
					"E01",
					"E09",
					"E01",
					"E01",
					"E01",
					"E01",
					"E01",
					"E03",
					"E01",
					"E01",
					"E07"
				],
				"formation": "intercept",
				"spawn_radius": 620,
				"formation_spread": 1.7,
				"intercept_lead": 1.0
			}
		],
		"boss_min_time": 34.0
	},
	"B08": {
		"boss_time": 100.0,
		"boss_kills": 154,
		"bonus_time": 180.0,
		"spawn_interval": 0.696,
		"enemy_cap": 72,
		"boss_hp": 2700.0,
		"boss_name": "水门冲将·闸齿鳄首",
		"seed": 1708,
		"enemy_hp": 1.65,
		"enemy_damage": 1.329,
		"boss_definition": "B08",
		"field_elites": [
			"L06",
			"L03"
		],
		"action_budget": {
			"major": 4,
			"melee": 8
		},
		"derivative_cap": 6,
		"boss_derivative_cap": 4,
		"role_caps": {
			"support": 1,
			"heavy": 3,
			"ranged": 7
		},
		"waves": [
			{
				"at": 0.0,
				"count": 5,
				"cycle": [
					"E01",
					"E01",
					"E03",
					"E01",
					"E01",
					"E04",
					"E01",
					"E01",
					"E02"
				],
				"interval": 0.696,
				"formation": "surround",
				"spawn_radius": 620,
				"formation_spread": 1.7,
				"intercept_lead": 1.0
			},
			{
				"at": 34.0,
				"interval": 0.636,
				"count": 6,
				"cycle": [
					"E01",
					"E01",
					"E10",
					"E01",
					"E01",
					"E01",
					"E01",
					"E01",
					"E07",
					"E01",
					"E01",
					"E03"
				],
				"formation": "flank",
				"spawn_radius": 620,
				"formation_spread": 1.25,
				"intercept_lead": 1.0
			},
			{
				"at": 58.0,
				"interval": 0.576,
				"count": 6,
				"cycle": [
					"E01",
					"E01",
					"E10",
					"E01",
					"E01",
					"E01",
					"E01",
					"E01",
					"E07",
					"E01",
					"E01",
					"E03"
				],
				"formation": "intercept",
				"spawn_radius": 620,
				"formation_spread": 1.7,
				"intercept_lead": 1.0
			}
		],
		"boss_min_time": 35.0
	},
	"B09": {
		"boss_time": 100.0,
		"boss_kills": 154,
		"bonus_time": 180.0,
		"spawn_interval": 0.684,
		"enemy_cap": 74,
		"boss_hp": 2850.0,
		"boss_name": "军械库将·炉腹铁鬼",
		"seed": 1709,
		"enemy_hp": 1.65,
		"enemy_damage": 1.376,
		"boss_definition": "B09",
		"field_elites": [
			"L03",
			"L06"
		],
		"action_budget": {
			"major": 4,
			"melee": 8
		},
		"derivative_cap": 6,
		"boss_derivative_cap": 4,
		"role_caps": {
			"support": 1,
			"heavy": 3,
			"ranged": 7
		},
		"waves": [
			{
				"at": 0.0,
				"count": 5,
				"cycle": [
					"E01",
					"E01",
					"E09",
					"E01",
					"E01",
					"E01",
					"E01",
					"E01",
					"E04"
				],
				"interval": 0.684,
				"formation": "surround",
				"spawn_radius": 620,
				"formation_spread": 1.7,
				"intercept_lead": 1.0
			},
			{
				"at": 34.0,
				"interval": 0.624,
				"count": 6,
				"cycle": [
					"E01",
					"E01",
					"E10",
					"E01",
					"E01",
					"E02",
					"E01",
					"E01",
					"E07",
					"E01",
					"E01",
					"E01"
				],
				"formation": "flank",
				"spawn_radius": 620,
				"formation_spread": 1.25,
				"intercept_lead": 1.0
			},
			{
				"at": 58.0,
				"interval": 0.564,
				"count": 6,
				"cycle": [
					"E01",
					"E01",
					"E10",
					"E01",
					"E01",
					"E02",
					"E01",
					"E01",
					"E07",
					"E01",
					"E01",
					"E01"
				],
				"formation": "intercept",
				"spawn_radius": 620,
				"formation_spread": 1.7,
				"intercept_lead": 1.0
			}
		],
		"boss_min_time": 36.0
	},
	"B10": {
		"boss_time": 110.0,
		"boss_kills": 173,
		"bonus_time": 195.0,
		"spawn_interval": 0.672,
		"enemy_cap": 76,
		"boss_hp": 3200.0,
		"boss_name": "封库双禁卫·左锁",
		"seed": 1710,
		"enemy_hp": 1.75,
		"enemy_damage": 1.424,
		"boss_definition": "B10",
		"field_elites": [
			"L06",
			"L03"
		],
		"action_budget": {
			"major": 4,
			"melee": 8
		},
		"derivative_cap": 6,
		"boss_derivative_cap": 4,
		"role_caps": {
			"support": 1,
			"heavy": 3,
			"ranged": 7
		},
		"waves": [
			{
				"at": 0.0,
				"count": 5,
				"cycle": [
					"E01",
					"E01",
					"E09",
					"E01",
					"E01",
					"E04",
					"E01",
					"E01",
					"E02"
				],
				"interval": 0.672,
				"formation": "surround",
				"spawn_radius": 620,
				"formation_spread": 1.7,
				"intercept_lead": 1.0
			},
			{
				"at": 34.0,
				"interval": 0.612,
				"count": 6,
				"cycle": [
					"E01",
					"E01",
					"E10",
					"E01",
					"E01",
					"E01",
					"E01",
					"E01",
					"E07",
					"E01",
					"E01",
					"E03"
				],
				"formation": "flank",
				"spawn_radius": 620,
				"formation_spread": 1.25,
				"intercept_lead": 1.0
			},
			{
				"at": 58.0,
				"interval": 0.552,
				"count": 6,
				"cycle": [
					"E01",
					"E01",
					"E10",
					"E01",
					"E01",
					"E01",
					"E01",
					"E01",
					"E07",
					"E01",
					"E01",
					"E03"
				],
				"formation": "intercept",
				"spawn_radius": 620,
				"formation_spread": 1.7,
				"intercept_lead": 1.0
			}
		],
		"boss_min_time": 37.0
	},
	"B11": {
		"boss_time": 100.0,
		"boss_kills": 154,
		"bonus_time": 185.0,
		"spawn_interval": 0.66,
		"enemy_cap": 78,
		"boss_hp": 3150.0,
		"boss_name": "巡城灯师·伞眼灯灵",
		"seed": 1711,
		"enemy_hp": 1.8,
		"enemy_damage": 1.471,
		"boss_definition": "B11",
		"field_elites": [
			"L02",
			"L03"
		],
		"action_budget": {
			"major": 4,
			"melee": 8
		},
		"derivative_cap": 6,
		"boss_derivative_cap": 4,
		"role_caps": {
			"support": 1,
			"heavy": 3,
			"ranged": 7
		},
		"waves": [
			{
				"at": 0.0,
				"count": 5,
				"cycle": [
					"E01",
					"E01",
					"E01",
					"E01",
					"E01",
					"E08",
					"E01",
					"E01",
					"E05",
					"E01",
					"E01",
					"E04"
				],
				"interval": 0.66,
				"formation": "surround",
				"spawn_radius": 620,
				"formation_spread": 1.7,
				"intercept_lead": 1.0
			},
			{
				"at": 34.0,
				"interval": 0.6,
				"count": 6,
				"cycle": [
					"E01",
					"E01",
					"E10",
					"E01",
					"E01",
					"E02",
					"E01",
					"E01",
					"E08",
					"E01",
					"E01",
					"E01"
				],
				"formation": "flank",
				"spawn_radius": 620,
				"formation_spread": 1.25,
				"intercept_lead": 1.0
			},
			{
				"at": 58.0,
				"interval": 0.54,
				"count": 6,
				"cycle": [
					"E01",
					"E01",
					"E10",
					"E01",
					"E01",
					"E02",
					"E01",
					"E01",
					"E08",
					"E01",
					"E01",
					"E01"
				],
				"formation": "intercept",
				"spawn_radius": 620,
				"formation_spread": 1.7,
				"intercept_lead": 1.0
			}
		],
		"boss_min_time": 38.0
	},
	"B12": {
		"boss_time": 110.0,
		"boss_kills": 173,
		"bonus_time": 200.0,
		"spawn_interval": 0.648,
		"enemy_cap": 80,
		"boss_hp": 3600.0,
		"boss_name": "瘟灯阵主·多手幡灯大巫",
		"seed": 1712,
		"enemy_hp": 1.9,
		"enemy_damage": 1.518,
		"boss_definition": "B12",
		"field_elites": [
			"L02",
			"L05"
		],
		"action_budget": {
			"major": 4,
			"melee": 8
		},
		"derivative_cap": 6,
		"boss_derivative_cap": 4,
		"role_caps": {
			"support": 1,
			"heavy": 3,
			"ranged": 7
		},
		"waves": [
			{
				"at": 0.0,
				"count": 5,
				"cycle": [
					"E01",
					"E01",
					"E01",
					"E01",
					"E01",
					"E11",
					"E01",
					"E01",
					"E05"
				],
				"interval": 0.648,
				"formation": "surround",
				"spawn_radius": 620,
				"formation_spread": 1.7,
				"intercept_lead": 1.0
			},
			{
				"at": 34.0,
				"interval": 0.588,
				"count": 6,
				"cycle": [
					"E01",
					"E01",
					"E08",
					"E01",
					"E01",
					"E04",
					"E01",
					"E01",
					"E06",
					"E01",
					"E01",
					"E11"
				],
				"formation": "flank",
				"spawn_radius": 620,
				"formation_spread": 1.25,
				"intercept_lead": 1.0
			},
			{
				"at": 58.0,
				"interval": 0.528,
				"count": 6,
				"cycle": [
					"E01",
					"E01",
					"E08",
					"E01",
					"E01",
					"E04",
					"E01",
					"E01",
					"E06",
					"E01",
					"E01",
					"E11"
				],
				"formation": "intercept",
				"spawn_radius": 620,
				"formation_spread": 1.7,
				"intercept_lead": 1.0
			}
		],
		"boss_min_time": 39.0
	},
	"B13": {
		"boss_time": 105.0,
		"boss_kills": 166,
		"bonus_time": 195.0,
		"spawn_interval": 0.636,
		"enemy_cap": 82,
		"boss_hp": 3650.0,
		"boss_name": "城垣冲将·石鸱裂垛",
		"seed": 1713,
		"enemy_hp": 2,
		"enemy_damage": 1.565,
		"boss_definition": "B13",
		"field_elites": [
			"L04",
			"L06"
		],
		"action_budget": {
			"major": 5,
			"melee": 10
		},
		"derivative_cap": 6,
		"boss_derivative_cap": 4,
		"role_caps": {
			"support": 2,
			"heavy": 4,
			"ranged": 9
		},
		"waves": [
			{
				"at": 0.0,
				"count": 6,
				"cycle": [
					"E01",
					"E01",
					"E03",
					"E01",
					"E01",
					"E04",
					"E01",
					"E01",
					"E07",
					"E01",
					"E01",
					"E02"
				],
				"interval": 0.636,
				"formation": "surround",
				"spawn_radius": 620,
				"formation_spread": 1.7,
				"intercept_lead": 1.0
			},
			{
				"at": 34.0,
				"interval": 0.576,
				"count": 7,
				"cycle": [
					"E01",
					"E01",
					"E09",
					"E01",
					"E01",
					"E05",
					"E01",
					"E01",
					"E01",
					"E01",
					"E01",
					"E10"
				],
				"formation": "flank",
				"spawn_radius": 620,
				"formation_spread": 1.25,
				"intercept_lead": 1.0
			},
			{
				"at": 58.0,
				"interval": 0.516,
				"count": 7,
				"cycle": [
					"E01",
					"E01",
					"E09",
					"E01",
					"E01",
					"E05",
					"E01",
					"E01",
					"E01",
					"E01",
					"E01",
					"E10"
				],
				"formation": "intercept",
				"spawn_radius": 620,
				"formation_spread": 1.7,
				"intercept_lead": 1.0
			}
		],
		"boss_min_time": 40.0
	},
	"B14": {
		"boss_time": 105.0,
		"boss_kills": 166,
		"bonus_time": 195.0,
		"spawn_interval": 0.624,
		"enemy_cap": 84,
		"boss_hp": 3650.0,
		"boss_name": "渡口号令者·引舟鬼帅",
		"seed": 1714,
		"enemy_hp": 2,
		"enemy_damage": 1.612,
		"boss_definition": "B14",
		"field_elites": [
			"L04",
			"L02"
		],
		"action_budget": {
			"major": 5,
			"melee": 10
		},
		"derivative_cap": 6,
		"boss_derivative_cap": 4,
		"role_caps": {
			"support": 2,
			"heavy": 4,
			"ranged": 9
		},
		"waves": [
			{
				"at": 0.0,
				"count": 6,
				"cycle": [
					"E01",
					"E01",
					"E01",
					"E01",
					"E01",
					"E12",
					"E01",
					"E01",
					"E07",
					"E01",
					"E01",
					"E02"
				],
				"interval": 0.624,
				"formation": "surround",
				"spawn_radius": 620,
				"formation_spread": 1.7,
				"intercept_lead": 1.0
			},
			{
				"at": 34.0,
				"interval": 0.564,
				"count": 7,
				"cycle": [
					"E01",
					"E01",
					"E10",
					"E01",
					"E01",
					"E05",
					"E01",
					"E01",
					"E04",
					"E01",
					"E01",
					"E01"
				],
				"formation": "flank",
				"spawn_radius": 620,
				"formation_spread": 1.25,
				"intercept_lead": 1.0
			},
			{
				"at": 58.0,
				"interval": 0.504,
				"count": 7,
				"cycle": [
					"E01",
					"E01",
					"E10",
					"E01",
					"E01",
					"E05",
					"E01",
					"E01",
					"E04",
					"E01",
					"E01",
					"E01"
				],
				"formation": "intercept",
				"spawn_radius": 620,
				"formation_spread": 1.7,
				"intercept_lead": 1.0
			}
		],
		"boss_min_time": 40.0
	},
	"B15": {
		"boss_time": 110.0,
		"boss_kills": 179,
		"bonus_time": 205.0,
		"spawn_interval": 0.612,
		"enemy_cap": 86,
		"boss_hp": 4300.0,
		"boss_name": "曹休",
		"seed": 1715,
		"enemy_hp": 2.15,
		"enemy_damage": 1.659,
		"boss_definition": "B15",
		"field_elites": [
			"L04",
			"L01"
		],
		"action_budget": {
			"major": 5,
			"melee": 10
		},
		"derivative_cap": 6,
		"boss_derivative_cap": 4,
		"role_caps": {
			"support": 2,
			"heavy": 4,
			"ranged": 9
		},
		"waves": [
			{
				"at": 0.0,
				"count": 6,
				"cycle": [
					"E01",
					"E01",
					"E12",
					"E01",
					"E01",
					"E02",
					"E01",
					"E01",
					"E07",
					"E01",
					"E01",
					"E01"
				],
				"interval": 0.612,
				"formation": "surround",
				"spawn_radius": 620,
				"formation_spread": 1.7,
				"intercept_lead": 1.0
			},
			{
				"at": 34.0,
				"interval": 0.552,
				"count": 7,
				"cycle": [
					"E01",
					"E01",
					"E09",
					"E01",
					"E01",
					"E05",
					"E01",
					"E01",
					"E03",
					"E01",
					"E01",
					"E04"
				],
				"formation": "flank",
				"spawn_radius": 620,
				"formation_spread": 1.25,
				"intercept_lead": 1.0
			},
			{
				"at": 58.0,
				"interval": 0.492,
				"count": 7,
				"cycle": [
					"E01",
					"E01",
					"E09",
					"E01",
					"E01",
					"E05",
					"E01",
					"E01",
					"E03",
					"E01",
					"E01",
					"E04"
				],
				"formation": "intercept",
				"spawn_radius": 620,
				"formation_spread": 1.7,
				"intercept_lead": 1.0
			}
		],
		"boss_min_time": 40.0
	},
	"B16": {
		"boss_time": 115.0,
		"boss_kills": 192,
		"bonus_time": 215.0,
		"spawn_interval": 0.6,
		"enemy_cap": 88,
		"boss_hp": 4800.0,
		"boss_name": "曹纯",
		"seed": 1716,
		"enemy_hp": 2.25,
		"enemy_damage": 1.706,
		"boss_definition": "B16",
		"field_elites": [
			"L06",
			"L04"
		],
		"action_budget": {
			"major": 5,
			"melee": 10
		},
		"derivative_cap": 6,
		"boss_derivative_cap": 4,
		"role_caps": {
			"support": 2,
			"heavy": 4,
			"ranged": 9
		},
		"waves": [
			{
				"at": 0.0,
				"count": 6,
				"cycle": [
					"E01",
					"E01",
					"E11",
					"E01",
					"E01",
					"E04",
					"E01",
					"E01",
					"E02",
					"E01",
					"E01",
					"E01"
				],
				"interval": 0.6,
				"formation": "surround",
				"spawn_radius": 620,
				"formation_spread": 1.7,
				"intercept_lead": 1.0
			},
			{
				"at": 34.0,
				"interval": 0.54,
				"count": 7,
				"cycle": [
					"E01",
					"E01",
					"E12",
					"E01",
					"E01",
					"E08",
					"E01",
					"E01",
					"E03",
					"E01",
					"E01",
					"E05"
				],
				"formation": "flank",
				"spawn_radius": 620,
				"formation_spread": 1.25,
				"intercept_lead": 1.0
			},
			{
				"at": 58.0,
				"interval": 0.48,
				"count": 7,
				"cycle": [
					"E01",
					"E01",
					"E12",
					"E01",
					"E01",
					"E08",
					"E01",
					"E01",
					"E03",
					"E01",
					"E01",
					"E05"
				],
				"formation": "intercept",
				"spawn_radius": 620,
				"formation_spread": 1.7,
				"intercept_lead": 1.0
			}
		],
		"boss_min_time": 40.0
	},
	"B17": {
		"boss_time": 115.0,
		"boss_kills": 192,
		"bonus_time": 215.0,
		"spawn_interval": 0.588,
		"enemy_cap": 90,
		"boss_hp": 6200.0,
		"boss_name": "张辽",
		"seed": 1717,
		"enemy_hp": 2.35,
		"enemy_damage": 1.753,
		"boss_definition": "B17",
		"field_elites": [
			"L03",
			"L05"
		],
		"action_budget": {
			"major": 5,
			"melee": 10
		},
		"derivative_cap": 6,
		"boss_derivative_cap": 4,
		"role_caps": {
			"support": 2,
			"heavy": 4,
			"ranged": 9
		},
		"waves": [
			{
				"at": 0.0,
				"count": 6,
				"cycle": [
					"E01",
					"E01",
					"E09",
					"E01",
					"E01",
					"E07",
					"E01",
					"E01",
					"E04",
					"E01",
					"E01",
					"E02"
				],
				"interval": 0.588,
				"formation": "surround",
				"spawn_radius": 620,
				"formation_spread": 1.7,
				"intercept_lead": 1.0
			},
			{
				"at": 34.0,
				"interval": 0.528,
				"count": 7,
				"cycle": [
					"E01",
					"E01",
					"E12",
					"E01",
					"E01",
					"E05",
					"E01",
					"E01",
					"E11",
					"E01",
					"E01",
					"E01"
				],
				"formation": "flank",
				"spawn_radius": 620,
				"formation_spread": 1.25,
				"intercept_lead": 1.0
			},
			{
				"at": 58.0,
				"interval": 0.468,
				"count": 7,
				"cycle": [
					"E01",
					"E01",
					"E12",
					"E01",
					"E01",
					"E05",
					"E01",
					"E01",
					"E11",
					"E01",
					"E01",
					"E01"
				],
				"formation": "intercept",
				"spawn_radius": 620,
				"formation_spread": 1.7,
				"intercept_lead": 1.0
			}
		],
		"boss_min_time": 40.0
	},
	"B18": {
		"encounter_mode": "boss_duel",
		"fields_enabled": false,
		"boss_time": 0.0,
		"boss_kills": 0,
		"bonus_time": 100.0,
		"spawn_interval": 1.35,
		"enemy_cap": 0,
		"boss_hp": 7600.0,
		"boss_name": "吕布",
		"seed": 1718,
		"enemy_hp": 2.5,
		"enemy_damage": 1.8,
		"boss_definition": "B18",
		"field_elites": [],
		"action_budget": {
			"major": 2,
			"melee": 2
		},
		"derivative_cap": 0,
		"boss_derivative_cap": 0,
		"role_caps": {
			"support": 1,
			"heavy": 2,
			"ranged": 4
		},
		"waves": [],
		"boss_min_time": 0.0
	}
}

static func stage(id: String) -> Dictionary:
	return STAGES.get(id, {}).duplicate(true)

## Fail before simulation when a stage cannot supply its authored spawn definitions.
static func runtime_errors(value: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in ["boss_definition", "boss_time", "boss_kills", "boss_hp", "bonus_time", "enemy_hp", "enemy_damage", "enemy_cap", "spawn_interval", "waves", "field_elites"]:
		if not value.has(key): errors.append("missing " + key)
	if not errors.is_empty(): return errors
	var boss := ENEMIES.definition(str(value.boss_definition))
	if boss.get("rank", "") != "boss": errors.append("invalid boss definition " + str(value.boss_definition))
	for error in ENEMIES.runtime_errors(boss): errors.append("boss: " + error)
	if float(value.boss_hp) <= 0: errors.append("invalid boss health")
	var duel := str(value.get("encounter_mode", "")) == "boss_duel"
	if duel:
		if float(value.boss_time) != 0 or int(value.boss_kills) != 0: errors.append("duel must begin immediately")
		if bool(value.get("fields_enabled", true)) or not value.field_elites.is_empty() or not value.waves.is_empty() or int(value.enemy_cap) != 0: errors.append("duel cannot spawn waves or field elites")
	else:
		if value.waves.is_empty() or float(value.waves[0].get("at", -1)) != 0: errors.append("ordinary encounter requires a wave at time zero")
		if bool(value.get("fields_enabled", true)) and value.field_elites.size() != 2: errors.append("two field elite definitions required")
	for elite_id in value.field_elites:
		var elite := ENEMIES.definition(str(elite_id))
		if elite.get("rank", "") != "field_elite": errors.append("invalid field elite " + str(elite_id))
		for error in ENEMIES.runtime_errors(elite): errors.append(str(elite_id) + ": " + error)
	var previous_time := -1.0
	for wave in value.waves:
		for key in ["at", "count", "cycle"]:
			if not wave.has(key): errors.append("wave missing " + key)
		if not wave.has_all(["at", "count", "cycle"]): continue
		if float(wave.at) < previous_time or float(wave.get("interval", value.spawn_interval)) <= 0 or int(wave.count) <= 0: errors.append("invalid wave schedule")
		previous_time = float(wave.at)
		if wave.cycle.is_empty(): errors.append("empty authored wave cycle")
		for enemy_id in wave.cycle:
			var enemy := ENEMIES.definition(str(enemy_id))
			if enemy.get("rank", "") not in ["ordinary", "heavy"]: errors.append("invalid ordinary definition " + str(enemy_id))
			for error in ENEMIES.runtime_errors(enemy): errors.append(str(enemy_id) + ": " + error)
	return errors

static func validate() -> Array:
	var errors: Array = []
	if STAGES.size() != 18: errors.append("chapter must author all 18 combat nodes")
	for id in STAGES:
		var value: Dictionary = STAGES[id]
		for error in runtime_errors(value): errors.append(id + ": " + error)
		var boss := ENEMIES.definition(value.boss_definition)
		if boss.is_empty() or boss.rank != "boss": errors.append(id + ": invalid boss")
		var duel := str(value.get("encounter_mode", "")) == "boss_duel"
		if value.boss_hp <= 0: errors.append(id + ": invalid boss health")
		if duel:
			if value.boss_time != 0 or value.boss_kills != 0: errors.append(id + ": duel must begin immediately")
			if value.get("fields_enabled", true) or not value.field_elites.is_empty() or not value.waves.is_empty(): errors.append(id + ": duel must not offer reinforcements or fields")
			if value.enemy_cap != 0 or value.derivative_cap != 0 or value.boss_derivative_cap != 0: errors.append(id + ": duel population must contain only its boss")
		else:
			if value.boss_time <= 0 or value.boss_kills <= 0: errors.append(id + ": invalid gate")
			if value.field_elites.size() != 2: errors.append(id + ": two reward slot profiles required")
		for elite_id in value.field_elites:
			if ENEMIES.definition(elite_id).get("rank") != "field_elite": errors.append(id + ": invalid field elite")
		if not duel and (value.enemy_cap < 58 or value.enemy_cap > 94): errors.append(id + ": ordinary cap outside authored range")
		if value.action_budget.major != (2 if duel else (3 if int(id.substr(1)) <= 6 else (4 if int(id.substr(1)) <= 12 else 5))): errors.append(id + ": action budget mismatch")
		for wave in value.waves:
			if wave.cycle.is_empty(): errors.append(id + ": empty wave")
			for enemy_id in wave.cycle:
				if enemy_id not in ENEMIES.ordinary_ids(): errors.append(id + ": invalid ordinary " + enemy_id)
	return errors
