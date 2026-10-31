# 白门楼女性人物战斗素材

九位女性的战斗像素动作与独立头像由各自的[全身母版](../../../design/baimen-women-20261028/README.md)派生；本轮用户看过母版后要求继续制作。九人均已导出并接入，完整结果和验证以[素材记录](../../../design/baimen-women-20261028/README.md)与[当前状态](../../../docs/08_当前实现状态与后续重点.md)为准。

每个人物目录包含 `idle`、`run`、`attack`、`cast` 四组横排 PNG 及同名可编辑 Aseprite 文件；每组分别为 4、8、4、4 帧。`head.aseprite` 为独立 64×64 头像，`head.png` 用最近邻放大为 128×128。场景与 `women_visual.gd` 提供人物动作；独立头像由 `women_portrait.gd` 显示。普攻或攻击技能使用攻击动作，治疗、回魔、护盾等辅助技能使用独立施法动作；伤害、资源和技能特效仍由现有战斗系统负责。

每帧画布为 192×192，脚底锚点 `(96, 176)`；同一人物各动作按站姿统一尺度，站姿可见身体以 80 像素为基准。导出的战斗像素帧使用二值 alpha，各人物 20 帧共享调色板至多 63 个不透明色。九人的实际尺寸、颜色数、帧数和 SHA-256 见[导出清单](../../../design/baimen-women-20261028/export-manifest.json)；源图、所用提示词、身份和技法参考见[派生记录](../../../design/baimen-women-20261028/derivatives.json)。原始全身立绘的半透明边缘不套用像素帧二值规则。

蕾娜原图的两格攻击帧因剑尖与邻帧披风粘连而弃用，单独生成的补画源替换攻击第 3、4 帧；其余 18 帧仍用原源图，补画量测采用 `80/595` 尺度。详情见[素材记录](../../../design/baimen-women-20261028/README.md)和[逐帧量测](../../../design/baimen-women-20261028/export-measurements.json)。

## 复现入口

先查看并确认该角色的源图与[逐帧量测](../../../design/baimen-women-20261028/export-measurements.json)，包括独立连通区域、脚底和动作；生成图不保证规则网格，不应盲切。下例仅重导出 F03，命令会覆盖该人物的导出 PNG 与 Aseprite 文件；重新生成源图后须先重新量测，不能沿用过期坐标。

```bash
aseprite --batch --script-param id=F03 --script scripts/tools/import_baimen_women_art.lua
python3 design/baimen-women-20261028/audit_exports.py
```

Aseprite 负责切帧、登记锚点、统一调色板及导出；图像内容由内置 ImageGen 制作。只读图像检查会核对尺寸、帧数、色数、二值透明与源图哈希，并刷新导出清单；动作观感及实际游戏内呈现仍需独立检查。
