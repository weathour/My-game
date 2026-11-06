# 三首中国器乐与调式试听

状态：The Beautiful People、Disposable Teens、Man That You Fear 的 C／D1／D2 全曲及短对照已生成，音频与 MIDI 专项检查通过；主观听审待进行。本轮不修改原 12 首 MIDI、游戏音乐资源或播放路由，不创建新游戏包。

- **C**：当前游戏音色的响度匹配副本，原文件保留。
- **D1**：调整部分声部的器乐音色，源音符事件不变。D1 MIDI 是源 MIDI 的逐字副本；中国器乐分配记录在制作计划并由渲染器执行，普通 MIDI 播放器不会自动播放出 D1 音色。
- **D2**：与 D1 使用相同编制和处理设置，仅对选定中国器乐旋律骨干作有限音高改写；时间、力度、速度、鼓、贝司与受保护 riff 保持。它不是全声部五声化。

C 沿用现有成品及其既有处理，D1／D2 使用同一新混音流程。特别是《Man That You Fear》的原 C 版已有总线压缩，而新版本没有，因此 C 与新版本的动态差异不全来自换乐器；比较调式调整时优先听 D1 与 D2。

每曲提供三版全曲 FLAC／MP3、每版 45 秒片段、拼接短对照和播放列表，并保留 D1／D2 MIDI、分配计划及差异报告。试听声音以渲染音频为准，不以 MIDI 播放器中的默认音色代替。以下播放列表为本机文件，顺序均为 Disposable Teens、Man That You Fear、The Beautiful People：

- [先听短对照](</home/weathour/音乐/Marilyn-Manson-伴奏学习/中国器乐首轮_20261104/先听短对照.m3u8>)：每曲依次播放 C、D1、D2 的对应片段。
- [全部全曲 C／D1／D2](</home/weathour/音乐/Marilyn-Manson-伴奏学习/中国器乐首轮_20261104/全部全曲_C-D1-D2.m3u8>)；[仅中国器乐全曲 D1／D2](</home/weathour/音乐/Marilyn-Manson-伴奏学习/中国器乐首轮_20261104/中国器乐全曲_D1-D2.m3u8>)。

每首歌的三个版本在各自组内匹配响度，三首歌之间不强制一致；《Man That You Fear》全曲整体较安静。45 秒片段另作组内匹配，不能据此比较三首完整曲的绝对响度。

中国器乐音色取自 DSK Music 的 Asian DreamZ SoundFont，名称按厂商标识记录；音源可用于私人及商业用途，但不标为 CC0，原始音源与导出采样只留在本机缓存。实际分配为：《Disposable Teens》琵琶 508 音、阮类 108 音；《Man That You Fear》二胡 145 音、古筝 371 音；《The Beautiful People》阮类 198 音、琵琶 1 音。厂商 `LUAN` 的具体阮种未确认。没有可靠的笙或扬琴音源，本轮没有使用。音源出处、继承的 C 版乐器及 MuldjordKit 鼓组署名见同目录 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

三个 D1 MIDI 与源 MIDI 逐字一致；D2 分别修改 19、83、100 个选定音符的音高，保留时间、力度、速度、鼓、贝司和受保护吉他声部。《Man That You Fear》有 10 组重复源音因约束产生不同输出的例外，详见逐曲 MIDI 报告。18 个全曲文件均通过解码、非静音、时长和不高于 −3 dBTP 的真峰值检查；[渲染汇总](render-status.json)、[短对照报告](reports/comparisons.json)与 `reports/` 记录哈希和检查范围。完整制作要求见仓库内 `docs/implementation/2026-11-04_三首中国器乐与调式试听.md`；自动指标不等于主观听审通过。

本轮完整工程检查通过 52 项（48 项源码、4 项独立 PCK），详见[检查报告](verification/project-check-report.json)。主页渲染测试夹具在释放场景后等待 0.3 秒，让原生音频线程完成清理；该修订未改游戏生产逻辑或音乐。直接按帧数强制退出时的既有音频诊断仍记在[已知问题](../../docs/KNOWN_ISSUES.md)。
