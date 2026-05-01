extends RefCounted

const SLOT_LABELS := {
	"body": "\u6218\u6597",
	"combat": "\u8FDE\u643A",
	"skill": "\u5927\u62DB",
	"special": "\u5956\u52B1"
}

const CORE_CARD_ORDER := [
	"battle_dangzhen_qichao",
	"battle_dangzhen_dielang",
	"battle_dangzhen_huichao"
]

const BRANCH_THEME_IDS := [
	"branch_omni_edge",
	"branch_blood_shield",
	"branch_tri_finale"
]

const THEME_DATA := {
	"theme_threefold_tide": {
		"title": "三相荡阵",
		"description": "开局主题：起潮、叠浪、回潮分别代表直线主伤、多段扩散、回收防御。",
		"card_ids": CORE_CARD_ORDER,
		"initial": true
	},
	"branch_omni_edge": {
		"title": "万向锋路",
		"description": "起潮 + 叠浪导向的分支：单方向推进到扇形、环形与全方向覆盖。",
		"card_ids": ["battle_omni_pierce", "battle_omni_fan", "battle_omni_ring"]
	},
	"branch_blood_shield": {
		"title": "血盾回路",
		"description": "起潮 + 回潮导向的分支：吸血、护盾、击退与控制反击。",
		"card_ids": ["battle_blood_drink", "battle_blood_shield", "battle_blood_reflux"]
	},
	"branch_tri_finale": {
		"title": "三相终式",
		"description": "叠浪 + 回潮导向的分支：回能、大招变形、三元素终式。",
		"card_ids": ["battle_finale_charge", "battle_finale_break", "battle_finale_unity"]
	}
}

const THEME_UNLOCK_RECIPES := {
	"branch_omni_edge": {
		"title": "万向锋路",
		"description": "起潮与叠浪形成进攻配比后解锁。",
		"requirements": {
			"battle_dangzhen_qichao": 2,
			"battle_dangzhen_dielang": 1
		}
	},
	"branch_blood_shield": {
		"title": "血盾回路",
		"description": "起潮与回潮形成攻守配比后解锁。",
		"requirements": {
			"battle_dangzhen_qichao": 2,
			"battle_dangzhen_huichao": 1
		}
	},
	"branch_tri_finale": {
		"title": "三相终式",
		"description": "叠浪与回潮形成循环配比后解锁。",
		"requirements": {
			"battle_dangzhen_dielang": 2,
			"battle_dangzhen_huichao": 1
		}
	}
}

const EVOLUTION_CARD_ORDER := [
	"battle_omni_pierce",
	"battle_omni_fan",
	"battle_omni_ring",
	"battle_blood_drink",
	"battle_blood_shield",
	"battle_blood_reflux",
	"battle_finale_charge",
	"battle_finale_break",
	"battle_finale_unity"
]

const EVOLUTION_REWARD_CARD_IDS := {
	"branch_omni_edge": [
		"battle_omni_pierce",
		"battle_omni_fan",
		"battle_omni_ring"
	],
	"branch_blood_shield": [
		"battle_blood_drink",
		"battle_blood_shield",
		"battle_blood_reflux"
	],
	"branch_tri_finale": [
		"battle_finale_charge",
		"battle_finale_break",
		"battle_finale_unity"
	],
	"small_boss_dangzhen_blade_storm": [
		"battle_omni_pierce",
		"battle_omni_fan",
		"battle_omni_ring"
	],
	"small_boss_dangzhen_infinite_reload": [
		"battle_blood_drink",
		"battle_blood_shield",
		"battle_blood_reflux"
	],
	"small_boss_dangzhen_tidal_surge": [
		"battle_finale_charge",
		"battle_finale_break",
		"battle_finale_unity"
	]
}

const ROLE_EVOLUTION_REWARD_IDS := {
	"swordsman": "branch_omni_edge",
	"gunner": "branch_blood_shield",
	"mage": "branch_tri_finale"
}

const LEGACY_EVOLUTION_CARD_ALIASES := {
	"battle_blade_storm_fury": "battle_omni_pierce",
	"battle_blade_storm_eye": "battle_omni_fan",
	"battle_blade_storm_multi": "battle_omni_ring",
	"battle_infinite_reload_overload": "battle_blood_drink",
	"battle_infinite_reload_chain": "battle_blood_shield",
	"battle_infinite_reload_bore": "battle_blood_reflux",
	"battle_tidal_surge_pressure": "battle_finale_charge",
	"battle_tidal_surge_echo": "battle_finale_break",
	"battle_tidal_surge_widen": "battle_finale_unity"
}

const LEGACY_EVOLUTION_REWARD_ALIASES := {
	"small_boss_dangzhen_blade_storm": "branch_omni_edge",
	"small_boss_dangzhen_infinite_reload": "branch_blood_shield",
	"small_boss_dangzhen_tidal_surge": "branch_tri_finale"
}



const CARD_TYPE_LABELS := {
	"new_passive": "新的被动技能",
	"passive_attack": "被动 / 普攻加强",
	"ultimate": "大招加强"
}

const CARD_TYPE_BY_ID := {
	"battle_dangzhen_qichao": "new_passive",
	"battle_dangzhen_dielang": "passive_attack",
	"battle_dangzhen_huichao": "passive_attack",
	"battle_omni_pierce": "new_passive",
	"battle_omni_fan": "new_passive",
	"battle_omni_ring": "new_passive",
	"battle_blood_drink": "passive_attack",
	"battle_blood_shield": "passive_attack",
	"battle_blood_reflux": "new_passive",
	"battle_finale_charge": "ultimate",
	"battle_finale_break": "ultimate",
	"battle_finale_unity": "ultimate"
}

