extends RefCounted

const STORY_MODE_ENABLED := false

const PREP_SCENE_PATH := "res://scenes/story_prep.tscn"
const BATTLE_SCENE_PATH := "res://scenes/main.tscn"
const SAVE_SELECT_SCENE_PATH := "res://scenes/save_select.tscn"

const ROLE_POOL := [
	{"id": "swordsman", "name": "剑士", "available": true},
	{"id": "gunner", "name": "枪手", "available": true},
	{"id": "mage", "name": "法师", "available": true},
	{"id": "mechanic", "name": "机械师", "available": true},
	{"id": "reserved_5", "name": "角色5", "available": false}
]

const STORY_STAGES := [
	{
		"id": "chapter1_stage1",
		"chapter": 1,
		"title": "第一章·前哨清剿",
		"description": "标准战斗关。撑过 180 秒即可过关。",
		"type": "normal",
		"target_time": 180.0,
		"boss_spawn_time": 9999.0,
		"spawn_interval_multiplier": 1.0,
		"enemy_health_multiplier": 1.0,
		"enemy_speed_multiplier": 1.0
	},
	{
		"id": "chapter1_stage2",
		"chapter": 1,
		"title": "第一章·裂隙推进",
		"description": "高压普通关。撑过 210 秒即可过关。",
		"type": "normal",
		"target_time": 210.0,
		"boss_spawn_time": 9999.0,
		"spawn_interval_multiplier": 0.9,
		"enemy_health_multiplier": 1.1,
		"enemy_speed_multiplier": 1.08
	},
	{
		"id": "chapter1_stage3",
		"chapter": 1,
		"title": "第一章·星核讨伐",
		"description": "Boss关。135 秒后Boss登场，击败后获得 1 枚Boss核心。",
		"type": "boss",
		"target_time": 300.0,
		"boss_spawn_time": 135.0,
		"spawn_interval_multiplier": 0.92,
		"enemy_health_multiplier": 1.14,
		"enemy_speed_multiplier": 1.1,
		"boss_material_reward": 1
	}
]

static func build_default_story_profile(slot_id: int) -> Dictionary:
	return {
		"slot_id": slot_id,
		"chapter_index": 1,
		"current_stage_index": 0,
		"boss_core_fragments": 0,
		"unlocked_role_ids": ["swordsman", "gunner", "mage", "mechanic"],
		"team_order": ["swordsman", "gunner", "mage"],
		"created_unix": Time.get_unix_time_from_system(),
		"last_updated_unix": Time.get_unix_time_from_system()
	}

static func is_story_mode_enabled() -> bool:
	return STORY_MODE_ENABLED

static func get_stage(stage_index: int) -> Dictionary:
	if stage_index < 0 or stage_index >= STORY_STAGES.size():
		return {}
	return STORY_STAGES[stage_index].duplicate(true)

static func get_stage_count() -> int:
	return STORY_STAGES.size()
