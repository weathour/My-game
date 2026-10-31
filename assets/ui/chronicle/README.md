# 白门楼界面素材

2026-10-27，内置 image_gen 生成。设计依据是用户批准的 D 稿：三国志式朴素地理与人物绘画，兰斯10式操作布局。

- `baimen-terrain.png`：白门楼区域地形，非精确地理，未画入文字与路线。
- `emma.png`：由 D 稿中的艾玛独立重绘，透明背景；启用 mipmaps，避免缩小立绘时产生锯齿。
- `world-relief.png`：大陆尺度的山川纹理；由代码按 Natural Earth 陆地几何裁切。纹理中的山川不作为精确历史水文。

[提示词](../../../design/ui-direction-20261027/runtime-prompts.md)、[来源与哈希](../../../design/ui-direction-20261027/manifest.json)。生成原件保留在本机生成目录，运行文件均已复制进仓库。

商用游戏截图只在被 `.gdignore` 排除的 `design/` 下用于研究，没有导入运行资源。文字、按钮、路线、节点、状态和海陆轮廓由 Godot 绘制，未将试稿当成整屏 UI。

## 九位女性独立立绘

`characters/` 收录九位女性各自的透明全身母版副本。人物详情使用完整立绘，卡片与对白通过 `chronicle_portraits.gd` 的独立构图从同一源图取景；九人对应身份、生成提示词与母版见[素材记录](../../../design/baimen-women-20261028/README.md)。该批 UI 接入专项 headless／真实渲染各 525 项通过（重叠检查不相加）；九人的独立战斗头像与动作亦已接入，验证见[素材记录](../../../design/baimen-women-20261028/README.md)。艾玛沿用已有素材，其他未覆盖人物继续使用原有图集。

## 路线类型图标

2026-10-28 新增的 `route-icons/` 是本作原创 SVG 矢量素材，不取自商业游戏截图。`battle.svg` 为交叉刀剑，`elite.svg` 为护颊战盔，`spring.svg` 为古井水波，`event.svg` 为卷轴，`boss.svg` 为城楼将旗。图标分别用于路线节点、图例和右侧详情；节点状态外框由界面单独绘制。

横向路线继续复用 `baimen-terrain.png` 地形，查看路线时不再用大幅艾玛像遮挡；`emma.png` 仍供其他页面使用。图标合图与实机截图见[本轮证据](../../../docs/implementation/evidence/2026-10-28/route-map/)；实际代码入口及验证见[实施记录](../../../docs/implementation/2026-10-28_横向战役路线图.md)。
