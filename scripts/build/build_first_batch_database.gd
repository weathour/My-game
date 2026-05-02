extends RefCounted

const CARD_TYPE_HERO := "hero"
const CARD_TYPE_CAPSTONE := "capstone"
const CARD_TYPE_RESONANCE_PAIR := "resonance_pair"
const CARD_TYPE_RESONANCE_TRI := "resonance_tri"
const CARD_TYPE_GENERIC := "generic"
const CARD_TYPE_MASTERY := "mastery"

const AXIS_ENTRY := "entry"
const AXIS_EXIT := "exit"
const AXIS_CORE_OUTPUT := "core_output"
const AXIS_ULTIMATE := "ultimate"
const AXIS_CAPSTONE := "capstone"
const AXIS_INDEPENDENT_PASSIVE := "independent_passive"
const AXIS_RESONANCE := "resonance"
const AXIS_GENERIC := "generic"

const SKILL_SURFACE_INDEPENDENT_PASSIVE := "independent_passive"

const POSITION_DAMAGE := "damage"
const POSITION_CONTROL := "control"
const POSITION_SURVIVAL := "survival"
const POSITION_SUPPORT := "support"
const POSITION_SUMMON := "summon"
const POSITION_RESOURCE := "resource"
const POSITION_MOBILITY := "mobility"

const PACKAGE_SWORDSMAN := "swd_break_blood"
const PACKAGE_GUNNER := "gun_overload_fireline"
const PACKAGE_MAGE := "mag_starfall_field"

const ROLE_PACKAGES := {
	"swordsman": PACKAGE_SWORDSMAN,
	"gunner": PACKAGE_GUNNER,
	"mage": PACKAGE_MAGE
}

const TEAM_LEVEL_MILESTONES := [6, 12, 18, 25]

const ROLE_IDENTITY_PROFILES := {
	"swordsman": {
		"primary_position": "frontline_breaker",
		"secondary_positions": ["lifesteal_guard", "taunt_afterimage", "execute_finisher"],
		"position_weights": {POSITION_DAMAGE: 0.75, POSITION_SURVIVAL: 0.8, POSITION_CONTROL: 0.45, POSITION_SUMMON: 0.25, POSITION_SUPPORT: 0.25, POSITION_MOBILITY: 0.45},
		"signature_position": POSITION_SURVIVAL,
		"identity_weights": {"entry_burst": 1.0, "direct_hit": 0.9, "armor_break": 0.9, "lifesteal": 0.75, "guard": 0.7, "overheal": 0.45, "execute": 0.35},
		"signature_identity": "entry_burst",
		"identity_summary": "用近身破阵、吸血和护盾承担输出/生存/控制，副定位也围绕斩击风险展开。"
	},
	"gunner": {
		"primary_position": "ranged_fireline",
		"secondary_positions": ["mark_support", "reload_resource", "drone_spotter"],
		"position_weights": {POSITION_DAMAGE: 0.85, POSITION_SUPPORT: 0.55, POSITION_RESOURCE: 0.45, POSITION_CONTROL: 0.35, POSITION_SUMMON: 0.3, POSITION_SURVIVAL: 0.2},
		"signature_position": POSITION_DAMAGE,
		"identity_weights": {"projectile_storm": 1.0, "projectile_chain": 0.9, "mark_execute": 0.8, "marked": 0.8, "overdrive": 0.75, "resource_loop": 0.55, "command_summon": 0.25},
		"signature_identity": "projectile_storm",
		"identity_summary": "用弹道、标记、装填和过载承担输出/支援/资源循环，副定位也围绕火线窗口展开。"
	},
	"mage": {
		"primary_position": "field_controller",
		"secondary_positions": ["ultimate_battery", "guardian_summon", "domain_support"],
		"position_weights": {POSITION_CONTROL: 0.8, POSITION_SUPPORT: 0.65, POSITION_DAMAGE: 0.65, POSITION_RESOURCE: 0.6, POSITION_SUMMON: 0.55, POSITION_SURVIVAL: 0.35},
		"signature_position": POSITION_CONTROL,
		"identity_weights": {"domain_blast": 1.0, "field_tick": 0.9, "control_lock": 0.8, "ultimate_cycle": 0.75, "field": 0.8, "slowed": 0.65, "charge": 0.6, "command_summon": 0.35},
		"signature_identity": "domain_blast",
		"identity_summary": "用领域、符印、回能和造物承担控制/支援/输出，副定位也围绕法阵持续空间展开。"
	}
}

const CARD_UPGRADE_AXES := {
	"swd_break_step": [AXIS_ENTRY, AXIS_CORE_OUTPUT],
	"swd_blood_echo": [AXIS_CORE_OUTPUT, AXIS_EXIT],
	"swd_tide_pull": [AXIS_ENTRY, AXIS_CORE_OUTPUT],
	"swd_overheal_guard": [AXIS_CORE_OUTPUT, AXIS_EXIT],
	"swd_blade_shadow": [AXIS_INDEPENDENT_PASSIVE, AXIS_ENTRY, AXIS_CORE_OUTPUT],
	"swd_break_execute": [AXIS_CORE_OUTPUT],
	"swd_tide_unbound": [AXIS_CAPSTONE, AXIS_ULTIMATE, AXIS_ENTRY, AXIS_EXIT],
	"gun_entry_barrage": [AXIS_ENTRY, AXIS_CORE_OUTPUT],
	"gun_overload_mag": [AXIS_EXIT, AXIS_CORE_OUTPUT],
	"gun_fireline_mark": [AXIS_CORE_OUTPUT],
	"gun_tactical_reload": [AXIS_CORE_OUTPUT, AXIS_EXIT],
	"gun_spotter_drone": [AXIS_INDEPENDENT_PASSIVE, AXIS_CORE_OUTPUT],
	"gun_suppression_grid": [AXIS_CORE_OUTPUT],
	"gun_infinite_fireline": [AXIS_CAPSTONE, AXIS_ULTIMATE, AXIS_ENTRY, AXIS_CORE_OUTPUT],
	"mag_starfall_seed": [AXIS_ENTRY, AXIS_CORE_OUTPUT],
	"mag_mana_tide": [AXIS_EXIT, AXIS_ULTIMATE],
	"mag_frost_seal": [AXIS_EXIT, AXIS_CORE_OUTPUT],
	"mag_field_convergence": [AXIS_CORE_OUTPUT],
	"mag_guardian_puppet": [AXIS_INDEPENDENT_PASSIVE, AXIS_CORE_OUTPUT, AXIS_EXIT],
	"mag_orbital_script": [AXIS_CORE_OUTPUT],
	"mag_sky_dome": [AXIS_CAPSTONE, AXIS_ULTIMATE, AXIS_ENTRY, AXIS_CORE_OUTPUT]
}

