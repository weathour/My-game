# 既有失败项对照

以下22项在当前工作区和未修改的 `9c1472e` 上均失败。这里记录当前扫描的首条错误，并核对其在基线日志中也出现；不能据此认定所有后续错误均已分析完毕。部分项目是测试夹具或断言落后于现行实现，未以恢复旧玩法的方式消除失败。

| 检查 | 当前首条错误（基线也出现） | 日志 |
| --- | --- | --- |
| `developer_catalog_smoke` | ERROR: unavailable item rejected | [当前](all-smokes/developer_catalog_smoke.log) / [基线](baseline-smokes/developer_catalog_smoke.log) |
| `enemy_rebirth_smoke` | SCRIPT ERROR: Invalid call to function 'apply_enemy_slow' in base 'Node2D (TargetStub)'. Expected 2 argument(s). | [当前](all-smokes/enemy_rebirth_smoke.log) / [基线](baseline-smokes/enemy_rebirth_smoke.log) |
| `gunner_basic_level_talents_smoke` | SCRIPT ERROR: Invalid access to property or key 'electric_stacks' on a base object of type 'Node2D (BasicEnemy)'. | [当前](all-smokes/gunner_basic_level_talents_smoke.log) / [基线](baseline-smokes/gunner_basic_level_talents_smoke.log) |
| `gunner_infinite_reload_manual_smoke` | SCRIPT ERROR: Out of bounds get index '0' (on base: 'Array[Dictionary]') | [当前](all-smokes/gunner_infinite_reload_manual_smoke.log) / [基线](baseline-smokes/gunner_infinite_reload_manual_smoke.log) |
| `gunner_skill_level_effect_smoke` | ERROR: 枪手普攻 level 5 should add 60 range: 0.0000 != 60.0000 | [当前](all-smokes/gunner_skill_level_effect_smoke.log) / [基线](baseline-smokes/gunner_skill_level_effect_smoke.log) |
| `gunner_skill_talents_smoke` | SCRIPT ERROR: Invalid call. Nonexistent function '_apply_piercing_beam_damage' in base 'RefCounted (gunner_infinite_reload_ability.gd)'. | [当前](all-smokes/gunner_skill_talents_smoke.log) / [基线](baseline-smokes/gunner_skill_talents_smoke.log) |
| `mage_arcane_charge_level_talents_smoke` | SCRIPT ERROR: Assertion failed. | [当前](all-smokes/mage_arcane_charge_level_talents_smoke.log) / [基线](baseline-smokes/mage_arcane_charge_level_talents_smoke.log) |
| `mage_basic_level_talents_smoke` | ERROR: first mage lightning should keep full damage | [当前](all-smokes/mage_basic_level_talents_smoke.log) / [基线](baseline-smokes/mage_basic_level_talents_smoke.log) |
| `mage_skill_level_effect_smoke` | ERROR: 法师普攻 level 5 should scale radius by 1.40: 1.0000 != 1.4000 | [当前](all-smokes/mage_skill_level_effect_smoke.log) / [基线](baseline-smokes/mage_skill_level_effect_smoke.log) |
| `mage_stage_two_three_talents_smoke` | SCRIPT ERROR: Invalid assignment of property or key 'animated_visual_width' with value of type 'float' on a base object of type 'Node2D (ProjectileStub)'. | [当前](all-smokes/mage_stage_two_three_talents_smoke.log) / [基线](baseline-smokes/mage_stage_two_three_talents_smoke.log) |
| `mage_talent_smoke` | SCRIPT ERROR: Assertion failed. | [当前](all-smokes/mage_talent_smoke.log) / [基线](baseline-smokes/mage_talent_smoke.log) |
| `player_blindness_smoke` | ERROR: damage triggers blindness | [当前](all-smokes/player_blindness_smoke.log) / [基线](baseline-smokes/player_blindness_smoke.log) |
| `player_projectile_query_smoke` | SCRIPT ERROR: Assertion failed. | [当前](all-smokes/player_projectile_query_smoke.log) / [基线](baseline-smokes/player_projectile_query_smoke.log) |
| `player_skill_level_system_smoke` | ERROR: unlocked active skills should start at level 1: 0 != 1 | [当前](all-smokes/player_skill_level_system_smoke.log) / [基线](baseline-smokes/player_skill_level_system_smoke.log) |
| `ruan_stone_ui_smoke` | ERROR: 战斗 HUD 缺少常驻阮石状态控件。 | [当前](all-smokes/ruan_stone_ui_smoke.log) / [基线](baseline-smokes/ruan_stone_ui_smoke.log) |
| `skill_info_ui_smoke` | SCRIPT ERROR: Assertion failed. | [当前](all-smokes/skill_info_ui_smoke.log) / [基线](baseline-smokes/skill_info_ui_smoke.log) |
| `skill_level_milestone_runtime_smoke` | SCRIPT ERROR: Invalid call to function '_damage_enemies_in_oriented_rect_unique' in base 'Node (SwordsmanRuntimeStub)'. Expected 10 argument(s). | [当前](all-smokes/skill_level_milestone_runtime_smoke.log) / [基线](baseline-smokes/skill_level_milestone_runtime_smoke.log) |
| `skulltomb_rework_smoke` | SCRIPT ERROR: Assertion failed. | [当前](all-smokes/skulltomb_rework_smoke.log) / [基线](baseline-smokes/skulltomb_rework_smoke.log) |
| `swordsman_advanced_talents_smoke` | SCRIPT ERROR: Invalid call. Nonexistent function '_update_recall' in base 'RefCounted (swordsman_blade_storm_ability.gd)'. | [当前](all-smokes/swordsman_advanced_talents_smoke.log) / [基线](baseline-smokes/swordsman_advanced_talents_smoke.log) |
| `swordsman_basic_attack_event_smoke` | SCRIPT ERROR: Invalid call to function '_damage_enemies_in_oriented_rect_unique' in base 'Node2D (AttackOwner)'. Expected 10 argument(s). | [当前](all-smokes/swordsman_basic_attack_event_smoke.log) / [基线](baseline-smokes/swordsman_basic_attack_event_smoke.log) |
| `swordsman_skill_talents_smoke` | SCRIPT ERROR: Invalid call. Nonexistent function '_get_storm_centers' in base 'RefCounted (swordsman_blade_storm_ability.gd)'. | [当前](all-smokes/swordsman_skill_talents_smoke.log) / [基线](baseline-smokes/swordsman_skill_talents_smoke.log) |
| `swordsman_trait_runtime_flow_smoke` | SCRIPT ERROR: Invalid call. Nonexistent function '_get_size_multiplier' in base 'RefCounted (swordsman_blade_storm_ability.gd)'. | [当前](all-smokes/swordsman_trait_runtime_flow_smoke.log) / [基线](baseline-smokes/swordsman_trait_runtime_flow_smoke.log) |

`skill_info_ui_smoke` 在当前1.5秒悬停延迟之前便断言提示可见；`ruan_stone_ui_smoke` 期待的常驻HUD控件当前未建立，阮石详情仍可在人机界面的装备页读取。这两项属于既有UI/测试合同差异，不归类为本轮新剧情功能通过的证据。