const SKILL_CARD_IDS := [
	"battle_dangzhen_qichao",
	"battle_omni_pierce",
	"battle_omni_fan",
	"battle_omni_ring",
	"battle_blood_reflux"
]

const COOLDOWN_PASSIVE_SKILL_CARD_IDS := [
	"battle_dangzhen_qichao",
	"battle_blood_reflux"
]

const CARD_ROLE_NUMBERS := {
	"battle_dangzhen_qichao": {
		"swordsman": ["解锁前方月牙斩；冷却 7.0 秒。", "伤害：剑士伤害 × (45% + 每级 10%)。", "叠浪：每级 +1 段补发；回潮：每级增加反向/多方向。"],
		"gunner": ["解锁前方贯穿弹；冷却 5.5 秒。", "伤害：枪手伤害 × (38% + 每级 8%)。", "散射：每级 +1 段补发；震退：每级提高射程。"],
		"mage": ["解锁火相冲击波；冷却 7.0 秒。", "伤害：术师伤害 × (40% + 每级 8%)。", "雷相：每级 +1 轮连发；冰相：每级增加夹角和宽度。"]
	},
	"battle_dangzhen_dielang": {
		"swordsman": ["月牙斩补发段数：每级 +1。", "每段继承起潮伤害。"],
		"gunner": ["贯穿弹补发段数：每级 +1。", "每段继承贯穿伤害。"],
		"mage": ["元素波补发轮数：每级 +1。", "每轮继承火相伤害。"]
	},
	"battle_dangzhen_huichao": {
		"swordsman": ["剑气方向扩展：每级增加反向/侧向覆盖。", "覆盖面提高，但不改变基础冷却。"],
		"gunner": ["贯穿射程提高：读取震退等级提升距离。", "无限装填射程：每级 +42%。"],
		"mage": ["冲击波角度/宽度提升。", "波涛涌动宽度：每级 +12%。"]
	},
	"battle_omni_pierce": {
		"swordsman": ["命中触发贯流剑。", "长度：118 + 38 × 等级。", "宽度：16 + 5 × 等级。", "伤害：剑士伤害 × (22% + 6% × 等级)。"],
		"gunner": ["命中触发穿甲线。", "长度：118 + 38 × 等级。", "宽度：16 + 5 × 等级。", "伤害：枪手伤害 × (22% + 6% × 等级)。"],
		"mage": ["命中触发火雷贯链。", "长度：118 + 38 × 等级。", "宽度：16 + 5 × 等级。", "伤害：术师伤害 × (22% + 6% × 等级)。"]
	},
	"battle_omni_fan": {
		"swordsman": ["命中 ≥2 个敌人触发分浪剑阵。", "弹道数：Lv1=3，Lv2=4，Lv3=6。", "伤害：剑士伤害 × (20% + 5.5% × 等级)。"],
		"gunner": ["命中 ≥2 个敌人触发扇面散射。", "弹道数：Lv1=3，Lv2=4，Lv3=6。", "伤害：枪手伤害 × (20% + 5.5% × 等级)。"],
		"mage": ["命中 ≥2 个敌人触发雷火扇爆。", "弹道数：Lv1=3，Lv2=4，Lv3=6。", "伤害：术师伤害 × (20% + 5.5% × 等级)。"]
	},
	"battle_omni_ring": {
		"swordsman": ["命中 ≥3 或击杀触发回潮环斩。", "半径：52 + 16 × 等级。", "伤害：剑士伤害 × (18% + 5.5% × 等级)。"],
		"gunner": ["命中 ≥3 或击杀触发环形弹幕。", "半径：52 + 16 × 等级。", "伤害：枪手伤害 × (18% + 5.5% × 等级)。"],
		"mage": ["命中 ≥3 或击杀触发火雷环阵。", "半径：52 + 16 × 等级。", "伤害：术师伤害 × (18% + 5.5% × 等级)。"]
	},
	"battle_blood_drink": {
		"swordsman": ["命中回血：角色伤害 × 1.8% × 等级 × 命中数，最多计 6 命中。", "击杀额外回血：0.8 × 等级。"],
		"gunner": ["命中回血：角色伤害 × 1.8% × 等级 × 命中数，最多计 6 命中。", "枪手额外回能：0.25 × 等级 / 次触发。"],
		"mage": ["命中回血：角色伤害 × 1.8% × 等级 × 命中数，最多计 6 命中。", "击杀额外回血：0.8 × 等级；冰火控制提高站场收益。"]
	},
	"battle_blood_shield": {
		"swordsman": ["拾取时最大生命 +8，当前生命 +8。", "基础减伤额外 -2.5%。", "战斗减伤再乘以 1 - 3.5% × 等级，最低乘区 78%。"],
		"gunner": ["拾取时最大生命 +8，当前生命 +8。", "基础减伤额外 -2.5%。", "压制站桩容错提高。"],
		"mage": ["拾取时最大生命 +8，当前生命 +8。", "基础减伤额外 -2.5%。", "冰盾回路提高被围时容错。"]
	},
	"battle_blood_reflux": {
		"swordsman": ["受击触发血返环斩。", "冷却：0.65 秒。", "半径：58 + 14 × 等级。", "伤害：剑士伤害 × (34% + 10% × 等级) + 本次伤害 × 22%。"],
		"gunner": ["受击触发震退反冲。", "冷却：0.65 秒。", "半径：58 + 14 × 等级。", "伤害：枪手伤害 × (34% + 10% × 等级) + 本次伤害 × 22%。"],
		"mage": ["受击触发冰雷反场。", "冷却：0.65 秒。", "半径：58 + 14 × 等级。", "伤害：术师伤害 × (34% + 10% × 等级) + 本次伤害 × 22%；减速更强。"]
	},
	"battle_finale_charge": {
		"swordsman": ["能量获取倍率 +8%。", "最大能量 +4。", "命中 ≥2 触发蓄势冲击：半径 24 + 6 × 等级，伤害 × (14% + 3.5% × 等级)。", "命中回能：0.16 × 等级 × 命中数。"],
		"gunner": ["能量获取倍率 +8%。", "最大能量 +4。", "命中 ≥2 触发蓄膛冲击：半径 24 + 6 × 等级，伤害 × (14% + 3.5% × 等级)。", "命中回能：0.16 × 等级 × 命中数。"],
		"mage": ["能量获取倍率 +8%。", "最大能量 +4。", "命中 ≥2 触发火雷蓄相冲击：半径 24 + 6 × 等级，伤害 × (14% + 3.5% × 等级)。", "命中回能：0.16 × 等级 × 命中数。"]
	},
	"battle_finale_break": {
		"swordsman": ["大招消耗倍率 -4%，最低 58%。", "击杀触发破势终斩。", "长度：98 + 28 × 等级；宽度：22 + 4 × 等级。", "伤害：剑士伤害 × (34% + 8% × 等级)。"],
		"gunner": ["大招消耗倍率 -4%，最低 58%。", "击杀触发破膛穿炮。", "长度：98 + 28 × 等级；宽度：22 + 4 × 等级。", "伤害：枪手伤害 × (34% + 8% × 等级)。"],
		"mage": ["大招消耗倍率 -4%，最低 58%。", "击杀触发雷冰破相。", "长度：98 + 28 × 等级；宽度：22 + 4 × 等级。", "伤害：术师伤害 × (34% + 8% × 等级)，并附带减速。"]
	},
	"battle_finale_unity": {
		"swordsman": ["全局伤害 +3%。", "后台攻击间隔倍率 -4%，最低 45%。", "命中 ≥4 或击杀触发三相环斩。", "半径：70 + 20 × 等级；伤害：剑士伤害 × (26% + 6.5% × 等级)。"],
		"gunner": ["全局伤害 +3%。", "后台攻击间隔倍率 -4%，最低 45%。", "命中 ≥4 或击杀触发三相弹幕。", "半径：70 + 20 × 等级；伤害：枪手伤害 × (26% + 6.5% × 等级)。"],
		"mage": ["全局伤害 +3%。", "后台攻击间隔倍率 -4%，最低 45%。", "命中 ≥4 或击杀触发火雷冰归一。", "半径：70 + 20 × 等级；伤害：术师伤害 × (26% + 6.5% × 等级)，并附带减速。"]
	}
}

