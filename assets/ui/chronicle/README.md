# 白门楼界面素材

2026-10-27，内置 image_gen 生成。设计依据是用户批准的 D 稿：三国志式朴素地理与人物绘画，兰斯10式操作布局。

- `baimen-terrain.png`：白门楼区域地形，非精确地理，未画入文字与路线。
- `emma.png`：由 D 稿中的艾玛独立重绘，透明背景；启用 mipmaps，避免缩小立绘时产生锯齿。
- `world-relief.png`：大陆尺度的山川纹理；由代码按 Natural Earth 陆地几何裁切。纹理中的山川不作为精确历史水文。

[提示词](../../../design/ui-direction-20261027/runtime-prompts.md)、[来源与哈希](../../../design/ui-direction-20261027/manifest.json)。生成原件保留在本机生成目录，运行文件均已复制进仓库。

商用游戏截图只在被 `.gdignore` 排除的 `design/` 下用于研究，没有导入运行资源。文字、按钮、路线、节点、状态和海陆轮廓由 Godot 绘制，未将试稿当成整屏 UI。
