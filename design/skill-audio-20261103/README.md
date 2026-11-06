# 角色与怪物技能音效制作

状态：音效素材、逐项映射、运行时接入和本地测试包检查已完成，完整工程检查通过；实际听审待进行。完成情况以实际产物和[当前状态](../../docs/08_当前实现状态与后续重点.md)为准。

[角色与怪物技能音效更新](../../docs/implementation/2026-11-03_角色与怪物技能音效更新.md)记录开始前的声音覆盖、四类切片、全角色／敌方动作覆盖及验收要求。新音效位于 `assets/sfx/skill-combat-20261103/`，逐项映射位于 `assets/data/audio/skill_sound_profiles.json`；[覆盖审计](profiles/coverage-audit.json)记录 38 名角色的 137 条能力、9 项行为特性和 87 条敌方动作。后者因 6 组相同行为共享 move ID，实际为 81 个唯一绑定键，仍逐配置登记。18 名 Boss 的 22 个形态上下文均有事件映射。

本轮从 rubberduck 的 CC0 RPG、材料音效及水／黏液音效包中选取来源音频，并进行剪裁、处理与程序化补层；实际来源、许可和哈希见[来源锁](audio/sources/)及[素材检查报告](audio/qa/sfx-bank-verification.json)。并未使用此前调研的 Sonniss 音效包；新素材均为一次性短音，不含长循环。

本轮与[第一章音乐测试](../music-20261103-midi-test/README.md)共同检查混音，但不替换其 12 首新配乐、4 首保留旧曲或恢复退役音乐。自动检查用于验证覆盖与运行行为，声音的辨识度、力度与耐听性仍需实际听审。

Godot 4.6.2 完整工程检查通过 51 项 smoke；音效专项、18 关实际会话及独立包反馈检查分别通过 2233、133547 和 806 项，本地测试包启动和包内音效专项通过 198 项。音效单独及 12 首配乐密集片段的 13 组固定混音均有信号且未削波，不代表全部游戏时刻或人工听审。现有 53 个玩家数据文件与 20 项数值、路线和配乐保护输入前后相同，证据见[运行验证报告](runtime/validation-report.json)、[完成核验索引](completion-verification.json)、[玩家文件对账](runtime/player-data-after.json)与[保护输入对账](runtime/protected-inputs-after.json)。

## 本地游戏测试

当时本地测试包在仓库根目录使用以下脚本启动；`builds/` 不随 Git 分发，克隆后不保证该脚本存在。包的检查范围见[运行验证报告](runtime/validation-report.json)：

```bash
./builds/linux-skill-audio-20261103/run.sh
```

测试包使用自己的 `test-user-data/` 保存进度和设置，与用户正式目录分开；正式存档不会自动载入测试包。

## 离线试听

以下为当时本机试听路径，`audio/previews/` 不随 Git 分发，克隆后不保证存在；索引原位于 `audio/previews/preview-index.json`。[试听生成脚本](audio/make_previews.py)保留了处理过程，重新生成需要其依赖和输入文件，输入版本变化时不保证与历史试听相同。

这些文件供比较选材和处理方向：前四个依次为旧音和新音，部分对应不同事件；旧段直接播放原文件，新段应用音效目录增益。这些是音色示意，不是等响度比较，也不是游戏录音。第五个是按默认音乐与音效增益比例离线叠加配乐的压力示例，未模拟完整动态避让、限幅和空间定位，也不是实机混战。

- 旧斩击施放音／新斩击施放音：`audio/previews/blade-old-new.wav`
- 旧魔法命中音／新奥术施放音：`audio/previews/arcane-old-new.wav`
- 旧幽灵死亡音／新怪兽命中音：`audio/previews/beast-old-new.wav`
- 旧幽灵死亡音／新 Boss 击败音：`audio/previews/boss_demon-old-new.wav`
- 新音效与配乐离线压力示例：`audio/previews/new-sfx-under-existing-bgm-pressure-preview.wav`

这些示例尚未完成人工听审，实际战斗时序和混音以游戏运行后的验证与听感为准。