const ROLE_CARD_VARIANTS := {
	"battle_dangzhen_qichao": {
		"swordsman": {
			"title": "起潮",
			"preview": "获得前突月牙斩，作为剑士荡阵起手技能。",
			"detail": "剑士·起潮。普攻后追加前方月牙斩，建立单方向进攻轴。",
			"detail_lines": ["技能牌：追加独立剑气段。", "后续叠浪会复制这一方向的剑气，回潮会改变方向。"]
		},
		"gunner": {
			"title": "贯穿",
			"preview": "获得前向贯穿弹，作为枪手荡阵起手技能。",
			"detail": "枪手·贯穿。普攻后追加一发前向穿透弹，适合拉直线清怪。",
			"detail_lines": ["技能牌：追加独立贯穿弹。", "后续散射会补发弹链，震退会扩大距离和控制价值。"]
		},
		"mage": {
			"title": "火相",
			"preview": "获得火相冲击波，作为术师三元素起手。",
			"detail": "术师·火相。普攻后追加火相冲击波，作为火/雷/冰组合的第一相。",
			"detail_lines": ["技能牌：追加直线元素波。", "后续雷相会增加连发，冰相会改变角度和控制面。"]
		}
	},
	"battle_dangzhen_dielang": {
		"swordsman": {
			"title": "叠浪",
			"preview": "月牙斩结束后继续补发剑气。",
			"detail": "剑士·叠浪。当前月牙斩结束后，继续补发同方向月牙斩。",
			"detail_lines": ["增强牌：提高剑气段数。", "与回潮组合后会形成多方向补发。"]
		},
		"gunner": {
			"title": "散射",
			"preview": "贯穿弹结束后继续补发弹链。",
			"detail": "枪手·散射。贯穿弹结束后继续补发同方向弹链，并为后续散射路线提供基础。",
			"detail_lines": ["增强牌：提高弹链段数。", "与震退组合后形成远距离压制。"]
		},
		"mage": {
			"title": "雷相",
			"preview": "火相冲击后追加雷相连锁波。",
			"detail": "术师·雷相。第一道元素波后继续补发雷相波，形成火雷连锁。",
			"detail_lines": ["增强牌：提高元素连发段数。", "与冰相组合后形成雷冰控制链。"]
		}
	},
	"battle_dangzhen_huichao": {
		"swordsman": {
			"title": "回潮",
			"preview": "月牙斩向反向或多方向扩展。",
			"detail": "剑士·回潮。剑气不再只向前推进，会向反向或多方向回卷。",
			"detail_lines": ["增强牌：改变剑气方向与覆盖面。", "与叠浪组合后形成潮汐式多段斩。"]
		},
		"gunner": {
			"title": "震退",
			"preview": "贯穿弹距离提高，并更偏控制压制。",
			"detail": "枪手·震退。提高弹道距离与压制面，强化击退和高伤分支。",
			"detail_lines": ["增强牌：提高距离和控制面。", "与散射组合后形成远距离火力网。"]
		},
		"mage": {
			"title": "冰相",
			"preview": "元素波扩成夹角发射，增加控制覆盖。",
			"detail": "术师·冰相。火雷链路加入冰相，冲击波扩成夹角并获得更强控制面。",
			"detail_lines": ["增强牌：改变元素方向与范围。", "火/雷/冰的配比会解锁后续三相终式。"]
		}
	},
	"battle_omni_pierce": {
		"swordsman": {"title": "贯流剑", "preview": "解锁被动技能：命中时向前贯出长线剑气。", "detail": "剑士·贯流剑。命中后触发前向长线剑气，按等级提高伤害和长度。", "detail_lines": ["技能牌：触发式直线剑气。", "继承万向锋路的单方向推进路线。"]},
		"gunner": {"title": "穿甲线", "preview": "解锁被动技能：命中时追加穿甲光束。", "detail": "枪手·穿甲线。命中后追加前向穿甲线，适合贯穿密集敌群。", "detail_lines": ["技能牌：触发式直线火力。", "与散射、震退路线共同扩充覆盖。"]},
		"mage": {"title": "火雷贯链", "preview": "解锁被动技能：火雷组合形成直线爆链。", "detail": "术师·火雷贯链。命中后释放火雷直线爆链，造成穿透伤害。", "detail_lines": ["技能牌：触发式火雷直线。", "这是术师版本的贯流，不显示为剑士名。"]}
	},
	"battle_omni_fan": {
		"swordsman": {"title": "分浪剑阵", "preview": "解锁被动技能：多目标命中时扇形斩开。", "detail": "剑士·分浪剑阵。命中多个敌人时向前扇形分裂剑气。", "detail_lines": ["技能牌：触发式扇形斩。", "与叠浪式连段形成更大清场面。"]},
		"gunner": {"title": "扇面散射", "preview": "解锁被动技能：多目标命中时扇面散射。", "detail": "枪手·扇面散射。命中多个敌人时释放扇面弹幕。", "detail_lines": ["技能牌：触发式散射火力。", "强化枪手主散射路线。"]},
		"mage": {"title": "雷火扇爆", "preview": "解锁被动技能：雷火组合扇形爆发。", "detail": "术师·雷火扇爆。命中多个敌人时释放雷火扇形爆发。", "detail_lines": ["技能牌：触发式雷火扇面。", "区别于剑士分浪与枪手散射。"]}
	},
	"battle_omni_ring": {
		"swordsman": {"title": "回潮环斩", "preview": "解锁被动技能：高命中或击杀时身周环斩。", "detail": "剑士·回潮环斩。高命中或击杀时在身周释放环形剑气。", "detail_lines": ["技能牌：触发式环形斩。", "把回潮路线推进到全方向覆盖。"]},
		"gunner": {"title": "环形弹幕", "preview": "解锁被动技能：高命中或击杀时环形扫射。", "detail": "枪手·环形弹幕。高命中或击杀时在身周释放环形弹幕。", "detail_lines": ["技能牌：触发式环形火力。", "给枪手提供近身清场保护。"]},
		"mage": {"title": "火雷环阵", "preview": "解锁被动技能：高命中或击杀时火雷环阵爆发。", "detail": "术师·火雷环阵。高命中或击杀时展开火雷环阵，清理身周敌人。", "detail_lines": ["技能牌：触发式元素环阵。", "这是术师全方向覆盖版本。"]}
	},
	"battle_blood_drink": {
		"swordsman": {"title": "饮血剑", "preview": "命中回血，并提高剑士续航。", "detail": "剑士·饮血剑。命中按命中数回复生命，击杀时额外回复。", "detail_lines": ["加成牌：续航。", "适合近身承压。"]},
		"gunner": {"title": "压制回能", "preview": "命中回能，枪手命中额外补充大招能量。", "detail": "枪手·压制回能。贯穿或压制命中后额外补充大招能量。", "detail_lines": ["加成牌：能量循环。", "适合高频命中火力。"]},
		"mage": {"title": "冰火汲取", "preview": "命中回血，并强化术师冰火吸取。", "detail": "术师·冰火汲取。元素命中后回复生命，受控敌人收益更高。", "detail_lines": ["加成牌：续航。", "为冰火组合提供安全回报。"]}
	},
	"battle_blood_shield": {
		"swordsman": {"title": "凝血盾", "preview": "提高最大生命和减伤。", "detail": "剑士·凝血盾。提高最大生命和减伤，给近身站场提供容错。", "detail_lines": ["加成牌：防御。"]},
		"gunner": {"title": "压制护幕", "preview": "提高减伤，并强化枪手站桩压制容错。", "detail": "枪手·压制护幕。连续压制路线获得更高生存容错。", "detail_lines": ["加成牌：防御。"]},
		"mage": {"title": "冰盾回路", "preview": "提高减伤，并强化术师冰系保护。", "detail": "术师·冰盾回路。冰系控制期间更安全，能量循环更稳定。", "detail_lines": ["加成牌：防御。"]}
	},
	"battle_blood_reflux": {
		"swordsman": {"title": "血返环斩", "preview": "解锁受击反击：释放吸血环斩。", "detail": "剑士·血返环斩。受击后触发环形反击，造成伤害并短暂保护自身。", "detail_lines": ["技能牌：受击反击。"]},
		"gunner": {"title": "震退反冲", "preview": "解锁受击反击：释放震退冲击。", "detail": "枪手·震退反冲。受击后释放震退冲击，压开周围敌人。", "detail_lines": ["技能牌：受击反击。"]},
		"mage": {"title": "冰雷反场", "preview": "解锁受击反击：释放冰雷控制场。", "detail": "术师·冰雷反场。受击后释放冰雷控制场，减速并伤害周围敌人。", "detail_lines": ["技能牌：受击反击。", "这是冰雷组合的防御触发版本。"]}
	},
	"battle_finale_charge": {
		"swordsman": {"title": "蓄势", "preview": "命中回能，并为终结剑气蓄力。", "detail": "剑士·蓄势。命中越多，大招能量越稳定，并会触发小型蓄势冲击。", "detail_lines": ["加成牌：回能 + 小爆发。"]},
		"gunner": {"title": "蓄膛", "preview": "穿刺命中回能，并为压缩炮蓄力。", "detail": "枪手·蓄膛。多目标命中获得更多能量，并会触发小型蓄膛爆发。", "detail_lines": ["加成牌：回能 + 小爆发。"]},
		"mage": {"title": "火雷蓄相", "preview": "记录火雷排列，提高回能并触发元素蓄爆。", "detail": "术师·火雷蓄相。火雷命中记录终式能量，并触发小型元素蓄爆。", "detail_lines": ["加成牌：回能 + 元素爆发。"]}
	},
	"battle_finale_break": {
		"swordsman": {"title": "破势终斩", "preview": "解锁击杀触发：追加终结剑气。", "detail": "剑士·破势终斩。击杀后释放终结剑气，强化大招路线。", "detail_lines": ["技能牌：击杀触发。"]},
		"gunner": {"title": "破膛穿炮", "preview": "解锁击杀触发：追加高伤穿炮。", "detail": "枪手·破膛穿炮。击杀后追加高伤穿刺炮，适合穿透队列。", "detail_lines": ["技能牌：击杀触发。"]},
		"mage": {"title": "雷冰破相", "preview": "解锁击杀触发：释放雷冰破相。", "detail": "术师·雷冰破相。击杀后释放雷冰组合爆发。", "detail_lines": ["技能牌：击杀触发。", "火雷、雷冰、冰火会逐步导向三相终式。"]}
	},
	"battle_finale_unity": {
		"swordsman": {"title": "三相环斩", "preview": "解锁终局触发：高命中时释放三相环斩。", "detail": "剑士·三相环斩。高命中或击杀时释放三相环斩，兼具清场和回能。", "detail_lines": ["技能牌：终局触发。"]},
		"gunner": {"title": "三相弹幕", "preview": "解锁终局触发：高命中时释放三相弹幕。", "detail": "枪手·三相弹幕。高命中或击杀时释放三相弹幕爆发。", "detail_lines": ["技能牌：终局触发。"]},
		"mage": {"title": "火雷冰归一", "preview": "解锁终局触发：火雷冰领域轮转。", "detail": "术师·火雷冰归一。高命中或击杀时释放火雷冰轮转领域。", "detail_lines": ["技能牌：终局触发。", "这是术师三元素排列组合的终点。"]}
	}
}

