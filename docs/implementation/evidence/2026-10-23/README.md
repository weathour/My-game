# 系统框架验证证据

基线为 `9c1472e429af1168ec8e75f4c9adc980427a9235`，环境为Linux、Godot `4.6.2.stable.official.71f334935`。图形检查使用X11、OpenGL Compatibility、NVIDIA RTX 5080。音频设备使用Dummy，验证音源与设置状态，未作声学听感验收。所有游戏检查隔离XDG数据/配置目录。

## 结果入口

- [汇总矩阵](verification-matrix.json)：165项常规smoke，初扫138通过，专项复测后累计143通过、22项失败。每项记录所用日志；不是一次全绿运行。
- [既有失败逐项对照](baseline-failures.md)：剩余22项的当前/未修改基线日志，首条错误逐项匹配。`all-smokes/`保留初扫，`final-checks/`保留19项最终复测；原日志没有改写。
- [故事图形流程](story-ui-graphical.log)、[菜单图形检查](menu-ui-graphical.log)：实际入口、三关事件驱动、检查点、键盘焦点、小窗口和放大正文。截图位于`screenshots/`，已查看。
- [Godot启动/解析](godot-parse.log)、[静态检查](static-checks.log)：后者覆盖文档链接、成就、配置、架构和实际剧情内容。
- [内容包检查](package-content.log)、[包启动](package-boot.log)、[包大小和SHA-256](package.json)。本地包在项目`builds/linux/`，不作为源码提交。
- [密集合成场景](dense-combat.log)及`dense-results/`、[Boss压力复测](boss-stress-recheck.log)：短时间回归，不能证明完整实战性能。CPU/core文件是脚本的占位说明，没有采集发布级逐核profiling。
- [Graphify覆盖审查](graph-coverage.json)、[更新日志](graph-update.log)、[旧图HTML重建](graph-html-restored.log)：CLI成功但GDScript不受支持，因此保留旧图并标明过期。
- [代码校验值](validated-files.sha256)：本轮改动的运行代码、测试、剧情JSON和导出配置，供判断证据是否仍适用。

保存测试故意创建坏JSON与不可写目标；`save_recovery_smoke`的JSON解析诊断是注入结果，以明确断言和成功标记判断。脚本错误、`ERROR:`或缺少成功标记均计失败，即使Godot返回0。图形流程退出时偶有ObjectDB清理警告，不能用这些短测试证明不存在长期泄漏。

## 可重复检查

在仓库根目录为验证进程设置独立路径：

```bash
CHECK_DATA="$(mktemp -d /tmp/my-game-verify.XXXXXX)"
export XDG_DATA_HOME="$CHECK_DATA/data"
export XDG_CONFIG_HOME="$CHECK_DATA/config"
/home/weathour/.local/bin/godot-4.6.2 --headless --path . --quit
python3 scripts/tests/check_story_content.py
/home/weathour/.local/bin/godot-4.6.2 --headless --path . --script scripts/tests/story_progress_smoke.gd
/home/weathour/.local/bin/godot-4.6.2 --headless --path . --script scripts/tests/story_lifecycle_smoke.gd
/home/weathour/.local/bin/godot-4.6.2 --headless --path . --script scripts/tests/system_feedback_smoke.gd
/home/weathour/.local/bin/godot-4.6.2 --path . --rendering-method gl_compatibility --display-driver x11 --audio-driver Dummy --script scripts/tests/story_ui_smoke.gd -- --capture
```

常规入口 `bash scripts/check_project.sh` 已隔离存档并限制单项时限，保留遇错停止行为；**当前仍会被既有失败阻断，不会输出项目全绿**。为了取得全部失败项，本轮用[初扫脚本](run_all_smokes.py)逐项执行，每项50秒、3进程并发。Boss压力初扫超时后以180秒上限单独通过，常规入口已给该项240秒。初扫超时不算已定位的性能回归。

基线使用临时目录里的`git archive 9c1472e`源码，包含运行目录、`shaders/`、项目配置、图标和插件，先导入再运行[对照脚本](run_baseline_smokes.py)。脚本绝对路径记录本机位置，异机需改路径；缺少shader的中间试跑没有用作对照证据。

导出和包内检查沿用上述隔离环境：

```bash
mkdir -p builds/linux
/home/weathour/.local/bin/godot-4.6.2 --headless --path . --export-pack 'Linux development' builds/linux/survivor_like.pck
mkdir -p /tmp/my-game-package-probe
/home/weathour/.local/bin/godot-4.6.2 --headless --path /tmp/my-game-package-probe --script "$PWD/scripts/tests/package_content_check.gd" -- "$PWD/builds/linux/survivor_like.pck"
/home/weathour/.local/bin/godot-4.6.2 --headless --main-pack "$PWD/builds/linux/survivor_like.pck" --quit
```

探针在空目录加载PCK，只从包内取内容与业务代码，验证JSON包含、测试脚本/编译重定向及MCP插件排除，然后执行三关接取/结算/交付。

## 验收边界

未做完整20波人工游玩、正常速度三关战斗通关、长时硬件分析、跨平台测试或公开发行。[独立导出失败](export-executable.log)明确指出模板缺失，PCK可用不代表独立安装包完成。

[PCK导出](export-pack.log)记录成功打包及编辑器退出诊断；[verbose日志](export-pack-verbose.log)将5个仍在引用的资源定位到MCP编辑器插件。该插件不在包内，没有省略这些诊断而宣称“导出零错误”。
