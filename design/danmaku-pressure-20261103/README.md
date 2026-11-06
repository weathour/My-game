# 第一章怪群压力与 Boss 弹幕升级

状态：战斗升级已完成工程接入，Godot 4.6.2 完整检查及本地测试包专项通过；真实玩家的手感和难度判断尚未完成。

[实施目标与验收](../../docs/implementation/2026-11-03_怪群压力与Boss弹幕升级.md)记录用户已确定的方向、4 世界单位真实受击圈、选择性预警、B18 独战及奖励／存档／音频保护边界。敌人身份与旧版设计见[敌人图鉴](../../docs/18_白门楼敌人图鉴与战斗规格.md)，具体运行行为以当前代码与数据为准。

本目录保存配置对照、运行时保护输入、密度与走位验证、三尺寸画面和检查证据。可从[运行验证报告](runtime/validation-report.json)、[独立验收摘要](validation/acceptance_summary.json)、[画面核验](runtime/presentation-review.json)和[测试包记录](runtime/package-integrity-review.json)追溯；静态数据检查不能证明实际刷怪压力、躲避公平性、帧耗或用户体验。固定 12 级队伍的吕布连续两形态测试有中心起点失败样本，不能用两条自动通关路线掩盖。

## 本地游戏测试

当时本地测试包在仓库根目录使用以下脚本启动；`builds/` 不随 Git 分发，克隆后不保证该脚本存在。包的检查范围见[测试包记录](runtime/package-integrity-review.json)：

```bash
./builds/linux-danmaku-pressure-20261103/run.sh
```

测试包使用独立的 `test-user-data/`，不会自动载入正式存档。包的常规启动、功能和有序卸载检查通过；短帧图形强制退出偶发的旧音频尾引用诊断见[已知问题](../../docs/KNOWN_ISSUES.md)。