const CORE_CARDS := {
	"battle_dangzhen_qichao": {
		"title": "\u8D77\u6F6E",
		"slot": "body",
		"max_level": 3,
		"set_key": "battle_dangzhen",
		"preview": "\u83B7\u5F97\u8361\u9635\u989D\u5916\u653B\u51FB\u624B\u6BB5\u3002",
		"detail": "\u8361\u9635\u8D77\u624B\u5361\u3002\u5251\u58EB\u8FFD\u52A0\u6708\u7259\u65A9\uFF0C\u67AA\u624B\u8FFD\u52A0\u8D2F\u7A7F\u5F39\uFF0C\u672F\u5E08\u8FFD\u52A0\u51B2\u51FB\u6CE2\u3002",
		"detail_lines": [
			"\u5251\u58EB\uFF1A\u8FFD\u52A0\u6708\u7259\u65A9\uFF0C\u4F5C\u4E3A\u72EC\u7ACB\u7684\u989D\u5916\u4F24\u5BB3\u6BB5\u3002",
			"\u67AA\u624B\uFF1A\u8FFD\u52A0\u8D2F\u7A7F\u5F39\uFF0C\u5411\u524D\u65B9\u8D2F\u7A7F\u6253\u51FB\u3002",
			"\u672F\u5E08\uFF1A\u805A\u80FD\u540E\u8FFD\u52A0\u51B2\u51FB\u6CE2\u3002",
			"\u53E0\u6D6A\u4E0E\u56DE\u6F6E\u9700\u8981\u5148\u62FF\u5230\u8D77\u6F6E\u624D\u4F1A\u8FDB\u5165\u5361\u6C60\u3002"
		]
	},
	"battle_dangzhen_dielang": {
		"title": "\u53E0\u6D6A",
		"slot": "body",
		"max_level": 3,
		"set_key": "battle_dangzhen",
		"requires": ["battle_dangzhen_qichao"],
		"preview": "\u8361\u9635\u653B\u51FB\u7ED3\u675F\u540E\u8FFD\u52A0\u8865\u53D1\u3002",
		"detail": "\u8361\u9635\u8FFD\u51FB\u5361\u3002\u6BCF\u6B21\u7279\u6548\u4E0E\u5224\u5B9A\u7ED3\u675F\u540E\uFF0C\u7ACB\u523B\u8865\u53D1\u4E0B\u4E00\u6BB5\u540C\u65B9\u5411\u653B\u51FB\u3002",
		"detail_lines": [
			"\u5251\u58EB\uFF1A\u5F53\u524D\u6708\u7259\u65A9\u7ED3\u675F\u540E\uFF0C\u7EE7\u7EED\u8865\u53D1\u540C\u65B9\u5411\u6708\u7259\u65A9\u3002",
			"\u67AA\u624B\uFF1A\u5F53\u524D\u8D2F\u7A7F\u5F39\u7ED3\u675F\u540E\uFF0C\u7EE7\u7EED\u8865\u53D1\u540C\u65B9\u5411\u8D2F\u7A7F\u5F39\u3002",
			"\u672F\u5E08\uFF1A\u7B2C\u4E00\u9053\u51B2\u51FB\u6CE2\u540E\uFF0C\u7EE7\u7EED\u8865\u53D1\u540C\u65B9\u5411\u540E\u7EED\u6CE2\u3002",
			"\u7B49\u7EA7\u8D8A\u9AD8\uFF0C\u8FDE\u7EED\u8865\u53D1\u7684\u6BB5\u6570\u8D8A\u591A\u3002"
		]
	},
	"battle_dangzhen_huichao": {
		"title": "\u56DE\u6F6E",
		"slot": "body",
		"max_level": 3,
		"set_key": "battle_dangzhen",
		"requires": ["battle_dangzhen_qichao"],
		"preview": "\u6539\u53D8\u8361\u9635\u653B\u51FB\u7684\u65B9\u5411\u6216\u8DDD\u79BB\u3002",
		"detail": "\u8361\u9635\u53D8\u5316\u5361\u3002\u5251\u58EB\u6269\u6210\u591A\u65B9\u5411\u65A9\u51FB\uFF0C\u67AA\u624B\u5F3A\u5316\u8D2F\u7A7F\u8DDD\u79BB\uFF0C\u672F\u5E08\u6269\u6210\u5939\u89D2\u51B2\u51FB\u6CE2\u3002",
		"detail_lines": [
			"\u5251\u58EB\uFF1A\u8FFD\u52A0\u65A9\u51FB\u4F1A\u5411\u53CD\u65B9\u5411\u6216\u591A\u65B9\u5411\u6269\u5C55\u3002",
			"\u67AA\u624B\uFF1A\u8D2F\u7A7F\u5F39\u5C04\u7A0B\u63D0\u9AD8\uFF0C\u5E76\u7EE7\u627F\u53E0\u6D6A\u8865\u53D1\u3002",
			"\u672F\u5E08\uFF1A\u51B2\u51FB\u6CE2\u6269\u6210\u5939\u89D2\u53D1\u5C04\uFF0C\u5E76\u7EE7\u627F\u53E0\u6D6A\u8865\u53D1\u3002",
			"\u8FD9\u5F20\u5361\u4E3B\u8981\u6269\u5927\u8986\u76D6\u9762\uFF0C\u4E0D\u6539\u53D8\u8361\u9635\u7684\u57FA\u7840\u89E6\u53D1\u6761\u4EF6\u3002"
		]
	}
}