const CARD_POSITION_WEIGHTS := {
	"swd_break_step": {POSITION_DAMAGE: 0.7, POSITION_MOBILITY: 0.5, POSITION_CONTROL: 0.2},
	"swd_blood_echo": {POSITION_SURVIVAL: 0.7, POSITION_DAMAGE: 0.3, POSITION_SUPPORT: 0.2},
	"swd_tide_pull": {POSITION_CONTROL: 0.7, POSITION_DAMAGE: 0.4, POSITION_MOBILITY: 0.3},
	"swd_overheal_guard": {POSITION_SURVIVAL: 0.8, POSITION_SUPPORT: 0.5, POSITION_CONTROL: 0.3},
	"swd_blade_shadow": {POSITION_SUMMON: 0.7, POSITION_CONTROL: 0.4, POSITION_SURVIVAL: 0.4, POSITION_DAMAGE: 0.3},
	"swd_break_execute": {POSITION_DAMAGE: 0.8, POSITION_CONTROL: 0.2},
	"swd_tide_unbound": {POSITION_DAMAGE: 0.9, POSITION_SURVIVAL: 0.4, POSITION_MOBILITY: 0.4},
	"gun_entry_barrage": {POSITION_DAMAGE: 0.8, POSITION_CONTROL: 0.2},
	"gun_overload_mag": {POSITION_SUPPORT: 0.5, POSITION_RESOURCE: 0.4, POSITION_DAMAGE: 0.4},
	"gun_fireline_mark": {POSITION_DAMAGE: 0.5, POSITION_SUPPORT: 0.5, POSITION_CONTROL: 0.3},
	"gun_tactical_reload": {POSITION_RESOURCE: 0.8, POSITION_DAMAGE: 0.4, POSITION_SUPPORT: 0.2},
	"gun_spotter_drone": {POSITION_SUPPORT: 0.7, POSITION_SUMMON: 0.7, POSITION_DAMAGE: 0.2},
	"gun_suppression_grid": {POSITION_CONTROL: 0.7, POSITION_DAMAGE: 0.5, POSITION_SUPPORT: 0.2},
	"gun_infinite_fireline": {POSITION_DAMAGE: 0.9, POSITION_RESOURCE: 0.3},
	"mag_starfall_seed": {POSITION_DAMAGE: 0.6, POSITION_CONTROL: 0.4},
	"mag_mana_tide": {POSITION_RESOURCE: 0.8, POSITION_SUPPORT: 0.5},
	"mag_frost_seal": {POSITION_CONTROL: 0.8, POSITION_SUPPORT: 0.3},
	"mag_field_convergence": {POSITION_DAMAGE: 0.6, POSITION_CONTROL: 0.6},
	"mag_guardian_puppet": {POSITION_SUMMON: 0.8, POSITION_SURVIVAL: 0.7, POSITION_SUPPORT: 0.5, POSITION_CONTROL: 0.3},
	"mag_orbital_script": {POSITION_DAMAGE: 0.6, POSITION_SUPPORT: 0.4, POSITION_CONTROL: 0.3},
	"mag_sky_dome": {POSITION_CONTROL: 0.8, POSITION_DAMAGE: 0.7, POSITION_SUPPORT: 0.4}
}

const CARD_INDEPENDENT_PASSIVES := {
	"swd_blade_shadow": {
		"cooldown_seconds": 9.0,
		"cooldown_slot": "swordsman_blade_shadow",
		"trigger_mode": "after_entry_then_periodic",
		"passive_family": "afterimage_taunt",
		"independent_passive_summary": "入场后按独立冷却留下剑影，重复斩击并短暂嘲讽。"
	},
	"gun_spotter_drone": {
		"cooldown_seconds": 10.0,
		"cooldown_slot": "gunner_spotter_drone",
		"trigger_mode": "auto_mark_high_value_target",
		"passive_family": "spotter_mark_support",
		"independent_passive_summary": "按独立冷却部署无人机，优先标记高价值目标并提供轻支援。"
	},
	"mag_guardian_puppet": {
		"cooldown_seconds": 12.0,
		"cooldown_slot": "mage_guardian_puppet",
		"trigger_mode": "auto_summon_when_field_or_pressure",
		"passive_family": "guardian_field_taunt",
		"independent_passive_summary": "按独立冷却召唤守护傀儡，在领域或高压下承担嘲讽与护盾。"
	}
}

