# 主线人物卡面素材

2026-10-27：本目录为界面重排使用的临时图集，不代表人物最终定稿。

| 透明图集 | 保留的原图 | 分格与用途 |
| --- | --- | --- |
| `named-transparent.png` | `named.png` | 4 × 2，共8格，具名三国人物临时肖像 |
| `common-transparent.png` | `common.png` | 3 × 2，共6格，普通兵种按人物映射和改色复用 |
| `companions-transparent.png` | `companions.png` | 4 × 3，共12格，伙伴及部分普通卡的临时肖像 |

三张图共26个肖像单元，继续供未被独立立绘覆盖的人物使用；艾玛沿用 [`emma.png`](../emma.png)，主角使用 `jia.png`。九位女性已改用各自的 [`characters/`](../characters/) 透明全身母版：卡面取上半身，人物详情使用全身图，剧情使用独立对白构图。主角战斗已接入其独立动作，不再使用旧剑士战斗素材。具体映射、取景及兵种色变见 [`chronicle_portraits.gd`](../../../../scripts/ui/chronicle/chronicle_portraits.gd)；美术替换不改变人物身份或技能规则。

三张透明图集使用 ImageGen 从对应原图生成，均为RGBA且保持原分格；[透明版清单](../../../../design/card-rarity-20261027/manifest.json)记录来源与哈希。人物、稀有度卡底、边框和文字分层。普通蓝、稀有紫、传说金橙及主角专属朱红的分类与接入状态见[实施记录](../../../../docs/implementation/2026-10-27_人物稀有度与编队加成.md)；稀有度不决定抽率或章末保底，章末重要人物资格仍按 `kind` 判断。

图集由 ImageGen 为本项目生成，来源、尺寸和哈希见[生成清单](../../../../design/ui-reflow-20261027/generated-manifest.json)，提示词见[生成提示](../../../../design/ui-reflow-20261027/prompts.json)。八张具名三国人物卡的造型参考《火凤燎原》，并非逐人定稿复刻；[参考来源](../../../../design/ui-reflow-20261027/reference/sources.json)中两项来自作者官网，高顺图为新浪转载的次级图源。商业参考图片仅用于研究，不作为游戏运行贴图。参考衍生设计不等于已取得对应角色设计的发行授权，公开发行前仍须核查或替换。
