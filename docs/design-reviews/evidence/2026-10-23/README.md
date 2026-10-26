# 2026-10-23 当前版本评审证据

源码基准 `9c1472e429af1168ec8e75f4c9adc980427a9235`，Godot `4.6.2.stable.official.71f334935`。这是评审期间的结果快照，未修复所复现问题。

## 范围与结果

| 证据 | 结果 | 说明 |
| --- | --- | --- |
| [15项现有检查](baseline-checks/results.json) | 15/15通过 | 成就、菜单、人物页、营地、无尽推进/返回、等级/存档往返、波次/祝福/经验、教学退出、性能保护/记录、地图；各项日志位于同目录 |
| [奖励恢复脚本](run_flow_repro.gd.txt) / [日志](run_flow_repro.log.txt) | 两项缺陷复现 | 小Boss领奖中保存退出会漏掉原奖励；最终结算写永久档失败后保存退出，续战停在complete阶段 |
| [存档恢复脚本](camp_save_repro.gd.txt) / [日志](camp_save_repro.log.txt) | 两项缺陷复现 | 损坏永久档被视为空槽；可解析但无效的运行主档不回退有效备份，非空无效主档还会导致有效备份删除 |
| [故事schema探针](story_schema_probe.gd.txt) / [日志](story_schema_probe.log.txt) | 约束确认 | 主线门禁关闭；现有故事档白名单会丢弃新增story数据 |
| [内容校验脚本](validate_story_fixture.py.txt) / [结果](story_fixture_check.json) | 通过 | 3关、3任务、6说话者、3种物品、13对话、29节点、6个一次性凭据；检查引用、出口、任务顺序与固定物品预算 |

`RUN_FLOW_REPRO_OK` / `CAMP_SAVE_REPRO_OK` 表示脚本成功观察到缺陷，不能解读为功能通过。内容校验只检查[第一章设计样例](../../../story/chapter1_framework.example.json)，没有加载新的Godot故事系统，也没有证明事务、迁移或UI已实现。

现有smoke每项独立使用 `/tmp/my-game-review-20261023/baseline-checks/` 下的XDG数据/配置目录。奖励和存档复现分别使用该临时根下的 `run-flow-data`、`camp-save-data`，通过真实SaveManager和对应flow验证边界；存档复现脚本还断言user路径。永久档数据、阵容、层级和战局均为测试构造，没有使用玩家真实存档。

## 复查方法与限制

这些 `.gd.txt` 是留存的探针源码，不进入Godot运行目录。需要复查时，将对应文件复制到 `/tmp/my-game-review-20261023/<同名>.gd`，设置探针对应的 `XDG_DATA_HOME` 与 `XDG_CONFIG_HOME` 后，从仓库根目录使用Godot `--headless --path . -s <探针路径>` 执行。`camp_save_repro` 依赖脚本中固定的临时目录前缀，不要删除路径断言或改为真实用户目录。奖励探针使用简化场景驱动真实flow，不等价于完整人工通关。

内容结构检查可直接从仓库根执行：

```bash
python3 docs/design-reviews/evidence/2026-10-23/validate_story_fixture.py.txt
```

同步阶段Godot导入、无界面加载与三个场景检查通过；全量 `scripts/check_project.sh` 未完成，停在 `ability_talent_snapshot_save_smoke.gd:65` 调用不存在的 `_has_talent`。本次未通过恢复旧技能接口来绕开失败，也未把15项专项通过当作全量通过。

未做当前版本完整20波人工游玩、图形模式截图验收、GPU压测、导出包运行、故事新框架实装验证。Graphify索引仍基于 `91fd75c9`；当前安装缺少GDScript提取支持，索引只用于导航，事实判断来自当前源码与这些检查。
