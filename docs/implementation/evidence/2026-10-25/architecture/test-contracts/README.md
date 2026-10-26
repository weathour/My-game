# 当前测试合同对账

- [战斗与成长合同](combat-contracts.md)：15项旧失败的现行依据、6项专用替代覆盖、21项最终结果与边界。
- [UI合同](UI-contracts.md)：开发者目录、阮石人物页与真实1.5秒悬停时序；技能提示夹具退出释放静态特效池，headless/图形检查无错误。
- `player_blindness_smoke.log`、`skulltomb_rework_smoke.log`：原断言漏算剑士既有10%状态抗性，现验证2.25秒致盲/4.5秒减速以及恢复不二次减时；未改状态数值。
- `player_projectile_query_smoke.log`、`enemy_model_hurtbox_smoke.log`、`player_damage_resolver_smoke.log`：查询对账发现真实几何问题；零长度扫掠现在先按圆形交叠判定，拒绝方形Boss框外圆角假命中，同时保留相切命中。
- `mage_surging_wave_level_talents_smoke.gd`在成功/失败退出前释放未入树的TestOwner，消除测试自身的ObjectDB退出警告，未改技能逻辑。
- 保存优化取消JSON对象键排序后，`combat_performance_regression_smoke.gd`改为检查解析状态、写入长度和主备字节一致，不绑定键顺序；临时文件改用隔离`user://`。初次严格gate正确拦截了旧断言，日志保留于`../json-order-failed-project-check.log`。

这些是专项结果；最终全仓结果见上级架构实施记录。修复前日志与初次失败的图形尝试保留为过程证据，不当作最终结果。