const OFFER_CARD_DEFINITIONS := [
	{
		"id": "swd_break_step",
		"title": "破阵步",
		"owner_role": "swordsman",
		"card_type": CARD_TYPE_HERO,
		"package_id": PACKAGE_SWORDSMAN,
		"team_level_min": 0,
		"max_level": 3,
		"base_weight": 1.0,
		"trait_gain": {"swordsman": 1.0},
		"package_gain": {PACKAGE_SWORDSMAN: 1.0},
		"role_weights": {"swordsman": 1.0},
		"timing_weights": {"entry": 1.0},
		"function_weights": {"burst": 0.8, "mobility": 0.5, "survival": 0.2},
		"mechanic_weights": {"direct_hit": 0.8},
		"archetype_weights": {"entry_burst": 0.9},
		"produce_weights": {"armor_break": 0.8},
		"edge_gain": {"swordsman->gunner": 0.2, "swordsman->mage": 0.2},
		"edge_weights": {"swordsman->gunner": 0.2, "swordsman->mage": 0.2},
		"slot_affinity": {"continue": 1.0, "link": 0.3, "pivot": 0.3},
		"summary": "入场突进距离和斩击伤害提高；Lv.3 在终点追加横斩。"
	},
	{
		"id": "swd_blood_echo",
		"title": "血刃回响",
		"owner_role": "swordsman",
		"card_type": CARD_TYPE_HERO,
		"package_id": PACKAGE_SWORDSMAN,
		"team_level_min": 0,
		"max_level": 3,
		"base_weight": 1.0,
		"trait_gain": {"swordsman": 1.0},
		"package_gain": {PACKAGE_SWORDSMAN: 1.0},
		"role_weights": {"swordsman": 1.0},
		"timing_weights": {"active": 0.6, "exit": 0.4},
		"function_weights": {"survival": 0.7, "lifesteal": 0.8, "sustain": 0.3},
		"mechanic_weights": {"heal": 0.7, "direct_hit": 0.3},
		"archetype_weights": {"lifesteal_grind": 0.8, "guard_counter": 0.2},
		"produce_weights": {"guard": 0.2},
		"edge_gain": {"swordsman->mage": 0.2},
		"edge_weights": {"swordsman->mage": 0.2},
		"slot_affinity": {"continue": 1.0, "link": 0.3, "pivot": 0.4},
		"summary": "攻击破甲敌人回血，离场吸血祝福增强。"
	},
	{
		"id": "swd_tide_pull",
		"title": "断潮聚锋",
		"owner_role": "swordsman",
		"card_type": CARD_TYPE_HERO,
		"package_id": PACKAGE_SWORDSMAN,
		"team_level_min": 6,
		"investment_requirements": {"role_investment": {"swordsman": 2.0}, "package_depth": {PACKAGE_SWORDSMAN: 2.0}},
		"max_level": 3,
		"base_weight": 1.0,
		"trait_gain": {"swordsman": 1.0},
		"package_gain": {PACKAGE_SWORDSMAN: 1.0},
		"role_weights": {"swordsman": 1.0},
		"timing_weights": {"entry": 1.0},
		"function_weights": {"control": 0.7, "burst": 0.5, "mobility": 0.3},
		"mechanic_weights": {"direct_hit": 0.5, "push": 0.6},
		"archetype_weights": {"entry_burst": 0.6, "control_lock": 0.4},
		"consume_weights": {"slowed": 0.5, "field": 0.4},
		"edge_gain": {"mage->swordsman": 0.5},
		"edge_weights": {"mage->swordsman": 0.5},
		"slot_affinity": {"continue": 1.0, "link": 0.5, "pivot": 0.3},
		"summary": "入场终点牵引敌人；对减速或领域内敌人牵引增强。"
	},
	{
		"id": "swd_overheal_guard",
		"title": "血潮护身",
		"owner_role": "swordsman",
		"card_type": CARD_TYPE_HERO,
		"package_id": PACKAGE_SWORDSMAN,
		"team_level_min": 6,
		"investment_requirements": {"role_investment": {"swordsman": 2.0}, "package_depth": {PACKAGE_SWORDSMAN: 2.0}},
		"max_level": 3,
		"base_weight": 1.0,
		"trait_gain": {"swordsman": 1.0},
		"package_gain": {PACKAGE_SWORDSMAN: 1.0},
		"role_weights": {"swordsman": 1.0},
		"timing_weights": {"active": 0.5, "exit": 0.5},
		"function_weights": {"survival": 0.7, "control": 0.3, "burst": 0.2, "shield": 0.5},
		"mechanic_weights": {"heal": 0.5, "overheal": 0.8, "push": 0.4},
		"archetype_weights": {"healing_push": 0.7, "guard_counter": 0.4, "lifesteal_grind": 0.4},
		"produce_weights": {"guard": 0.8, "push": 0.3},
		"bridge_weights": {"lifesteal_grind->healing_push": 0.8, "healing_push->guard_counter": 0.4},
		"package_edges": [{"to": "swd_blade_shadow", "type": "bridge_edge", "cost": 2.0}, {"to": "mag_guardian_puppet", "type": "relay_edge", "cost": 1.0}],
		"slot_affinity": {"continue": 0.8, "link": 0.7, "pivot": 0.8},
		"summary": "过量治疗转护盾，护盾破裂释放推波。"
	},
	{
		"id": "swd_blade_shadow",
		"title": "剑影留形",
		"owner_role": "swordsman",
		"card_type": CARD_TYPE_HERO,
		"package_id": PACKAGE_SWORDSMAN,
		"team_level_min": 12,
		"investment_requirements": {"role_investment": {"swordsman": 4.0}, "package_depth": {PACKAGE_SWORDSMAN: 4.0}},
		"max_level": 3,
		"base_weight": 1.0,
		"trait_gain": {"swordsman": 1.0},
		"package_gain": {PACKAGE_SWORDSMAN: 1.0},
		"role_weights": {"swordsman": 1.0},
		"timing_weights": {"entry": 0.7, "exit": 0.4},
		"function_weights": {"burst": 0.5, "taunt": 0.4, "survival": 0.3},
		"mechanic_weights": {"summon_unit": 0.7, "direct_hit": 0.5},
		"archetype_weights": {"summon_swarm": 0.5, "entry_burst": 0.4, "guard_counter": 0.3},
		"produce_weights": {"guard": 0.4, "summon_unit": 0.7},
		"bridge_weights": {"entry_burst->summon_swarm": 0.6},
		"edge_gain": {"swordsman->mage": 0.3},
		"edge_weights": {"swordsman->mage": 0.3},
		"slot_affinity": {"continue": 0.7, "link": 0.6, "pivot": 0.8},
		"summary": "入场后留下剑影，重复斩击并短暂嘲讽。"
	},
	{
		"id": "swd_break_execute",
		"title": "裂甲处决",
		"owner_role": "swordsman",
		"card_type": CARD_TYPE_HERO,
		"package_id": PACKAGE_SWORDSMAN,
		"team_level_min": 12,
		"investment_requirements": {"role_investment": {"swordsman": 4.0}, "package_depth": {PACKAGE_SWORDSMAN: 4.0}},
		"max_level": 3,
		"base_weight": 1.0,
		"trait_gain": {"swordsman": 1.0},
		"package_gain": {PACKAGE_SWORDSMAN: 1.0},
		"role_weights": {"swordsman": 1.0},
		"timing_weights": {"active": 0.7, "entry": 0.4},
		"function_weights": {"burst": 0.7, "execute": 0.8},
		"mechanic_weights": {"execute": 0.8, "direct_hit": 0.5},
		"archetype_weights": {"mark_execute": 0.6, "entry_burst": 0.4},
		"consume_weights": {"armor_break": 0.8, "vulnerable": 0.5, "marked": 0.3},
		"edge_gain": {"gunner->swordsman": 0.4},
		"edge_weights": {"gunner->swordsman": 0.4},
		"slot_affinity": {"continue": 0.8, "link": 0.7, "pivot": 0.4},
		"summary": "破甲敌人低血量时被处决，精英改为额外伤害。"
	},
	{
		"id": "swd_tide_unbound",
		"title": "断潮无双",
		"owner_role": "swordsman",
		"card_type": CARD_TYPE_CAPSTONE,
		"package_id": PACKAGE_SWORDSMAN,
		"team_level_min": 18,
		"investment_requirements": {"package_depth": {PACKAGE_SWORDSMAN: 6.0}},
		"max_level": 1,
		"base_weight": 0.8,
		"trait_gain": {"swordsman": 1.0},
		"package_gain": {PACKAGE_SWORDSMAN: 2.0},
		"role_weights": {"swordsman": 1.0},
		"timing_weights": {"entry": 1.0, "exit": 0.4},
		"function_weights": {"burst": 0.9, "survival": 0.4, "lifesteal": 0.5},
		"mechanic_weights": {"direct_hit": 0.8, "heal": 0.4},
		"archetype_weights": {"entry_burst": 0.8, "lifesteal_grind": 0.5},
		"produce_weights": {"armor_break": 1.0, "guard": 0.4},
		"edge_gain": {"cycle->swordsman": 1.0},
		"slot_affinity": {"continue": 0.8, "link": 1.0, "pivot": 0.2},
		"summary": "三英雄轮转后，剑士下一次入场变为二段破阵。"
	},

	{
		"id": "gun_entry_barrage",
		"title": "弹幕开局",
		"owner_role": "gunner",
		"card_type": CARD_TYPE_HERO,
		"package_id": PACKAGE_GUNNER,
		"team_level_min": 0,
		"max_level": 3,
		"base_weight": 1.0,
		"trait_gain": {"gunner": 1.0},
		"package_gain": {PACKAGE_GUNNER: 1.0},
		"role_weights": {"gunner": 1.0},
		"timing_weights": {"entry": 1.0},
		"function_weights": {"burst": 0.5, "projectile": 0.9},
		"mechanic_weights": {"projectile_chain": 0.8},
		"archetype_weights": {"projectile_storm": 0.9},
		"produce_weights": {"marked": 0.5},
		"edge_gain": {"gunner->mage": 0.2},
		"edge_weights": {"gunner->mage": 0.2},
		"slot_affinity": {"continue": 1.0, "link": 0.3, "pivot": 0.3},
		"summary": "入场弹幕伤害提高；Lv.3 额外增加一波弹幕。"
	},
	{
		"id": "gun_overload_mag",
		"title": "过载弹匣",
		"owner_role": "gunner",
		"card_type": CARD_TYPE_HERO,
		"package_id": PACKAGE_GUNNER,
		"team_level_min": 0,
		"max_level": 3,
		"base_weight": 1.0,
		"trait_gain": {"gunner": 1.0},
		"package_gain": {PACKAGE_GUNNER: 1.0},
		"role_weights": {"gunner": 1.0},
		"timing_weights": {"exit": 0.8},
		"function_weights": {"sustain": 0.5, "projectile": 0.4, "pass_next": 0.8},
		"mechanic_weights": {"resource_loop": 0.5, "projectile_chain": 0.4},
		"archetype_weights": {"projectile_storm": 0.6, "ultimate_cycle": 0.3},
		"produce_weights": {"overdrive": 0.8},
		"edge_gain": {"gunner->swordsman": 0.3},
		"edge_weights": {"gunner->swordsman": 0.3},
		"slot_affinity": {"continue": 1.0, "link": 0.5, "pivot": 0.4},
		"summary": "离场过载持续更久，并强化下一名英雄火力窗口。"
	},
	{
		"id": "gun_fireline_mark",
		"title": "火线标记",
		"owner_role": "gunner",
		"card_type": CARD_TYPE_HERO,
		"package_id": PACKAGE_GUNNER,
		"team_level_min": 6,
		"investment_requirements": {"role_investment": {"gunner": 2.0}, "package_depth": {PACKAGE_GUNNER: 2.0}},
		"max_level": 3,
		"base_weight": 1.0,
		"trait_gain": {"gunner": 1.0},
		"package_gain": {PACKAGE_GUNNER: 1.0},
		"role_weights": {"gunner": 1.0},
		"timing_weights": {"active": 1.0},
		"function_weights": {"mark": 0.9, "projectile": 0.6, "burst": 0.2},
		"mechanic_weights": {"projectile_chain": 0.7},
		"archetype_weights": {"mark_execute": 0.7, "projectile_storm": 0.5},
		"produce_weights": {"marked": 0.9},
		"consume_weights": {"armor_break": 0.6},
		"edge_gain": {"swordsman->gunner": 0.6},
		"edge_weights": {"swordsman->gunner": 0.6},
		"slot_affinity": {"continue": 1.0, "link": 0.7, "pivot": 0.3},
		"summary": "连续命中标记敌人，攻击破甲敌人立即标记。"
	},
	{
		"id": "gun_tactical_reload",
		"title": "战术装填",
		"owner_role": "gunner",
		"card_type": CARD_TYPE_HERO,
		"package_id": PACKAGE_GUNNER,
		"team_level_min": 6,
		"investment_requirements": {"role_investment": {"gunner": 2.0}, "package_depth": {PACKAGE_GUNNER: 2.0}},
		"max_level": 3,
		"base_weight": 1.0,
		"trait_gain": {"gunner": 1.0},
		"package_gain": {PACKAGE_GUNNER: 1.0},
		"role_weights": {"gunner": 1.0},
		"timing_weights": {"active": 0.7, "exit": 0.3},
		"function_weights": {"energy": 0.5, "sustain": 0.6, "projectile": 0.4},
		"mechanic_weights": {"resource_loop": 0.8, "projectile_chain": 0.3},
		"archetype_weights": {"projectile_storm": 0.5, "ultimate_cycle": 0.5},
		"consume_weights": {"marked": 0.7, "overdrive": 0.3},
		"slot_affinity": {"continue": 1.0, "link": 0.5, "pivot": 0.3},
		"summary": "击杀标记敌人返还装填/过载时间。"
	},
	{
		"id": "gun_spotter_drone",
		"title": "侦察无人机",
		"owner_role": "gunner",
		"card_type": CARD_TYPE_HERO,
		"package_id": PACKAGE_GUNNER,
		"team_level_min": 12,
		"investment_requirements": {"role_investment": {"gunner": 4.0}, "package_depth": {PACKAGE_GUNNER: 4.0}},
		"max_level": 3,
		"base_weight": 1.0,
		"trait_gain": {"gunner": 1.0},
		"package_gain": {PACKAGE_GUNNER: 1.0},
		"role_weights": {"gunner": 1.0},
		"timing_weights": {"active": 0.7, "exit": 0.3},
		"function_weights": {"mark": 0.8, "sustain": 0.3, "survival": 0.2},
		"mechanic_weights": {"summon_unit": 0.7, "command_summon": 0.6},
		"archetype_weights": {"summon_swarm": 0.5, "mark_execute": 0.6, "projectile_storm": 0.3},
		"produce_weights": {"marked": 0.9, "summon_unit": 0.7},
		"bridge_weights": {"projectile_storm->summon_swarm": 0.5, "mark_execute->summon_swarm": 0.6},
		"package_edges": [{"to": "mag_guardian_puppet", "type": "mirror_edge", "cost": 1.5}, {"to": "swd_break_execute", "type": "relay_edge", "cost": 1.0}],
		"slot_affinity": {"continue": 0.7, "link": 0.8, "pivot": 0.8},
		"summary": "无人机标记关键敌人，第 3 级可提供少量治疗护盾。"
	},
	{
		"id": "gun_suppression_grid",
		"title": "压制火网",
		"owner_role": "gunner",
		"card_type": CARD_TYPE_HERO,
		"package_id": PACKAGE_GUNNER,
		"team_level_min": 12,
		"investment_requirements": {"role_investment": {"gunner": 4.0}, "package_depth": {PACKAGE_GUNNER: 4.0}},
		"max_level": 3,
		"base_weight": 1.0,
		"trait_gain": {"gunner": 1.0},
		"package_gain": {PACKAGE_GUNNER: 1.0},
		"role_weights": {"gunner": 1.0},
		"timing_weights": {"active": 1.0},
		"function_weights": {"control": 0.5, "projectile": 0.8, "sustain": 0.4},
		"mechanic_weights": {"projectile_chain": 0.7, "push": 0.4},
		"archetype_weights": {"projectile_storm": 0.5, "control_lock": 0.5},
		"consume_weights": {"slowed": 0.5, "field": 0.5},
		"edge_gain": {"mage->gunner": 0.5},
		"edge_weights": {"mage->gunner": 0.5},
		"slot_affinity": {"continue": 0.8, "link": 0.8, "pivot": 0.5},
		"summary": "过载期间子弹击退；对领域/减速敌人更易穿透。"
	},
	{
		"id": "gun_infinite_fireline",
		"title": "无限火线",
		"owner_role": "gunner",
		"card_type": CARD_TYPE_CAPSTONE,
		"package_id": PACKAGE_GUNNER,
		"team_level_min": 18,
		"investment_requirements": {"package_depth": {PACKAGE_GUNNER: 6.0}},
		"max_level": 1,
		"base_weight": 0.8,
		"trait_gain": {"gunner": 1.0},
		"package_gain": {PACKAGE_GUNNER: 2.0},
		"role_weights": {"gunner": 1.0},
		"timing_weights": {"entry": 0.8, "active": 0.8},
		"function_weights": {"burst": 0.6, "projectile": 1.0, "sustain": 0.6},
		"mechanic_weights": {"projectile_chain": 0.9, "resource_loop": 0.4},
		"archetype_weights": {"projectile_storm": 1.0},
		"produce_weights": {"overdrive": 0.8, "marked": 0.4},
		"edge_gain": {"cycle->gunner": 1.0},
		"slot_affinity": {"continue": 0.8, "link": 1.0, "pivot": 0.2},
		"summary": "三英雄轮转后，枪手下一次入场进入短暂无限弹幕。"
	},

	{
		"id": "mag_starfall_seed",
		"title": "星陨落点",
		"owner_role": "mage",
		"card_type": CARD_TYPE_HERO,
		"package_id": PACKAGE_MAGE,
		"team_level_min": 0,
		"max_level": 3,
		"base_weight": 1.0,
		"trait_gain": {"mage": 1.0},
		"package_gain": {PACKAGE_MAGE: 1.0},
		"role_weights": {"mage": 1.0},
		"timing_weights": {"entry": 1.0},
		"function_weights": {"burst": 0.7, "domain": 0.7},
		"mechanic_weights": {"field_tick": 0.6},
		"archetype_weights": {"domain_blast": 0.9},
		"produce_weights": {"field": 0.8},
		"edge_gain": {"mage->swordsman": 0.2},
		"edge_weights": {"mage->swordsman": 0.2},
		"slot_affinity": {"continue": 1.0, "link": 0.4, "pivot": 0.3},
		"summary": "入场轰炸半径提高；Lv.3 额外增加落点。"
	},
	{
		"id": "mag_mana_tide",
		"title": "法力回潮",
		"owner_role": "mage",
		"card_type": CARD_TYPE_HERO,
		"package_id": PACKAGE_MAGE,
		"team_level_min": 0,
		"max_level": 3,
		"base_weight": 1.0,
		"trait_gain": {"mage": 1.0},
		"package_gain": {PACKAGE_MAGE: 1.0},
		"role_weights": {"mage": 1.0},
		"timing_weights": {"exit": 0.7, "ultimate": 0.4},
		"function_weights": {"energy": 0.9, "domain": 0.2},
		"mechanic_weights": {"resource_loop": 0.8},
		"archetype_weights": {"ultimate_cycle": 0.7, "domain_blast": 0.2},
		"produce_weights": {"charge": 0.8},
		"edge_gain": {"mage->gunner": 0.2},
		"edge_weights": {"mage->gunner": 0.2},
		"slot_affinity": {"continue": 1.0, "link": 0.5, "pivot": 0.4},
		"summary": "离场给下一名英雄回能，并提高术师回能速度。"
	},
	{
		"id": "mag_frost_seal",
		"title": "冰封符印",
		"owner_role": "mage",
		"card_type": CARD_TYPE_HERO,
		"package_id": PACKAGE_MAGE,
		"team_level_min": 6,
		"investment_requirements": {"role_investment": {"mage": 2.0}, "package_depth": {PACKAGE_MAGE: 2.0}},
		"max_level": 3,
		"base_weight": 1.0,
		"trait_gain": {"mage": 1.0},
		"package_gain": {PACKAGE_MAGE: 1.0},
		"role_weights": {"mage": 1.0},
		"timing_weights": {"exit": 0.8, "active": 0.3},
		"function_weights": {"control": 0.8, "domain": 0.7},
		"mechanic_weights": {"field_tick": 0.6},
		"archetype_weights": {"control_lock": 0.7, "domain_blast": 0.4},
		"produce_weights": {"slowed": 0.8, "field": 0.5},
		"edge_gain": {"mage->swordsman": 0.5},
		"edge_weights": {"mage->swordsman": 0.5},
		"slot_affinity": {"continue": 1.0, "link": 0.8, "pivot": 0.4},
		"summary": "离场领域持续更久，减速更强。"
	},
	{
		"id": "mag_field_convergence",
		"title": "法阵聚流",
		"owner_role": "mage",
		"card_type": CARD_TYPE_HERO,
		"package_id": PACKAGE_MAGE,
		"team_level_min": 6,
		"investment_requirements": {"role_investment": {"mage": 2.0}, "package_depth": {PACKAGE_MAGE: 2.0}},
		"max_level": 3,
		"base_weight": 1.0,
		"trait_gain": {"mage": 1.0},
		"package_gain": {PACKAGE_MAGE: 1.0},
		"role_weights": {"mage": 1.0},
		"timing_weights": {"active": 0.8, "entry": 0.4},
		"function_weights": {"domain": 0.8, "control": 0.5, "burst": 0.4},
		"mechanic_weights": {"field_tick": 0.8},
		"archetype_weights": {"domain_blast": 0.7, "control_lock": 0.4},
		"consume_weights": {"field": 0.7},
		"slot_affinity": {"continue": 1.0, "link": 0.5, "pivot": 0.3},
		"summary": "两个领域重叠时合并并造成额外伤害。"
	},
	{
		"id": "mag_guardian_puppet",
		"title": "守护傀儡",
		"owner_role": "mage",
		"card_type": CARD_TYPE_HERO,
		"package_id": PACKAGE_MAGE,
		"team_level_min": 12,
		"investment_requirements": {"role_investment": {"mage": 4.0}, "package_depth": {PACKAGE_MAGE: 4.0}},
		"max_level": 3,
		"base_weight": 1.0,
		"trait_gain": {"mage": 1.0},
		"package_gain": {PACKAGE_MAGE: 1.0},
		"role_weights": {"mage": 1.0},
		"timing_weights": {"exit": 0.4, "active": 0.6},
		"function_weights": {"control": 0.5, "survival": 0.7, "domain": 0.4, "taunt": 0.8},
		"mechanic_weights": {"summon_unit": 0.8, "command_summon": 0.4, "field_tick": 0.3},
		"archetype_weights": {"summon_swarm": 0.8, "control_lock": 0.4, "guard_counter": 0.3},
		"produce_weights": {"guard": 0.6, "field": 0.3, "summon_unit": 0.8},
		"bridge_weights": {"domain_blast->summon_swarm": 0.8, "summon_swarm->healing_push": 0.3},
		"package_edges": [{"to": "gun_spotter_drone", "type": "mirror_edge", "cost": 1.5}, {"to": "swd_overheal_guard", "type": "relay_edge", "cost": 1.0}],
		"slot_affinity": {"continue": 0.7, "link": 0.8, "pivot": 0.8},
		"summary": "召唤元素傀儡吸引敌人，领域内获得护盾。"
	},
	{
		"id": "mag_orbital_script",
		"title": "星轨咒文",
		"owner_role": "mage",
		"card_type": CARD_TYPE_HERO,
		"package_id": PACKAGE_MAGE,
		"team_level_min": 12,
		"investment_requirements": {"role_investment": {"mage": 4.0}, "package_depth": {PACKAGE_MAGE: 4.0}},
		"max_level": 3,
		"base_weight": 1.0,
		"trait_gain": {"mage": 1.0},
		"package_gain": {PACKAGE_MAGE: 1.0},
		"role_weights": {"mage": 1.0},
		"timing_weights": {"active": 0.8, "entry": 0.4},
		"function_weights": {"domain": 0.6, "burst": 0.6, "mark": 0.4},
		"mechanic_weights": {"field_tick": 0.6, "direct_hit": 0.3},
		"archetype_weights": {"domain_blast": 0.5, "mark_execute": 0.5},
		"consume_weights": {"marked": 0.7},
		"edge_gain": {"gunner->mage": 0.6},
		"edge_weights": {"gunner->mage": 0.6},
		"slot_affinity": {"continue": 0.7, "link": 0.9, "pivot": 0.5},
		"summary": "领域优先锁定标记敌人追加星轨。"
	},
	{
		"id": "mag_sky_dome",
		"title": "星穹降临",
		"owner_role": "mage",
		"card_type": CARD_TYPE_CAPSTONE,
		"package_id": PACKAGE_MAGE,
		"team_level_min": 18,
		"investment_requirements": {"package_depth": {PACKAGE_MAGE: 6.0}},
		"max_level": 1,
		"base_weight": 0.8,
		"trait_gain": {"mage": 1.0},
		"package_gain": {PACKAGE_MAGE: 2.0},
		"role_weights": {"mage": 1.0},
		"timing_weights": {"entry": 0.8, "active": 0.8},
		"function_weights": {"domain": 1.0, "burst": 0.7, "control": 0.4},
		"mechanic_weights": {"field_tick": 0.9},
		"archetype_weights": {"domain_blast": 1.0, "control_lock": 0.3},
		"produce_weights": {"field": 1.0, "slowed": 0.4},
		"edge_gain": {"cycle->mage": 1.0},
		"slot_affinity": {"continue": 0.8, "link": 1.0, "pivot": 0.2},
		"summary": "三英雄轮转后，术师下一次入场生成持续星穹领域。"
	},

	{
		"id": "res_swd_gun_open_fire",
		"title": "开路火线",
		"card_type": CARD_TYPE_RESONANCE_PAIR,
		"team_level_min": 6,
		"requires_any": [{"tag_points": {"armor_break": 0.5, "marked": 0.5}}, {"edge_level": {"swordsman->gunner": 1.0}}],
		"max_level": 2,
		"base_weight": 0.9,
		"trait_gain": {"swordsman": 0.5, "gunner": 0.5},
		"edge_gain": {"swordsman->gunner": 1.0},
		"role_weights": {"swordsman": 0.5, "gunner": 0.5},
		"function_weights": {"mark": 0.5, "projectile": 0.6, "burst": 0.3},
		"mechanic_weights": {"projectile_chain": 0.5, "direct_hit": 0.3},
		"archetype_weights": {"entry_burst": 0.4, "projectile_storm": 0.5, "mark_execute": 0.3},
		"consume_weights": {"armor_break": 0.5},
		"produce_weights": {"marked": 0.5},
		"edge_weights": {"swordsman->gunner": 1.0},
		"slot_affinity": {"continue": 0.1, "link": 1.0, "pivot": 0.2},
		"summary": "剑士破甲敌人会被枪手优先标记，枪手攻击破甲敌人额外穿透。"
	},
	{
		"id": "res_gun_swd_cover_dash",
		"title": "护航突进",
		"card_type": CARD_TYPE_RESONANCE_PAIR,
		"team_level_min": 6,
		"requires_any": [{"tag_points": {"overdrive": 0.5, "entry_burst": 0.5}}, {"edge_level": {"gunner->swordsman": 1.0}}],
		"max_level": 2,
		"base_weight": 0.9,
		"trait_gain": {"gunner": 0.5, "swordsman": 0.5},
		"edge_gain": {"gunner->swordsman": 1.0},
		"role_weights": {"gunner": 0.5, "swordsman": 0.5},
		"function_weights": {"burst": 0.5, "projectile": 0.4, "survival": 0.3},
		"mechanic_weights": {"projectile_chain": 0.4, "direct_hit": 0.4},
		"archetype_weights": {"projectile_storm": 0.4, "entry_burst": 0.5},
		"consume_weights": {"overdrive": 0.5},
		"edge_weights": {"gunner->swordsman": 1.0},
		"slot_affinity": {"continue": 0.1, "link": 1.0, "pivot": 0.3},
		"summary": "枪手离场过载期间，剑士下一次突进附带弹幕护航。"
	},
	{
		"id": "res_gun_mag_orbital_lock",
		"title": "星轨锁定",
		"card_type": CARD_TYPE_RESONANCE_PAIR,
		"team_level_min": 6,
		"requires_any": [{"tag_points": {"marked": 1.0, "field": 0.5}}, {"edge_level": {"gunner->mage": 1.0}}],
		"max_level": 2,
		"base_weight": 0.9,
		"trait_gain": {"gunner": 0.5, "mage": 0.5},
		"edge_gain": {"gunner->mage": 1.0, "mage->gunner": 0.5},
		"role_weights": {"gunner": 0.5, "mage": 0.5},
		"function_weights": {"mark": 0.4, "domain": 0.6, "burst": 0.4},
		"mechanic_weights": {"field_tick": 0.5, "projectile_chain": 0.4},
		"archetype_weights": {"mark_execute": 0.4, "domain_blast": 0.5},
		"consume_weights": {"marked": 0.6},
		"produce_weights": {"field": 0.3},
		"edge_weights": {"gunner->mage": 1.0, "mage->gunner": 0.5},
		"slot_affinity": {"continue": 0.1, "link": 1.0, "pivot": 0.3},
		"summary": "术师领域优先轰炸标记敌人，枪手攻击领域内敌人更易穿透。"
	},
	{
		"id": "res_mag_gun_arcane_reload",
		"title": "秘能装填",
		"card_type": CARD_TYPE_RESONANCE_PAIR,
		"team_level_min": 6,
		"requires_any": [{"tag_points": {"charge": 0.5, "overdrive": 0.5}}, {"edge_level": {"mage->gunner": 1.0}}],
		"max_level": 2,
		"base_weight": 0.9,
		"trait_gain": {"mage": 0.5, "gunner": 0.5},
		"edge_gain": {"mage->gunner": 1.0},
		"role_weights": {"mage": 0.5, "gunner": 0.5},
		"function_weights": {"energy": 0.7, "projectile": 0.4},
		"mechanic_weights": {"resource_loop": 0.8},
		"archetype_weights": {"ultimate_cycle": 0.6, "projectile_storm": 0.3},
		"consume_weights": {"charge": 0.4, "overdrive": 0.3},
		"produce_weights": {"charge": 0.4},
		"edge_weights": {"mage->gunner": 1.0},
		"slot_affinity": {"continue": 0.1, "link": 1.0, "pivot": 0.4},
		"summary": "术师离场回能同时给枪手装填，枪手过载命中为术师回能。"
	},
	{
		"id": "res_mag_swd_star_cleave",
		"title": "星灾破阵",
		"card_type": CARD_TYPE_RESONANCE_PAIR,
		"team_level_min": 6,
		"requires_any": [{"tag_points": {"field": 0.5, "entry_burst": 0.5}}, {"edge_level": {"mage->swordsman": 1.0}}],
		"max_level": 2,
		"base_weight": 0.9,
		"trait_gain": {"mage": 0.5, "swordsman": 0.5},
		"edge_gain": {"mage->swordsman": 1.0},
		"role_weights": {"mage": 0.5, "swordsman": 0.5},
		"function_weights": {"domain": 0.4, "burst": 0.6, "control": 0.3},
		"mechanic_weights": {"field_tick": 0.4, "direct_hit": 0.5},
		"archetype_weights": {"domain_blast": 0.4, "entry_burst": 0.5},
		"consume_weights": {"field": 0.5, "slowed": 0.4},
		"edge_weights": {"mage->swordsman": 1.0},
		"slot_affinity": {"continue": 0.1, "link": 1.0, "pivot": 0.3},
		"summary": "剑士在术师领域内入场时，突进终点追加星灾斩。"
	},
	{
		"id": "res_swd_mag_blood_ward",
		"title": "血守法阵",
		"card_type": CARD_TYPE_RESONANCE_PAIR,
		"team_level_min": 6,
		"requires_any": [{"tag_points": {"guard": 0.5, "field": 0.5}}, {"edge_level": {"swordsman->mage": 1.0}}],
		"max_level": 2,
		"base_weight": 0.9,
		"trait_gain": {"swordsman": 0.5, "mage": 0.5},
		"edge_gain": {"swordsman->mage": 1.0, "mage->swordsman": 0.3},
		"role_weights": {"swordsman": 0.5, "mage": 0.5},
		"function_weights": {"survival": 0.6, "domain": 0.4, "control": 0.3},
		"mechanic_weights": {"overheal": 0.4, "field_tick": 0.4},
		"archetype_weights": {"healing_push": 0.4, "domain_blast": 0.3, "summon_swarm": 0.3},
		"consume_weights": {"guard": 0.5, "field": 0.4},
		"produce_weights": {"guard": 0.4},
		"edge_weights": {"swordsman->mage": 1.0, "mage->swordsman": 0.3},
		"slot_affinity": {"continue": 0.1, "link": 1.0, "pivot": 0.5},
		"summary": "剑士护盾破裂时在术师领域内释放守护爆波，傀儡获得护盾。"
	},

	{
		"id": "res_tri_three_step_cycle",
		"title": "三相接力",
		"card_type": CARD_TYPE_RESONANCE_TRI,
		"team_level_min": 18,
		"requires_any": [{"role_investment": {"swordsman": 2.0, "gunner": 2.0, "mage": 2.0}}, {"edge_total_min": 4.0}],
		"max_level": 2,
		"base_weight": 0.8,
		"trait_gain": {"swordsman": 0.35, "gunner": 0.35, "mage": 0.35},
		"edge_gain": {"cycle->swordsman": 0.5, "cycle->gunner": 0.5, "cycle->mage": 0.5},
		"role_weights": {"swordsman": 0.33, "gunner": 0.33, "mage": 0.33},
		"function_weights": {"burst": 0.6, "sustain": 0.3},
		"mechanic_weights": {"resource_loop": 0.4, "direct_hit": 0.4},
		"archetype_weights": {"entry_burst": 0.3, "projectile_storm": 0.3, "domain_blast": 0.3},
		"consume_weights": {"armor_break": 0.3, "marked": 0.3, "field": 0.3},
		"slot_affinity": {"continue": 0.0, "link": 1.0, "pivot": 0.3},
		"summary": "短时间内依次切入三名不同英雄后，触发队伍终结打击。"
	},
	{
		"id": "res_tri_all_damage_concert",
		"title": "火力合奏",
		"card_type": CARD_TYPE_RESONANCE_TRI,
		"team_level_min": 18,
		"requires_any": [{"tag_points": {"burst": 2.0, "projectile": 1.0, "domain": 1.0}}, {"role_investment": {"swordsman": 2.0, "gunner": 2.0, "mage": 2.0}}],
		"max_level": 2,
		"base_weight": 0.8,
		"trait_gain": {"swordsman": 0.35, "gunner": 0.35, "mage": 0.35},
		"edge_gain": {"cycle->swordsman": 0.4, "cycle->gunner": 0.4, "cycle->mage": 0.4},
		"role_weights": {"swordsman": 0.33, "gunner": 0.33, "mage": 0.33},
		"function_weights": {"burst": 0.8, "sustain": 0.5, "projectile": 0.4, "domain": 0.4},
		"mechanic_weights": {"direct_hit": 0.4, "projectile_chain": 0.4, "field_tick": 0.4},
		"archetype_weights": {"entry_burst": 0.3, "projectile_storm": 0.3, "domain_blast": 0.3},
		"slot_affinity": {"continue": 0.0, "link": 1.0, "pivot": 0.3},
		"summary": "三名英雄都在短时间内造成核心伤害后，全队获得短暂伤害增幅。"
	},
	{
		"id": "res_tri_guard_loop",
		"title": "守势合环",
		"card_type": CARD_TYPE_RESONANCE_TRI,
		"team_level_min": 18,
		"requires_any": [{"tag_points": {"guard": 0.5, "field": 0.5, "overdrive": 0.5}}, {"edge_total_min": 4.0}],
		"max_level": 2,
		"base_weight": 0.8,
		"trait_gain": {"swordsman": 0.35, "gunner": 0.35, "mage": 0.35},
		"edge_gain": {"cycle->swordsman": 0.4, "cycle->gunner": 0.4, "cycle->mage": 0.4},
		"role_weights": {"swordsman": 0.33, "gunner": 0.33, "mage": 0.33},
		"function_weights": {"survival": 0.7, "control": 0.4, "shield": 0.4},
		"mechanic_weights": {"overheal": 0.3, "field_tick": 0.3, "resource_loop": 0.3},
		"archetype_weights": {"guard_counter": 0.4, "healing_push": 0.3, "control_lock": 0.3},
		"produce_weights": {"guard": 0.6},
		"slot_affinity": {"continue": 0.0, "link": 1.0, "pivot": 0.4},
		"summary": "过载、领域、护盾依次出现时，生成团队保护环。"
	},

	{
		"id": "gen_vital_pace",
		"title": "稳健步调",
		"card_type": CARD_TYPE_GENERIC,
		"team_level_min": 0,
		"max_level": 3,
		"base_weight": 0.65,
		"function_weights": {"survival": 0.5, "mobility": 0.3},
		"mechanic_weights": {},
		"archetype_weights": {},
		"slot_affinity": {"continue": 0.0, "link": 0.1, "pivot": 0.9},
		"summary": "最大生命和移动容错提高。"
	},
	{
		"id": "gen_pickup_focus",
		"title": "拾取专注",
		"card_type": CARD_TYPE_GENERIC,
		"team_level_min": 0,
		"max_level": 3,
		"base_weight": 0.65,
		"function_weights": {"energy": 0.4, "survival": 0.2},
		"mechanic_weights": {"resource_loop": 0.4},
		"archetype_weights": {"ultimate_cycle": 0.2},
		"slot_affinity": {"continue": 0.0, "link": 0.2, "pivot": 0.9},
		"summary": "吸取范围、经验拾取和少量回能体验提高。"
	},
	{
		"id": "gen_switch_tempo",
		"title": "轮转节拍",
		"card_type": CARD_TYPE_GENERIC,
		"team_level_min": 0,
		"max_level": 2,
		"base_weight": 0.7,
		"trait_gain": {"swordsman": 0.15, "gunner": 0.15, "mage": 0.15},
		"edge_gain": {"cycle->swordsman": 0.2, "cycle->gunner": 0.2, "cycle->mage": 0.2},
		"function_weights": {"energy": 0.3, "sustain": 0.3},
		"mechanic_weights": {"resource_loop": 0.5},
		"archetype_weights": {"ultimate_cycle": 0.3},
		"slot_affinity": {"continue": 0.0, "link": 0.5, "pivot": 0.8},
		"summary": "切换节奏更顺，少量推动三人轮转。"
	},
	{
		"id": "gen_field_rations",
		"title": "战地配给",
		"card_type": CARD_TYPE_GENERIC,
		"team_level_min": 6,
		"max_level": 2,
		"base_weight": 0.6,
		"function_weights": {"survival": 0.6, "energy": 0.3},
		"mechanic_weights": {"heal": 0.4, "resource_loop": 0.3},
		"archetype_weights": {"healing_push": 0.2},
		"produce_weights": {"guard": 0.2},
		"slot_affinity": {"continue": 0.0, "link": 0.2, "pivot": 0.8},
		"summary": "战斗中获得少量补给，支持治疗/守护桥接。"
	},
	{
		"id": "gen_second_wind",
		"title": "逆风再起",
		"card_type": CARD_TYPE_GENERIC,
		"team_level_min": 12,
		"max_level": 2,
		"base_weight": 0.55,
		"function_weights": {"survival": 0.8, "shield": 0.4},
		"mechanic_weights": {"overheal": 0.3, "resource_loop": 0.2},
		"archetype_weights": {"guard_counter": 0.3, "healing_push": 0.2},
		"produce_weights": {"guard": 0.5},
		"slot_affinity": {"continue": 0.0, "link": 0.3, "pivot": 0.8},
		"summary": "低生命或高压时获得护盾与短暂恢复窗口。"
	}
]

