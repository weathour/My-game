# 技能悬停与四张卡牌的信息排布

用户确认保留原有四张弹出纸牌、暗金基调，基于 `approved-card-direction.png` 的信息层级实现。卡牌图案与场景继续使用现有资源；生成图只作方向参考。

- [确认的布局示意](approved-card-direction.png)
- [原四卡界面](current/current-upgrade-cards.png)
- [原祝福黑底黑字问题](current/current-blessing-detail.png)
- [原技能悬停](current/current-hud-tooltip.png)
- [实装四卡与升级详情](implemented/four-cards-upgrade.png)
- [实装新技能详情](implemented/four-cards-new-skill.png)
- [实装祝福详情](implemented/four-cards-blessing.png)
- [长祝福卡面](implemented/long-blessing-cards.png)
- [天赋占位卡](implemented/talent-cards.png)
- [960×540 窗口](implemented/four-cards-960.png)
- [战斗技能悬停](implemented/combat-tooltip.png)
- [队伍状态带悬停](implemented/team-tooltip.png)
- 旧选卡评审已随新设计删除，历史可从Git查阅。本目录保留素材来源，不能据此恢复技能选卡；当前方向见[设计共识](../../docs/00_当前设计共识.md)。

实装图由实际 Godot 控件和 Player 生成的数据捕获，使用隔离背景；不是完整关卡试玩。逻辑基准 1280×720，960×540 图按项目 `canvas_items` 规则缩放。

复现：

```bash
/home/weathour/.local/bin/godot-4.6.2 --path . --rendering-method gl_compatibility --audio-driver Dummy --script scripts/tests/skill_info_ui_smoke.gd -- --screenshots=/tmp/my-game-ui-check
```

示意图数字不是数值规格。实装的剑士普攻分开展示等级伤害加成与本次增量；炮台读取当前标准部署数据。天赋效果与缺失等级成长未由本轮 UI 补成玩法。

验证：Godot 4.6.2 无头启动、上述界面检查（无头和图形模式）、选卡重开、技能等级、剑士成长、机械师角色与美术冒烟检查均通过。完整一局试玩与跨平台字体尚未验证。