const EVOLUTION_CARDS := {
	"battle_omni_pierce": {
		"title": "贯流",
		"slot": "body",
		"theme_id": "branch_omni_edge",
		"max_level": 3,
		"preview": "强化直线穿透与单方向推进。",
		"detail": "万向锋路·贯流。剑士剑气更长并可穿透；枪手穿刺弹强化；术师火雷组合形成直线爆链。",
		"detail_lines": [
			"剑士：荡阵剑气伤害提高，前方单方向推进更强。",
			"枪手：贯穿判定与射程倾向提高，穿透目标更稳定。",
			"术师：火雷排列强化直线爆发，波浪命中后更容易形成连锁爆裂。"
		]
	},
	"battle_omni_fan": {
		"title": "分浪",
		"slot": "body",
		"theme_id": "branch_omni_edge",
		"max_level": 3,
		"preview": "强化扇形扩散、散射和多段覆盖。",
		"detail": "万向锋路·分浪。剑士由单方向扩成扇形；枪手散射弹片更多；术师雷火组合形成扇形连锁爆发。",
		"detail_lines": [
			"剑士：提高叠浪补发价值，后续更容易形成多方向斩击。",
			"枪手：散射倾向增强，弹片数量与覆盖面提升。",
			"术师：雷火排列强化扇形连锁，适合清理密集敌群。"
		]
	},
	"battle_omni_ring": {
		"title": "环潮",
		"slot": "body",
		"theme_id": "branch_omni_edge",
		"max_level": 3,
		"preview": "强化环形、全方向和身周覆盖。",
		"detail": "万向锋路·环潮。剑士逐步走向全方向环斩；枪手获得环形溅射倾向；术师火雷环阵围绕自身释放。",
		"detail_lines": [
			"剑士：回潮方向扩展更强，满级后荡阵趋向所有方向覆盖。",
			"枪手：散射与穿刺命中后追加身周溅射压制。",
			"术师：火雷环阵增强身边安全区与持续清场能力。"
		]
	},
	"battle_blood_drink": {
		"title": "饮潮",
		"slot": "body",
		"theme_id": "branch_blood_shield",
		"max_level": 3,
		"preview": "命中回复生命或能量，建立续航。",
		"detail": "血盾回路·饮潮。剑士命中回血；枪手击退或压制时回能；术师冰火吸取，命中受控敌人获得护盾。",
		"detail_lines": [
			"剑士：荡阵命中后按命中数回复生命。",
			"枪手：贯穿/压制命中后补充大招能量。",
			"术师：冰火吸取强化控制后的生存回报。"
		]
	},
	"battle_blood_shield": {
		"title": "凝盾",
		"slot": "body",
		"theme_id": "branch_blood_shield",
		"max_level": 3,
		"preview": "提高护盾、防御和站场容错。",
		"detail": "血盾回路·凝盾。剑士溢出治疗转防御；枪手连续压制获得护盾；术师冰元素生成护盾并提高回能。",
		"detail_lines": [
			"剑士：最大生命与减伤提高，适合近身硬抗。",
			"枪手：击退/高伤压制路线获得更高容错。",
			"术师：冰系控制期间更安全，能量循环更稳定。"
		]
	},
	"battle_blood_reflux": {
		"title": "退潮",
		"slot": "body",
		"theme_id": "branch_blood_shield",
		"max_level": 3,
		"preview": "护盾反击、击退强化和控制场。",
		"detail": "血盾回路·退潮。剑士护盾破裂释放环形斩；枪手击退增强，不可击退则转高伤；术师冰雷组合生成冻结/麻痹控制场。",
		"detail_lines": [
			"剑士：提高受压时反击能力。",
			"枪手：控制不生效时转化为额外伤害。",
			"术师：冰雷排列强化减速、冻结和麻痹控制。"
		]
	},
	"battle_finale_charge": {
		"title": "蓄相",
		"slot": "body",
		"theme_id": "branch_tri_finale",
		"max_level": 3,
		"preview": "提高大招能量获取与元素记录。",
		"detail": "三相终式·蓄相。剑士普攻命中回能；枪手穿刺多目标回能；术师记录火雷冰排列，准备组合技能。",
		"detail_lines": [
			"剑士：命中数越高，大招能量越稳定。",
			"枪手：穿刺命中多个敌人时获得更多能量。",
			"术师：火/雷/冰排列越完整，后续终式越强。"
		]
	},
	"battle_finale_break": {
		"title": "破相",
		"slot": "body",
		"theme_id": "branch_tri_finale",
		"max_level": 3,
		"preview": "强化大招变形与终结打击。",
		"detail": "三相终式·破相。剑士大招追加终结剑气；枪手大招压缩为高伤穿刺炮；术师按双元素排列释放组合技能。",
		"detail_lines": [
			"剑士：大招终段伤害提高。",
			"枪手：大招更偏高伤害穿刺与爆裂。",
			"术师：火雷、雷冰、冰火等排列会导向不同技能形态。"
		]
	},
	"battle_finale_unity": {
		"title": "归一",
		"slot": "body",
		"theme_id": "branch_tri_finale",
		"max_level": 3,
		"preview": "三元素齐备后的终式领域。",
		"detail": "三相终式·归一。剑士大招期间释放三相环斩；枪手子弹附带元素爆裂；术师生成火雷冰轮转领域。",
		"detail_lines": [
			"剑士：大招持续期获得环斩和生存回响。",
			"枪手：穿刺、散射、击退收益统一到元素爆裂。",
			"术师：火雷冰齐备后形成三相领域。"
		]
	}
}