const MASTERY_NODES := [
	{
		"id": "swd_break_mastery",
		"title": "破阵血潮·成型",
		"card_type": CARD_TYPE_MASTERY,
		"package_id": PACKAGE_SWORDSMAN,
		"team_level_min": 25,
		"trigger_requirements": {"package_depth": {PACKAGE_SWORDSMAN: 8.0}},
		"effects": {"continue_weight_factor": 0.45, "bridge_weight_factor": 1.6, "resonance_weight_factor": 1.3}
	},
	{
		"id": "gun_fireline_mastery",
		"title": "过载火线·成型",
		"card_type": CARD_TYPE_MASTERY,
		"package_id": PACKAGE_GUNNER,
		"team_level_min": 25,
		"trigger_requirements": {"package_depth": {PACKAGE_GUNNER: 8.0}},
		"effects": {"continue_weight_factor": 0.45, "bridge_weight_factor": 1.6, "resonance_weight_factor": 1.3}
	},
	{
		"id": "mag_starfield_mastery",
		"title": "星灾符印·成型",
		"card_type": CARD_TYPE_MASTERY,
		"package_id": PACKAGE_MAGE,
		"team_level_min": 25,
		"trigger_requirements": {"package_depth": {PACKAGE_MAGE: 8.0}},
		"effects": {"continue_weight_factor": 0.45, "bridge_weight_factor": 1.6, "resonance_weight_factor": 1.3}
	}
]


