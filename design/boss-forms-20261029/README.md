# 名将人形与战相素材

2026-10-29。曹休、曹纯、张辽、吕布、高顺、陈宫各有一套新制人形全身母版和战斗动作；四名首领先以人形交战，再切换为各自原有战相，高顺与陈宫按张辽阶段使用对应协同形象。六人的可招募形象与敌方人形使用同一人物来源，战斗表现仍按各自身份和能力区分。玩法与验证见[Boss深化执行记录](../../docs/implementation/2026-10-29_Boss深化与双形态战斗.md)。

## 人物与查看入口

| 人物 | 人形素材与记录 | 我方人物 | 原有战相 |
| --- | --- | --- | --- |
| 曹休 | [B15_human](characters/B15_human/) | M06 | 鬼猎兽相，保留弓与豹体线索 |
| 曹纯 | [B16_human](characters/B16_human/) | M05 | 虎豹甲骑巨相 |
| 张辽 | [B17_human](characters/B17_human/) | M02 | 夜叉裂阵将相 |
| 吕布 | [B18_human](characters/B18_human/) | M01 | 四臂鬼神相 |
| 高顺 | [M03_human](characters/M03_human/) | M03 | 城壁铠魂 |
| 陈宫 | [M04_human](characters/M04_human/) | M04 | 卷轴冥相 |

查看六组人形与战相：[1280宽对照](evidence/forms-1280.png)；[动作预览](evidence/preview.gif)包含 36 个动画样本。对照图每格右上角的「card view」是卡图立绘局部；实际裁脸头像见[我方头像对照](evidence/friendly-head-crops.png)。画面检查和代理实际操作不等于用户已逐张审美确认；用户的后续反馈可用于迭代。

## 制作与来源

六套人形以现有具名人物卡和各自原战相为身份参考，通过内置 ImageGen 生成独立透明全身母版及各 16 个动作姿态源；原战相保留，并为具体招式增加动作映射。人形和鬼怪战相各有独立形象，不通过人形换色代替战相。

每人目录保存提示词、`generation-record.json`、`measurements.json`、源 PNG 和 `export-manifest.json`；源图、运行文件及哈希见各自记录，[汇总清单](manifest.json)列出六套运行清单和来源，[生成来源](generation-origins.json)保留工具保存位置。参考的人物卡为现有临时造型，其来源与发行边界见[卡图素材说明](../../assets/ui/chronicle/cards/README.md)。

吕布初版全身母版的羽冠触顶，修订后采用完整的 `master-v2`；`actions-v2` 因人物姿态重叠未采用，动作选用 `actions-v1`。吕布与曹纯动作源的第 4 个移动姿态触边，因此运行时各使用 3 帧移动，其余四人各使用 4 帧。

## 导出与接入

每套动作包含待机 4、移动 3 或 4、攻击 4、特殊 3、受击 2、死亡 2 帧；特殊动作复用 3 个攻击姿态。六套合计 **112 个命名动画帧、94 个不重复运行姿态**，输出 **42 个运行 PNG 和 48 个可编辑 Aseprite 文件**。运行战斗帧统一为 640×512，脚底锚点为 `(288, 480)`，人物基准身体高度为 224 像素；按共同源尺度和脚底对齐，不逐姿态拉伸。战斗动作采用二值 Alpha 与最近邻采样，全身立绘保留原 RGBA。

各套不透明人物共同色数依次为曹休 59、曹纯 57、张辽 63、吕布 62、高顺 57、陈宫 58。可招募人物的卡图、剧情立绘、战斗身体和头像均与对应人形同源；头像由素材中实际头部区域 `head_rect_px` 裁出，并非另绘头像。我方战斗角色按约 72 的人物尺度显示，使用独立动画节点；成功施放、手动动作优先、暂停及朝向已纳入专项检查。

从项目根目录重新导出：

```bash
python3 design/boss-forms-20261029/prepare_exports.py
for boss_human_id in B15_human B16_human B17_human B18_human M03_human M04_human; do
  /home/weathour/programs/aseprite-src/build/bin/aseprite --batch --script-param "id=$boss_human_id" --script scripts/tools/import_boss_forms_art.lua
done
python3 design/boss-forms-20261029/finalize_exports.py
python3 design/boss-forms-20261029/audit_exports.py --all
/home/weathour/.local/bin/godot-4.6.2 --headless --editor --path . --quit
/home/weathour/.local/bin/godot-4.6.2 --headless --path . --quit
```

## 本轮检查与边界

六套素材审计通过；[我方素材专项](../../scripts/tests/boss_friendly_art_smoke.gd) headless 与真实 OpenGL 各 **146 项**通过，重叠检查不相加，[渲染日志](evidence/friendly-art-render.log)保留。六组人形／战相的三尺寸对照与 36 个动画样本通过真实渲染检查，见[预览日志](evidence/forms-art-render.log)；吕布在隔离环境重新导出的 7 个 PNG 与现用文件逐字节一致。源图连通分组、脚底锚点和姿态由制作过程检查，主代理已审看三尺寸对照、头像及我方同人外观，完成本轮视觉接入复核；用户尚未逐张审美确认。最终完整战斗回放及总体回归以[执行记录](../../docs/implementation/2026-10-29_Boss深化与双形态战斗.md)为准。