const FINAL_SETS := {
	"battle_dangzhen": {
		"main_name": "\u8361\u9635",
		"full_title": "\u8361\u9635\uFF1A\u6F6E\u950B\u8FDE\u5377",
		"requirements": [
			{"card_id": "battle_dangzhen_qichao", "label": "\u8D77\u6F6E", "max_level": 3},
			{"card_id": "battle_dangzhen_dielang", "label": "\u53E0\u6D6A", "max_level": 3},
			{"card_id": "battle_dangzhen_huichao", "label": "\u56DE\u6F6E", "max_level": 3}
		]
	}
}

const SMALL_BOSS_REWARDS := {
	"small_boss_dangzhen_qichao": {
		"title": "\u8361\u9635\u8865\u5F3A\u00B7\u8D77\u6F6E",
		"description": "\u8361\u9635\u7684\u8D77\u6F6E\u7B49\u7EA7 +1\uFF0C\u4F18\u5148\u628A\u989D\u5916\u653B\u51FB\u624B\u6BB5\u8865\u51FA\u6765\u3002"
	},
	"small_boss_dangzhen_dielang": {
		"title": "\u8361\u9635\u8865\u5F3A\u00B7\u53E0\u6D6A",
		"description": "\u8361\u9635\u7684\u53E0\u6D6A\u7B49\u7EA7 +1\uFF0C\u8FFD\u52A0\u8FDE\u7EED\u8865\u53D1\u6B21\u6570\u3002"
	},
	"small_boss_dangzhen_huichao": {
		"title": "\u8361\u9635\u8865\u5F3A\u00B7\u56DE\u6F6E",
		"description": "\u8361\u9635\u7684\u56DE\u6F6E\u7B49\u7EA7 +1\uFF0C\u8FFD\u52A0\u65B9\u5411\u53D8\u5316\u4E0E\u8986\u76D6\u8303\u56F4\u3002"
	},
	"small_boss_dangzhen_blade_storm": {
		"title": "主题解锁·万向锋路",
		"description": "旧存档兼容入口。解锁万向锋路主题，后续卡池加入贯流、分浪、环潮；剑士可进入剑刃风暴进化。"
	},
	"small_boss_dangzhen_infinite_reload": {
		"title": "主题解锁·血盾回路",
		"description": "旧存档兼容入口。解锁血盾回路主题，后续卡池加入饮潮、凝盾、退潮；枪手可进入无限装填进化。"
	},
	"small_boss_dangzhen_tidal_surge": {
		"title": "主题解锁·三相终式",
		"description": "旧存档兼容入口。解锁三相终式主题，后续卡池加入蓄相、破相、归一；术师可进入波涛涌动进化。"
	}
}