static func get_offer_card_definitions() -> Array:
	var result: Array = []
	for card in OFFER_CARD_DEFINITIONS:
		result.append(_enrich_offer_card((card as Dictionary).duplicate(true)))
	return result


static func get_mastery_nodes() -> Array:
	return MASTERY_NODES.duplicate(true)


static func get_card_data(card_id: String) -> Dictionary:
	for card in OFFER_CARD_DEFINITIONS:
		if str((card as Dictionary).get("id", "")) == card_id:
			return _enrich_offer_card((card as Dictionary).duplicate(true))
	for node in MASTERY_NODES:
		if str((node as Dictionary).get("id", "")) == card_id:
			return (node as Dictionary).duplicate(true)
	return {}


static func get_offer_card_ids() -> Array:
	var result: Array = []
	for card in OFFER_CARD_DEFINITIONS:
		result.append(str((card as Dictionary).get("id", "")))
	return result


static func get_cards_by_type(card_type: String) -> Array:
	var result: Array = []
	for card in OFFER_CARD_DEFINITIONS:
		if str((card as Dictionary).get("card_type", "")) == card_type:
			result.append(_enrich_offer_card((card as Dictionary).duplicate(true)))
	return result


static func get_role_package_id(role_id: String) -> String:
	return str(ROLE_PACKAGES.get(role_id, ""))


