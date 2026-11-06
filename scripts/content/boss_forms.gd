extends RefCounted
## Each encounter spends one stage HP budget across two authored forms.
## Shapes use the same descriptors for warning drawing, reachability and hits.
const FORM_COPY := {
	"B15": [
		{
			"description": "曹休以瞄准射击和扇形箭矢压制远处，随后直线突进。",
			"counterplay": [
				"横移离开瞄准线，从扇箭间隙接近。",
				"避开突进路线，趁曹休收势反击。"
			]
		},
		{
			"description": "鬼猎兽相以扇射、扑击和落点重击追猎，近处还有大范围横扫。",
			"counterplay": [
				"从扇箭间隙穿过，横移避开扑击路线。",
				"离开地面标记，等横扫结束再接近。"
			]
		}
	],
	"B16": [
		{
			"description": "曹纯持枪直冲，穿插近身横斩，再次发起冲击。",
			"counterplay": [
				"看清冲锋方向，横移离开路线。",
				"避开横斩后，趁收势接近攻击。"
			]
		},
		{
			"description": "虎豹甲骑巨相以长冲与踏击压制战场，还会引发带缺口的环形震击。",
			"counterplay": [
				"横移离开冲锋路线，等他停步后反击。",
				"朝震击缺口移动，或退出震击范围。"
			]
		}
	],
	"B17": [
		{
			"description": "张辽以突进和横斩主攻，高顺与陈宫轮流协同。",
			"counterplay": [
				"高顺列阵时离开路线；陈宫布阵时离开落点。",
				"避过协同后，趁张辽回气反击。"
			]
		},
		{
			"description": "夜叉将相以冲阵、横斩和环形震击施压，高顺与陈宫仍轮流协同。",
			"counterplay": [
				"看清震击缺口，沿空处移动。",
				"注意高顺的直线与陈宫的落点，避过后攻击张辽。"
			]
		}
	],
	"B18": [
		{
			"description": "吕布独自持戟迎战，以横扫、突进和落戟交替进攻。",
			"counterplay": [
				"横移避开突进路线，离开落戟标记。",
				"避过戟刃横扫，趁收势接近反击。"
			]
		},
		{
			"description": "四臂鬼神相挥戟横扫、长冲，以环形震击与落戟覆盖大片战场。",
			"counterplay": [
				"沿环形震击的缺口移动，或退出震击范围。",
				"避开长冲路线与落戟标记，趁吕布收势反击。"
			]
		}
	]
}

