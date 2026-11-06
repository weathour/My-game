# 十二首 MIDI 换音色本地测试

本目录记录 2026-11-03 的 C 版生产基线，下文测试包也属于 C 版。当时使用的 `assets/music/midi_test/` 十二首 OGG 现已替换为 D2，当前游戏版本见[D2 接入记录](../../docs/implementation/2026-11-04_中国器乐D2游戏接入.md)。当时 D2 本地包入口为 `builds/linux-chinese-d2-20261104/run.sh`，`builds/` 不随 Git 分发。

状态：12 首音频及游戏接入已完成，完整工程、本地测试包和玩家文件对账检查通过；实际听审尚未完成。本目录记录制作输入、安排与结果；它不是公开发行或最终配乐完成的证明。

## 入口

- [测试目标与冻结边界](../../docs/implementation/2026-11-03_十二首MIDI原曲换音色效果测试目标.md)：原音乐事件保持不变，保留电吉他、贝司和套鼓骨架，允许换音源与少量同音符叠色。
- [第一章音乐对应表](../../docs/implementation/2026-11-03_第一章音乐对应表.md)：战斗、剧情、泉水与界面的测试安排。
- [实验清单](experiment-manifest.json)：12 首输入、哈希、对照材料和旧曲保留范围。
- [章节映射](chapter-music-map.json)：节点、事件、逐句覆盖、界面及路径覆盖的机器可读记录。
- [冻结 MIDI 副本](inputs/)；[音源与许可说明](THIRD_PARTY_NOTICES.md)；[逐曲渲染记录](reports/)；[音频汇总报告](audio-production-release-report.json)。
- [运行验证报告](runtime/validation-report.json)；[旧资源清退记录](runtime/retired-assets.json)；[玩家文件对账](player-data-after.json)；[完成核验索引](completion-verification.json)。

输入由第三方器乐 cover 自动扒为 MIDI，并非原版录音多轨；本批所有音符的力度均为 100。12 个源文件保持只读，42063 个源音符的起止配对已对照事件日志核验；其中 15106 个鼓音符也单独核对了源起止与触发映射。鼓采用 one-shot 采样自然衰减和闭镲截断开放踩镲尾音，音源映射的临时控制流不逐字保留源 note-off，不能称临时派生 MIDI 与源文件完全相同。技术检查与路径覆盖不能代替人的听审和游玩。

## 已生成的试听文件

每首当时产出游戏 OGG、24-bit FLAC 和 MP3；当时 OGG 写入 `assets/music/midi_test/`，当前路径的版本见[D2 接入记录](../../docs/implementation/2026-11-04_中国器乐D2游戏接入.md)，其余两种格式位于本机对应曲目目录。以下播放列表为仓库外的本机文件，不随 Git 分发；[列表生成脚本](tools/build_playlists.py)需要原音频和清单中的本机路径：

- 全部 A／B／C 对照：`/home/weathour/音乐/Marilyn-Manson-伴奏学习/扒谱试验/MuScriptor-large/全部完整伴奏_全曲对照/全部A-B-C对照播放.m3u8`，依次试听原伴奏、GeneralUser GS 重放及新音色。
- 全部 C 版新音色：`/home/weathour/音乐/Marilyn-Manson-伴奏学习/扒谱试验/MuScriptor-large/全部完整伴奏_全曲对照/全部C音色试听.m3u8`，仅试听新音色版本。

对照版按既有 A／B 目标做静态响度匹配；游戏 OGG 使用单独的固定衰减。渲染报告逐首记录声部音色、处理、文件哈希和响度测量。音频和运行检查不代表主观效果已经通过。

## 本地游戏测试

当时本地 C 版测试包在仓库根目录使用以下脚本启动；`builds/` 不随 Git 分发，克隆后不保证该脚本存在。包的检查范围见[运行验证报告](runtime/validation-report.json)：

```bash
./builds/linux-midi-test-20261103/run.sh
```

脚本使用包内的 Godot 4.6.2 与独立 PCK，测试进度和设置写入包内 `test-user-data/`，与现有玩家目录分开。标题和菜单可进入音乐鉴赏；单次路线未必听完整首，可在鉴赏中逐首试听。
