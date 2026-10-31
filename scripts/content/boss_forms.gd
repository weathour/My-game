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

static func forms(id: String) -> Array:
	var result := _authored(id)
	for index in result.size(): result[index].merge(FORM_COPY[id][index], true)
	return result

static func _authored(id: String) -> Array:
	match id:
		"B15":
			return [
				_form("曹休", 120, 30, 66, [
					_line("hunter_aim", "shot", 760, 12, 1.35, 1.9, 1.0, {"speed":420, "life":2.2}),
					_fan("hunter_volley", 640, 5, 1.25, 1.55, 2.1, 0.8),
					_line("hunter_reposition", "charge", 340, 32, 1.2, 2.6, 0.9)]),
				_form("鬼猎兽相", 204, 43, 78, [
					_fan("beast_hunt", 860, 7, 1.55, 1.55, 2.0, 0.9),
					_line("beast_leap", "charge", 510, 50, 1.4, 2.2, 1.15),
					_marker("hunt_mark", 180, 1.55, 2.2, 1.1),
					_sector("beast_rend", 280, 2.6, 1.5, 3.1, 1.2)])]
		"B16":
			return [
				_form("曹纯", 128, 31, 62, [
					_line("rider_lance", "charge", 600, 38, 1.4, 2.2, 1.0),
					_sector("rider_cleave", 230, 2.4, 1.35, 2.1, 0.9),
					_line("rider_return", "charge", 440, 42, 1.3, 3.0, 1.1)]),
				_form("虎豹甲骑巨相", 218, 44, 70, [
					_line("tiger_long_charge", "charge", 900, 62, 1.65, 2.5, 1.2),
					_sector("tiger_trample", 310, 2.8, 1.6, 2.2, 1.05),
					_line("leopard_return", "charge", 720, 54, 1.5, 2.4, 1.1),
					_ring("cavalry_break", 390, 85, 1.6, 1.75, 3.4, 1.25)])]
		"B17":
			return [
				_form("张辽", 130, 32, 64, [
					_line("general_lunge", "charge", 460, 38, 1.3, 1.8, 1.0),
					_sector("general_cut", 245, 2.4, 1.35, 1.7, 0.95),
					_collaboration("human_formation", 1.45, 3.0, 1.0)]),
				_form("夜叉裂阵将相", 220, 45, 72, [
					_line("yaksha_break", "charge", 660, 54, 1.5, 1.9, 1.1),
					_sector("yaksha_cleave", 340, 2.65, 1.65, 1.8, 1.05),
					_collaboration("war_formation", 1.65, 3.3, 1.15),
					_ring("yaksha_pulse", 420, 90, 1.65, 1.8, 3.4, 1.2)])]
		"B18":
			return [
				_form("吕布", 144, 34, 70, [
					_sector("halberd_sweep", 300, 2.5, 1.5, 1.9, 1.0),
					_line("halberd_charge", "charge", 650, 48, 1.5, 2.1, 1.15),
					_marker("halberd_fall", 175, 1.55, 2.2, 1.1),
					_sector("halberd_finish", 350, 2.8, 1.7, 3.3, 1.2)]),
				_form("四臂鬼神相", 248, 46, 80, [
					_sector("demon_fourfold", 410, 2.8, 1.85, 0.65, 1.15),
					_line("demon_skybreaker", "charge", 940, 68, 1.75, 0.8, 1.25),
					_ring("demon_quake", 520, 105, 1.75, 1.9, 1.0, 1.15),
					_marker("demon_heavenfall", 235, 1.9, 0.9, 1.2),
					_sector("demon_final_cleave", 460, 3.1, 2.0, 3.7, 1.35)])]
	return []

static func _form(label: String, height: float, radius: float, speed: float, attacks: Array) -> Dictionary:
	return {"name":label, "body_height":height, "radius":radius, "speed":speed, "attacks":attacks}

static func _base(id: String, action: String, shape: String, reach: float, tell: float, rest: float, damage: float) -> Dictionary:
	return {"id":id, "action":action, "shape":shape, "range":reach, "windup":tell, "recovery":rest, "damage_scale":damage, "major":true}

static func _line(id: String, action: String, length: float, width: float, tell: float, rest: float, damage: float, extra: Dictionary = {}) -> Dictionary:
	var value := _base(id, action, "line", length, tell, rest, damage)
	value.merge({"length":length, "half_width":width}, true)
	value.merge(extra, true)
	return value

static func _sector(id: String, radius: float, spread: float, tell: float, rest: float, damage: float) -> Dictionary:
	var value := _base(id, "slam", "sector", radius, tell, rest, damage)
	value.merge({"radius":radius, "spread":spread}, true)
	return value

static func _marker(id: String, radius: float, tell: float, rest: float, damage: float) -> Dictionary:
	var value := _base(id, "marker", "marker", 1050, tell, rest, damage)
	value.radius = radius
	return value

static func _fan(id: String, reach: float, count: int, spread: float, tell: float, rest: float, damage: float) -> Dictionary:
	var value := _base(id, "fan", "fan", reach, tell, rest, damage)
	value.merge({"radius":reach, "count":count, "spread":spread, "speed":310, "life":3.0}, true)
	return value

static func _ring(id: String, radius: float, inner: float, gap: float, tell: float, rest: float, damage: float) -> Dictionary:
	var value := _base(id, "pulse", "ring_gap", radius, tell, rest, damage)
	value.merge({"radius":radius, "inner_radius":inner, "gap_width":gap, "gap_angle":0.9}, true)
	return value

static func _collaboration(id: String, tell: float, rest: float, damage: float) -> Dictionary:
	var value := _base(id, "collaboration", "line", 820, tell, rest, damage)
	value.merge({"length":720, "half_width":55, "radius":185}, true)
	return value
