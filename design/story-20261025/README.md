# 主线场景与叙事呈现 · 2026-10-25

本目录保留当前主线界面的改造前后图形证据。实施规则与测试边界见 [设计评审](../../docs/design-reviews/2026-10-25_主线场景与叙事呈现.md)。

## 原创场景

运行资源：[communications_camp.png](../../assets/story/communications_camp.png)。使用内置 ImageGen 生成，2026-10-25；没有将相邻水仙仓库的文本、图片或音乐复制进本项目。原始生成文件保留在 Codex generated_images 中，游戏只引用仓库内资源。

最终生成提示词：

```text
Use case: illustration-story. Asset type: original 16:9 background illustration for a Godot pixel-art narrative game, 1536x864 or similarly wide. Draw a beautifully art-directed pixel-art nighttime communications outpost after rain. View from inside an open wooden field hut toward a quiet abandoned forest road and distant blue-green mountains. On the right half, a small wooden desk under a warm amber lamp with a compact old field radio, a folded weather log, a small glass vial and a few cables, a simple empty chair. On the far right a support post and climbing plants frame the view. Left half is calm deep navy open night and layered mountain silhouettes, suitable for overlay of chapter title without detailed objects. A narrow worn footpath leads out of the hut toward a very distant dark watchtower, tiny amber window, mist near ground. No people. Evoke waiting for a reply, quiet human absence, restrained hope. Medium: excellent professional hand-placed pixel art, deliberate clusters, crisp pixels, low detail density, original 2D RPG cinematic environment, not smooth painting and not 3D. Palette: ink navy #101923, muted teal slate foliage, desaturated blue distance, localized honey amber lights, pale warm reflections, no purple. Composition: desk centered around x=74%, y=64%; horizon at y=42%, foreground mostly dark. Landscape must read well cropped to a wide cinematic band. No UI, no frames, no writing, no logo, no watermark, no decorative stars, no moon, no copied game characters or recognizable scenes.
```

## 图形证据

- before-01-preparation-1280.png：改造前主线准备页。
- preparation-1280.png / preparation-960.png：当前主线准备页。
- completed-960.png：三关交付完成后的营地、物件与重访入口。
- reading-choices-1280.png：有选择的剧情阅读。
- reading-choices-large-960.png：960×540、120%剧情字号下的选择。
- reading-large-960.png：960×540、120%剧情字号下的叙述。
- reading-history-large-960.png：已见旁白与台词回看。

检查来自实际 Godot OpenGL 渲染。截图中的任务进度由隔离存档和真实 UI 流程产生，测试以关卡胜利事件代替完整战斗。结算截图可能含正常触发的成就通知；它不属于新剧情界面。

## 验证结论

主线三关图形流程、物件只读检查、全部29节点在960×540及120%文字下的阅读边界、进度/生命周期/保存恢复/菜单检查通过。整仓检查停于已有`developer_catalog_smoke`失败，Graphify安装包仍不支持`.gd`提取，保留旧图并标记过期。具体日志与限制见设计评审。