static func get_slot_label(slot_id: String) -> String:
	return str(SLOT_LABELS.get(slot_id, "\u6784\u7B51"))


static func canonical_card_id(card_id: String) -> String:
	return str(LEGACY_EVOLUTION_CARD_ALIASES.get(card_id, card_id))


static func canonical_reward_id(reward_id: String) -> String:
	return str(LEGACY_EVOLUTION_REWARD_ALIASES.get(reward_id, reward_id))


static func get_core_card(card_id: String) -> Dictionary:
	var canonical_id := canonical_card_id(card_id)
	if CORE_CARDS.has(canonical_id):
		return CORE_CARDS.get(canonical_id, {}).duplicate(true)
	return EVOLUTION_CARDS.get(canonical_id, {}).duplicate(true)


static func get_role_card_variant(card_id: String, role_id: String) -> Dictionary:
	var canonical_id := canonical_card_id(card_id)
	var variants: Dictionary = ROLE_CARD_VARIANTS.get(canonical_id, {})
	return variants.get(role_id, {}).duplicate(true)


static func get_role_card_config(card_id: String, role_id: String) -> Dictionary:
	var config := get_core_card(card_id)
	var canonical_id := canonical_card_id(card_id)
	var card_type := str(CARD_TYPE_BY_ID.get(canonical_id, "passive_attack"))
	config["card_type"] = card_type
	config["card_type_label"] = str(CARD_TYPE_LABELS.get(card_type, card_type))
	config["is_new_passive_skill"] = SKILL_CARD_IDS.has(canonical_id)
	config["has_independent_cooldown"] = COOLDOWN_PASSIVE_SKILL_CARD_IDS.has(canonical_id)
	config["role_effects"] = get_role_effect_payload(canonical_id)
	var variant := get_role_card_variant(canonical_id, role_id)
	if not variant.is_empty():
		for key in variant.keys():
			config[key] = variant[key]
	return config


