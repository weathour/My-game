# 十二首离线试听：音乐与音源来源

本轮从第三方器乐 cover 的自动 MIDI 扒谱派生试听，并非项目原创作品，也不是原录音多轨。音源的使用声明与音乐作品及原伴奏的权利属于不同事项。首轮已交付三首按原文件复用，新增九首的实际分配见逐曲渲染报告。

## 中国器乐采样

- **DSK Asian DreamZ SF2**：DSK Music／Victor Castilla，[官方产品页](https://www.dskmusic.com/dsk-asian-dreamz/)。发布者声明其虚拟乐器免费供私人和商业用途使用；这不是 CC0，公开声明及随包说明未明确授予独立再分发原始采样的许可。原 SF2 和导出原始采样仅保留在本机缓存，不复制到试听包。
- 音源 SF2 SHA-256：`e61d0f590db00434fa1a904ab210fdf4439fef13617d89d33eacc8edfc403e5e`。本轮采用厂商标记为 PIPA、LUAN、GUZHEN、ERHU 的采样，分别在制作计划中作为琵琶、阮类、古筝、二胡音色；LUAN 的具体阮种及演奏者、录音链没有独立证据。音名是厂商标识，不证明全部采样录音细节。
- 音域延伸可能使用采样转调，不证明实际乐器的可演奏音域；长音区域的循环方式以逐曲报告为准。没有已取得的可靠笙或扬琴音源；Berklee BISA 二胡未用于本轮。

## 当前 C 版沿用的音源

- **MuldjordKit**：由 Lars Muldjord 录制、Roberto 为 FreePats 整理的 2020-10-18 立体声 SF2 版本；[原始页面](https://freepats.zenvoid.org/Percussion/acoustic-drum-kit.html)，[CC BY 4.0 许可](https://creativecommons.org/licenses/by/4.0/)。原 C 版将输入的 GM 鼓角色映射到该套鼓并处理声音；这不表示创作者为本项目背书。
- **Emilyguitar 与 Fashionbass**：Karoryfer 的[吉他](https://github.com/sfzinstruments/karoryfer.emilyguitar)和[贝司](https://github.com/sfzinstruments/karoryfer.fashionbass)采样，许可为 [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/)；C 版对干直入声音使用程序化音色处理。
- **VSCO 2 Community Edition**：按原音源清单使用的 [VSCO 2 CE](https://github.com/sgossner/VSCO-2-CE) 钢琴采样，许可记录为 CC0 1.0；程序化合成声由项目引擎生成。
- **GeneralUser GS 2.0.3**：S. Christian Collins 的 [GeneralUser GS](https://github.com/mrbumpy409/GeneralUser-GS) 为原 C 版中 MuldjordKit 缺失的 GM 54 铃鼓提供兜底，其许可为该库自带文本，不能标为 CC0；上游许可也记录了部分历史样本来源的不确定性。

Attribution: MuldjordKit by Lars Muldjord; FreePats stereo SF2 version assembled by Roberto, version 2020-10-18, licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The project maps GM drum roles to kit keys and processes the rendered sound; no endorsement by the creators is implied.

原始十二首的音源锁定及许可文本见仓库内 `design/music-20261103-midi-test/THIRD_PARTY_NOTICES.md` 与 `design/music-20261103-midi-test/sources/instrument-sources.json`；DSK 细项及首轮三首记录见 `design/music-20261104-chinese-trial/sources/lock.json`。本轮各曲实际使用情况以逐曲报告为准。