static func get_role_identity_profile(role_id: String) -> Dictionary:
	return (ROLE_IDENTITY_PROFILES.get(role_id, {}) as Dictionary).duplicate(true)


static func get_cards_by_role(role_id: String) -> Array:
	var result: Array = []
	for card in OFFER_CARD_DEFINITIONS:
		var data := _enrich_offer_card((card as Dictionary).duplicate(true))
		if str(data.get("owner_role", "")) == role_id:
			result.append(data)
	return result


static func get_cards_by_axis(role_id: String, axis: String) -> Array:
	var result: Array = []
	for card in get_cards_by_role(role_id):
		var axes: Array = (card as Dictionary).get("upgrade_axes", [])
		if axes.has(axis):
			result.append((card as Dictionary).duplicate(true))
	return result


static func get_independent_passive_cards(role_id: String) -> Array:
	return get_cards_by_axis(role_id, AXIS_INDEPENDENT_PASSIVE)


static func get_role_position_totals(role_id: String) -> Dictionary:
	var totals := {}
	for card in get_cards_by_role(role_id):
		var weights: Dictionary = (card as Dictionary).get("position_weights", {})
		for position in weights.keys():
			totals[position] = float(totals.get(position, 0.0)) + float(weights.get(position, 0.0))
	return totals


