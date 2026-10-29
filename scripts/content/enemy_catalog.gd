extends RefCounted
## Immutable authored encounter definitions. Base stats precede the stage multiplier.
## Elite rule identity never determines card/equipment reward ownership.
## B15–B18 attacks are authored only in boss_forms.gd; definition() projects the first form.
const BOSS_FORMS := preload("res://scripts/content/boss_forms.gd")
const DEFINITIONS := {
	"E01": {
		"id": "E01",
		"name": "草甲鬼卒",
		"behavior_id": "E01",
		"rank": "ordinary",
		"visual_id": "E01",
		"hp": 38,
		"damage": 10,
		"speed": 58,
		"radius": 13,
		"xp": 3,
		"body_height": 52,
		"attacks": [
			{
				"id": "swipe",
				"action": "swipe",
				"shape": "sector",
				"range": 48,
				"windup": 0.5,
				"recovery": 1.0,
				"damage_scale": 1.0,
				"radius": 48,
				"spread": 1.8
			}
		],
		"params": {
			"role": "melee"
		},
		"elite_rule_id": "",
		"description": "草席与残甲裹住木骨，结群逼近后挥臂攻击。",
		"counterplay": [
			"聚拢后用范围攻击清群。",
			"从一侧开路，避开包围。"
		],
		"portrait_path": "",
		"actor_path": "",
		"palette": [
			"72694f",
			"c5ad79",
			"9a4838"
		]
	},
	"E02": {
		"id": "E02",
		"name": "骨弓伥",
		"behavior_id": "E02",
		"rank": "ordinary",
		"visual_id": "E02",
		"hp": 32,
		"damage": 12,
		"speed": 40,
		"radius": 13,
		"xp": 4,
		"body_height": 64,
		"attacks": [
			{
				"id": "shot",
				"action": "shot",
				"shape": "line",
				"range": 430,
				"windup": 0.9,
				"recovery": 1.25,
				"damage_scale": 1.0,
				"length": 430,
				"half_width": 7,
				"speed": 250,
				"life": 2.2,
				"major": true
			}
		],
		"params": {
			"role": "ranged"
		},
		"elite_rule_id": "",
		"description": "持枯骨长弓，停步瞄准后向锁定位置射箭。",
		"counterplay": [
			"看清瞄准方向后侧移避箭。",
			"清开前排或绕侧接近弓手。"
		],
		"portrait_path": "",
		"actor_path": "",
		"palette": [
			"72694f",
			"c5ad79",
			"9a4838"
		]
	},
	"E03": {
		"id": "E03",
		"name": "轭骨奔兽",
		"behavior_id": "E03",
		"rank": "ordinary",
		"visual_id": "E03",
		"hp": 58,
		"damage": 16,
		"speed": 82,
		"radius": 16,
		"xp": 5,
		"body_height": 70,
		"attacks": [
			{
				"id": "charge",
				"action": "charge",
				"shape": "line",
				"range": 310,
				"windup": 1.0,
				"recovery": 1.4,
				"damage_scale": 1.0,
				"length": 270,
				"half_width": 18,
				"major": true
			}
		],
		"params": {
			"role": "melee"
		},
		"elite_rule_id": "",
		"description": "兽首套着断轭，压低前身后沿直线冲锋。",
		"counterplay": [
			"横向避开锁定路线。",
			"等待冲锋停步后上前反击。"
		],
		"portrait_path": "",
		"actor_path": "",
		"palette": [
			"72694f",
			"c5ad79",
			"9a4838"
		]
	},
	"E04": {
		"id": "E04",
		"name": "扉甲卒",
		"behavior_id": "E04",
		"rank": "ordinary",
		"visual_id": "E04",
		"hp": 90,
		"damage": 15,
		"speed": 42,
		"radius": 18,
		"xp": 6,
		"body_height": 74,
		"attacks": [
			{
				"id": "swipe",
				"action": "swipe",
				"shape": "sector",
				"range": 65,
				"windup": 0.6,
				"recovery": 1.35,
				"damage_scale": 1.0,
				"radius": 65,
				"spread": 1.8
			}
		],
		"params": {
			"role": "melee",
			"shield_reduction": 0.4,
			"shield_arc": 1.8,
			"guard_duration": 2.6
		},
		"elite_rule_id": "",
		"description": "残门板作盾，举盾期间正面直接伤害减少，出手时会放盾。",
		"counterplay": [
			"从盾面侧后进攻。",
			"等它放盾再集中攻击，或持续击打正面。"
		],
		"portrait_path": "",
		"actor_path": "",
		"palette": [
			"72694f",
			"c5ad79",
			"9a4838"
		]
	},
	"E05": {
		"id": "E05",
		"name": "纸灯蛛",
		"behavior_id": "E05",
		"rank": "ordinary",
		"visual_id": "E05",
		"hp": 48,
		"damage": 12,
		"speed": 36,
		"radius": 16,
		"xp": 5,
		"body_height": 62,
		"attacks": [
			{
				"id": "fan",
				"action": "fan",
				"shape": "fan",
				"range": 390,
				"windup": 1.1,
				"recovery": 1.4,
				"damage_scale": 1.0,
				"count": 5,
				"spread": 1.2,
				"speed": 210,
				"life": 2.2,
				"major": true
			}
		],
		"params": {
			"role": "ranged"
		},
		"elite_rule_id": "",
		"description": "竹篾纸灯长出细腿，张开灯架后射出扇形灯弹。",
		"counterplay": [
			"沿弹幕间隙移动。",
			"趁发射空档接近并处理来源。"
		],
		"portrait_path": "",
		"actor_path": "",
		"palette": [
			"72694f",
			"c5ad79",
			"9a4838"
		]
	},
	"E06": {
		"id": "E06",
		"name": "背瓮行脚",
		"behavior_id": "E06",
		"rank": "ordinary",
		"visual_id": "E06",
		"hp": 56,
		"damage": 14,
		"speed": 38,
		"radius": 17,
		"xp": 5,
		"body_height": 68,
		"attacks": [
			{
				"id": "pot",
				"action": "pot",
				"shape": "marker",
				"range": 330,
				"windup": 1.1,
				"recovery": 1.5,
				"damage_scale": 1.0,
				"radius": 54,
				"delay": 0.7,
				"duration": 2.4,
				"limit": 1,
				"major": true
			}
		],
		"params": {
			"role": "ranged",
			"hazard_limit": 1
		},
		"elite_rule_id": "",
		"description": "背负大瓮，抛出的陶罐在预告落点形成短时危险区。",
		"counterplay": [
			"在落罐前离开标记位置。",
			"利用投罐后的空档接近来源。"
		],
		"portrait_path": "",
		"actor_path": "",
		"palette": [
			"72694f",
			"c5ad79",
			"9a4838"
		]
	},
	"E07": {
		"id": "E07",
		"name": "鸣幡吏",
		"behavior_id": "E07",
		"rank": "ordinary",
		"visual_id": "E07",
		"hp": 72,
		"damage": 10,
		"speed": 34,
		"radius": 17,
		"xp": 6,
		"body_height": 82,
		"attacks": [
			{
				"id": "command",
				"action": "command",
				"shape": "disc",
				"range": 290,
				"windup": 1.0,
				"recovery": 1.5,
				"damage_scale": 1.0,
				"count": 3,
				"duration": 3.0,
				"major": true
			},
			{
				"id": "swipe",
				"action": "swipe",
				"shape": "sector",
				"range": 48,
				"windup": 0.5,
				"recovery": 1.0,
				"damage_scale": 1.0,
				"radius": 48,
				"spread": 1.8
			}
		],
		"params": {
			"role": "support",
			"command_limit": 3,
			"command_duration": 3.0
		},
		"elite_rule_id": "",
		"description": "挥动长幡指挥附近已有部众，不额外召唤敌人。",
		"counterplay": [
			"先处理鸣幡吏，停止后续指挥。",
			"先清除部众，减少号令收益。"
		],
		"portrait_path": "",
		"actor_path": "",
		"palette": [
			"72694f",
			"c5ad79",
			"9a4838"
		]
	},
	"E08": {
		"id": "E08",
		"name": "供碗祠巫",
		"behavior_id": "E08",
		"rank": "ordinary",
		"visual_id": "E08",
		"hp": 68,
		"damage": 8,
		"speed": 18,
		"radius": 18,
		"xp": 6,
		"body_height": 74,
		"attacks": [
			{
				"id": "heal",
				"action": "heal",
				"shape": "disc",
				"range": 230,
				"windup": 1.1,
				"recovery": 1.6,
				"damage_scale": 1.0,
				"count": 2,
				"major": true
			},
			{
				"id": "swipe",
				"action": "swipe",
				"shape": "sector",
				"range": 48,
				"windup": 0.5,
				"recovery": 1.0,
				"damage_scale": 1.0,
				"radius": 48,
				"spread": 1.8
			}
		],
		"params": {
			"role": "support",
			"heal_limit": 2,
			"heal_fraction": 0.15,
			"heal_received_cap": 0.15,
			"heal_radius": 230.0,
			"anchored": true
		},
		"elite_rule_id": "",
		"description": "停在原地举碗，有限治疗附近随从，每名受益者的整场恢复总量有上限。",
		"counterplay": [
			"击败祭巫，停止后续治疗。",
			"把随从引出治疗范围再逐个处理。"
		],
		"portrait_path": "",
		"actor_path": "",
		"palette": [
			"72694f",
			"c5ad79",
			"9a4838"
		]
	},
	"E09": {
		"id": "E09",
		"name": "撼钟尸卫",
		"behavior_id": "E09",
		"rank": "heavy",
		"visual_id": "E09",
		"hp": 160,
		"damage": 22,
		"speed": 32,
		"radius": 25,
		"xp": 10,
		"body_height": 112,
		"attacks": [
			{
				"id": "slam",
				"action": "slam",
				"shape": "sector",
				"range": 110,
				"windup": 1.2,
				"recovery": 1.4,
				"damage_scale": 1.0,
				"radius": 110,
				"spread": 1.8,
				"major": true
			},
			{
				"id": "slam",
				"action": "slam",
				"shape": "sector",
				"range": 130,
				"windup": 1.0,
				"recovery": 1.6,
				"damage_scale": 1.0,
				"radius": 130,
				"spread": 1.6,
				"major": true
			}
		],
		"params": {
			"role": "heavy"
		},
		"elite_rule_id": "",
		"description": "身披钟形铜甲，接连挥出两次重槌，随后回气。",
		"counterplay": [
			"避过两次预告后抓回气进攻。",
			"先清周围轻敌，腾出侧移空间。"
		],
		"portrait_path": "",
		"actor_path": "",
		"palette": [
			"72694f",
			"c5ad79",
			"9a4838"
		]
	},
	"E10": {
		"id": "E10",
		"name": "钩轮牵阵者",
		"behavior_id": "E10",
		"rank": "heavy",
		"visual_id": "E10",
		"hp": 130,
		"damage": 18,
		"speed": 42,
		"radius": 23,
		"xp": 9,
		"body_height": 108,
		"attacks": [
			{
				"id": "hook",
				"action": "hook",
				"shape": "line",
				"range": 300,
				"windup": 1.2,
				"recovery": 1.6,
				"damage_scale": 1.0,
				"length": 280,
				"half_width": 24,
				"slow": 0.25,
				"duration": 2.0,
				"major": true
			}
		],
		"params": {
			"role": "heavy"
		},
		"elite_rule_id": "",
		"description": "拖着斜轮挥动长钩，沿预告路线留下短暂减速带。",
		"counterplay": [
			"离开预告线路，等待钩镰扫过。",
			"在锁向前穿过线路，从侧面接近。"
		],
		"portrait_path": "",
		"actor_path": "",
		"palette": [
			"72694f",
			"c5ad79",
			"9a4838"
		]
	},
	"E11": {
		"id": "E11",
		"name": "负棺驮役",
		"behavior_id": "E11",
		"rank": "heavy",
		"visual_id": "E11",
		"hp": 150,
		"damage": 14,
		"speed": 30,
		"radius": 26,
		"xp": 10,
		"body_height": 104,
		"attacks": [
			{
				"id": "summon",
				"action": "summon",
				"shape": "disc",
				"range": 250,
				"windup": 1.3,
				"recovery": 1.6,
				"damage_scale": 1.0,
				"spawn_id": "D05",
				"spawn_count": 2,
				"limit": 4,
				"major": true
			},
			{
				"id": "swipe",
				"action": "swipe",
				"shape": "sector",
				"range": 48,
				"windup": 0.5,
				"recovery": 1.0,
				"damage_scale": 1.0,
				"radius": 48,
				"spread": 1.8
			}
		],
		"params": {
			"role": "heavy",
			"spawn_waves": 2,
			"spawn_count": 2,
			"spawn_limit": 4,
			"egg_delay": 1.5
		},
		"elite_rule_id": "",
		"description": "多足驮体背负木棺，停步后分批放出有限援军。",
		"counterplay": [
			"在孵化前破坏待孵棺卵。",
			"优先处理驮役，阻止后续出生。"
		],
		"portrait_path": "",
		"actor_path": "",
		"palette": [
			"72694f",
			"c5ad79",
			"9a4838"
		]
	},
	"E12": {
		"id": "E12",
		"name": "碑背石龟",
		"behavior_id": "E12",
		"rank": "heavy",
		"visual_id": "E12",
		"hp": 185,
		"damage": 22,
		"speed": 24,
		"radius": 28,
		"xp": 12,
		"body_height": 116,
		"attacks": [
			{
				"id": "stele_arc_1",
				"action": "slam",
				"shape": "sector",
				"range": 130,
				"radius": 130,
				"windup": 1.2,
				"recovery": 1.2,
				"damage_scale": 1.0,
				"spread": 1.7,
				"major": true
			},
			{
				"id": "stele_arc_2",
				"action": "slam",
				"shape": "sector",
				"range": 150,
				"radius": 150,
				"windup": 1.2,
				"recovery": 1.4,
				"damage_scale": 1.0,
				"spread": 1.5,
				"major": true
			},
			{
				"id": "pulse",
				"action": "pulse",
				"shape": "ring_gap",
				"range": 180,
				"windup": 1.4,
				"recovery": 1.6,
				"damage_scale": 1.0,
				"radius": 180,
				"gap_angle": 0.0,
				"gap_width": 1.4,
				"major": true
			}
		],
		"params": {
			"role": "heavy",
			"gap_width": 1.4
		},
		"elite_rule_id": "",
		"description": "四足石兽背负残碑，以缓慢的地面弧和缺口环压制周围。",
		"counterplay": [
			"沿预告缺口移动到安全处。",
			"退出范围，等它回气后接近。"
		],
		"portrait_path": "",
		"actor_path": "",
		"palette": [
			"72694f",
			"c5ad79",
			"9a4838"
		]
	},
	"L00": {
		"id": "L00",
		"name": "先遣重卒",
		"behavior_id": "E01",
		"rank": "field_elite",
		"visual_id": "E01",
		"hp": 280,
		"damage": 20,
		"speed": 44,
		"radius": 24,
		"xp": 18,
		"body_height": 116,
		"attacks": [
			{
				"id": "swipe",
				"action": "swipe",
				"shape": "sector",
				"range": 48,
				"windup": 0.5,
				"recovery": 1.0,
				"damage_scale": 1.0,
				"radius": 48,
				"spread": 1.8
			}
		],
		"params": {
			"role": "heavy"
		},
		"elite_rule_id": "",
		"description": "更强壮的草甲鬼卒，保留基础近身攻击。",
		"counterplay": [
			"先清附近轻敌，留下走位空间。",
			"诱出挥击，趁收手时进攻。"
		],
		"portrait_path": "",
		"actor_path": "",
		"palette": [
			"72694f",
			"c5ad79",
			"9a4838"
		]
	},
	"L01": {
		"id": "L01",
		"name": "旌威督军",
		"behavior_id": "E07",
		"rank": "field_elite",
		"visual_id": "L01",
		"hp": 340,
		"damage": 22,
		"speed": 42,
		"radius": 26,
		"xp": 18,
		"body_height": 140,
		"attacks": [
			{
				"id": "command",
				"action": "command",
				"shape": "disc",
				"range": 290,
				"windup": 1.0,
				"recovery": 1.5,
				"damage_scale": 1.0,
				"count": 3,
				"duration": 3.0,
				"major": true
			},
			{
				"id": "swipe",
				"action": "swipe",
				"shape": "sector",
				"range": 48,
				"windup": 0.5,
				"recovery": 1.0,
				"damage_scale": 1.0,
				"radius": 48,
				"spread": 1.8
			}
		],
		"params": {
			"role": "heavy",
			"command_limit": 3,
			"command_duration": 3.0
		},
		"elite_rule_id": "L01",
		"description": "指挥最多三名已经在场的普通敌人；部众散尽后回到自身攻击。",
		"counterplay": [
			"优先击败督军，停止后续指挥。",
			"先清随从，使其无法继续受令。"
		],
		"portrait_path": "",
		"actor_path": "",
		"palette": [
			"72694f",
			"c5ad79",
			"9a4838"
		]
	},
	"L02": {
		"id": "L02",
		"name": "织阵灯母",
		"behavior_id": "E05",
		"rank": "field_elite",
		"visual_id": "L02",
		"hp": 340,
		"damage": 20,
		"speed": 36,
		"radius": 26,
		"xp": 18,
		"body_height": 138,
		"attacks": [
			{
				"id": "fan",
				"action": "fan",
				"shape": "fan",
				"range": 390,
				"windup": 1.1,
				"recovery": 1.4,
				"damage_scale": 1.0,
				"count": 5,
				"spread": 1.2,
				"speed": 210,
				"life": 2.2,
				"major": true
			}
		],
		"params": {
			"role": "heavy",
			"anchor_count": 2,
			"anchor_limit": 2
		},
		"elite_rule_id": "L02",
		"description": "展开可攻击的灯锚形成有限灯阵，灯母本体仍可受伤。",
		"counterplay": [
			"破坏灯锚，扩大安全空间。",
			"穿过灯阵缺口直接攻击灯母。"
		],
		"portrait_path": "",
		"actor_path": "",
		"palette": [
			"72694f",
			"c5ad79",
			"9a4838"
		]
	},
	"L03": {
		"id": "L03",
		"name": "缚契盾魁",
		"behavior_id": "E04",
		"rank": "field_elite",
		"visual_id": "L03",
		"hp": 400,
		"damage": 22,
		"speed": 40,
		"radius": 28,
		"xp": 18,
		"body_height": 146,
		"attacks": [
			{
				"id": "swipe",
				"action": "swipe",
				"shape": "sector",
				"range": 65,
				"windup": 0.6,
				"recovery": 1.35,
				"damage_scale": 1.0,
				"radius": 65,
				"spread": 1.8
			}
		],
		"params": {
			"role": "heavy",
			"shield_reduction": 0.4,
			"shield_arc": 1.8,
			"guard_duration": 2.6,
			"escort_id": "D01",
			"escort_count": 1,
			"tether_distance": 220.0,
			"link_reduction": 0.25,
			"link_duration": 5.0,
			"link_cooldown": 8.0
		},
		"elite_rule_id": "L03",
		"description": "与一名护卫形成可见连线，短时间减少所受伤害。",
		"counterplay": [
			"拉开精英与护卫的距离，断开连线。",
			"先击败护卫，解除这次保护。"
		],
		"portrait_path": "",
		"actor_path": "",
		"palette": [
			"72694f",
			"c5ad79",
			"9a4838"
		]
	},
	"L04": {
		"id": "L04",
		"name": "孵棺驮役",
		"behavior_id": "E11",
		"rank": "field_elite",
		"visual_id": "L04",
		"hp": 420,
		"damage": 22,
		"speed": 30,
		"radius": 30,
		"xp": 18,
		"body_height": 150,
		"attacks": [
			{
				"id": "summon",
				"action": "summon",
				"shape": "disc",
				"range": 250,
				"windup": 1.3,
				"recovery": 1.6,
				"damage_scale": 1.0,
				"spawn_id": "D05",
				"spawn_count": 2,
				"limit": 4,
				"major": true
			},
			{
				"id": "swipe",
				"action": "swipe",
				"shape": "sector",
				"range": 48,
				"windup": 0.5,
				"recovery": 1.0,
				"damage_scale": 1.0,
				"radius": 48,
				"spread": 1.8
			}
		],
		"params": {
			"role": "heavy",
			"spawn_waves": 2,
			"spawn_count": 2,
			"spawn_limit": 4,
			"egg_delay": 1.5
		},
		"elite_rule_id": "L04",
		"description": "背棺分批放出待孵物，出生数量有限。",
		"counterplay": [
			"孵化前破坏待孵物。",
			"优先处理驮役，取消后续孵化。"
		],
		"portrait_path": "",
		"actor_path": "",
		"palette": [
			"72694f",
			"c5ad79",
			"9a4838"
		]
	},
	"L05": {
		"id": "L05",
		"name": "镜影复唱鬼",
		"behavior_id": "E10",
		"rank": "field_elite",
		"visual_id": "L05",
		"hp": 360,
		"damage": 22,
		"speed": 44,
		"radius": 26,
		"xp": 18,
		"body_height": 144,
		"attacks": [
			{
				"id": "hook",
				"action": "hook",
				"shape": "line",
				"range": 300,
				"windup": 1.2,
				"recovery": 1.6,
				"damage_scale": 1.0,
				"length": 280,
				"half_width": 24,
				"slow": 0.25,
				"duration": 2.0,
				"major": true
			}
		],
		"params": {
			"role": "heavy",
			"echo_count": 1,
			"echo_delay": 1.0
		},
		"elite_rule_id": "L05",
		"description": "一次攻击后，虚影在旧位置另作预告并重复一次。",
		"counterplay": [
			"避开两次独立预告的危险范围。",
			"趁虚影出招，从侧面攻击本体。"
		],
		"portrait_path": "",
		"actor_path": "",
		"palette": [
			"72694f",
			"c5ad79",
			"9a4838"
		]
	},
	"L06": {
		"id": "L06",
		"name": "鸣雷行刑鬼",
		"behavior_id": "E09",
		"rank": "field_elite",
		"visual_id": "L06",
		"hp": 430,
		"damage": 24,
		"speed": 42,
		"radius": 28,
		"xp": 18,
		"body_height": 152,
		"attacks": [
			{
				"id": "slam",
				"action": "slam",
				"shape": "sector",
				"range": 110,
				"windup": 1.2,
				"recovery": 1.4,
				"damage_scale": 1.0,
				"radius": 110,
				"spread": 1.8,
				"major": true
			},
			{
				"id": "slam",
				"action": "slam",
				"shape": "sector",
				"range": 130,
				"windup": 1.0,
				"recovery": 1.6,
				"damage_scale": 1.0,
				"radius": 130,
				"spread": 1.6,
				"major": true
			}
		],
		"params": {
			"role": "heavy",
			"marker_limit": 2,
			"marker_delay": 1.2
		},
		"elite_rule_id": "L06",
		"description": "指定攻击后，在锁定地点留下延迟雷标。",
		"counterplay": [
			"看清雷标并提前离开落点。",
			"把雷标引向暂不经过的位置，再接近本体。"
		],
		"portrait_path": "",
		"actor_path": "",
		"palette": [
			"72694f",
			"c5ad79",
			"9a4838"
		]
	},
	"B01": {
		"id": "B01",
		"name": "荒道鬼校·空面碑甲",
		"behavior_id": "A",
		"rank": "boss",
		"visual_id": "B01",
		"hp": 550,
		"damage": 22.65,
		"speed": 42,
		"radius": 29,
		"xp": 30,
		"body_height": 128,
		"attacks": [
			{
				"id": "swipe",
				"action": "swipe",
				"shape": "sector",
				"range": 120,
				"windup": 1.15,
				"recovery": 1.8,
				"damage_scale": 1.0,
				"radius": 120,
				"spread": 2.0,
				"major": true
			}
		],
		"params": {
			"role": "boss",
			"command_limit": 3,
			"spawn_limit": 4,
			"anchor_limit": 2
		},
		"elite_rule_id": "",
		"description": "空面嵌入碑甲，以短追击和宽横扫阻路。",
		"counterplay": [
			"诱使横扫落空，趁收势反击。",
			"先清周围轻敌，再选择侧面接近。"
		],
		"portrait_path": "",
		"actor_path": "",
		"palette": [
			"72694f",
			"c5ad79",
			"9a4838"
		]
	},
	"B02": {
		"id": "B02",
		"name": "守街尸将·檐面巡将",
		"behavior_id": "A",
		"rank": "boss",
		"visual_id": "B02",
		"hp": 900,
		"damage": 23.3,
		"speed": 42,
		"radius": 30,
		"xp": 30,
		"body_height": 148,
		"attacks": [
			{
				"id": "swipe",
				"action": "swipe",
				"shape": "sector",
				"range": 120,
				"windup": 1.15,
				"recovery": 1.8,
				"damage_scale": 1.0,
				"radius": 120,
				"spread": 2.0,
				"major": true
			}
		],
		"params": {
			"role": "boss",
			"command_limit": 3,
			"spawn_limit": 4,
			"anchor_limit": 2
		},
		"elite_rule_id": "",
		"description": "巨大铜神面与屋檐化作躯体，追击并挥出横扫。",
		"counterplay": [
			"避开横扫后利用回气攻击。",
			"先清理远射敌人，减少接近压力。"
		],
		"portrait_path": "",
		"actor_path": "",
		"palette": [
			"72694f",
			"c5ad79",
			"9a4838"
		]
	},
	"B03": {
		"id": "B03",
		"name": "盘寨鬼魁·三面裂旗魁",
		"behavior_id": "B",
		"rank": "boss",
		"visual_id": "B03",
		"hp": 1750,
		"damage": 23.95,
		"speed": 42,
		"radius": 31,
		"xp": 30,
		"body_height": 172,
		"attacks": [
			{
				"id": "charge",
				"action": "charge",
				"shape": "line",
				"range": 420,
				"windup": 1.3,
				"recovery": 2.1,
				"damage_scale": 1.0,
				"length": 340,
				"half_width": 32,
				"major": true
			},
			{
				"id": "swipe",
				"action": "swipe",
				"shape": "sector",
				"range": 140,
				"windup": 1.1,
				"recovery": 1.8,
				"damage_scale": 1.0,
				"radius": 140,
				"spread": 2.0,
				"major": true
			}
		],
		"params": {
			"role": "boss",
			"command_limit": 3,
			"spawn_limit": 4,
			"anchor_limit": 2
		},
		"elite_rule_id": "",
		"description": "三张裂面与残旗连成一个鬼躯，横扫后再作冲击。",
		"counterplay": [
			"避开分别预告的横扫与冲刺。",
			"清开一侧的来敌，再集中攻击鬼魁。"
		],
		"portrait_path": "",
		"actor_path": "",
		"palette": [
			"72694f",
			"c5ad79",
			"9a4838"
		]
	},
	"B04": {
		"id": "B04",
		"name": "押粮鬼尉·轭骨牛督",
		"behavior_id": "B",
		"rank": "boss",
		"visual_id": "B04",
		"hp": 1250,
		"damage": 24.6,
		"speed": 42,
		"radius": 32,
		"xp": 30,
		"body_height": 164,
		"attacks": [
			{
				"id": "charge",
				"action": "charge",
				"shape": "line",
				"range": 420,
				"windup": 1.3,
				"recovery": 2.1,
				"damage_scale": 1.0,
				"length": 340,
				"half_width": 32,
				"major": true
			},
			{
				"id": "swipe",
				"action": "swipe",
				"shape": "sector",
				"range": 140,
				"windup": 1.1,
				"recovery": 1.8,
				"damage_scale": 1.0,
				"radius": 140,
				"spread": 2.0,
				"major": true
			}
		],
		"params": {
			"role": "boss",
			"command_limit": 3,
			"spawn_limit": 4,
			"anchor_limit": 2
		},
		"elite_rule_id": "",
		"description": "粮车残轭、牛兽与鬼尉化为一体，低头后直线冲阵。",
		"counterplay": [
			"横向避开锁定的冲锋路线。",
			"在冲锋终点附近等待回气再反击。"
		],
		"portrait_path": "",
		"actor_path": "",
		"palette": [
			"72694f",
			"c5ad79",
			"9a4838"
		]
	},
	"B05": {
		"id": "B05",
		"name": "冥灯术士·悬灯道人",
		"behavior_id": "C",
		"rank": "boss",
		"visual_id": "B05",
		"hp": 1150,
		"damage": 25.25,
		"speed": 42,
		"radius": 33,
		"xp": 30,
		"body_height": 166,
		"attacks": [
			{
				"id": "fan",
				"action": "fan",
				"shape": "fan",
				"range": 520,
				"windup": 1.3,
				"recovery": 1.6,
				"damage_scale": 1.0,
				"count": 5,
				"spread": 1.3,
				"speed": 230,
				"life": 2.4,
				"major": true
			},
			{
				"id": "pot",
				"action": "pot",
				"shape": "marker",
				"range": 420,
				"windup": 1.2,
				"recovery": 2.2,
				"damage_scale": 1.0,
				"radius": 65,
				"delay": 0.8,
				"duration": 2.4,
				"limit": 2,
				"major": true
			}
		],
		"params": {
			"role": "boss",
			"command_limit": 3,
			"spawn_limit": 4,
			"anchor_limit": 2
		},
		"elite_rule_id": "",
		"description": "面具悬于旧灯，长节肢展开扇射并留下延迟灯位。",
		"counterplay": [
			"穿过扇弹的间隙。",
			"避开灯位，趁术士停手接近。"
		],
		"portrait_path": "",
		"actor_path": "",
		"palette": [
			"72694f",
			"c5ad79",
			"9a4838"
		]
	},
	"B06": {
		"id": "B06",
		"name": "荒祠镇将·祠脊石兽",
		"behavior_id": "D",
		"rank": "boss",
		"visual_id": "B06",
		"hp": 2150,
		"damage": 25.9,
		"speed": 42,
		"radius": 34,
		"xp": 30,
		"body_height": 184,
		"attacks": [
			{
				"id": "slam",
				"action": "slam",
				"shape": "sector",
				"range": 155,
				"windup": 1.4,
				"recovery": 1.6,
				"damage_scale": 1.0,
				"radius": 155,
				"spread": 1.9,
				"major": true
			},
			{
				"id": "slam",
				"action": "slam",
				"shape": "sector",
				"range": 175,
				"windup": 1.25,
				"recovery": 2.4,
				"damage_scale": 1.0,
				"radius": 175,
				"spread": 1.7,
				"major": true
			}
		],
		"params": {
			"role": "boss",
			"command_limit": 3,
			"spawn_limit": 4,
			"anchor_limit": 2
		},
		"elite_rule_id": "",
		"description": "祠脊与巨大石兽相连，以两拍重击守住荒祠。",
		"counterplay": [
			"避过连续重击，抓回气进攻。",
			"先清附近敌人，再从侧面接近。"
		],
		"portrait_path": "",
		"actor_path": "",
		"palette": [
			"72694f",
			"c5ad79",
			"9a4838"
		]
	},
	"B07": {
		"id": "B07",
		"name": "官署号令者·悬印司令",
		"behavior_id": "E",
		"rank": "boss",
		"visual_id": "B07",
		"hp": 2400,
		"damage": 26.55,
		"speed": 42,
		"radius": 35,
		"xp": 30,
		"body_height": 184,
		"attacks": [
			{
				"id": "command",
				"action": "command",
				"shape": "disc",
				"range": 390,
				"windup": 1.25,
				"recovery": 1.6,
				"damage_scale": 1.0,
				"count": 3,
				"duration": 3.0,
				"major": true
			},
			{
				"id": "swipe",
				"action": "swipe",
				"shape": "sector",
				"range": 165,
				"windup": 1.2,
				"recovery": 2.3,
				"damage_scale": 1.0,
				"radius": 165,
				"spread": 2.0,
				"major": true
			}
		],
		"params": {
			"role": "boss",
			"command_limit": 3,
			"spawn_limit": 4,
			"anchor_limit": 2
		},
		"elite_rule_id": "",
		"description": "巨印为躯，卷宗化臂，通过可见号令指挥有限部众。",
		"counterplay": [
			"先处理随从，减轻号令压力。",
			"清开道路，优先攻击司令本体。"
		],
		"portrait_path": "",
		"actor_path": "",
		"palette": [
			"72694f",
			"c5ad79",
			"9a4838"
		]
	},
	"B08": {
		"id": "B08",
		"name": "水门冲将·闸齿鳄首",
		"behavior_id": "B",
		"rank": "boss",
		"visual_id": "B08",
		"hp": 2700,
		"damage": 27.2,
		"speed": 42,
		"radius": 36,
		"xp": 30,
		"body_height": 176,
		"attacks": [
			{
				"id": "charge",
				"action": "charge",
				"shape": "line",
				"range": 420,
				"windup": 1.3,
				"recovery": 2.1,
				"damage_scale": 1.0,
				"length": 340,
				"half_width": 32,
				"major": true
			},
			{
				"id": "swipe",
				"action": "swipe",
				"shape": "sector",
				"range": 140,
				"windup": 1.1,
				"recovery": 1.8,
				"damage_scale": 1.0,
				"radius": 140,
				"spread": 2.0,
				"major": true
			}
		],
		"params": {
			"role": "boss",
			"command_limit": 3,
			"spawn_limit": 4,
			"anchor_limit": 2
		},
		"elite_rule_id": "",
		"description": "闸齿与鳄首组成狭长鬼躯，锁向后沿直线冲击。",
		"counterplay": [
			"横移离开预告路线。",
			"清开侧路，在冲锋落点抓住回气。"
		],
		"portrait_path": "",
		"actor_path": "",
		"palette": [
			"72694f",
			"c5ad79",
			"9a4838"
		]
	},
	"B09": {
		"id": "B09",
		"name": "军械库将·炉腹铁鬼",
		"behavior_id": "D",
		"rank": "boss",
		"visual_id": "B09",
		"hp": 2850,
		"damage": 27.85,
		"speed": 42,
		"radius": 37,
		"xp": 30,
		"body_height": 184,
		"attacks": [
			{
				"id": "slam",
				"action": "slam",
				"shape": "sector",
				"range": 155,
				"windup": 1.4,
				"recovery": 1.6,
				"damage_scale": 1.0,
				"radius": 155,
				"spread": 1.9,
				"major": true
			},
			{
				"id": "slam",
				"action": "slam",
				"shape": "sector",
				"range": 175,
				"windup": 1.25,
				"recovery": 2.4,
				"damage_scale": 1.0,
				"radius": 175,
				"spread": 1.7,
				"major": true
			}
		],
		"params": {
			"role": "boss",
			"command_limit": 3,
			"spawn_limit": 4,
			"anchor_limit": 2
		},
		"elite_rule_id": "",
		"description": "旧炉为腹、铁桩为足，以两次重击守住库门。",
		"counterplay": [
			"避过两拍攻击后从侧面反击。",
			"先清开附近轻敌，留出移动空间。"
		],
		"portrait_path": "",
		"actor_path": "",
		"palette": [
			"72694f",
			"c5ad79",
			"9a4838"
		]
	},
	"B10": {
		"id": "B10",
		"name": "封库双禁卫·左锁",
		"behavior_id": "D",
		"rank": "boss",
		"visual_id": "B10",
		"hp": 3200,
		"damage": 28.5,
		"speed": 42,
		"radius": 38,
		"xp": 30,
		"body_height": 170,
		"attacks": [
			{
				"id": "slam",
				"action": "slam",
				"shape": "sector",
				"range": 155,
				"windup": 1.4,
				"recovery": 1.6,
				"damage_scale": 1.0,
				"radius": 155,
				"spread": 1.9,
				"major": true
			},
			{
				"id": "slam",
				"action": "slam",
				"shape": "sector",
				"range": 175,
				"windup": 1.25,
				"recovery": 2.4,
				"damage_scale": 1.0,
				"radius": 175,
				"spread": 1.7,
				"major": true
			}
		],
		"params": {
			"role": "boss",
			"command_limit": 3,
			"spawn_limit": 4,
			"anchor_limit": 2,
			"partner_id": "B10_R"
		},
		"elite_rule_id": "",
		"description": "左右锁卫交替攻击，两体共享同一条生命。",
		"counterplay": [
			"留意两体分别预告的动作并逐次避开。",
			"抓交替空档攻击任一锁卫；一次范围攻击不会双倍结算。"
		],
		"portrait_path": "",
		"actor_path": "",
		"palette": [
			"72694f",
			"c5ad79",
			"9a4838"
		]
	},
	"B11": {
		"id": "B11",
		"name": "巡城灯师·伞眼灯灵",
		"behavior_id": "C",
		"rank": "boss",
		"visual_id": "B11",
		"hp": 3150,
		"damage": 29.15,
		"speed": 42,
		"radius": 39,
		"xp": 30,
		"body_height": 178,
		"attacks": [
			{
				"id": "fan",
				"action": "fan",
				"shape": "fan",
				"range": 520,
				"windup": 1.3,
				"recovery": 1.6,
				"damage_scale": 1.0,
				"count": 5,
				"spread": 1.3,
				"speed": 230,
				"life": 2.4,
				"major": true
			},
			{
				"id": "pot",
				"action": "pot",
				"shape": "marker",
				"range": 420,
				"windup": 1.2,
				"recovery": 2.2,
				"damage_scale": 1.0,
				"radius": 65,
				"delay": 0.8,
				"duration": 2.4,
				"limit": 2,
				"major": true
			}
		],
		"params": {
			"role": "boss",
			"command_limit": 3,
			"spawn_limit": 4,
			"anchor_limit": 2
		},
		"elite_rule_id": "",
		"description": "伞下多只灯眼聚为一体，展开扇射并留下有限灯位。",
		"counterplay": [
			"穿过扇形弹幕的空隙。",
			"绕开延迟灯位，趁灯灵回气接近。"
		],
		"portrait_path": "",
		"actor_path": "",
		"palette": [
			"72694f",
			"c5ad79",
			"9a4838"
		]
	},
	"B12": {
		"id": "B12",
		"name": "瘟灯阵主·多手幡灯大巫",
		"behavior_id": "F",
		"rank": "boss",
		"visual_id": "B12",
		"hp": 3600,
		"damage": 29.8,
		"speed": 42,
		"radius": 40,
		"xp": 30,
		"body_height": 202,
		"attacks": [
			{
				"id": "anchor",
				"action": "anchor",
				"shape": "ring_gap",
				"range": 230,
				"windup": 1.4,
				"recovery": 1.7,
				"damage_scale": 1.0,
				"radius": 230,
				"gap_angle": 0.0,
				"gap_width": 1.4,
				"spawn_id": "D03",
				"spawn_count": 2,
				"limit": 2,
				"major": true
			},
			{
				"id": "pulse",
				"action": "pulse",
				"shape": "ring_gap",
				"range": 230,
				"windup": 1.3,
				"recovery": 2.4,
				"damage_scale": 1.0,
				"radius": 230,
				"gap_angle": 0.0,
				"gap_width": 1.4,
				"major": true
			}
		],
		"params": {
			"role": "boss",
			"command_limit": 3,
			"spawn_limit": 4,
			"anchor_limit": 2
		},
		"elite_rule_id": "",
		"description": "多手鬼巫布下可攻击灯锚，改变周围安全通路。",
		"counterplay": [
			"破坏灯锚，扩大可移动空间。",
			"穿过已有缺口，直接攻击阵主。"
		],
		"portrait_path": "",
		"actor_path": "",
		"palette": [
			"72694f",
			"c5ad79",
			"9a4838"
		]
	},
	"B13": {
		"id": "B13",
		"name": "城垣冲将·石鸱裂垛",
		"behavior_id": "B",
		"rank": "boss",
		"visual_id": "B13",
		"hp": 3650,
		"damage": 30.450000000000003,
		"speed": 42,
		"radius": 41,
		"xp": 30,
		"body_height": 188,
		"attacks": [
			{
				"id": "charge",
				"action": "charge",
				"shape": "line",
				"range": 420,
				"windup": 1.3,
				"recovery": 2.1,
				"damage_scale": 1.0,
				"length": 340,
				"half_width": 32,
				"major": true
			},
			{
				"id": "swipe",
				"action": "swipe",
				"shape": "sector",
				"range": 140,
				"windup": 1.1,
				"recovery": 1.8,
				"damage_scale": 1.0,
				"radius": 140,
				"spread": 2.0,
				"major": true
			}
		],
		"params": {
			"role": "boss",
			"command_limit": 3,
			"spawn_limit": 4,
			"anchor_limit": 2
		},
		"elite_rule_id": "",
		"description": "石鸱与城垛巨兽融合，压低前身后冲出。",
		"counterplay": [
			"避开预告冲线，待其停步反击。",
			"先清轻敌，留出能横移的路线。"
		],
		"portrait_path": "",
		"actor_path": "",
		"palette": [
			"72694f",
			"c5ad79",
			"9a4838"
		]
	},
	"B14": {
		"id": "B14",
		"name": "渡口号令者·引舟鬼帅",
		"behavior_id": "E",
		"rank": "boss",
		"visual_id": "B14",
		"hp": 3650,
		"damage": 31.1,
		"speed": 42,
		"radius": 42,
		"xp": 30,
		"body_height": 188,
		"attacks": [
			{
				"id": "command",
				"action": "command",
				"shape": "disc",
				"range": 390,
				"windup": 1.25,
				"recovery": 1.6,
				"damage_scale": 1.0,
				"count": 3,
				"duration": 3.0,
				"major": true
			},
			{
				"id": "swipe",
				"action": "swipe",
				"shape": "sector",
				"range": 165,
				"windup": 1.2,
				"recovery": 2.3,
				"damage_scale": 1.0,
				"radius": 165,
				"spread": 2.0,
				"major": true
			}
		],
		"params": {
			"role": "boss",
			"command_limit": 3,
			"spawn_limit": 4,
			"anchor_limit": 2
		},
		"elite_rule_id": "",
		"description": "舟棺状长躯挥令杖，指挥有限部众协同进攻。",
		"counterplay": [
			"先清随从，减轻号令压力。",
			"绕开前排，集中处理鬼帅。"
		],
		"portrait_path": "",
		"actor_path": "",
		"palette": [
			"72694f",
			"c5ad79",
			"9a4838"
		]
	},
	"B15": {
		"id": "B15",
		"name": "曹休·鬼猎兽相",
		"behavior_id": "G",
		"rank": "boss",
		"visual_id": "B15",
		"hp": 4300,
		"damage": 31.75,
		"speed": 42,
		"radius": 43,
		"xp": 40,
		"body_height": 204,
		"attacks": [],
		"params": {
			"role": "boss"
		},
		"elite_rule_id": "",
		"description": "曹休以瞄准射击和扇形箭矢压制远处，随后直线突进。",
		"counterplay": [
			"横移离开瞄准线，从扇箭间隙接近。",
			"避开突进路线，趁曹休收势反击。"
		],
		"portrait_path": "",
		"actor_path": "",
		"palette": [
			"72694f",
			"c5ad79",
			"9a4838"
		]
	},
	"B16": {
		"id": "B16",
		"name": "曹纯·虎豹甲骑巨相",
		"behavior_id": "H",
		"rank": "boss",
		"visual_id": "B16",
		"hp": 4800,
		"damage": 32.4,
		"speed": 46,
		"radius": 44,
		"xp": 40,
		"body_height": 218,
		"attacks": [],
		"params": {
			"role": "boss"
		},
		"elite_rule_id": "",
		"description": "曹纯持枪直冲，穿插近身横斩，再次发起冲击。",
		"counterplay": [
			"看清冲锋方向，横移离开路线。",
			"避开横斩后，趁收势接近攻击。"
		],
		"portrait_path": "",
		"actor_path": "",
		"palette": [
			"72694f",
			"c5ad79",
			"9a4838"
		]
	},
	"B17": {
		"id": "B17",
		"name": "张辽·夜叉裂阵将相",
		"behavior_id": "I",
		"rank": "boss",
		"visual_id": "B17",
		"hp": 6200,
		"damage": 33.05,
		"speed": 42,
		"radius": 45,
		"xp": 40,
		"body_height": 220,
		"attacks": [],
		"params": {
			"role": "boss",
			"collaborators": [
				"M03_WAR",
				"M04_WAR"
			]
		},
		"elite_rule_id": "",
		"description": "张辽以突进和横斩主攻，高顺与陈宫轮流协同。",
		"counterplay": [
			"高顺列阵时离开路线；陈宫布阵时离开落点。",
			"避过协同后，趁张辽回气反击。"
		],
		"portrait_path": "",
		"actor_path": "",
		"palette": [
			"72694f",
			"c5ad79",
			"9a4838"
		]
	},
	"B18": {
		"id": "B18",
		"name": "吕布·四臂鬼神相",
		"behavior_id": "J",
		"rank": "boss",
		"visual_id": "B18",
		"hp": 7600,
		"damage": 33.7,
		"speed": 46,
		"radius": 46,
		"xp": 60,
		"body_height": 248,
		"attacks": [],
		"params": {
			"role": "boss"
		},
		"elite_rule_id": "",
		"description": "吕布独自持戟迎战，以横扫、突进和落戟交替进攻。",
		"counterplay": [
			"横移避开突进路线，离开落戟标记。",
			"避过戟刃横扫，趁收势接近反击。"
		],
		"portrait_path": "",
		"actor_path": "",
		"palette": [
			"72694f",
			"c5ad79",
			"9a4838"
		]
	},
	"D01": {
		"id": "D01",
		"name": "有限援军",
		"behavior_id": "E01",
		"rank": "ordinary",
		"visual_id": "D01",
		"hp": 28,
		"damage": 8,
		"speed": 52,
		"radius": 11,
		"xp": 0,
		"body_height": 40,
		"attacks": [
			{
				"id": "swipe",
				"action": "swipe",
				"shape": "sector",
				"range": 48,
				"windup": 0.5,
				"recovery": 1.0,
				"damage_scale": 1.0,
				"radius": 48,
				"spread": 1.8
			}
		],
		"params": {
			"role": "derivative",
			"counts_for_threshold": false,
			"targetable": true
		},
		"elite_rule_id": "",
		"description": "由敌人有限召出的活体，出生后可正常受击。",
		"counterplay": [
			"先清援军，腾出行动空间。",
			"先处理来源，阻止后续召唤。"
		],
		"portrait_path": "",
		"actor_path": "",
		"palette": [
			"72694f",
			"c5ad79",
			"9a4838"
		]
	},
	"D03": {
		"id": "D03",
		"name": "灯锚",
		"behavior_id": "E05",
		"rank": "object",
		"visual_id": "D03",
		"hp": 65,
		"damage": 0,
		"speed": 0,
		"radius": 16,
		"xp": 0,
		"body_height": 46,
		"attacks": [],
		"params": {
			"role": "derivative",
			"counts_for_threshold": false,
			"targetable": true
		},
		"elite_rule_id": "",
		"description": "灯阵中可受击的固定锚点，破坏后缩小对应危险范围。",
		"counterplay": [
			"破坏灯锚，扩大通路。",
			"从缺口接近来源，不必先破锚。"
		],
		"portrait_path": "",
		"actor_path": "",
		"palette": [
			"72694f",
			"c5ad79",
			"9a4838"
		]
	},
	"D05": {
		"id": "D05",
		"name": "待孵棺卵",
		"behavior_id": "E11",
		"rank": "object",
		"visual_id": "D05",
		"hp": 45,
		"damage": 0,
		"speed": 0,
		"radius": 17,
		"xp": 0,
		"body_height": 38,
		"attacks": [],
		"params": {
			"role": "derivative",
			"counts_for_threshold": false,
			"targetable": true
		},
		"elite_rule_id": "",
		"description": "带有孵化预告的可攻击对象，孵化后产生援军。",
		"counterplay": [
			"孵化前破坏待孵物。",
			"处理来源，取消尚未孵出的援军。"
		],
		"portrait_path": "",
		"actor_path": "",
		"palette": [
			"72694f",
			"c5ad79",
			"9a4838"
		]
	},
	"B10_R": {
		"id": "B10_R",
		"name": "封库双禁卫·右锁",
		"behavior_id": "D",
		"rank": "proxy",
		"visual_id": "B10_R",
		"hp": 3200,
		"damage": 0,
		"speed": 0,
		"radius": 38,
		"xp": 0,
		"body_height": 170,
		"attacks": [
			{
				"id": "slam",
				"action": "slam",
				"shape": "sector",
				"range": 155,
				"windup": 1.4,
				"recovery": 1.6,
				"damage_scale": 1.0,
				"radius": 155,
				"spread": 1.9,
				"major": true
			},
			{
				"id": "slam",
				"action": "slam",
				"shape": "sector",
				"range": 175,
				"windup": 1.25,
				"recovery": 2.4,
				"damage_scale": 1.0,
				"radius": 175,
				"spread": 1.7,
				"major": true
			}
		],
		"params": {
			"role": "derivative",
			"counts_for_threshold": false,
			"targetable": true
		},
		"elite_rule_id": "",
		"description": "右锁与左锁交替出手，共享同一条生命。",
		"counterplay": [
			"观察右锁的预告并避开。",
			"抓两体交替空档，攻击任一锁卫。"
		],
		"portrait_path": "",
		"actor_path": "",
		"palette": [
			"72694f",
			"c5ad79",
			"9a4838"
		]
	},
	"M03_WAR": {
		"id": "M03_WAR",
		"name": "高顺·城壁铠魂",
		"behavior_id": "I",
		"rank": "proxy",
		"visual_id": "M03_WAR",
		"hp": 1,
		"damage": 0,
		"speed": 0,
		"radius": 0,
		"xp": 0,
		"body_height": 200,
		"attacks": [],
		"params": {
			"role": "derivative",
			"counts_for_threshold": false,
			"targetable": false
		},
		"elite_rule_id": "",
		"description": "高顺的协同战相，以列阵配合张辽；自身不能被锁定。",
		"counterplay": [
			"离开列阵预告的路线。",
			"趁协同结束后的共同回气攻击张辽。"
		],
		"portrait_path": "",
		"actor_path": "",
		"palette": [
			"72694f",
			"c5ad79",
			"9a4838"
		]
	},
	"M04_WAR": {
		"id": "M04_WAR",
		"name": "陈宫·卷轴冥相",
		"behavior_id": "I",
		"rank": "proxy",
		"visual_id": "M04_WAR",
		"hp": 1,
		"damage": 0,
		"speed": 0,
		"radius": 0,
		"xp": 0,
		"body_height": 190,
		"attacks": [],
		"params": {
			"role": "derivative",
			"counts_for_threshold": false,
			"targetable": false
		},
		"elite_rule_id": "",
		"description": "陈宫的协同战相，以延迟阵区配合张辽；自身不能被锁定。",
		"counterplay": [
			"离开阵区预告的落点。",
			"趁协同结束后的共同回气攻击张辽。"
		],
		"portrait_path": "",
		"actor_path": "",
		"palette": [
			"72694f",
			"c5ad79",
			"9a4838"
		]
	}
}

