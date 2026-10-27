# 主线人物卡面素材

2026-10-27：本目录为界面重排使用的临时图集，不代表人物最终定稿。

| 透明图集 | 保留的原图 | 分格与用途 |
| --- | --- | --- |
| `named-transparent.png` | `named.png` | 4 × 2，共8格，具名三国人物临时肖像 |
| `common-transparent.png` | `common.png` | 3 × 2，共6格，普通兵种按人物映射和改色复用 |
| `companions-transparent.png` | `companions.png` | 4 × 3，共12格，伙伴及部分普通卡的临时肖像 |

三张图共26个肖像单元，透明图集复用、艾玛既有的 [`emma.png`](../emma.png) 与主角独立的 `jia.png` 共同呈现38条人物目录；主角卡和人物详情使用已确认外貌的[起家立绘](../../../../design/jia-weisuo-20261027/jia-standing-v1.png)，战斗仍用旧剑士。具体图集分格、人物映射及兵种色变见 [`chronicle_portraits.gd`](../../../../scripts/ui/chronicle/chronicle_portraits.gd)。这些资源只影响呈现，不代表其余人物战斗机制已完成。

三张透明图集使用 ImageGen 从对应原图生成，均为RGBA且保持原分格；[透明版清单](../../../../design/card-rarity-20261027/manifest.json)记录来源与哈希。人物、稀有度卡底、边框和文字分层。普通蓝、稀有紫、传说金橙及主角专属朱红的分类与接入状态见[实施记录](../../../../docs/implementation/2026-10-27_人物稀有度与编队加成.md)；稀有度不决定抽率或章末保底，章末重要人物资格仍按 `kind` 判断。

图集由 ImageGen 为本项目生成，来源、尺寸和哈希见[生成清单](../../../../design/ui-reflow-20261027/generated-manifest.json)，提示词见[生成提示](../../../../design/ui-reflow-20261027/prompts.json)。八张具名三国人物卡的造型参考《火凤燎原》，并非逐人定稿复刻；[参考来源](../../../../design/ui-reflow-20261027/reference/sources.json)中两项来自作者官网，高顺图为新浪转载的次级图源。商业参考图片仅用于研究，不作为游戏运行贴图。参考衍生设计不等于已取得对应角色设计的发行授权，公开发行前仍须核查或替换。
