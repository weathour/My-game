# 三首离线试听：音乐与音源来源

这三首试听从第三方器乐 cover 的自动 MIDI 扒谱派生，并非项目原创作品，也不是原录音多轨。音源的使用声明与音乐作品及原伴奏的权利属于不同事项。本文件随试听目录提供，用于记录来源及实际音源边界。

## 中国器乐采样

- **DSK Asian DreamZ SF2**：DSK Music／Victor Castilla，[官方产品页](https://www.dskmusic.com/dsk-asian-dreamz/)。发布者声明其虚拟乐器免费供私人和商业用途使用；这不是 CC0，公开声明及随包说明未明确授予独立再分发原始采样的许可。本轮的原 SF2 和导出原始采样仅保留在本机缓存，不复制到试听包。
- SF2 的 SHA-256：`e61d0f590db00434fa1a904ab210fdf4439fef13617d89d33eacc8edfc403e5e`。厂商在音源中标注 PIPA、PIPA TREM、LUAN、GUZHEN、ERHU、BAN-DI 和 Chinese Percussion；渲染计划可将它们称作琵琶、轮指琵琶、阮、古筝、二胡、笛子和中国打击乐。LUAN 的具体阮种及演奏者、录音链没有独立证据；音名以发布者标识为准，不能因此声称已核验全部真实录音细节。
- 映射音域可能超过实际采样根音范围，属于采样转调，不证明乐器的真实可演奏音域。长音区域的循环方式以逐曲报告为准；不能从样本头存在循环点就断言所有区域会循环。
- Berklee BISA 二胡与此前调研的其他候选音源未用于本轮试听。没有已取得的可靠笙或扬琴音源；本次实际使用厂商标记为 PIPA、LUAN、ERHU 和 GUZHEN 的音色，逐曲分配以渲染记录为准。

## 当前 C 版沿用的音源

- **MuldjordKit**：由 Lars Muldjord 录制、Roberto 为 FreePats 整理的 2020-10-18 立体声 SF2 版本；[原始页面](https://freepats.zenvoid.org/Percussion/acoustic-drum-kit.html)，[CC BY 4.0 许可](https://creativecommons.org/licenses/by/4.0/)。原 C 版将输入的 GM 鼓角色映射到该套鼓并处理声音；这不表示创作者为本项目背书。
- **Emilyguitar 与 Fashionbass**：Karoryfer 的[吉他](https://github.com/sfzinstruments/karoryfer.emilyguitar)和[贝司](https://github.com/sfzinstruments/karoryfer.fashionbass)采样，许可为 [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/)；C 版对干直入声音使用程序化音色处理。
- **VSCO 2 Community Edition**：按原音源清单使用的 [VSCO 2 CE](https://github.com/sgossner/VSCO-2-CE) 钢琴采样，许可记录为 CC0 1.0；程序化合成声由项目引擎生成。
- **GeneralUser GS 2.0.3**：S. Christian Collins 的 [GeneralUser GS](https://github.com/mrbumpy409/GeneralUser-GS) 原 C 版为《Disposable Teens》中 MuldjordKit 缺失的 GM 54 铃鼓提供兜底，其许可为该库自带文本，不能标为 CC0。上游许可也记录了部分历史样本来源的不确定性；具体每版是否沿用该音色以渲染报告为准。

Attribution: MuldjordKit by Lars Muldjord; FreePats stereo SF2 version assembled by Roberto, version 2020-10-18, licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The project maps GM drum roles to kit keys and processes the rendered sound; no endorsement by the creators is implied.

原始 12 首制作的锁定版本、哈希、许可文本和处理见仓库内 `design/music-20261103-midi-test/THIRD_PARTY_NOTICES.md` 与 `design/music-20261103-midi-test/sources/instrument-sources.json`；本轮 DSK 细项见 `design/music-20261104-chinese-trial/sources/lock.json` 和逐曲报告。上述资料为来源记录，不代表本轮已完成人工听审或公开发行。
