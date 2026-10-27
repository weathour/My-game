# C 键人物信息页：设计与实装

设计基准：`d77b258`。已按用户选定的 A 固定来源区方案实装。

用户已确定：首屏优先看清角色当前能力，再查看加成来源；保留暗金风格和角色切换，允许重排内容。比较两张探针后，选择 A 固定来源区。

## 改造前的运行证据

- [初始剑士](current/01-starting-swordsman.png)
- [升级后的普通攻击](current/02-swordsman-basic.png)
- [已持有祝福及旧配方提示](current/03-owned-blessings.png)
- [待命机械师的定点机炮](current/04-mechanic-turret.png)
- [960×540 窗口](current/05-minimum-window.png)
- [实际文本与控件尺寸](current/runtime.json)
- [捕获脚本留档](capture-current.gd.txt)

截图来自 Godot 4.6.2 的真实 Player 与 CharacterPanel，使用隔离场景和人工设置的构筑状态，不代表完整关卡试玩。逻辑画布为 1280×720。测试状态包含焰阳 I×2、神赐 I×1 / II×2、爆裂 I×1、乘风 I×1；机械师已学习定点机炮和重型炮台。

此留档脚本依赖改造前的节点接口，仅用于基准版本的历史复现；将留档脚本复制到 `/tmp/my_game_character_audit.gd`，在项目根目录执行：

```bash
/home/weathour/.local/bin/godot-4.6.2 --path . --rendering-method gl_compatibility --audio-driver Dummy --script /tmp/my_game_character_audit.gd
```

## 两个方向探针

- [A：属性总览与固定来源区](probes/a-fixed-inspector.png)，已选定。
- [B：宽版档案与行内展开](probes/b-inline-sources.png)，用于比较。

生成图只记录当时的视觉与信息布局；对应旧评审已撤下，可从Git历史查阅。这些截图不规定新人物页面，当前方向见[设计共识](../../docs/00_当前设计共识.md)。数值来自同一测试角色，示例 `23 + 4 = 27` 指机械师当前攻击力，不是最终伤害。

提示词存于 `probes/prompts.json`。没有批准将概念图作为运行资源。

## 实装后的运行截图

- [初始总览](implemented/01-starting-overview.png)
- [机械师攻击来源：23 + 4 = 27](implemented/02-mechanic-sources.png)
- [定点机炮当前效果](implemented/03-mechanic-skill.png)
- [神赐跨阶合计与每份效果](implemented/04-blessing-tiers.png)
- [角色道具合计与赠与](implemented/05-equipment-gift.png)
- [960×540 窗口与法师冷却来源](implemented/06-minimum-window.png)
- [已获得角色强化](implemented/07-owned-talent.png)
- [长祝福列表与固定详情](implemented/08-long-blessings.png)

Godot 4.6.2 / Vulkan Mobile / Linux 实际渲染。使用隔离场景与测试构筑，未进行整局试玩。新截图的机械师状态为焰阳 I×2、神赐 I×1 / II×2、乘风 I×1、不屈 I×1；后续步骤另加入道具、角色强化与其他祝福测试长内容。

可运行当前测试并重新捕获：

```bash
/home/weathour/.local/bin/godot-4.6.2 --path . --script scripts/tests/character_panel_ui_smoke.gd -- --capture=design/character-info-20261013/implemented
```

无窗口验证可省略 `--capture` 并添加 `--headless`。捕获模式需实际图形渲染。