static func get_card_type(card_id: String) -> String:
	return str(CARD_TYPE_BY_ID.get(canonical_card_id(card_id), "passive_attack"))


static func get_card_type_label(card_id: String) -> String:
	var card_type := get_card_type(card_id)
	return str(CARD_TYPE_LABELS.get(card_type, card_type))


static func is_new_passive_skill_card(card_id: String) -> bool:
	return SKILL_CARD_IDS.has(canonical_card_id(card_id))


static func has_independent_skill_cooldown(card_id: String) -> bool:
	return COOLDOWN_PASSIVE_SKILL_CARD_IDS.has(canonical_card_id(card_id))


static func get_role_effect_payload(card_id: String) -> Array:
	var canonical_id := canonical_card_id(card_id)
	var result: Array = []
	var role_labels := {
		"swordsman": "剑士",
		"gunner": "枪手",
		"mage": "术师"
	}
	var role_order := ["swordsman", "gunner", "mage"]
	var numbers: Dictionary = CARD_ROLE_NUMBERS.get(canonical_id, {})
	for role_id in role_order:
		var variant := get_role_card_variant(canonical_id, role_id)
		var lines: Array = []
		for line in numbers.get(role_id, []):
			lines.append(str(line))
		if lines.is_empty():
			lines.append(str(variant.get("preview", get_core_card(canonical_id).get("preview", ""))))
		result.append({
			"role_id": role_id,
			"role_name": str(role_labels.get(role_id, role_id)),
			"title": str(variant.get("title", get_core_card(canonical_id).get("title", canonical_id))),
			"lines": lines
		})
	return result


static func get_core_card_ids_for_slot(slot_id: String) -> Array:
	var result: Array = []
	for card_id in CORE_CARD_ORDER:
		var config: Dictionary = CORE_CARDS[card_id]
		if str(config.get("slot", "")) == slot_id:
			result.append(card_id)
	return result


static func get_branch_theme_ids() -> Array:
	return BRANCH_THEME_IDS.duplicate()


static func get_theme_data(theme_id: String) -> Dictionary:
	return THEME_DATA.get(theme_id, {}).duplicate(true)


static func get_theme_unlock_recipes() -> Dictionary:
	return THEME_UNLOCK_RECIPES.duplicate(true)


static func get_theme_card_ids(theme_id: String) -> Array:
	var theme_data: Dictionary = THEME_DATA.get(theme_id, {})
	return theme_data.get("card_ids", []).duplicate()


static func get_card_ids_for_theme_slot(theme_id: String, slot_id: String) -> Array:
	var result: Array = []
	for card_id in get_theme_card_ids(theme_id):
		var config := get_core_card(str(card_id))
		if str(config.get("slot", "")) == slot_id:
			result.append(str(card_id))
	return result


static func get_evolution_card_ids_for_reward(reward_id: String) -> Array:
	var canonical_id := canonical_reward_id(reward_id)
	return EVOLUTION_REWARD_CARD_IDS.get(canonical_id, EVOLUTION_REWARD_CARD_IDS.get(reward_id, [])).duplicate()


static func get_evolution_reward_id_for_role(role_id: String) -> String:
	return str(ROLE_EVOLUTION_REWARD_IDS.get(role_id, ""))


static func get_final_set_data(set_key: String) -> Dictionary:
	return FINAL_SETS.get(set_key, {}).duplicate(true)


static func get_small_boss_reward(reward_id: String) -> Dictionary:
	if SMALL_BOSS_REWARDS.has(reward_id):
		return SMALL_BOSS_REWARDS.get(reward_id, {}).duplicate(true)
	var canonical_id := canonical_reward_id(reward_id)
	if SMALL_BOSS_REWARDS.has(canonical_id):
		return SMALL_BOSS_REWARDS.get(canonical_id, {}).duplicate(true)
	var theme_data := get_theme_data(canonical_id)
	if not theme_data.is_empty():
		var title := str(theme_data.get("title", canonical_id))
		return {
			"title": "主题解锁·%s" % title,
			"description": str(theme_data.get("description", ""))
		}
	return {}
