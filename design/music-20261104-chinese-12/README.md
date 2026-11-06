# 全十二首中国器乐与调式试听

状态：十二首离线试听已完成音频制作和技术检查。用户认可的首轮三首 The Beautiful People、Disposable Teens、Man That You Fear 的全曲、短对照、MIDI 和分部计划按原文件复用；其余九首为本轮新制作。用户对首轮的认可不代表已听审新增九首。

后续已将十二首 D2 重新导出并接入游戏，原有场景分配不变；音频、音乐专项、完整工程及本地测试包检查通过，实际听感仍待反馈。范围及证据见[D2 游戏接入记录](../../docs/implementation/2026-11-04_中国器乐D2游戏接入.md)。下文离线试听的文件与检查属于当时的交付基线。

- **C**：离线试听交付时游戏音色的响度匹配参考，保留其原有处理。
- **D1**：调整部分声部的器乐音色，源音符事件不变。D1 MIDI 为源 MIDI 的逐字副本；中国器乐分配由分部计划和渲染器执行，普通 MIDI 播放器不会自动还原 D1 音色。
- **D2**：沿用 D1 的器乐分配和混音设置，仅对选定中国器乐旋律骨干作有限的相邻半音音高调整；保留事件数量、时间、力度、速度、鼓、贝司和受保护的吉他骨架。它不是全声部五声化。

C 保留当时游戏成品的处理；D1 与 D2 使用同一新混音流程。既有 C 版中的 The Nobodies、Man That You Fear、Deformography 和 Minute of Decay 使用过总线压缩，而 D1／D2 不使用总线压缩；C 与新版本的动态差异不能全部归因于器乐，比较调式影响时优先听 D1 与 D2。各曲处理见[既有 C 版记录](reports/C-historical-processing.json)。

各曲均提供 C／D1／D2 全曲 FLAC 和 MP3、同一段落各 45 秒的短片段及拼接对照。全曲在各自曲目内匹配响度，十二首之间目标可能不同；短片段另作组内匹配。五份本机播放列表按 01—12 顺序排列：

- [先听十二首短对照](</home/weathour/音乐/Marilyn-Manson-伴奏学习/中国器乐全12曲_20261104/先听12首短对照.m3u8>)：每首依次为 C、D1、D2。
- [全部全曲 C／D1／D2](</home/weathour/音乐/Marilyn-Manson-伴奏学习/中国器乐全12曲_20261104/全部12首全曲_C-D1-D2.m3u8>)；[全部中国器乐全曲 D1／D2](</home/weathour/音乐/Marilyn-Manson-伴奏学习/中国器乐全12曲_20261104/仅中国器乐全曲_D1-D2.m3u8>)。
- [连续听 D1 原音高](</home/weathour/音乐/Marilyn-Manson-伴奏学习/中国器乐全12曲_20261104/仅D1_中国器乐原音高.m3u8>)；[连续听 D2 有限调式](</home/weathour/音乐/Marilyn-Manson-伴奏学习/中国器乐全12曲_20261104/仅D2_中国器乐有限调式.m3u8>)。

中国器乐使用首轮锁定的 DSK Asian DreamZ 采样，按曲分配琵琶、阮类、古筝或二胡音色；厂商标记与来源边界见[音源说明](THIRD_PARTY_NOTICES.md)，实际声部和调整数量见[逐曲分配汇总](reports/arrangement-summary.json)。没有可靠的笙或扬琴音源，本轮未使用。

36 个全曲版本均有 FLAC 与 MP3，共 72 个全曲文件；另有 36 段单版短片及 12 条拼接对照。[全曲检查](reports/root-full-file-review.json)、[短对照检查](reports/comparisons.json)和[源文件与 MIDI 事件独立核验](reports/midi-independent-verification.json)通过，首轮三首的原样复用见[复用记录](reports/first-three-reuse.json)。离线交付时 Godot 4.6.2 完整工程检查通过 52 项（48 源码、4 独立 PCK），见[检查报告](verification/project-check-report.json)。听感仍须实际试听；离线交付当时未更换游戏音频或路由，也未制作新游戏包。完整记录见[实施记录](../../docs/implementation/2026-11-04_全十二首中国器乐与调式试听.md)。