static func definition(id: String) -> Dictionary:
	var value: Dictionary = DEFINITIONS.get(id, {}).duplicate(true)
	var authored := BOSS_FORMS.forms(id)
	if not authored.is_empty():
		value.forms = authored
		value.attacks = authored[0].attacks.duplicate(true)
		value.params.phase_hp_fraction = 0.4
		value.params.transition_duration = 1.0
		value.params.phase_observation_duration = 0.65
		value.params.solo = id == "B18"
	return value

static func ordinary_ids() -> Array:
	return ["E01", "E02", "E03", "E04", "E05", "E06", "E07", "E08", "E09", "E10", "E11", "E12"]

static func elite_ids() -> Array:
	return ["L01", "L02", "L03", "L04", "L05", "L06"]

static func boss_ids() -> Array:
	return ["B01", "B02", "B03", "B04", "B05", "B06", "B07", "B08", "B09", "B10", "B11", "B12", "B13", "B14", "B15", "B16", "B17", "B18"]

static func derivative_ids() -> Array:
	return ["D01", "D03", "D05", "B10_R", "M03_WAR", "M04_WAR"]

static func validate() -> Array:
	var errors: Array = []
	var required := ["id", "name", "behavior_id", "rank", "visual_id", "hp", "damage", "speed", "radius", "xp", "body_height", "attacks", "params", "elite_rule_id", "description", "counterplay", "portrait_path", "actor_path", "palette"]
	for id in DEFINITIONS:
		var value: Dictionary = DEFINITIONS[id]
		for key in required:
			if not value.has(key): errors.append(id + ": missing " + key)
		if value.id != id: errors.append(id + ": identity mismatch")
		if value.hp <= 0 or value.radius < 0: errors.append(id + ": invalid body stats")
		if value.counterplay.size() != 2: errors.append(id + ": two counterplay entries required")
		for action in value.attacks:
			for key in ["id", "action", "shape", "range", "windup", "recovery", "damage_scale"]:
				if not action.has(key): errors.append(id + ": attack missing " + key)
			if action.windup <= 0 or action.recovery <= 0: errors.append(id + ": invalid timing")
	return errors