static func get_role_identity_totals(role_id: String) -> Dictionary:
	var totals := {}
	for card in get_cards_by_role(role_id):
		for map_key in ["archetype_weights", "mechanic_weights", "produce_weights", "consume_weights"]:
			var weights: Dictionary = (card as Dictionary).get(map_key, {})
			for identity_key in weights.keys():
				totals[identity_key] = float(totals.get(identity_key, 0.0)) + float(weights.get(identity_key, 0.0))
	return totals


static func _enrich_offer_card(card: Dictionary) -> Dictionary:
	var card_id := str(card.get("id", ""))
	if CARD_UPGRADE_AXES.has(card_id):
		card["upgrade_axes"] = (CARD_UPGRADE_AXES.get(card_id, []) as Array).duplicate(true)
	elif str(card.get("card_type", "")) == CARD_TYPE_RESONANCE_PAIR or str(card.get("card_type", "")) == CARD_TYPE_RESONANCE_TRI:
		card["upgrade_axes"] = [AXIS_RESONANCE]
	elif str(card.get("card_type", "")) == CARD_TYPE_GENERIC:
		card["upgrade_axes"] = [AXIS_GENERIC]
	else:
		card["upgrade_axes"] = []
	if CARD_POSITION_WEIGHTS.has(card_id):
		card["position_weights"] = (CARD_POSITION_WEIGHTS.get(card_id, {}) as Dictionary).duplicate(true)
	if CARD_INDEPENDENT_PASSIVES.has(card_id):
		var passive_data: Dictionary = (CARD_INDEPENDENT_PASSIVES.get(card_id, {}) as Dictionary).duplicate(true)
		card["skill_surface"] = SKILL_SURFACE_INDEPENDENT_PASSIVE
		card["has_independent_cooldown"] = true
		card["cooldown_seconds"] = float(passive_data.get("cooldown_seconds", 0.0))
		card["cooldown_slot"] = str(passive_data.get("cooldown_slot", card_id))
		card["trigger_mode"] = str(passive_data.get("trigger_mode", "auto"))
		card["passive_family"] = str(passive_data.get("passive_family", ""))
		card["independent_passive_summary"] = str(passive_data.get("independent_passive_summary", ""))
	else:
		card["has_independent_cooldown"] = false
	return card
