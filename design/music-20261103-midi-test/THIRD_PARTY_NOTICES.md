# 十二首 MIDI 本地测试：来源与音源说明

本轮以第三方器乐 cover 自动扒谱得到的 12 首 MIDI 为输入，并用下列音源渲染游戏测试音乐。曲目并非本项目原创；原伴奏、扒谱输入及其哈希对应关系见[实验清单](experiment-manifest.json)。音源许可不等同于输入音乐作品及其原伴奏的许可。

## 音源和署名

| 用途 | 来源与许可 | 本轮使用 |
|---|---|---|
| 套鼓 | [FreePats MuldjordKit](https://freepats.zenvoid.org/Percussion/acoustic-drum-kit.html)，Lars Muldjord 录制，Roberto 为 FreePats 整理 2020-10-18 立体声 SF2 版本；[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)，[许可文本](sources/muldjordkit/LICENSE.txt)及[上游说明](sources/muldjordkit/README.txt)已保留。 | 将输入的 GM 鼓角色映射到该 SF2 的对应键位，并用于渲染和声音处理；键位映射及文件哈希见[音源清单](sources/instrument-sources.json)。 |
| 电吉他 | Karoryfer [Emilyguitar](https://github.com/sfzinstruments/karoryfer.emilyguitar)，[CC0 1.0](sources/karoryfer/Emilyguitar-LICENSE)，固定版本见音源清单。 | 使用干直入采样，加入程序化音箱饱和及频率处理。 |
| 电贝司 | Karoryfer [Fashionbass](https://github.com/sfzinstruments/karoryfer.fashionbass)，[CC0 1.0](sources/karoryfer/Fashionbass-LICENSE)，固定版本见音源清单。 | 使用干直入采样，加入轻度饱和及频率处理。 |
| 铃鼓兜底 | S. Christian Collins 的 [GeneralUser GS 2.0.3](https://github.com/mrbumpy409/GeneralUser-GS)，[上游许可全文](sources/generaluser/GeneralUser-GS-LICENSE.txt)已保留。 | MuldjordKit 不含输入的 GM 54 铃鼓；《Disposable Teens》的该角色使用 GeneralUser 音源兜底，未将其余鼓声整体替换为该音源。 |
| 辅助钢琴 | VSCO 2 Community Edition 的 Upright Piano Nr1，音源来源及 CC0 记录见[旧制作音源说明](../music-20261030/THIRD_PARTY_NOTICES.md)。 | 用于输入中已有的钢琴声部。 |
| 合成声 | 项目旧音频引擎的程序化音色，见[引擎](../music-20261030/audio_engine.py)。 | 用于输入中已有的合成声部。 |

Attribution: MuldjordKit by Lars Muldjord; FreePats stereo SF2 version assembled by Roberto, version 2020-10-18, licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). This project maps the source drum roles to the kit and processes its sound in the rendered music; no endorsement by the creators is implied.

GeneralUser GS 的许可文件也记载了上游对部分历史采样来源的说明；具体内容以保留的原文为准。B 版对照使用该 SoundFont 的默认重放；它与 C 版中的单项铃鼓兜底应分别理解。

## 制作工具和记录

鼓音源使用本地 FluidSynth 2.3.4 渲染；工具及固定依赖见[工具链清单](sources/render-toolchain.lock.json)和[本地配置脚本](sources/setup-user-renderer.sh)。各曲使用的声部映射、处理参数和输出哈希见[逐曲报告](reports/)及[音频汇总报告](audio-production-release-report.json)。这些工具用于本地生产，不表示游戏运行时需要安装它们。