const FORM_DEFINITIONS := {
	"B15": [
		{
			"name": "曹休",
			"body_height": 120,
			"radius": 30,
			"speed": 66,
			"attacks": [
				{
					"id": "hunter_aim",
					"action": "shot",
					"shape": "line",
					"range": 1300,
					"windup": 0.9,
					"recovery": 1.102,
					"damage_scale": 1.0,
					"major": true,
					"length": 1300,
					"half_width": 12,
					"speed": 420,
					"life": 3.2,
					"warning_policy": "aim",
					"bullet_style": "needle",
					"hit_radius": 4.0,
					"burst_count": 3,
					"burst_interval": 0.24,
					"angle_step": 0.08,
					"aim_each_burst": true
				},
				{
					"id": "hunter_volley",
					"action": "fan",
					"shape": "fan",
					"range": 1200,
					"windup": 1.0,
					"recovery": 1.218,
					"damage_scale": 0.8,
					"major": true,
					"radius": 1200,
					"count": 19,
					"spread": 2.8,
					"speed": 260,
					"life": 5.0,
					"warning_policy": "none",
					"bullet_style": "orb",
					"hit_radius": 4.0,
					"burst_count": 3,
					"burst_interval": 0.32,
					"angle_step": 0.08,
					"aim_each_burst": false
				},
				{
					"id": "hunter_reposition",
					"action": "charge",
					"shape": "line",
					"range": 820,
					"windup": 1.15,
					"recovery": 1.508,
					"damage_scale": 0.9,
					"major": true,
					"length": 820,
					"half_width": 38.4,
					"warning_policy": "area",
					"secondary_pattern": {
						"kind": "fan",
						"count": 23,
						"speed": 205,
						"life": 5.0,
						"hit_radius": 4.5,
						"burst_count": 2,
						"burst_interval": 0.34,
						"angle_step": 0.14,
						"angle_offset": 0.0,
						"aim_each_burst": false,
						"bullet_style": "orb",
						"spread": 4.0
					}
				}
			]
		},
		{
			"name": "鬼猎兽相",
			"body_height": 204,
			"radius": 43,
			"speed": 78,
			"attacks": [
				{
					"id": "beast_hunt",
					"action": "fan",
					"shape": "fan",
					"range": 1200,
					"windup": 1.0,
					"recovery": 1.16,
					"damage_scale": 0.9,
					"major": true,
					"radius": 1200,
					"count": 27,
					"spread": 3.8,
					"speed": 240,
					"life": 5.0,
					"warning_policy": "none",
					"bullet_style": "orb",
					"hit_radius": 4.0,
					"burst_count": 4,
					"burst_interval": 0.32,
					"angle_step": 0.08,
					"aim_each_burst": false
				},
				{
					"id": "beast_leap",
					"action": "charge",
					"shape": "line",
					"range": 820,
					"windup": 1.25,
					"recovery": 1.276,
					"damage_scale": 1.15,
					"major": true,
					"length": 820,
					"half_width": 60.0,
					"warning_policy": "area",
					"secondary_pattern": {
						"kind": "fan",
						"count": 31,
						"speed": 205,
						"life": 5.0,
						"hit_radius": 4.5,
						"burst_count": 3,
						"burst_interval": 0.34,
						"angle_step": 0.14,
						"angle_offset": 0.0,
						"aim_each_burst": false,
						"bullet_style": "orb",
						"spread": 4.0
					}
				},
				{
					"id": "hunt_mark",
					"action": "marker",
					"shape": "marker",
					"range": 1050,
					"windup": 1.227,
					"recovery": 1.276,
					"damage_scale": 1.1,
					"major": true,
					"radius": 208.79999999999998,
					"warning_policy": "area",
					"marker_count": 5,
					"marker_spacing": 334.08,
					"marker_delay": 0.18,
					"secondary_pattern": {
						"kind": "ring",
						"count": 44,
						"speed": 175,
						"life": 5.0,
						"hit_radius": 4.5,
						"burst_count": 2,
						"burst_interval": 0.34,
						"angle_step": 0.1,
						"angle_offset": 0.0,
						"aim_each_burst": false,
						"bullet_style": "orb",
						"gap_width": 1.1,
						"gap_angle_offset": 0.65
					}
				},
				{
					"id": "beast_rend",
					"action": "slam",
					"shape": "sector",
					"range": 341.59999999999997,
					"windup": 1.25,
					"recovery": 1.798,
					"damage_scale": 1.2,
					"major": true,
					"radius": 341.59999999999997,
					"spread": 2.6,
					"warning_policy": "area",
					"secondary_pattern": {
						"kind": "ring",
						"count": 44,
						"speed": 195,
						"life": 5.0,
						"hit_radius": 4.5,
						"burst_count": 2,
						"burst_interval": 0.34,
						"angle_step": 0.12,
						"angle_offset": 0.0,
						"aim_each_burst": false,
						"bullet_style": "orb",
						"gap_width": 1.0,
						"gap_angle_offset": 0.65
					}
				}
			]
		}
	],
	"B16": [
		{
			"name": "曹纯",
			"body_height": 128,
			"radius": 31,
			"speed": 62,
			"attacks": [
				{
					"id": "rider_lance",
					"action": "charge",
					"shape": "line",
					"range": 820,
					"windup": 1.15,
					"recovery": 1.276,
					"damage_scale": 1.0,
					"major": true,
					"length": 820,
					"half_width": 45.6,
					"warning_policy": "area",
					"secondary_pattern": {
						"kind": "fan",
						"count": 23,
						"speed": 205,
						"life": 5.0,
						"hit_radius": 4.5,
						"burst_count": 2,
						"burst_interval": 0.34,
						"angle_step": 0.14,
						"angle_offset": 0.0,
						"aim_each_burst": false,
						"bullet_style": "orb",
						"spread": 4.0
					}
				},
				{
					"id": "rider_cleave",
					"action": "slam",
					"shape": "sector",
					"range": 280.59999999999997,
					"windup": 1.25,
					"recovery": 1.218,
					"damage_scale": 0.9,
					"major": true,
					"radius": 280.59999999999997,
					"spread": 2.4,
					"warning_policy": "area",
					"secondary_pattern": {
						"kind": "ring",
						"count": 32,
						"speed": 180,
						"life": 5.0,
						"hit_radius": 4.5,
						"burst_count": 2,
						"burst_interval": 0.34,
						"angle_step": 0.12,
						"angle_offset": 0.0,
						"aim_each_burst": false,
						"bullet_style": "orb",
						"gap_width": 1.0,
						"gap_angle_offset": 0.65
					}
				},
				{
					"id": "rider_return",
					"action": "charge",
					"shape": "line",
					"range": 820,
					"windup": 1.15,
					"recovery": 1.74,
					"damage_scale": 1.1,
					"major": true,
					"length": 820,
					"half_width": 50.4,
					"warning_policy": "area",
					"secondary_pattern": {
						"kind": "fan",
						"count": 23,
						"speed": 205,
						"life": 5.0,
						"hit_radius": 4.5,
						"burst_count": 2,
						"burst_interval": 0.34,
						"angle_step": 0.14,
						"angle_offset": 0.0,
						"aim_each_burst": false,
						"bullet_style": "orb",
						"spread": 4.0
					}
				}
			]
		},
		{
			"name": "虎豹甲骑巨相",
			"body_height": 218,
			"radius": 44,
			"speed": 70,
			"attacks": [
				{
					"id": "tiger_long_charge",
					"action": "charge",
					"shape": "line",
					"range": 1125.0,
					"windup": 1.25,
					"recovery": 1.45,
					"damage_scale": 1.2,
					"major": true,
					"length": 1125.0,
					"half_width": 74.39999999999999,
					"warning_policy": "area",
					"secondary_pattern": {
						"kind": "fan",
						"count": 31,
						"speed": 205,
						"life": 5.0,
						"hit_radius": 4.5,
						"burst_count": 3,
						"burst_interval": 0.34,
						"angle_step": 0.14,
						"angle_offset": 0.0,
						"aim_each_burst": false,
						"bullet_style": "orb",
						"spread": 4.0
					}
				},
				{
					"id": "tiger_trample",
					"action": "slam",
					"shape": "sector",
					"range": 378.2,
					"windup": 1.337,
					"recovery": 1.276,
					"damage_scale": 1.05,
					"major": true,
					"radius": 378.2,
					"spread": 2.8,
					"warning_policy": "area",
					"secondary_pattern": {
						"kind": "ring",
						"count": 44,
						"speed": 195,
						"life": 5.0,
						"hit_radius": 4.5,
						"burst_count": 2,
						"burst_interval": 0.34,
						"angle_step": 0.12,
						"angle_offset": 0.0,
						"aim_each_burst": false,
						"bullet_style": "orb",
						"gap_width": 1.0,
						"gap_angle_offset": 0.65
					}
				},
				{
					"id": "leopard_return",
					"action": "charge",
					"shape": "line",
					"range": 900.0,
					"windup": 1.25,
					"recovery": 1.392,
					"damage_scale": 1.1,
					"major": true,
					"length": 900.0,
					"half_width": 64.8,
					"warning_policy": "area",
					"secondary_pattern": {
						"kind": "fan",
						"count": 31,
						"speed": 205,
						"life": 5.0,
						"hit_radius": 4.5,
						"burst_count": 3,
						"burst_interval": 0.34,
						"angle_step": 0.14,
						"angle_offset": 0.0,
						"aim_each_burst": false,
						"bullet_style": "orb",
						"spread": 4.0
					}
				},
				{
					"id": "cavalry_break",
					"action": "pulse",
					"shape": "ring_gap",
					"range": 468.0,
					"windup": 1.8,
					"recovery": 1.972,
					"damage_scale": 1.25,
					"major": true,
					"radius": 468.0,
					"inner_radius": 85,
					"gap_width": 1.75,
					"gap_angle": 0.9,
					"warning_policy": "area",
					"secondary_pattern": {
						"kind": "ring",
						"count": 44,
						"speed": 185,
						"life": 5.0,
						"hit_radius": 4.5,
						"burst_count": 3,
						"burst_interval": 0.34,
						"angle_step": 0.1,
						"angle_offset": 0.0,
						"aim_each_burst": false,
						"bullet_style": "orb",
						"gap_width": 1.0,
						"gap_angle_offset": 0.65
					}
				}
			]
		}
	],
	"B17": [
		{
			"name": "张辽",
			"body_height": 130,
			"radius": 32,
			"speed": 64,
			"attacks": [
				{
					"id": "general_lunge",
					"action": "charge",
					"shape": "line",
					"range": 820,
					"windup": 1.15,
					"recovery": 1.044,
					"damage_scale": 1.0,
					"major": true,
					"length": 820,
					"half_width": 45.6,
					"warning_policy": "area",
					"secondary_pattern": {
						"kind": "fan",
						"count": 23,
						"speed": 205,
						"life": 5.0,
						"hit_radius": 4.5,
						"burst_count": 2,
						"burst_interval": 0.34,
						"angle_step": 0.14,
						"angle_offset": 0.0,
						"aim_each_burst": false,
						"bullet_style": "orb",
						"spread": 4.0
					}
				},
				{
					"id": "general_cut",
					"action": "slam",
					"shape": "sector",
					"range": 298.9,
					"windup": 1.25,
					"recovery": 0.986,
					"damage_scale": 0.95,
					"major": true,
					"radius": 298.9,
					"spread": 2.4,
					"warning_policy": "area",
					"secondary_pattern": {
						"kind": "ring",
						"count": 32,
						"speed": 180,
						"life": 5.0,
						"hit_radius": 4.5,
						"burst_count": 2,
						"burst_interval": 0.34,
						"angle_step": 0.12,
						"angle_offset": 0.0,
						"aim_each_burst": false,
						"bullet_style": "orb",
						"gap_width": 1.0,
						"gap_angle_offset": 0.65
					},
					"approach_speed": 210
				},
				{
					"id": "human_formation",
					"action": "collaboration",
					"shape": "line",
					"range": 1200,
					"windup": 1.4,
					"recovery": 1.5,
					"damage_scale": 1.0,
					"major": true,
					"length": 1100,
					"half_width": 80,
					"radius": 225,
					"warning_policy": "area",
					"marker_count": 3,
					"marker_spacing": 320,
					"marker_delay": 0.22,
					"secondary_pattern": {
						"kind": "fan",
						"count": 27,
						"speed": 200,
						"life": 5.0,
						"hit_radius": 4.5,
						"burst_count": 3,
						"burst_interval": 0.34,
						"angle_step": 0.12,
						"angle_offset": 0.0,
						"aim_each_burst": false,
						"bullet_style": "orb",
						"spread": 4.6
					}
				}
			]
		},
		{
			"name": "夜叉裂阵将相",
			"body_height": 220,
			"radius": 45,
			"speed": 72,
			"attacks": [
				{
					"id": "yaksha_break",
					"action": "charge",
					"shape": "line",
					"range": 825.0,
					"windup": 1.25,
					"recovery": 1.102,
					"damage_scale": 1.1,
					"major": true,
					"length": 825.0,
					"half_width": 64.8,
					"warning_policy": "area",
					"secondary_pattern": {
						"kind": "fan",
						"count": 31,
						"speed": 205,
						"life": 5.0,
						"hit_radius": 4.5,
						"burst_count": 3,
						"burst_interval": 0.34,
						"angle_step": 0.14,
						"angle_offset": 0.0,
						"aim_each_burst": false,
						"bullet_style": "orb",
						"spread": 4.0
					}
				},
				{
					"id": "yaksha_cleave",
					"action": "slam",
					"shape": "sector",
					"range": 414.8,
					"windup": 1.466,
					"recovery": 1.044,
					"damage_scale": 1.05,
					"major": true,
					"radius": 414.8,
					"spread": 2.65,
					"warning_policy": "area",
					"secondary_pattern": {
						"kind": "ring",
						"count": 44,
						"speed": 195,
						"life": 5.0,
						"hit_radius": 4.5,
						"burst_count": 2,
						"burst_interval": 0.34,
						"angle_step": 0.12,
						"angle_offset": 0.0,
						"aim_each_burst": false,
						"bullet_style": "orb",
						"gap_width": 1.0,
						"gap_angle_offset": 0.65
					}
				},
				{
					"id": "war_formation",
					"action": "collaboration",
					"shape": "line",
					"range": 1200,
					"windup": 1.4,
					"recovery": 1.5,
					"damage_scale": 1.15,
					"major": true,
					"length": 1100,
					"half_width": 80,
					"radius": 225,
					"warning_policy": "area",
					"marker_count": 3,
					"marker_spacing": 320,
					"marker_delay": 0.22,
					"secondary_pattern": {
						"kind": "fan",
						"count": 35,
						"speed": 200,
						"life": 5.0,
						"hit_radius": 4.5,
						"burst_count": 3,
						"burst_interval": 0.34,
						"angle_step": 0.12,
						"angle_offset": 0.0,
						"aim_each_burst": false,
						"bullet_style": "orb",
						"spread": 4.6
					}
				},
				{
					"id": "yaksha_pulse",
					"action": "pulse",
					"shape": "ring_gap",
					"range": 504.0,
					"windup": 1.8,
					"recovery": 1.972,
					"damage_scale": 1.2,
					"major": true,
					"radius": 504.0,
					"inner_radius": 90,
					"gap_width": 1.75,
					"gap_angle": 0.9,
					"warning_policy": "area",
					"secondary_pattern": {
						"kind": "ring",
						"count": 44,
						"speed": 185,
						"life": 5.0,
						"hit_radius": 4.5,
						"burst_count": 3,
						"burst_interval": 0.34,
						"angle_step": 0.1,
						"angle_offset": 0.0,
						"aim_each_burst": false,
						"bullet_style": "orb",
						"gap_width": 1.0,
						"gap_angle_offset": 0.65
					}
				}
			]
		}
	],
	"B18": [
		{
			"name": "吕布",
			"body_height": 144,
			"radius": 34,
			"speed": 70,
			"attacks": [
				{
					"id": "halberd_sweep",
					"action": "slam",
					"shape": "sector",
					"range": 366.0,
					"windup": 1.294,
					"recovery": 1.102,
					"damage_scale": 1.0,
					"major": true,
					"radius": 366.0,
					"spread": 2.5,
					"warning_policy": "area",
					"secondary_pattern": {
						"kind": "ring",
						"count": 32,
						"speed": 180,
						"life": 5.0,
						"hit_radius": 4.5,
						"burst_count": 2,
						"burst_interval": 0.34,
						"angle_step": 0.12,
						"angle_offset": 0.0,
						"aim_each_burst": false,
						"bullet_style": "orb",
						"gap_width": 1.0,
						"gap_angle_offset": 0.65
					}
				},
				{
					"id": "halberd_charge",
					"action": "charge",
					"shape": "line",
					"range": 820,
					"windup": 1.15,
					"recovery": 1.218,
					"damage_scale": 1.15,
					"major": true,
					"length": 820,
					"half_width": 57.599999999999994,
					"warning_policy": "area",
					"secondary_pattern": {
						"kind": "fan",
						"count": 23,
						"speed": 205,
						"life": 5.0,
						"hit_radius": 4.5,
						"burst_count": 2,
						"burst_interval": 0.34,
						"angle_step": 0.14,
						"angle_offset": 0.0,
						"aim_each_burst": false,
						"bullet_style": "orb",
						"spread": 4.0
					}
				},
				{
					"id": "halberd_fall",
					"action": "marker",
					"shape": "marker",
					"range": 1050,
					"windup": 1.2,
					"recovery": 1.276,
					"damage_scale": 1.1,
					"major": true,
					"radius": 203.0,
					"warning_policy": "area",
					"marker_count": 3,
					"marker_spacing": 324.8,
					"marker_delay": 0.18,
					"secondary_pattern": {
						"kind": "ring",
						"count": 34,
						"speed": 175,
						"life": 5.0,
						"hit_radius": 4.5,
						"burst_count": 2,
						"burst_interval": 0.34,
						"angle_step": 0.1,
						"angle_offset": 0.0,
						"aim_each_burst": false,
						"bullet_style": "orb",
						"gap_width": 1.1,
						"gap_angle_offset": 0.65
					}
				},
				{
					"id": "halberd_finish",
					"action": "slam",
					"shape": "sector",
					"range": 427.0,
					"windup": 1.509,
					"recovery": 1.914,
					"damage_scale": 1.2,
					"major": true,
					"radius": 427.0,
					"spread": 2.8,
					"warning_policy": "area",
					"secondary_pattern": {
						"kind": "ring",
						"count": 32,
						"speed": 180,
						"life": 5.0,
						"hit_radius": 4.5,
						"burst_count": 2,
						"burst_interval": 0.34,
						"angle_step": 0.12,
						"angle_offset": 0.0,
						"aim_each_burst": false,
						"bullet_style": "orb",
						"gap_width": 1.0,
						"gap_angle_offset": 0.65
					}
				}
			]
		},
		{
			"name": "四臂鬼神相",
			"body_height": 248,
			"radius": 46,
			"speed": 80,
			"attacks": [
				{
					"id": "demon_fourfold",
					"action": "slam",
					"shape": "sector",
					"range": 500.2,
					"windup": 1.768,
					"recovery": 0.48,
					"damage_scale": 1.15,
					"major": true,
					"radius": 500.2,
					"spread": 2.8,
					"warning_policy": "area",
					"secondary_pattern": {
						"kind": "ring",
						"count": 44,
						"speed": 195,
						"life": 5.0,
						"hit_radius": 4.5,
						"burst_count": 2,
						"burst_interval": 0.34,
						"angle_step": 0.12,
						"angle_offset": 0.0,
						"aim_each_burst": false,
						"bullet_style": "orb",
						"gap_width": 1.0,
						"gap_angle_offset": 0.65
					}
				},
				{
					"id": "demon_skybreaker",
					"action": "charge",
					"shape": "line",
					"range": 1175.0,
					"windup": 1.25,
					"recovery": 0.48,
					"damage_scale": 1.25,
					"major": true,
					"length": 1175.0,
					"half_width": 81.6,
					"warning_policy": "area",
					"secondary_pattern": {
						"kind": "fan",
						"count": 31,
						"speed": 205,
						"life": 5.0,
						"hit_radius": 4.5,
						"burst_count": 3,
						"burst_interval": 0.34,
						"angle_step": 0.14,
						"angle_offset": 0.0,
						"aim_each_burst": false,
						"bullet_style": "orb",
						"spread": 4.0
					}
				},
				{
					"id": "demon_quake",
					"action": "pulse",
					"shape": "ring_gap",
					"range": 624.0,
					"windup": 1.8,
					"recovery": 0.58,
					"damage_scale": 1.15,
					"major": true,
					"radius": 624.0,
					"inner_radius": 105,
					"gap_width": 1.75,
					"gap_angle": 0.9,
					"warning_policy": "area",
					"secondary_pattern": {
						"kind": "ring",
						"count": 44,
						"speed": 185,
						"life": 5.0,
						"hit_radius": 4.5,
						"burst_count": 3,
						"burst_interval": 0.34,
						"angle_step": 0.1,
						"angle_offset": 0.0,
						"aim_each_burst": false,
						"bullet_style": "orb",
						"gap_width": 1.0,
						"gap_angle_offset": 0.65
					}
				},
				{
					"id": "demon_heavenfall",
					"action": "marker",
					"shape": "marker",
					"range": 1050,
					"windup": 1.524,
					"recovery": 0.522,
					"damage_scale": 1.2,
					"major": true,
					"radius": 272.59999999999997,
					"warning_policy": "area",
					"marker_count": 5,
					"marker_spacing": 436.16,
					"marker_delay": 0.18,
					"secondary_pattern": {
						"kind": "ring",
						"count": 44,
						"speed": 175,
						"life": 5.0,
						"hit_radius": 4.5,
						"burst_count": 2,
						"burst_interval": 0.34,
						"angle_step": 0.1,
						"angle_offset": 0.0,
						"aim_each_burst": false,
						"bullet_style": "orb",
						"gap_width": 1.1,
						"gap_angle_offset": 0.65
					}
				},
				{
					"id": "demon_final_cleave",
					"action": "slam",
					"shape": "sector",
					"range": 550,
					"windup": 1.944,
					"recovery": 2.146,
					"damage_scale": 1.35,
					"major": true,
					"radius": 550,
					"spread": 3.1,
					"warning_policy": "area",
					"secondary_pattern": {
						"kind": "ring",
						"count": 44,
						"speed": 195,
						"life": 5.0,
						"hit_radius": 4.5,
						"burst_count": 2,
						"burst_interval": 0.34,
						"angle_step": 0.12,
						"angle_offset": 0.0,
						"aim_each_burst": false,
						"bullet_style": "orb",
						"gap_width": 1.0,
						"gap_angle_offset": 0.65
					}
				}
			]
		}
	]
}

static func forms(id: String) -> Array:
	var result := _authored(id)
	for index in result.size(): result[index].merge(FORM_COPY[id][index], true)
	return result

static func _authored(id: String) -> Array:
	return FORM_DEFINITIONS.get(id, []).duplicate(true)
